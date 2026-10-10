-- ============================================================================
--  Purrperty — 04 · RPCs, Storage, and server-side aggregates
-- ============================================================================

-- ============================================================================
--  A. Profile provisioning
-- ============================================================================
--  A profile row is created by the database the moment an auth user exists.
--  Doing it client-side would mean a sign-up that half-succeeds when the app
--  is killed between the two calls.

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
begin
  insert into public.users (id, email, full_name, role, status)
  values (
    new.id,
    new.email,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    'viewer',        -- never taken from client metadata; elevated by create_organization
    'active'
  )
  on conflict (id) do nothing;
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- ============================================================================
--  B. Organization creation and membership
-- ============================================================================

create table if not exists public.organization_invites (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  email           text not null,
  role            user_role not null default 'property_manager',
  invited_by      uuid references public.users (id) on delete set null,
  accepted_at     timestamptz,
  expires_at      timestamptz not null default (now() + interval '14 days'),
  created_at      timestamptz not null default now(),
  unique (organization_id, email)
);

alter table public.organization_invites enable row level security;
alter table public.organization_invites force row level security;

create policy invites_select on public.organization_invites
  for select to authenticated
  using (organization_id = public.current_org_id() and public.is_org_admin());

--  Creates the workspace and makes the caller its owner, atomically.
--
--  This is the only path that grants the `owner` role, which is why it is a
--  function and not an INSERT policy: a client that could insert into
--  organizations directly could also make itself owner of one.
create or replace function public.create_organization(
  p_name text,
  p_slug text default null,
  p_property_type text default null,
  p_portfolio_size text default null
)
returns public.organizations
language plpgsql
security definer
set search_path = public
as $$
declare
  new_org public.organizations;
  base_slug text;
  final_slug text;
  suffix int := 0;
begin
  if auth.uid() is null then
    raise exception 'Not authenticated' using errcode = '42501';
  end if;

  -- One workspace per user. Re-running must not silently orphan the first.
  if public.current_org_id() is not null then
    raise exception 'User already belongs to an organization' using errcode = '23505';
  end if;

  base_slug := regexp_replace(lower(coalesce(nullif(trim(p_slug), ''), p_name)), '[^a-z0-9]+', '-', 'g');
  base_slug := trim(both '-' from base_slug);
  if base_slug = '' then base_slug := 'workspace'; end if;

  final_slug := base_slug;
  while exists (select 1 from public.organizations o where o.slug = final_slug) loop
    suffix := suffix + 1;
    final_slug := base_slug || '-' || suffix::text;
  end loop;

  insert into public.organizations (name, slug)
  values (trim(p_name), final_slug)
  returning * into new_org;

  update public.users
     set organization_id = new_org.id,
         role            = 'owner',
         status          = 'active',
         updated_at      = now()
   where id = auth.uid();

  insert into public.activities (organization_id, actor_user_id, verb, subject_type, subject_id, summary)
  values (new_org.id, auth.uid(), 'created', 'organization', new_org.id,
          'Created workspace ' || new_org.name);

  return new_org;
end;
$$;

grant execute on function public.create_organization to authenticated;

--  Role changes are owner-only and cannot be used to demote the last owner.
create or replace function public.set_member_role(p_user_id uuid, p_role user_role)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_org uuid := public.current_org_id();
  owner_count int;
begin
  if not public.is_org_admin() then
    raise exception 'Only an owner or admin may change roles' using errcode = '42501';
  end if;

  if not exists (
    select 1 from public.users
    where id = p_user_id and organization_id = caller_org
  ) then
    raise exception 'No such member' using errcode = 'P0002';
  end if;

  -- Never leave a workspace without an owner.
  select count(*) into owner_count
  from public.users
  where organization_id = caller_org and role = 'owner' and deleted_at is null;

  if owner_count = 1 and p_role <> 'owner'
     and exists (select 1 from public.users where id = p_user_id and role = 'owner') then
    raise exception 'An organization must keep at least one owner' using errcode = '23514';
  end if;

  update public.users
     set role = p_role, updated_at = now()
   where id = p_user_id and organization_id = caller_org;
end;
$$;

grant execute on function public.set_member_role to authenticated;

create or replace function public.invite_member(p_email text, p_role user_role default 'property_manager')
returns public.organization_invites
language plpgsql
security definer
set search_path = public
as $$
declare
  row_out public.organization_invites;
begin
  if not public.is_org_admin() then
    raise exception 'Only an owner or admin may invite' using errcode = '42501';
  end if;
  if p_role = 'owner' then
    raise exception 'Ownership is transferred, not invited' using errcode = '42501';
  end if;

  insert into public.organization_invites (organization_id, email, role, invited_by)
  values (public.current_org_id(), lower(trim(p_email)), p_role, auth.uid())
  on conflict (organization_id, email)
    do update set role = excluded.role, expires_at = now() + interval '14 days'
  returning * into row_out;

  return row_out;
end;
$$;

grant execute on function public.invite_member to authenticated;

--  Returns everything the app needs to build an AuthSession in one round trip.
create or replace function public.current_session_context()
returns table (
  user_id           uuid,
  email             text,
  full_name         text,
  app_role          text,
  organization_id   uuid,
  organization_name text
)
language sql
stable
security definer
set search_path = public
as $$
  select
    u.id,
    u.email,
    u.full_name,
    public.current_app_role(),
    u.organization_id,
    o.name
  from public.users u
  left join public.organizations o on o.id = u.organization_id
  where u.id = auth.uid();
$$;

grant execute on function public.current_session_context to authenticated;

