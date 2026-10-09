-- ============================================================================
--  RentOS — 09 · Global search
-- ============================================================================
--  ONE INDEX, NOT EIGHT QUERIES
--  ─────────────────────────────────────────────────────────────────────────
--  The obvious implementation — query eight tables and merge on the device —
--  fails in three ways that only show up with real data:
--
--   • Ranking. Merged result sets have no comparable score, so "Queen West"
--     returns the property tenth because tenants happened to load first.
--   • Paging. You cannot paginate a union you assembled client-side without
--     over-fetching every branch.
--   • Latency. Eight round trips on cellular is half a second before the
--     first character of feedback.
--
--  So a single `search_index` table is maintained by triggers, holding one
--  row per searchable entity with a precomputed `tsvector`. One GIN index,
--  one query, one ranking, real pagination.
--
--  The cost is write amplification — every property update touches two rows
--  instead of one — which is the right trade for a read-heavy app where
--  search must feel instant.
-- ============================================================================

create extension if not exists "unaccent";

-- ── Entity kinds ────────────────────────────────────────────────────────────

create type search_kind as enum (
  'property', 'unit', 'tenant', 'lease', 'maintenance_request',
  'document', 'message', 'vendor'
);

-- ── The index ───────────────────────────────────────────────────────────────

create table public.search_index (
  -- (kind, entity_id) is the natural key; a surrogate id keeps the trigger
  -- upserts simple.
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  kind             search_kind not null,
  entity_id        uuid not null,

  -- What the row renders as. Denormalised on purpose: a search result must
  -- not require eight joins to display.
  title            text not null,
  subtitle         text,
  -- The prose `ts_headline` snippets come from.
  body             text not null default '',

  -- Precomputed. Weighted so a match in the title outranks one in the body:
  -- A = title, B = subtitle, C = body.
  document         tsvector not null,

  -- Populated later by an embedding job. Nullable so semantic search is
  -- purely additive — nothing here needs to change to turn it on.
  embedding        jsonb,

  -- Lets results be filtered/sorted without joining back to the source.
  status           text,
  entity_updated_at timestamptz not null default now(),

  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),

  unique (kind, entity_id)
);

comment on table public.search_index is
  'Denormalised search corpus. Maintained by triggers; never written by a client.';
comment on column public.search_index.embedding is
  'Reserved for semantic search. jsonb rather than vector so the migration does not require pgvector; swap to vector(1536) + ivfflat when enabling.';

create index search_index_document_idx on public.search_index using gin (document);
-- Trigram index for typo tolerance and short prefixes, where FTS is weak:
-- "quee" produces no lexeme match but is a good trigram match.
create index search_index_title_trgm on public.search_index using gin (title gin_trgm_ops);
create index search_index_org_kind_idx on public.search_index (organization_id, kind);
create index search_index_recency_idx on public.search_index (organization_id, entity_updated_at desc);

-- ── RLS ─────────────────────────────────────────────────────────────────────
--  Read-only to clients. Writes happen inside SECURITY DEFINER triggers, so
--  there is deliberately no INSERT/UPDATE policy at all — a client that could
--  write here could forge a result pointing at another org's row.

alter table public.search_index enable row level security;
alter table public.search_index force row level security;

create policy search_index_select on public.search_index
  for select to authenticated
  using (organization_id = public.current_org_id() and public.is_staff());

-- ============================================================================
--  Index maintenance
-- ============================================================================

create or replace function public.search_upsert(
  p_org uuid, p_kind search_kind, p_entity uuid,
  p_title text, p_subtitle text, p_body text,
  p_status text, p_updated timestamptz
)
returns void
language sql
security definer
set search_path = public
as $$
  insert into public.search_index
    (organization_id, kind, entity_id, title, subtitle, body, document, status, entity_updated_at)
  values (
    p_org, p_kind, p_entity,
    coalesce(p_title, ''), p_subtitle, coalesce(p_body, ''),
    setweight(to_tsvector('english', unaccent(coalesce(p_title, ''))),    'A') ||
    setweight(to_tsvector('english', unaccent(coalesce(p_subtitle, ''))), 'B') ||
    setweight(to_tsvector('english', unaccent(coalesce(p_body, ''))),     'C'),
    p_status, coalesce(p_updated, now())
  )
  on conflict (kind, entity_id) do update set
    title             = excluded.title,
    subtitle          = excluded.subtitle,
    body              = excluded.body,
    document          = excluded.document,
    status            = excluded.status,
    entity_updated_at = excluded.entity_updated_at,
    updated_at        = now(),
    -- A changed document invalidates any embedding computed from the old
    -- text. Clearing it is what stops semantic search from silently
    -- answering with stale meaning.
    embedding         = case
                          when public.search_index.body is distinct from excluded.body
                            then null
                          else public.search_index.embedding
                        end;
