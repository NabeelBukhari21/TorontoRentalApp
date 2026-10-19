-- ============================================================================
--  Purrperty — 11 · Search filters
-- ============================================================================
--  STATES ARE NOT WORDS
--  ─────────────────────────────────────────────────────────────────────────
--  The search shortcuts — "vacant", "urgent", "expiring", "overdue" — name a
--  state of the data, not text in it. No lease document contains the word
--  "expiring", so `global_search` correctly finds nothing.
--
--  `search_filtered` answers each one with a predicate over the source
--  tables, and returns exactly the row shape of `global_search` so the
--  client decodes both the same way. Rows still come from `search_index`,
--  so titles match what a text search would show for the same entity.
--
--  The keyword list is mirrored by `SearchFilter` in the app; an unknown
--  keyword returns no rows rather than an error.
--
--  security invoker: RLS on search_index and every joined table scopes the
--  result to the caller's organisation.
-- ============================================================================

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
  total_count       bigint
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
    count(*) over () as total_count
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
