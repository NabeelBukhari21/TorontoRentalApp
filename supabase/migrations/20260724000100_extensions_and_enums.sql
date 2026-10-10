-- ============================================================================
--  Purrperty — 01 · Extensions, enums, and shared helpers
-- ============================================================================
--  Every value below is copied from the `rawValue` of the corresponding
--  Swift enum in `Domain/`. They are a wire contract: change one here and
--  you must change it there in the same commit.
--
--  `unknown` is a real value in most of these types on purpose. Every
--  Domain enum conforms to `FallbackDecodable`, which maps an unrecognised
--  string to `.unknown` rather than throwing — so the backend can add a
--  case without breaking clients already in the App Store.
-- ============================================================================

create extension if not exists "pgcrypto";   -- gen_random_uuid()
create extension if not exists "pg_trgm";    -- trigram indexes for ILIKE search

-- ── Organization ────────────────────────────────────────────────────────────
create type org_plan      as enum ('starter', 'professional', 'premium', 'enterprise', 'unknown');
create type currency_code as enum ('CAD', 'USD');

create type user_role as enum (
  'owner', 'admin', 'property_manager', 'maintenance_coordinator', 'viewer', 'unknown'
);
create type user_status as enum ('invited', 'active', 'suspended', 'unknown');

-- ── Portfolio ───────────────────────────────────────────────────────────────
create type property_kind as enum (
  'condo', 'house', 'duplex', 'triplex', 'multi_unit', 'commercial', 'mixed_use', 'unknown'
);
create type property_status as enum ('active', 'offline', 'listed_for_sale', 'sold', 'unknown');
create type unit_layout as enum (
  'studio', 'apartment', 'townhouse', 'basement_suite', 'commercial', 'unknown'
);
create type unit_status as enum ('occupied', 'vacant', 'notice', 'turnover', 'offline', 'unknown');

-- ── Leasing ─────────────────────────────────────────────────────────────────
create type tenant_status as enum ('prospective', 'current', 'notice', 'past', 'evicted', 'unknown');
create type lease_kind    as enum ('fixed_term', 'month_to_month', 'sublet', 'unknown');
create type lease_status  as enum (
  'draft', 'pending_signature', 'active', 'expiring', 'expired', 'terminated', 'renewed', 'unknown'
);
create type payment_kind as enum (
  'rent', 'deposit', 'late_fee', 'utilities', 'parking', 'repair_chargeback',
  'refund', 'reversal', 'unknown'
);
create type payment_method as enum (
  'e_transfer', 'pre_authorized_debit', 'card', 'cheque', 'cash', 'unknown'
);
create type payment_status as enum ('scheduled', 'processing', 'paid', 'failed', 'refunded', 'unknown');

-- ── Maintenance ─────────────────────────────────────────────────────────────
--  `vendor_trade` doubles as the request category: `MaintenanceRequest.category`
--  is typed `Vendor.Trade` in Swift, which is what makes vendor matching a
--  simple array-overlap query instead of a mapping table.
create type vendor_trade as enum (
  'plumbing', 'electrical', 'hvac', 'appliance', 'carpentry', 'roofing',
  'landscaping', 'cleaning', 'pest_control', 'general', 'unknown'
);
create type request_priority as enum ('emergency', 'urgent', 'high', 'medium', 'low', 'unknown');
create type request_status as enum (
  'new', 'triaged', 'scheduled', 'in_progress', 'awaiting_parts',
  'completed', 'cancelled', 'unknown'
);
create type update_kind as enum (
  'created', 'comment', 'status_changed', 'vendor_assigned', 'scheduled',
  'photos_added', 'cost_recorded', 'ai_triaged', 'tenant_notified', 'resolved', 'unknown'
);
create type inspection_kind as enum (
  'move_in', 'move_out', 'routine', 'annual', 'safety', 'insurance', 'unknown'
);
create type inspection_status as enum ('scheduled', 'in_progress', 'completed', 'cancelled', 'unknown');
create type inspection_severity as enum ('ok', 'minor', 'major', 'hazard', 'unknown');

-- ── Communication ───────────────────────────────────────────────────────────
create type conversation_kind as enum ('direct', 'group', 'maintenance', 'announcement', 'unknown');
create type participant_role  as enum ('staff', 'tenant', 'vendor', 'unknown');
create type message_kind      as enum ('text', 'attachment', 'system', 'ai_draft', 'unknown');
create type delivery_status   as enum ('sending', 'sent', 'delivered', 'read', 'failed', 'unknown');
create type notification_category as enum (
  'maintenance', 'payment', 'message', 'lease', 'inspection', 'ai_insight', 'system', 'unknown'
);
create type notification_priority as enum ('critical', 'high', 'normal', 'low', 'unknown');

-- ── Documents & workflow ────────────────────────────────────────────────────
create type document_category as enum (
  'lease', 'insurance', 'financial', 'inspection', 'identification',
  'notice', 'invoice', 'photo', 'other', 'unknown'
);
create type signature_status as enum (
  'not_required', 'pending', 'signed', 'declined', 'expired', 'unknown'
);
create type attachment_kind as enum ('image', 'video', 'pdf', 'spreadsheet', 'other');
create type task_status   as enum ('open', 'in_progress', 'blocked', 'completed', 'cancelled', 'unknown');
create type task_priority as enum ('urgent', 'high', 'normal', 'low', 'unknown');
create type activity_verb as enum (
  'created', 'updated', 'deleted', 'status_changed', 'assigned', 'signed',
  'paid', 'messaged', 'uploaded', 'invited', 'completed', 'unknown'
);

--  Polymorphic pointer target — `Domain.EntityReference.Kind`. Stored as
--  (subject_type, subject_id) so a table can point at anything without a
--  nullable foreign key per entity type.
create type entity_kind as enum (
  'organization', 'user', 'property', 'building', 'unit', 'tenant', 'lease',
  'maintenance_request', 'vendor', 'conversation', 'document', 'inspection',
  'payment', 'task'
);

-- ============================================================================
--  updated_at maintenance
-- ============================================================================

create or replace function public.touch_updated_at()
returns trigger
language plpgsql
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

comment on function public.touch_updated_at is
  'BEFORE UPDATE trigger: stamps updated_at server-side so a client cannot forge it.';