$$;

create or replace function public.search_delete(p_kind search_kind, p_entity uuid)
returns void
language sql
security definer
set search_path = public
as $$
  delete from public.search_index where kind = p_kind and entity_id = p_entity;
$$;

-- ── Per-table triggers ──────────────────────────────────────────────────────
--  Each builds the same three fields: what it is called, what identifies it,
--  and the prose worth matching against.

create or replace function public.search_sync_property()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('property', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  perform public.search_upsert(
    new.organization_id, 'property', new.id,
    new.name,
    concat_ws(', ', new.address_line1, new.address_city),
    concat_ws(' ', new.neighborhood, new.kind::text, new.address_postal_code),
    new.status::text, new.updated_at
  );
  return new;
end; $$;

create or replace function public.search_sync_unit()
returns trigger language plpgsql security definer set search_path = public as $$
declare property_name text;
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('unit', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  select p.name into property_name from public.properties p where p.id = new.property_id;
  perform public.search_upsert(
    new.organization_id, 'unit', new.id,
    concat_ws(' · ', property_name, new.label),
    concat_ws(' ', new.bedrooms::text || ' bd', new.bathrooms::text || ' ba'),
    concat_ws(' ', new.layout::text, array_to_string(new.amenities, ' ')),
    new.status::text, new.updated_at
  );
  return new;
end; $$;

create or replace function public.search_sync_tenant()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('tenant', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  perform public.search_upsert(
    new.organization_id, 'tenant', new.id,
    new.full_name,
    coalesce(new.email, new.phone),
    -- Notes are searchable; emergency contacts are not indexed by name, to
    -- avoid surfacing a third party who never consented to being in here.
    concat_ws(' ', new.notes, new.phone, new.email),
    new.status::text, new.updated_at
  );
  return new;
end; $$;

create or replace function public.search_sync_lease()
returns trigger language plpgsql security definer set search_path = public as $$
declare tenant_name text; unit_label text; property_name text;
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('lease', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  select t.full_name into tenant_name from public.tenants t where t.id = new.primary_tenant_id;
  select u.label into unit_label from public.units u where u.id = new.unit_id;
  select p.name into property_name from public.properties p where p.id = new.property_id;
  perform public.search_upsert(
    new.organization_id, 'lease', new.id,
    concat_ws(' — ', tenant_name, unit_label),
    concat_ws(' ', property_name, 'to', to_char(new.term_end, 'Mon YYYY')),
    concat_ws(' ', new.kind::text, new.rent::text, to_char(new.term_start, 'YYYY-MM-DD')),
    new.status::text, new.updated_at
  );
  return new;
end; $$;

create or replace function public.search_sync_request()
returns trigger language plpgsql security definer set search_path = public as $$
declare property_name text;
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('maintenance_request', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  select p.name into property_name from public.properties p where p.id = new.property_id;
  perform public.search_upsert(
    new.organization_id, 'maintenance_request', new.id,
    new.title,
    concat_ws(' · ', property_name, new.priority::text),
    concat_ws(' ', new.details, new.category::text, new.summary),
    new.status::text, new.updated_at
  );
  return new;
end; $$;

create or replace function public.search_sync_document()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('document', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  perform public.search_upsert(
    new.organization_id, 'document', new.id,
    new.name,
    new.category::text,
    concat_ws(' ', array_to_string(new.tags, ' '), new.file_name),
    new.signature_status::text, new.updated_at
  );
  return new;
end; $$;

create or replace function public.search_sync_message()
returns trigger language plpgsql security definer set search_path = public as $$
declare thread_name text;
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('message', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  -- System messages are noise in search results.
  if new.kind = 'system' then
    return new;
  end if;
  select c.display_name into thread_name
    from public.conversations c where c.id = new.conversation_id;
  perform public.search_upsert(
    new.organization_id, 'message', new.id,
    coalesce(nullif(thread_name, ''), 'Conversation'),
    to_char(new.created_at, 'Mon DD, YYYY'),
    new.body,
    new.delivery_status::text, new.updated_at
  );
  return new;
end; $$;

create or replace function public.search_sync_vendor()
returns trigger language plpgsql security definer set search_path = public as $$
begin
  if TG_OP = 'DELETE' or new.deleted_at is not null then
    perform public.search_delete('vendor', coalesce(old.id, new.id));
    return coalesce(new, old);
  end if;
  perform public.search_upsert(
    new.organization_id, 'vendor', new.id,
    new.company_name,
    concat_ws(' · ', new.contact_name, array_to_string(new.trades::text[], ', ')),
    concat_ws(' ', new.notes, new.email, new.phone, array_to_string(new.trades::text[], ' ')),
    case when new.is_preferred then 'preferred' else 'active' end, new.updated_at
  );
  return new;
end; $$;

do $$
declare
  pairs text[][] := array[
    ['properties','search_sync_property'], ['units','search_sync_unit'],
    ['tenants','search_sync_tenant'], ['leases','search_sync_lease'],
    ['maintenance_requests','search_sync_request'], ['documents','search_sync_document'],
    ['messages','search_sync_message'], ['vendors','search_sync_vendor']
  ];
  pair text[];
begin
  foreach pair slice 1 in array pairs loop
    execute format(
      'create trigger %I after insert or update or delete on public.%I
         for each row execute function public.%I()',
      pair[1] || '_search_sync', pair[1], pair[2]
    );
  end loop;
end;
$$;

-- ============================================================================
--  The search function
-- ============================================================================
--  Combines three signals, because no single one is enough:
--
--   • Full-text rank (ts_rank_cd) — the primary score, understands stemming
--     so "leaking" matches "leak".
--   • Trigram similarity — catches typos and short prefixes that produce no
--     lexeme at all. "Bathrust" still finds "Bathurst".
--   • Recency — a gentle tiebreaker. Between two equally good matches the
--     one touched this week is almost always the one meant.
--
--  `ts_headline` builds the snippet server-side, so highlighting reflects
--  what actually matched after stemming — something the client cannot know.

create or replace function public.global_search(
  p_query    text,
  p_kinds    search_kind[] default null,
  p_sort     text default 'relevance',
  p_limit    integer default 20,
  p_offset   integer default 0
)
returns table (
  kind              search_kind,
  entity_id         uuid,
  title             text,
  subtitle          text,
  headline          text,
  status            text,
  entity_updated_at timestamptz,
  rank              real,
  total_count       bigint
)
language sql
stable
security invoker              -- RLS on search_index scopes this to the org
set search_path = public
as $$
  with normalised as (
    select
      nullif(trim(p_query), '')                     as raw,
      websearch_to_tsquery('english', unaccent(coalesce(p_query, ''))) as tsq
  ),
  matched as (
    select
      si.*,
      -- 32 divides the rank by the document length, so a short title match
      -- is not out-ranked by a long body that mentions the term twice.
      ts_rank_cd(si.document, n.tsq, 32)            as fts_rank,
      similarity(si.title, n.raw)                   as trgm_rank
    from public.search_index si, normalised n
    where n.raw is not null
      and (p_kinds is null or si.kind = any(p_kinds))
      and (
        si.document @@ n.tsq
        -- Trigram fallback for typos and prefixes. Bounded at 0.2 so it
        -- widens the net without flooding it.
        or si.title % n.raw
        or si.title ilike '%' || n.raw || '%'
      )
  ),
  scored as (
    select
      m.*,
      (
        coalesce(m.fts_rank, 0) * 1.0
        + coalesce(m.trgm_rank, 0) * 0.35
        + greatest(
            0,
            0.15 - (extract(epoch from (now() - m.entity_updated_at)) / (86400.0 * 180)) * 0.15
          )
      )::real as score
    from matched m
  )
  select
    s.kind, s.entity_id, s.title, s.subtitle,
    ts_headline(
      'english',
      case when length(s.body) > 0 then s.body else coalesce(s.subtitle, s.title) end,
      (select tsq from normalised),
      -- Custom markers: the client parses these into styled ranges. HTML
      -- tags would have to be escaped and stripped for no benefit.
      'StartSel=«, StopSel=», MaxWords=18, MinWords=6, ShortWord=2, MaxFragments=2, FragmentDelimiter= … '
    ) as headline,
    s.status, s.entity_updated_at, s.score,
    count(*) over () as total_count
  from scored s
  order by
    case when p_sort = 'recent'   then s.entity_updated_at end desc nulls last,
    case when p_sort = 'title'    then s.title end asc nulls last,
    case when p_sort = 'relevance' then s.score end desc nulls last,
    s.entity_updated_at desc
  limit greatest(1, least(p_limit, 100))
  offset greatest(0, p_offset);
$$;

grant execute on function public.global_search to authenticated;

-- ── Suggestions ─────────────────────────────────────────────────────────────
--  Prefix completions from titles the user can actually reach. Cheap enough
--  to run on every keystroke, which is the point.

create or replace function public.search_suggestions(p_prefix text, p_limit integer default 6)
returns table (kind search_kind, entity_id uuid, title text, subtitle text)
language sql
stable
security invoker
set search_path = public
as $$
  select si.kind, si.entity_id, si.title, si.subtitle
  from public.search_index si
  where nullif(trim(p_prefix), '') is not null
    and si.title ilike trim(p_prefix) || '%'
  order by si.entity_updated_at desc
  limit greatest(1, least(p_limit, 20));
$$;

grant execute on function public.search_suggestions to authenticated;

-- ============================================================================
--  Backfill
-- ============================================================================
--  Triggers only cover changes from here on, so existing rows need one pass.

do $$
begin
  perform public.search_upsert(p.organization_id, 'property', p.id, p.name,
      concat_ws(', ', p.address_line1, p.address_city),
      concat_ws(' ', p.neighborhood, p.kind::text), p.status::text, p.updated_at)
    from public.properties p where p.deleted_at is null;

  perform public.search_upsert(t.organization_id, 'tenant', t.id, t.full_name,
      coalesce(t.email, t.phone), concat_ws(' ', t.notes, t.phone), t.status::text, t.updated_at)
    from public.tenants t where t.deleted_at is null;

  perform public.search_upsert(r.organization_id, 'maintenance_request', r.id, r.title,
      r.priority::text, concat_ws(' ', r.details, r.category::text), r.status::text, r.updated_at)
    from public.maintenance_requests r where r.deleted_at is null;

  perform public.search_upsert(d.organization_id, 'document', d.id, d.name,
      d.category::text, array_to_string(d.tags, ' '), d.signature_status::text, d.updated_at)
    from public.documents d where d.deleted_at is null;

  perform public.search_upsert(v.organization_id, 'vendor', v.id, v.company_name,
      v.contact_name, concat_ws(' ', v.notes, v.email), 'active', v.updated_at)
    from public.vendors v where v.deleted_at is null;
end;
$$;

-- ============================================================================
--  FUTURE: semantic search
-- ============================================================================
--  Turning it on is additive — no table or client change beyond these steps:
--
--    create extension vector;
--    alter table public.search_index
--      alter column embedding type vector(1536) using null;
--    create index on public.search_index
--      using ivfflat (embedding vector_cosine_ops) with (lists = 100);
--
--  Then an Edge Function embeds rows where `embedding is null` (the upsert
--  above already nulls it whenever the text changes, so staleness is handled),
--  and `global_search` gains a hybrid branch:
--
--    score = fts_rank * 0.6 + (1 - (embedding <=> query_embedding)) * 0.4
--
--  The Swift layer already sends `SearchMode`, so the client is ready today.
