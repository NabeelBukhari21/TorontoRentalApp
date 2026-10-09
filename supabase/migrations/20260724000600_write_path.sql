-- ============================================================================
--  RentOS — 06 · Write path: archive, restore, guarded delete
-- ============================================================================
--  Archive vs delete is a real distinction, not a UI nicety:
--
--   • Archive sets `deleted_at`. Units, leases, tenants, tickets and
--     documents are untouched, so restoring is a single UPDATE and the
--     app's Undo button is honest.
--   • Delete is irreversible. It is REFUSED while an active lease exists,
--     because a landlord deleting a property mid-tenancy would orphan a
--     legal agreement and a payment ledger.
--
--  Both are functions rather than plain UPDATEs so the rule lives in one
--  place the client cannot route around.
-- ============================================================================

create or replace function public.archive_property(p_property_id uuid)
returns void
language plpgsql
security invoker      -- runs under the caller's RLS, as it must
set search_path = public
as $$
begin
  if not public.can_manage_portfolio() then
    raise exception 'Not allowed to modify the portfolio' using errcode = '42501';
  end if;

  update public.properties
     set deleted_at = now(), updated_at = now()
   where id = p_property_id and deleted_at is null;

  if not found then
    raise exception 'Property not found' using errcode = 'P0002';
  end if;

  -- Units follow the property so the portfolio counts stay honest, and
  -- carry a marker so restore knows which ones it archived rather than
  -- un-archiving units that were already offline.
  update public.units
     set deleted_at = now(), updated_at = now()
   where property_id = p_property_id and deleted_at is null;

  insert into public.activities
    (organization_id, actor_user_id, verb, subject_type, subject_id, summary)
  values
    (public.current_org_id(), auth.uid(), 'deleted', 'property', p_property_id,
     'Archived property');
end;
$$;

create or replace function public.restore_property(p_property_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  archived_at timestamptz;
begin
  if not public.can_manage_portfolio() then
    raise exception 'Not allowed to modify the portfolio' using errcode = '42501';
  end if;

  select deleted_at into archived_at
  from public.properties
  where id = p_property_id;

  if archived_at is null then
    raise exception 'Property is not archived' using errcode = 'P0002';
  end if;

  update public.properties
     set deleted_at = null, updated_at = now()
   where id = p_property_id;

  -- Only the units archived by the same action come back. A unit taken
  -- offline before the property was archived stays offline.
  update public.units
     set deleted_at = null, updated_at = now()
   where property_id = p_property_id
     and deleted_at between archived_at - interval '2 seconds'
                        and archived_at + interval '2 seconds';

  insert into public.activities
    (organization_id, actor_user_id, verb, subject_type, subject_id, summary)
  values
    (public.current_org_id(), auth.uid(), 'updated', 'property', p_property_id,
     'Restored property');
end;
$$;

create or replace function public.delete_property(p_property_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  live_leases int;
begin
  if not public.can_manage_portfolio() then
    raise exception 'Not allowed to modify the portfolio' using errcode = '42501';
  end if;

  select count(*) into live_leases
  from public.leases
  where property_id = p_property_id
    and deleted_at is null
    and status in ('active', 'expiring', 'pending_signature');

  if live_leases > 0 then
    -- Surfaces in the app as a validation message, not a crash.
    raise exception
      'This property has % active lease(s). Archive it instead.', live_leases
      using errcode = '23514';
  end if;

  delete from public.properties where id = p_property_id;

  if not found then
    raise exception 'Property not found' using errcode = 'P0002';
  end if;
end;
$$;

create or replace function public.delete_unit(p_unit_id uuid)
returns void
language plpgsql
security invoker
set search_path = public
as $$
declare
  live_leases int;
begin
  if not public.can_manage_portfolio() then
    raise exception 'Not allowed to modify the portfolio' using errcode = '42501';
  end if;

  select count(*) into live_leases
  from public.leases
  where unit_id = p_unit_id
    and deleted_at is null
    and status in ('active', 'expiring', 'pending_signature');

  if live_leases > 0 then
    raise exception
      'This unit has a live lease. End the lease before deleting it.'
      using errcode = '23514';
  end if;

  update public.units
     set deleted_at = now(), updated_at = now()
   where id = p_unit_id and deleted_at is null;

  if not found then
    raise exception 'Unit not found' using errcode = 'P0002';
  end if;
end;
$$;

grant execute on function public.archive_property to authenticated;
grant execute on function public.restore_property to authenticated;
grant execute on function public.delete_property  to authenticated;
grant execute on function public.delete_unit      to authenticated;
