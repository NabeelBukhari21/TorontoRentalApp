-- ============================================================================
--  RentOS — 05 · Trend RPCs
-- ============================================================================
--  The detail charts need twelve monthly buckets. Doing that client-side
--  would mean downloading every lease and payment for the property just to
--  throw most of it away, so it is a function.
--
--  SECURITY INVOKER (the default) is important here: these must run under
--  the caller's RLS. A SECURITY DEFINER trend function would happily chart
--  a property belonging to another organization.
-- ============================================================================

create or replace function public.property_occupancy_trend(p_property_id uuid)
returns table (bucket date, value double precision)
language sql
stable
set search_path = public
as $$
  with months as (
    select generate_series(
      date_trunc('month', current_date) - interval '11 months',
      date_trunc('month', current_date),
      interval '1 month'
    )::date as bucket
  ),
  unit_count as (
    select count(*)::double precision as total
    from public.units u
    where u.property_id = p_property_id and u.deleted_at is null
  )
  select
    m.bucket,
    case
      when uc.total = 0 then 0::double precision
      else least(
        1.0,
        (
          select count(*)::double precision
          from public.leases l
          where l.property_id = p_property_id
            and l.deleted_at is null
            and l.term_start <= (m.bucket + interval '1 month' - interval '1 day')::date
            and l.term_end   >= m.bucket
        ) / uc.total
      )
    end as value
  from months m cross join unit_count uc
  order by m.bucket;
$$;

comment on function public.property_occupancy_trend is
  'Twelve monthly occupancy ratios (0..1) for one property. Runs under the caller''s RLS.';

create or replace function public.property_revenue_trend(p_property_id uuid)
returns table (bucket date, value double precision)
language sql
stable
set search_path = public
as $$
  with months as (
    select generate_series(
      date_trunc('month', current_date) - interval '11 months',
      date_trunc('month', current_date),
      interval '1 month'
    )::date as bucket
  )
  select
    m.bucket,
    coalesce((
      select sum(p.amount)::double precision
      from public.payments p
      where p.property_id = p_property_id
        and p.kind = 'rent'
        and p.status = 'paid'
        and date_trunc('month', p.due_on)::date = m.bucket
    ), 0)::double precision as value
  from months m
  order by m.bucket;
$$;

comment on function public.property_revenue_trend is
  'Twelve months of collected rent for one property, in dollars.';

grant execute on function public.property_occupancy_trend to authenticated;
grant execute on function public.property_revenue_trend  to authenticated;
