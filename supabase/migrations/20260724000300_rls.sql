-- ============================================================================
--  RentOS — 03 · Row Level Security
-- ============================================================================
--  THREAT MODEL
--  ─────────────────────────────────────────────────────────────────────────
--  The iOS app ships with the anon key. Anyone can extract it, open a REST
--  client, and issue any request they like with a valid JWT. So the client
--  is treated as hostile:
--
--   • The client NEVER supplies organization_id. A BEFORE INSERT trigger
--     overwrites it with the caller's real org, so a forged id is ignored
--     rather than merely rejected.
--   • The client NEVER supplies a role. Roles change only through
--     public.set_member_role(), which requires the caller to be an owner.
--   • Every policy resolves identity from auth.uid() — never from a column
--     the request body controls.
--   • Helper functions are SECURITY DEFINER so they can read public.users
--     without tripping that table's own RLS (which would recurse).
--     They are STABLE, so the planner calls them once per statement.
-- ============================================================================

-- Vendors need a portal login the same way tenants do.
alter table public.vendors
  add column if not exists portal_user_id uuid references public.users (id) on delete set null;
create index if not exists vendors_portal_user_idx
  on public.vendors (portal_user_id) where portal_user_id is not null;

-- ============================================================================
--  Identity helpers
-- ============================================================================

create or replace function public.current_org_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select organization_id
  from public.users
  where id = auth.uid() and deleted_at is null;
$$;

comment on function public.current_org_id is
  'The caller''s organization, resolved from auth.uid(). The only trusted source of org scope.';

create or replace function public.current_user_role()
returns user_role
language sql
stable
security definer
set search_path = public
as $$
  select role
  from public.users
  where id = auth.uid() and deleted_at is null;
$$;

-- Owners and admins may change org settings, billing, and membership.
create or replace function public.is_org_admin()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(public.current_user_role() in ('owner', 'admin'), false);
$$;

-- Anyone who may create and edit portfolio data.
create or replace function public.can_manage_portfolio()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.current_user_role() in ('owner', 'admin', 'property_manager'),
    false
  );
$$;

create or replace function public.can_manage_maintenance()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    public.current_user_role() in ('owner', 'admin', 'property_manager', 'maintenance_coordinator'),
    false
  );
$$;

-- The tenant record belonging to the caller, if they are a renter using
-- the portal rather than a staff member.
create or replace function public.current_tenant_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.tenants
  where portal_user_id = auth.uid() and deleted_at is null
  limit 1;
$$;

create or replace function public.current_vendor_id()
returns uuid
language sql
stable
security definer
set search_path = public
as $$
  select id from public.vendors
  where portal_user_id = auth.uid() and deleted_at is null
  limit 1;
$$;

-- True when the caller is staff (has a users row with an org).
create or replace function public.is_staff()
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select public.current_org_id() is not null
     and public.current_tenant_id() is null
     and public.current_vendor_id() is null;
$$;

-- ============================================================================
--  The app-level role the iOS client asks for at sign-in.
-- ============================================================================
--  Computed here rather than stored, so it cannot drift from the rows that
--  actually grant access. Maps Domain.User.Role onto the four AppRole cases.

create or replace function public.current_app_role()
returns text
language sql
stable
security definer
set search_path = public
as $$
  select case
    when public.current_tenant_id() is not null then 'tenant'
    when public.current_vendor_id() is not null then 'vendor'
    when public.current_user_role() in ('owner', 'admin') then 'owner'
    when public.current_user_role() is not null then 'property_manager'
    else 'tenant'
  end;
$$;

grant execute on function public.current_app_role to authenticated;

-- ============================================================================
--  organization_id is stamped, never accepted
-- ============================================================================

create or replace function public.force_org_id()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  caller_org uuid := public.current_org_id();
begin
  if caller_org is null then
    raise exception 'No organization for the current user' using errcode = '42501';
  end if;
  -- Whatever the client sent is discarded.
  new.organization_id := caller_org;
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'properties','buildings','units','tenants','leases','payments','vendors',
    'maintenance_requests','maintenance_updates','documents','conversations',
    'conversation_participants','messages','notifications','activities','tasks'
  ]
  loop
    execute format(
      'create trigger %I before insert on public.%I
         for each row execute function public.force_org_id()',
      t || '_force_org_id', t
    );
  end loop;
end;
$$;

-- ============================================================================
--  Enable RLS everywhere
-- ============================================================================
--  Note FORCE: without it the table owner bypasses RLS, which quietly
--  defeats the whole scheme when a migration or function runs as owner.

do $$
declare t text;
begin
  foreach t in array array[
    'organizations','users','properties','buildings','units','tenants','leases',
    'payments','vendors','maintenance_requests','maintenance_updates','documents',
    'conversations','conversation_participants','messages','notifications',
    'activities','tasks'
  ]
  loop
    execute format('alter table public.%I enable row level security', t);
    execute format('alter table public.%I force row level security', t);
  end loop;
