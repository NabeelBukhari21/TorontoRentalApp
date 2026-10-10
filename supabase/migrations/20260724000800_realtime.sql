-- ============================================================================
--  Purrperty — 08 · Realtime, versioning, and origin tracking
-- ============================================================================
--  Three things the client needs from the database to sync correctly:
--
--   1. A publication, so changes are streamed at all.
--   2. A `version` column bumped by a trigger, so a write can be rejected
--      when the row moved underneath it. A client-supplied version is not a
--      guard — it is whatever the client feels like sending.
--   3. An `origin_token`, so a client can recognise the echo of its own
--      write and skip re-applying it.
--
--  RLS applies to `postgres_changes`: a subscriber only receives rows it
--  could have SELECTed. That is why realtime does not need its own
--  authorization model — it inherits the one in 03_rls.sql. It also means
--  every streamed table MUST have a SELECT policy, or the stream is silently
--  empty rather than loudly broken.
-- ============================================================================

-- ── Version + origin columns ───────────────────────────────────────────────

do $$
declare t text;
begin
  foreach t in array array[
    'properties','units','tenants','leases','maintenance_requests',
    'maintenance_updates','documents','conversations','messages','notifications'
  ]
  loop
    execute format(
      'alter table public.%I
         add column if not exists version integer not null default 1,
         add column if not exists origin_token text',
      t
    );
  end loop;
end;
$$;

comment on column public.properties.version is
  'Optimistic concurrency counter. Bumped by trigger; never set by a client.';
comment on column public.properties.origin_token is
  'Opaque per-device token set by the writer so it can drop its own realtime echo.';

-- ── Version bump trigger ───────────────────────────────────────────────────
--  Combined with touch_updated_at so a row's version and timestamp always
--  move together. If they could diverge, the client's cursor and its
--  conflict check would disagree about which row is newer.

create or replace function public.bump_version()
returns trigger
language plpgsql
as $$
begin
  new.version    := coalesce(old.version, 0) + 1;
  new.updated_at := now();
  return new;
end;
$$;

do $$
declare t text;
begin
  foreach t in array array[
    'properties','units','tenants','leases','maintenance_requests',
    'maintenance_updates','documents','conversations','messages','notifications'
  ]
  loop
    -- Replaces the plain updated_at trigger: bump_version does both, and two
    -- BEFORE UPDATE triggers on the same columns is a race waiting to happen.
    execute format('drop trigger if exists %I on public.%I', t || '_touch_updated_at', t);
    execute format('drop trigger if exists %I on public.%I', t || '_bump_version', t);
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.bump_version()',
      t || '_bump_version', t
    );
  end loop;
end;
$$;

-- ── Guarded update helper ──────────────────────────────────────────────────
--  Rejects a write whose expected version is stale, returning the current row
--  so the client can diff and resolve. A plain UPDATE ... WHERE version = n
--  would affect zero rows and tell the client nothing about why.

create or replace function public.update_if_current(
  p_table         text,
  p_id            uuid,
  p_expected_version integer,
  p_patch         jsonb,
  p_origin_token  text default null
)
returns jsonb
language plpgsql
security invoker            -- the caller's RLS still governs the write
set search_path = public
as $$
declare
  current_version integer;
  current_row     jsonb;
  updated_row     jsonb;
  set_clause      text;
begin
  -- Allowlist: p_table is interpolated into SQL, so it must never be taken
  -- at face value. Anything not named here is rejected outright.
  if p_table not in (
    'properties','units','tenants','leases','maintenance_requests',
    'maintenance_updates','documents','conversations','messages','notifications'
  ) then
    raise exception 'Table % is not updatable through this function', p_table
      using errcode = '42501';
  end if;

  execute format('select version, to_jsonb(t) from public.%I t where t.id = $1', p_table)
    into current_version, current_row
    using p_id;

  if current_version is null then
    raise exception 'Record not found' using errcode = 'P0002';
  end if;

  if current_version <> p_expected_version then
    -- Not an error: a conflict is an expected outcome with two concurrent
    -- editors. Returned as data so the client can resolve it.
    return jsonb_build_object(
      'conflict', true,
      'current_version', current_version,
      'remote', current_row
    );
  end if;

  -- Build the SET list from the patch's keys. Values are passed as jsonb and
  -- cast by Postgres, so no user value reaches the statement text.
  select string_agg(format('%I = ($1->>%L)::text', key, key), ', ')
    into set_clause
    from jsonb_object_keys(p_patch) as key;

  if set_clause is null then
    return jsonb_build_object('conflict', false, 'row', current_row);
  end if;

  execute format(
    'update public.%I set %s, origin_token = $2 where id = $3 returning to_jsonb(%I.*)',
    p_table, set_clause, p_table
  )
  into updated_row
  using p_patch, p_origin_token, p_id;

  return jsonb_build_object('conflict', false, 'row', updated_row);
end;
$$;

grant execute on function public.update_if_current to authenticated;

-- ── Publication ────────────────────────────────────────────────────────────
--  Supabase Realtime reads from the `supabase_realtime` publication.
--  Adding a table here is what makes it stream.

do $$
declare t text;
begin
  if not exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    create publication supabase_realtime;
  end if;

  foreach t in array array[
    'properties','units','tenants','leases','maintenance_requests',
    'maintenance_updates','documents','conversations','messages','notifications'
  ]
  loop
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime' and schemaname = 'public' and tablename = t
    ) then
      execute format('alter publication supabase_realtime add table public.%I', t);
    end if;

    -- Without REPLICA IDENTITY FULL, a DELETE streams only the primary key.
    -- The client needs enough of the old row to know which list to remove it
    -- from, and RLS needs organization_id to decide who may see the event at
    -- all — so a key-only delete is invisible to every subscriber.
    execute format('alter table public.%I replica identity full', t);
  end loop;
end;
$$;

-- ── Delta query support ────────────────────────────────────────────────────
--  The gap resync fetches "everything in this table changed after X". A
--  composite index on (organization_id, updated_at) is what keeps that from
--  becoming a sequential scan after a long offline period.

do $$
declare t text;
begin
  foreach t in array array[
    'properties','units','tenants','leases','maintenance_requests',
    'maintenance_updates','documents','conversations','messages'
  ]
  loop
    execute format(
      'create index if not exists %I on public.%I (organization_id, updated_at desc)',
      t || '_org_updated_idx', t
    );
  end loop;
end;
$$;

create index if not exists notifications_recipient_updated_idx
  on public.notifications (recipient_user_id, updated_at desc);
