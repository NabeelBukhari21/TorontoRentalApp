-- ============================================================================
--  Purrperty — 10 · Notification generation, preferences, mutes, push tokens
-- ============================================================================
--  The `notifications` table has existed since migration 02, with RLS and no
--  INSERT policy — correct, but it meant nothing ever created a row. This
--  migration supplies the missing half: the rules that decide *whether* to
--  notify, and the triggers that do it.
--
--  Everything runs server-side on purpose. A client that decided whether to
--  notify could only decide for itself — the manager whose phone is in a
--  pocket would get nothing, and a muted thread would still buzz on their
--  iPad. Preferences, mutes, and quiet hours only work if the sender honours
--  them, and the sender is Postgres.
-- ============================================================================

-- ── Extend the existing table ───────────────────────────────────────────────

alter table public.notifications
  -- Collapses related notifications: three updates on one ticket become one
  -- row in the centre and one APNs thread, not three of each.
  add column if not exists group_key   text,
  -- Inline actions, e.g. [{"id":"assign","title":"Assign vendor"}]. Rendered
  -- in-app and mapped to a UNNotificationCategory for the lock screen.
  add column if not exists actions     jsonb not null default '[]'::jsonb,
  -- Time-sensitive notices stop being useful. An expired row is hidden
  -- rather than deleted, so the audit trail survives.
  add column if not exists expires_at  timestamptz,
  add column if not exists delivered_push boolean not null default false;

create index if not exists notifications_group_idx
  on public.notifications (recipient_user_id, group_key, created_at desc)
  where group_key is not null;

-- ── Device tokens ───────────────────────────────────────────────────────────

create type push_platform as enum ('ios', 'ios_sandbox', 'web');

create table public.device_tokens (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references public.users (id) on delete cascade,
  token          text not null,
  platform       push_platform not null default 'ios',
  app_version    text,
  device_name    text,
  -- Refreshed on every launch. A token unused for months is almost always a
  -- device the user no longer owns; APNs will reject it and the sender
  -- prunes it.
  last_seen_at   timestamptz not null default now(),
  created_at     timestamptz not null default now(),
  unique (token)
);

create index device_tokens_user_idx on public.device_tokens (user_id, last_seen_at desc);

alter table public.device_tokens enable row level security;
alter table public.device_tokens force row level security;

-- A user manages only their own tokens. Deliberately no SELECT for other
-- users: a device token is a targeting primitive, and one member of an org
-- should not be able to enumerate their colleagues' devices.
create policy device_tokens_own on public.device_tokens
  for all to authenticated
  using (user_id = auth.uid())
  with check (user_id = auth.uid());

-- ── Preferences ─────────────────────────────────────────────────────────────
--  One row per user per category. Server-side because the *sender* needs
--  them; the device-local toggles in Settings become a mirror of this.

create table public.notification_preferences (
  user_id        uuid not null default auth.uid() references public.users (id) on delete cascade,
  category       notification_category not null,
  in_app         boolean not null default true,
  push           boolean not null default true,
  email          boolean not null default false,
  -- Below this, no push (the centre still records it). Lets someone keep
  -- critical alerts while silencing routine ones in the same category.
  min_push_priority notification_priority not null default 'normal',
  created_at     timestamptz not null default now(),
  updated_at     timestamptz not null default now(),
  primary key (user_id, category)
);