end;
$$;

-- ============================================================================
--  Organizations
-- ============================================================================

create policy organizations_select on public.organizations
  for select to authenticated
  using (id = public.current_org_id());

create policy organizations_update on public.organizations
  for update to authenticated
  using (id = public.current_org_id() and public.is_org_admin())
  with check (id = public.current_org_id());

--  No INSERT policy on purpose: organizations are created only through
--  public.create_organization(), which also makes the caller its owner.
--  No DELETE policy: deleting a workspace is a support operation.

-- ============================================================================
--  Users (profiles)
-- ============================================================================

create policy users_select_self on public.users
  for select to authenticated
  using (id = auth.uid());

create policy users_select_org on public.users
  for select to authenticated
  using (organization_id = public.current_org_id() and organization_id is not null);

--  A user may edit their own profile but NOT their own role or org.
--  The WITH CHECK re-reads the committed row to prove neither changed.
create policy users_update_self on public.users
  for update to authenticated
  using (id = auth.uid())
  with check (
    id = auth.uid()
    and role = (select role from public.users u where u.id = auth.uid())
    and organization_id is not distinct from
        (select organization_id from public.users u where u.id = auth.uid())
  );

create policy users_update_admin on public.users
  for update to authenticated
  using (organization_id = public.current_org_id() and public.is_org_admin());

-- ============================================================================
--  Portfolio
-- ============================================================================

create policy properties_select on public.properties
  for select to authenticated
  using (
    organization_id = public.current_org_id()
    -- A renter sees only the property they actually live in.
    or id in (
      select l.property_id from public.leases l
      where l.primary_tenant_id = public.current_tenant_id()
    )
  );

create policy properties_write on public.properties
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_portfolio())
  with check (organization_id = public.current_org_id() and public.can_manage_portfolio());

create policy buildings_select on public.buildings
  for select to authenticated
  using (organization_id = public.current_org_id());

create policy buildings_write on public.buildings
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_portfolio())
  with check (organization_id = public.current_org_id() and public.can_manage_portfolio());

create policy units_select on public.units
  for select to authenticated
  using (
    organization_id = public.current_org_id()
    or id in (
      select l.unit_id from public.leases l
      where l.primary_tenant_id = public.current_tenant_id()
    )
  );

create policy units_write on public.units
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_portfolio())
  with check (organization_id = public.current_org_id() and public.can_manage_portfolio());

-- ============================================================================
--  Leasing
-- ============================================================================

create policy tenants_select on public.tenants
  for select to authenticated
  using (
    organization_id = public.current_org_id()
    or id = public.current_tenant_id()
  );

create policy tenants_write on public.tenants
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_portfolio())
  with check (organization_id = public.current_org_id() and public.can_manage_portfolio());

create policy leases_select on public.leases
  for select to authenticated
  using (
    organization_id = public.current_org_id()
    or primary_tenant_id = public.current_tenant_id()
    or public.current_tenant_id() = any (tenant_ids)
  );

create policy leases_write on public.leases
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_portfolio())
  with check (organization_id = public.current_org_id() and public.can_manage_portfolio());

create policy payments_select on public.payments
  for select to authenticated
  using (
    organization_id = public.current_org_id()
    or tenant_id = public.current_tenant_id()
  );

--  Payment rows are written by the payment webhook (service role), never by
--  the app. Staff may correct a memo; they may not invent a "paid" row.
create policy payments_update on public.payments
  for update to authenticated
  using (organization_id = public.current_org_id() and public.is_org_admin())
  with check (organization_id = public.current_org_id());

-- ============================================================================
--  Maintenance
-- ============================================================================

create policy vendors_select on public.vendors
  for select to authenticated
  using (organization_id = public.current_org_id() or id = public.current_vendor_id());

create policy vendors_write on public.vendors
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_maintenance())
  with check (organization_id = public.current_org_id() and public.can_manage_maintenance());

create policy requests_select on public.maintenance_requests
  for select to authenticated
  using (
    organization_id = public.current_org_id()
    or tenant_id = public.current_tenant_id()
    or assigned_vendor_id = public.current_vendor_id()
  );

--  A renter may report an issue, but only against their own unit, and the
--  AI/triage columns are staff-only — see the trigger below.
create policy requests_insert_tenant on public.maintenance_requests
  for insert to authenticated
  with check (
    tenant_id = public.current_tenant_id()
    and unit_id in (
      select l.unit_id from public.leases l
      where l.primary_tenant_id = public.current_tenant_id()
    )
  );

create policy requests_write_staff on public.maintenance_requests
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_maintenance())
  with check (organization_id = public.current_org_id() and public.can_manage_maintenance());