-- ============================================================================
--  C. Storage
-- ============================================================================
--  Every object path begins with the owning organization id:
--      documents/<org_id>/<document_id>/<filename>
--  so a single policy expression covers every object in the bucket.
--  `public = false` everywhere: files are reached through short-lived signed
--  URLs, never a guessable public link.

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values
  ('documents',   'documents',   false, 26214400,
     array['application/pdf','image/jpeg','image/png','image/heic',
           'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
           'application/vnd.openxmlformats-officedocument.wordprocessingml.document']),
  ('property-images', 'property-images', false, 10485760,
     array['image/jpeg','image/png','image/heic','image/webp']),
  ('avatars',     'avatars',     false, 2097152,
     array['image/jpeg','image/png','image/heic','image/webp']),
  ('attachments', 'attachments', false, 26214400, null)
on conflict (id) do nothing;

--  Reusable predicate: the first path segment is the caller's org.
create or replace function public.storage_path_in_org(object_name text)
returns boolean
language sql
stable
as $$
  select nullif((storage.foldername(object_name))[1], '') is not null
     and (storage.foldername(object_name))[1] = public.current_org_id()::text;
$$;

do $$
declare b text;
begin
  foreach b in array array['documents','property-images','avatars','attachments']
  loop
    execute format($p$
      create policy %I on storage.objects
        for select to authenticated
        using (bucket_id = %L and public.storage_path_in_org(name));
    $p$, b || '_read', b);

    execute format($p$
      create policy %I on storage.objects
        for insert to authenticated
        with check (bucket_id = %L and public.storage_path_in_org(name));
    $p$, b || '_insert', b);

    execute format($p$
      create policy %I on storage.objects
        for update to authenticated
        using (bucket_id = %L and public.storage_path_in_org(name))
        with check (bucket_id = %L and public.storage_path_in_org(name));
    $p$, b || '_update', b, b);

    -- Deleting stored files is restricted to portfolio managers.
    execute format($p$
      create policy %I on storage.objects
        for delete to authenticated
        using (bucket_id = %L and public.storage_path_in_org(name)
               and public.can_manage_portfolio());
    $p$, b || '_delete', b);
  end loop;
end;
$$;

-- ============================================================================
--  D. Server-side aggregates
-- ============================================================================
--  The header cards (occupancy, revenue, open tickets) must reflect the WHOLE
--  portfolio, not the page the client happens to have loaded. Computing them
--  in Postgres is both correct and cheaper than shipping every row.
--
--  `security_invoker = on` makes each view run under the caller's RLS, so a
--  view can never become a way around a policy.

create or replace view public.property_stats
with (security_invoker = on) as
select
  p.id                                                   as property_id,
  p.organization_id,
  count(u.id)                                            as unit_count,
  count(u.id) filter (where u.status = 'occupied')        as occupied_count,
  coalesce(sum(l.rent) filter (where l.status in ('active','expiring')), 0)::numeric(14,2)
                                                         as monthly_revenue,
  count(distinct mr.id) filter (
    where mr.status not in ('completed','cancelled') and mr.deleted_at is null
  )                                                      as open_request_count
from public.properties p
left join public.units u
       on u.property_id = p.id and u.deleted_at is null
left join public.leases l
       on l.unit_id = u.id and l.deleted_at is null and l.status in ('active','expiring')
left join public.maintenance_requests mr
       on mr.property_id = p.id and mr.deleted_at is null
where p.deleted_at is null
group by p.id, p.organization_id;

create or replace view public.portfolio_summary
with (security_invoker = on) as
select
  p.organization_id,
  count(distinct p.id)                    as property_count,
  coalesce(sum(s.unit_count), 0)          as total_units,
  coalesce(sum(s.occupied_count), 0)      as occupied_units,
  coalesce(sum(s.monthly_revenue), 0)::numeric(14,2) as monthly_revenue
from public.properties p
join public.property_stats s on s.property_id = p.id
where p.deleted_at is null
group by p.organization_id;

create or replace view public.tenant_summary
with (security_invoker = on) as
select
  t.organization_id,
  count(*)                                                    as total,
  count(*) filter (where t.status = 'current')                 as active,
  count(*) filter (where exists (
    select 1 from public.payments pm
    where pm.tenant_id = t.id and pm.status in ('scheduled','processing')
      and pm.due_on < current_date
  ))                                                           as overdue,
  count(*) filter (where exists (
    select 1 from public.leases l
    where l.primary_tenant_id = t.id and l.deleted_at is null
      and l.status in ('active','expiring')
      and l.term_end between current_date and current_date + interval '60 days'
  ))                                                           as renewals_soon
from public.tenants t
where t.deleted_at is null
group by t.organization_id;

create or replace view public.maintenance_summary
with (security_invoker = on) as
select
  mr.organization_id,
  count(*) filter (where mr.status not in ('completed','cancelled'))        as open_count,
  count(*) filter (where mr.priority in ('emergency','urgent')
                     and mr.status not in ('completed','cancelled'))        as urgent_count,
  count(*) filter (where mr.assigned_vendor_id is null
                     and mr.status not in ('completed','cancelled'))        as unassigned_count,
  avg(extract(epoch from (mr.resolved_at - mr.created_at)) / 3600.0)
    filter (where mr.resolved_at is not null)                               as avg_resolution_hours
from public.maintenance_requests mr
where mr.deleted_at is null
group by mr.organization_id;

grant select on public.property_stats, public.portfolio_summary,
                public.tenant_summary, public.maintenance_summary
  to authenticated;