create table public.notification_settings (
  user_id            uuid primary key default auth.uid() references public.users (id) on delete cascade,
  quiet_hours_enabled boolean not null default false,
  -- Local wall-clock times; interpreted in the org's timezone.
  quiet_start        time not null default '22:00',
  quiet_end          time not null default '07:00',
  -- Critical alerts pierce quiet hours. A flooded basement at 2am is exactly
  -- when someone needs to know.
  allow_critical_in_quiet boolean not null default true,
  digest_enabled     boolean not null default false,
  badge_enabled      boolean not null default true,
  created_at         timestamptz not null default now(),
  updated_at         timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;
alter table public.notification_preferences force row level security;
alter table public.notification_settings enable row level security;
alter table public.notification_settings force row level security;

create policy notification_preferences_own on public.notification_preferences
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

create policy notification_settings_own on public.notification_settings
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ── Mutes ───────────────────────────────────────────────────────────────────
--  Two shapes, because users want both: "stop telling me about *this ticket*"
--  and "stop telling me about payments entirely".

create table public.notification_mutes (
  id              uuid primary key default gen_random_uuid(),
  user_id         uuid not null default auth.uid() references public.users (id) on delete cascade,
  -- Stamped by the force_org_id trigger below; never accepted from a client.
  organization_id uuid not null references public.organizations (id) on delete cascade,
  -- Subject mute: silence one entity.
  subject_type    entity_kind,
  subject_id      uuid,
  -- Category mute: silence a whole class.
  category        notification_category,
  -- Null means forever; a timestamp makes it a snooze.
  expires_at      timestamptz,
  created_at      timestamptz not null default now(),
  check (subject_id is not null or category is not null)
);

create unique index notification_mutes_subject_idx
  on public.notification_mutes (user_id, subject_type, subject_id)
  where subject_id is not null;
create unique index notification_mutes_category_idx
  on public.notification_mutes (user_id, category)
  where category is not null and subject_id is null;

alter table public.notification_mutes enable row level security;
alter table public.notification_mutes force row level security;

create trigger notification_mutes_force_org_id
  before insert on public.notification_mutes
  for each row execute function public.force_org_id();

create policy notification_mutes_own on public.notification_mutes
  for all to authenticated
  using (user_id = auth.uid()) with check (user_id = auth.uid());

-- ============================================================================
--  The decision function
-- ============================================================================
--  Everything that could suppress a notification, in one place. Scattering
--  these checks across eight triggers is how a mute ends up honoured for
--  maintenance and ignored for payments.

create or replace function public.should_notify(
  p_user     uuid,
  p_category notification_category,
  p_priority notification_priority,
  p_subject_type entity_kind default null,
  p_subject_id   uuid default null
)
returns table (send_in_app boolean, send_push boolean)
language plpgsql
stable
security definer
set search_path = public
as $$
declare
  pref          record;
  settings      record;
  is_muted      boolean;
  in_quiet      boolean := false;
  org_tz        text;
  local_now     time;
  priority_rank int;
  min_rank      int;
begin
  -- 1 · Muted? Subject mute wins over category, and an expired mute is not
  --     a mute.
  select exists (
    select 1 from public.notification_mutes m
    where m.user_id = p_user
      and (m.expires_at is null or m.expires_at > now())
      and (
        (m.subject_id is not null and m.subject_type = p_subject_type and m.subject_id = p_subject_id)
        or (m.subject_id is null and m.category = p_category)
      )
  ) into is_muted;

  if is_muted then
    -- Still recorded in the centre; just never pushed. "Mute" means stop
    -- interrupting me, not stop tracking it.
    return query select true, false;
    return;
  end if;

  -- 2 · Category preference. A missing row means defaults, not silence.
  select * into pref
  from public.notification_preferences
  where user_id = p_user and category = p_category;

  select * into settings
  from public.notification_settings
  where user_id = p_user;

  -- 3 · Quiet hours, evaluated in the organization's timezone rather than
  --     UTC — 22:00 means the user's evening, not the server's.
  if coalesce(settings.quiet_hours_enabled, false) then
    select coalesce(o.time_zone, 'America/Toronto') into org_tz
    from public.users u
    join public.organizations o on o.id = u.organization_id
    where u.id = p_user;

    local_now := (now() at time zone coalesce(org_tz, 'America/Toronto'))::time;

    -- Windows that cross midnight (22:00 → 07:00) need the OR form.
    if settings.quiet_start <= settings.quiet_end then
      in_quiet := local_now >= settings.quiet_start and local_now < settings.quiet_end;
    else
      in_quiet := local_now >= settings.quiet_start or local_now < settings.quiet_end;
    end if;

    if in_quiet and p_priority = 'critical'
       and coalesce(settings.allow_critical_in_quiet, true) then
      in_quiet := false;
    end if;
  end if;

  -- 4 · Priority floor.
  priority_rank := case p_priority
    when 'critical' then 4 when 'high' then 3 when 'normal' then 2 else 1 end;
  min_rank := case coalesce(pref.min_push_priority, 'normal')
    when 'critical' then 4 when 'high' then 3 when 'normal' then 2 else 1 end;

  return query select
    coalesce(pref.in_app, true),
    coalesce(pref.push, true)
      and not in_quiet
      and priority_rank >= min_rank;
end;
$$;

-- ============================================================================
--  The emitter
-- ============================================================================

create or replace function public.emit_notification(
  p_org       uuid,
  p_recipient uuid,
  p_category  notification_category,
  p_priority  notification_priority,
  p_title     text,
  p_body      text,
  p_subject_type entity_kind default null,
  p_subject_id   uuid default null,
  p_deep_link text default null,
  p_group_key text default null,
  p_actions   jsonb default '[]'::jsonb,
  p_expires_at timestamptz default null
)
returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  decision record;
  new_id   uuid;
  existing uuid;
begin
  if p_recipient is null then return null; end if;

  select * into decision
  from public.should_notify(p_recipient, p_category, p_priority, p_subject_type, p_subject_id);

  if not decision.send_in_app then
    return null;
  end if;

  -- Collapse into an unread sibling rather than stacking. Three comments on
  -- one ticket should read as one item that says "3 updates", not three.
  if p_group_key is not null then
    select id into existing
    from public.notifications
    where recipient_user_id = p_recipient
      and group_key = p_group_key
      and read_at is null
      and dismissed_at is null
    order by created_at desc
    limit 1;

    if existing is not null then
      update public.notifications
         set title = p_title, body = p_body, priority = p_priority,
             actions = p_actions, updated_at = now(),
             -- Re-arm the push: a collapsed update is still news.
             delivered_push = not decision.send_push
       where id = existing;
      return existing;
    end if;
  end if;

  insert into public.notifications (
    organization_id, recipient_user_id, category, title, body, priority,
    subject_type, subject_id, deep_link, group_key, actions, expires_at,
    delivered_push
  ) values (
    p_org, p_recipient, p_category, p_title, p_body, p_priority,
    p_subject_type, p_subject_id, p_deep_link, p_group_key, p_actions, p_expires_at,
    -- False means "the push sender should pick this up". Setting it true
    -- when push is suppressed is what keeps the sender's queue clean.
    not decision.send_push
  )
  returning id into new_id;

  return new_id;
end;
$$;

-- Fan-out helper: notify every staff member who can act on something.
create or replace function public.emit_to_staff(
  p_org       uuid,
  p_category  notification_category,
  p_priority  notification_priority,
  p_title     text,
  p_body      text,
  p_subject_type entity_kind default null,
  p_subject_id   uuid default null,
  p_deep_link text default null,
  p_group_key text default null,
  p_actions   jsonb default '[]'::jsonb,
  p_exclude   uuid default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
declare member record;
begin
  for member in
    select u.id from public.users u
    where u.organization_id = p_org
      and u.deleted_at is null
      and u.status = 'active'
      and u.role in ('owner', 'admin', 'property_manager', 'maintenance_coordinator')
      -- Never notify someone about their own action.
      and (p_exclude is null or u.id <> p_exclude)
  loop
    perform public.emit_notification(
      p_org, member.id, p_category, p_priority, p_title, p_body,
      p_subject_type, p_subject_id, p_deep_link, p_group_key, p_actions, null
    );
  end loop;
end;
$$;

-- ============================================================================
--  Generation triggers
-- ============================================================================

create or replace function public.notify_maintenance_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare
  prop_name text;
  urgency   notification_priority;
begin
  select name into prop_name from public.properties where id = new.property_id;

  urgency := case new.priority
    when 'emergency' then 'critical'
    when 'urgent'    then 'high'
    else 'normal' end;

  if TG_OP = 'INSERT' then
    perform public.emit_to_staff(
      new.organization_id, 'maintenance', urgency,
      new.title,
      concat_ws(' · ', prop_name, initcap(replace(new.priority::text, '_', ' '))),
      'maintenance_request', new.id,
      'rentos://maintenance/' || new.id::text,
      'request:' || new.id::text,
      -- Actions the recipient can take without opening the app.
      '[{"id":"assign","title":"Assign vendor"},{"id":"view","title":"View"}]'::jsonb,
      new.reported_by_user_id
    );

  elsif TG_OP = 'UPDATE' and old.status is distinct from new.status then
    -- Tell the tenant their request moved, if they have a portal login.
    perform public.emit_notification(
      new.organization_id,
      (select t.portal_user_id from public.tenants t where t.id = new.tenant_id),
      'maintenance', 'normal',
      new.title,
      'Status: ' || initcap(replace(new.status::text, '_', ' ')),
      'maintenance_request', new.id,
      'rentos://maintenance/' || new.id::text,
      'request:' || new.id::text
    );
  end if;

  return new;
end; $$;

create or replace function public.notify_new_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare participant record; sender_label text;
begin
  if new.kind = 'system' then return new; end if;

  select coalesce(c.display_name, 'New message') into sender_label
  from public.conversations c where c.id = new.conversation_id;

  for participant in
    select p.user_id from public.conversation_participants p
    where p.conversation_id = new.conversation_id
      and p.user_id is not null
      and p.user_id <> coalesce(new.sender_id, '00000000-0000-0000-0000-000000000000'::uuid)
  loop
    perform public.emit_notification(
      new.organization_id, participant.user_id,
      'message', 'normal',
      sender_label,
      left(new.body, 140),
      'conversation', new.conversation_id,
      'rentos://messages/' || new.conversation_id::text,
      -- Grouped per thread, so a burst of replies is one badge, not nine.
      'thread:' || new.conversation_id::text,
      '[{"id":"reply","title":"Reply"}]'::jsonb
    );
  end loop;

  return new;
end; $$;

create or replace function public.notify_payment_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare tenant_name text;
begin
  if TG_OP = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;

  select full_name into tenant_name from public.tenants where id = new.tenant_id;

  if new.status = 'paid' then
    perform public.emit_to_staff(
      new.organization_id, 'payment', 'low',
      'Payment received',
      concat_ws(' · ', tenant_name, to_char(new.amount, 'FM$999,999.00')),
      'payment', new.id, null, 'payment:' || new.id::text
    );
  elsif new.status = 'failed' then
    perform public.emit_to_staff(
      new.organization_id, 'payment', 'high',
      'Payment failed',
      concat_ws(' · ', tenant_name, coalesce(new.failure_reason, 'No reason given')),
      'payment', new.id, null, 'payment:' || new.id::text,
      '[{"id":"contact","title":"Contact tenant"}]'::jsonb
    );
  end if;

  return new;
end; $$;

create or replace function public.notify_lease_change()
returns trigger language plpgsql security definer set search_path = public as $$
declare tenant_name text;
begin
  if TG_OP = 'UPDATE' and old.status is not distinct from new.status then
    return new;
  end if;
  if new.status not in ('expiring', 'expired', 'terminated') then
    return new;
  end if;

  select full_name into tenant_name from public.tenants where id = new.primary_tenant_id;

  perform public.emit_to_staff(
    new.organization_id, 'lease',
    case when new.status = 'expiring' then 'high' else 'normal' end,
    case new.status
      when 'expiring'   then 'Lease expiring soon'
      when 'expired'    then 'Lease expired'
      else 'Lease terminated' end,
    concat_ws(' · ', tenant_name, to_char(new.term_end, 'Mon DD, YYYY')),
    'lease', new.id, null, 'lease:' || new.id::text,
    '[{"id":"renew","title":"Start renewal"}]'::jsonb
  );

  return new;
end; $$;

create trigger maintenance_requests_notify
  after insert or update on public.maintenance_requests
  for each row execute function public.notify_maintenance_change();

create trigger messages_notify
  after insert on public.messages
  for each row execute function public.notify_new_message();

create trigger payments_notify
  after insert or update on public.payments
  for each row execute function public.notify_payment_change();

create trigger leases_notify
  after update on public.leases
  for each row execute function public.notify_lease_change();

-- ============================================================================
--  Actions
-- ============================================================================
--  Performing an action is server-side so a tap from the lock screen behaves
--  exactly like one in the app, and so the set of valid actions is whatever
--  the notification actually offered — not whatever the client sends.

create or replace function public.perform_notification_action(
  p_notification_id uuid,
  p_action_id       text
)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  note record;
  offered boolean;
begin
  select * into note
  from public.notifications
  where id = p_notification_id and recipient_user_id = auth.uid();

  if note is null then
    raise exception 'Notification not found' using errcode = 'P0002';
  end if;

  -- The action must be one this row advertised. Otherwise a client could
  -- invoke any action on any notification by guessing an identifier.
  select exists (
    select 1 from jsonb_array_elements(note.actions) a
    where a->>'id' = p_action_id
  ) into offered;

  if not offered then
    raise exception 'Action % is not available on this notification', p_action_id
      using errcode = '42501';
  end if;

  -- Acting implies seeing.
  update public.notifications
     set read_at = coalesce(read_at, now()), updated_at = now()
   where id = p_notification_id;

  -- Side effects are intentionally minimal: the app navigates to the subject
  -- and performs the real mutation through its normal, audited path. Doing
  -- the write here would bypass the mutation spine's validation and undo.
  insert into public.activities
    (organization_id, actor_user_id, verb, subject_type, subject_id, summary)
  values
    (note.organization_id, auth.uid(), 'updated', note.subject_type, note.subject_id,
     'Notification action: ' || p_action_id);
end;
$$;

grant execute on function public.perform_notification_action to authenticated;

-- ============================================================================
--  Reads
-- ============================================================================

create or replace function public.unread_notification_count()
returns integer
language sql
stable
security invoker
set search_path = public
as $$
  select count(*)::integer
  from public.notifications
  where recipient_user_id = auth.uid()
    and read_at is null
    and dismissed_at is null
    and (expires_at is null or expires_at > now());
$$;

create or replace function public.mark_all_notifications_read()
returns integer
language sql
security invoker
set search_path = public
as $$
  with updated as (
    update public.notifications
       set read_at = now(), updated_at = now()
     where recipient_user_id = auth.uid() and read_at is null
    returning 1
  )
  select count(*)::integer from updated;
$$;

grant execute on function public.unread_notification_count      to authenticated;
grant execute on function public.mark_all_notifications_read    to authenticated;
grant execute on function public.should_notify                  to authenticated;

-- Seed defaults for existing users so the first send is not a no-op.
insert into public.notification_settings (user_id)
select id from public.users on conflict (user_id) do nothing;

insert into public.notification_preferences (user_id, category)
select u.id, c.category
from public.users u
cross join (
  select unnest(enum_range(null::notification_category)) as category
) c
on conflict (user_id, category) do nothing;