--  An assigned vendor may move their own job forward, nothing else.
create policy requests_update_vendor on public.maintenance_requests
  for update to authenticated
  using (assigned_vendor_id = public.current_vendor_id())
  with check (assigned_vendor_id = public.current_vendor_id());

--  Internal notes are invisible to renters and vendors. Enforced here, so a
--  hand-written REST query cannot read them either.
create policy updates_select on public.maintenance_updates
  for select to authenticated
  using (
    (organization_id = public.current_org_id() and public.is_staff())
    or (
      is_internal = false
      and request_id in (
        select r.id from public.maintenance_requests r
        where r.tenant_id = public.current_tenant_id()
           or r.assigned_vendor_id = public.current_vendor_id()
      )
    )
  );

create policy updates_insert on public.maintenance_updates
  for insert to authenticated
  with check (
    (organization_id = public.current_org_id() and public.can_manage_maintenance())
    or (
      is_internal = false
      and request_id in (
        select r.id from public.maintenance_requests r
        where r.tenant_id = public.current_tenant_id()
           or r.assigned_vendor_id = public.current_vendor_id()
      )
    )
  );

-- ============================================================================
--  Documents
-- ============================================================================

create policy documents_select on public.documents
  for select to authenticated
  using (
    (organization_id = public.current_org_id() and public.is_staff())
    -- Renters see only documents explicitly shared with them.
    or (
      is_visible_to_tenant = true
      and owner_type = 'tenant'
      and owner_id = public.current_tenant_id()
    )
    or (
      is_visible_to_tenant = true
      and owner_type = 'lease'
      and owner_id in (
        select l.id from public.leases l
        where l.primary_tenant_id = public.current_tenant_id()
      )
    )
  );

create policy documents_write on public.documents
  for all to authenticated
  using (organization_id = public.current_org_id() and public.can_manage_portfolio())
  with check (organization_id = public.current_org_id() and public.can_manage_portfolio());

-- ============================================================================
--  Messaging
-- ============================================================================
--  Access is decided by conversation_participants, never by a conversation id
--  supplied in the request. Guessing a UUID gets you nothing.

create or replace function public.is_conversation_participant(target uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select exists (
    select 1 from public.conversation_participants p
    where p.conversation_id = target
      and (
        p.user_id = auth.uid()
        or p.tenant_id = public.current_tenant_id()
      )
  );
$$;

create policy conversations_select on public.conversations
  for select to authenticated
  using (
    (organization_id = public.current_org_id() and public.is_staff())
    or public.is_conversation_participant(id)
  );

create policy conversations_write on public.conversations
  for all to authenticated
  using (organization_id = public.current_org_id() and public.is_staff())
  with check (organization_id = public.current_org_id() and public.is_staff());

create policy participants_select on public.conversation_participants
  for select to authenticated
  using (
    (organization_id = public.current_org_id() and public.is_staff())
    or user_id = auth.uid()
    or tenant_id = public.current_tenant_id()
  );

create policy participants_write on public.conversation_participants
  for all to authenticated
  using (organization_id = public.current_org_id() and public.is_staff())
  with check (organization_id = public.current_org_id() and public.is_staff());

create policy messages_select on public.messages
  for select to authenticated
  using (public.is_conversation_participant(conversation_id)
         or (organization_id = public.current_org_id() and public.is_staff()));

--  You may only post as yourself, into a thread you belong to.
create policy messages_insert on public.messages
  for insert to authenticated
  with check (
    public.is_conversation_participant(conversation_id)
    and sender_id = coalesce(public.current_tenant_id(), auth.uid())
  );

--  Edits are limited to your own message; deletes are soft and staff-only.
create policy messages_update_own on public.messages
  for update to authenticated
  using (sender_id = coalesce(public.current_tenant_id(), auth.uid()))
  with check (sender_id = coalesce(public.current_tenant_id(), auth.uid()));

-- ============================================================================
--  Notifications
-- ============================================================================
--  Strictly per-recipient. There is deliberately no INSERT policy: only
--  triggers and Edge Functions running as service_role create notifications,
--  so a client cannot spam another user's feed.

create policy notifications_select on public.notifications
  for select to authenticated
  using (recipient_user_id = auth.uid());

create policy notifications_update on public.notifications
  for update to authenticated
  using (recipient_user_id = auth.uid())
  with check (recipient_user_id = auth.uid());

-- ============================================================================
--  Activity & tasks
-- ============================================================================

create policy activities_select on public.activities
  for select to authenticated
  using (organization_id = public.current_org_id() and public.is_staff());

create policy tasks_select on public.tasks
  for select to authenticated
  using (organization_id = public.current_org_id() and public.is_staff());

create policy tasks_write on public.tasks
  for all to authenticated
  using (organization_id = public.current_org_id() and public.is_staff())
  with check (organization_id = public.current_org_id() and public.is_staff());
