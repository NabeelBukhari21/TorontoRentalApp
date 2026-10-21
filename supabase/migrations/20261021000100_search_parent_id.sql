-- ============================================================================
--  Search: the record each result opens
-- ============================================================================
--
--  Units and leases have no screen of their own in the app. A unit result
--  opens its property; a lease result opens its primary tenant. Both search
--  functions now return that record as `parent_id` (null for other kinds),
--  so the client can route without a second query.
--
--  Adding a column to a function's result changes its type, which
--  `create or replace` can't do, so each function is dropped and recreated
--  with the same body plus the new column.

create or replace function public.search_parent_id(p_kind search_kind, p_entity_id uuid)
returns uuid
language sql
stable
security invoker              -- RLS on units and leases still applies
set search_path = public
as $$
  select case p_kind
    when 'unit'  then (select u.property_id from public.units u where u.id = p_entity_id)
    when 'lease' then (select l.primary_tenant_id from public.leases l where l.id = p_entity_id)
  end;
$$;

grant execute on function public.search_parent_id to authenticated;

drop function if exists public.global_search(text, search_kind[], text, integer, integer);

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
  total_count       bigint,
  parent_id         uuid
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
    count(*) over () as total_count,
    public.search_parent_id(s.kind, s.entity_id) as parent_id
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

drop function if exists public.search_filtered(text, search_kind[], text, integer, integer);

create or replace function public.search_filtered(
  p_filter   text,
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
  total_count       bigint,
  parent_id         uuid
)
language sql
stable
security invoker
set search_path = public
as $$
  with hits as (

    -- vacant · units with nobody in them, including turnover between tenants.
    select
      'unit'::search_kind as kind,
      u.id                as entity_id,
      '«' || initcap(u.status::text) || '» · ' || to_char(u.market_rent, 'FM$999,999,990') || '/mo' as reason,
      -- Alphabetical by title is the useful order for a vacancy list.
      0::real             as priority
    from public.units u
    where lower(p_filter) = 'vacant'
      and u.deleted_at is null
      and u.status in ('vacant', 'turnover')

    union all

    -- urgent · open requests at high priority or above, most severe first,
    -- then newest.
    select
      'maintenance_request'::search_kind,
      r.id,
      '«' || initcap(r.priority::text) || '» · ' || replace(initcap(r.status::text), '_', ' '),
      (
        case r.priority when 'emergency' then 3 when 'urgent' then 2 else 1 end
        + extract(epoch from r.created_at) / 1e10
      )::real
    from public.maintenance_requests r
    where lower(p_filter) = 'urgent'
      and r.deleted_at is null
      and r.priority in ('emergency', 'urgent', 'high')
      and r.status not in ('completed', 'cancelled')

    union all

    -- expiring · current leases ending within the 60-day Ontario notice
    -- window, soonest first.
    select
      'lease'::search_kind,
      l.id,
      case (l.term_end - current_date)
        when 0 then '«Ends today»'
        when 1 then '«Ends tomorrow»'
        else '«Ends in ' || (l.term_end - current_date) || ' days»'
      end,
      (61 - (l.term_end - current_date))::real
    from public.leases l
    where lower(p_filter) = 'expiring'
      and l.deleted_at is null
      and l.status in ('active', 'expiring')
      and l.term_end between current_date and current_date + 60

    union all

    -- overdue · tenants on a current lease with an unpaid, past-due
    -- payment, longest overdue first.
    select
      'tenant'::search_kind,
      t.id,
      '«' || to_char(sum(p.amount), 'FM$999,999,990') || ' overdue» · '
        || max(current_date - p.due_on) || ' days late',
      max(current_date - p.due_on)::real
    from public.tenants t
    join public.leases l
      on t.id = any(array_append(l.tenant_ids, l.primary_tenant_id))
     and l.status in ('active', 'expiring')
     and l.deleted_at is null
    join public.payments p
      on p.lease_id = l.id
     and p.status in ('scheduled', 'failed')
     and p.due_on < current_date
    where lower(p_filter) = 'overdue'
      and t.deleted_at is null
    group by t.id
  )
  select
    si.kind, si.entity_id, si.title, si.subtitle,
    -- Each reason carries the same «» markers ts_headline emits, around the
    -- part that made the row match, so the client highlights it.
    h.reason as headline,
    si.status, si.entity_updated_at, h.priority as rank,
    count(*) over () as total_count,
    public.search_parent_id(si.kind, si.entity_id) as parent_id
  from hits h
  join public.search_index si
    on si.kind = h.kind and si.entity_id = h.entity_id
  where p_kinds is null or si.kind = any(p_kinds)
  order by
    case when p_sort = 'recent'    then si.entity_updated_at end desc nulls last,
    case when p_sort = 'title'     then si.title end asc nulls last,
    case when p_sort = 'relevance' then h.priority end desc nulls last,
    si.title asc
  limit greatest(1, least(p_limit, 100))
  offset greatest(0, p_offset);
$$;

comment on function public.search_filtered is
  'Structured search for state keywords (vacant, urgent, expiring, overdue). Same row shape as global_search.';

grant execute on function public.search_filtered to authenticated;
