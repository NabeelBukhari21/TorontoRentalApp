-- ============================================================================
--  RentOS — 02 · Tables
-- ============================================================================
--  Every column name matches the `CodingKeys` of its Swift `Domain` model,
--  so PostgREST rows decode directly with no mapping layer.
--
--  Two rules hold everywhere:
--
--  1. Every tenant-owned table carries `organization_id`. That column is the
--     multi-tenancy boundary and every RLS policy filters on it.
--  2. `organization_id` is never trusted from the client. Inserts default it
--     from `public.current_org_id()` and a trigger overwrites whatever the
--     client sent. See 03_rls.sql.
-- ============================================================================

-- ── Organizations ───────────────────────────────────────────────────────────

create table public.organizations (
  id                  uuid primary key default gen_random_uuid(),
  name                text        not null check (length(trim(name)) between 2 and 120),
  slug                text        not null unique check (slug ~ '^[a-z0-9]+(-[a-z0-9]+)*$'),
  logo_path           text,
  address_line1       text,
  address_line2       text,
  address_city        text,
  address_province    text,
  address_postal_code text,
  address_country     text        default 'CA',
  latitude            double precision,
  longitude           double precision,
  support_email       text        check (support_email is null or support_email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone               text,
  plan                org_plan    not null default 'starter',
  unit_quota          integer     not null default 10 check (unit_quota >= 0),
  trial_ends_at       timestamptz,
  currency            currency_code not null default 'CAD',
  time_zone           text        not null default 'America/Toronto',
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

-- ── Users (profiles) ────────────────────────────────────────────────────────
--  `id` IS the auth.users id. One row per signed-in person. The FK with
--  ON DELETE CASCADE means deleting an auth user cleans up the profile.

create table public.users (
  id              uuid primary key references auth.users (id) on delete cascade,
  organization_id uuid        references public.organizations (id) on delete cascade,
  email           text        not null,
  full_name       text        not null default '',
  phone           text,
  avatar_path     text,
  job_title       text,
  role            user_role   not null default 'viewer',
  status          user_status not null default 'active',
  last_seen_at    timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

comment on column public.users.organization_id is
  'Null only between sign-up and organization creation. RLS denies all tenant data while null.';
comment on column public.users.role is
  'Authorization source of truth. Client-supplied roles are ignored; only elevate via public.set_member_role().';

-- ── Properties ──────────────────────────────────────────────────────────────

create table public.properties (
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references public.organizations (id) on delete cascade,
  name                text not null check (length(trim(name)) between 1 and 160),
  address_line1       text not null default '',
  address_line2       text,
  address_city        text not null default 'Toronto',
  address_province    text not null default 'ON',
  address_postal_code text not null default '',
  address_country     text not null default 'CA',
  latitude            double precision,
  longitude           double precision,
  neighborhood        text,
  kind                property_kind   not null default 'unknown',
  status              property_status not null default 'active',
  year_built          integer check (year_built is null or year_built between 1800 and 2100),
  square_feet         integer check (square_feet is null or square_feet >= 0),
  purchase_price      numeric(14,2),
  purchase_date       date,
  market_value        numeric(14,2),
  manager_id          uuid references public.users (id) on delete set null,
  cover_image_path    text,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

create table public.buildings (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  property_id     uuid not null references public.properties (id) on delete cascade,
  name            text not null default '',
  floor_count     integer not null default 1 check (floor_count > 0),
  has_elevator    boolean not null default false,
  year_built      integer,
  access_notes    text,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

create table public.units (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  property_id     uuid not null references public.properties (id) on delete cascade,
  building_id     uuid references public.buildings (id) on delete set null,
  label           text not null,
  floor           integer,
  bedrooms        integer not null default 1 check (bedrooms >= 0),
  bathrooms       numeric(3,1) not null default 1 check (bathrooms >= 0),
  square_feet     integer,
  layout          unit_layout not null default 'unknown',
  status          unit_status not null default 'vacant',
  market_rent     numeric(12,2) not null default 0 check (market_rent >= 0),
  deposit_amount  numeric(12,2),
  amenities       text[] not null default '{}',
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz,
  unique (property_id, label)
);

-- ── Tenants ─────────────────────────────────────────────────────────────────

create table public.tenants (
  id                      uuid primary key default gen_random_uuid(),
  organization_id         uuid not null references public.organizations (id) on delete cascade,
  full_name               text not null check (length(trim(full_name)) between 1 and 160),
  email                   text check (email is null or email ~* '^[^@\s]+@[^@\s]+\.[^@\s]+$'),
  phone                   text,
  avatar_path             text,
  date_of_birth           date,
  status                  tenant_status not null default 'current',
  -- Set when the renter accepts a portal invite. Drives tenant-side RLS.
  portal_user_id          uuid references public.users (id) on delete set null,
  emergency_contact_name  text,
  emergency_contact_phone text,
  on_time_payment_rate    numeric(4,3) check (on_time_payment_rate between 0 and 1),
  is_priority             boolean not null default false,
  notes                   text,
  created_at              timestamptz not null default now(),
  updated_at              timestamptz not null default now(),
  deleted_at              timestamptz
);

create table public.leases (
  id                     uuid primary key default gen_random_uuid(),
  organization_id        uuid not null references public.organizations (id) on delete cascade,
  unit_id                uuid not null references public.units (id) on delete cascade,
  property_id            uuid not null references public.properties (id) on delete cascade,
  primary_tenant_id      uuid not null references public.tenants (id) on delete cascade,
  tenant_ids             uuid[] not null default '{}',
  kind                   lease_kind   not null default 'fixed_term',
  status                 lease_status not null default 'active',
  rent                   numeric(12,2) not null check (rent >= 0),
  term_start             date not null,
  term_end               date not null,
  deposit_held           numeric(12,2),
  rent_due_day           smallint not null default 1 check (rent_due_day between 1 and 28),
  renewed_into_lease_id  uuid references public.leases (id) on delete set null,
  signed_at              timestamptz,
  document_id            uuid,
  move_in_at             timestamptz,
  move_out_at            timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  deleted_at             timestamptz,
  check (term_end >= term_start)
);

-- Only one live lease per unit. This is the invariant that makes occupancy
-- derivable rather than a denormalised field somebody has to remember to update.
create unique index leases_one_active_per_unit
  on public.leases (unit_id)
  where status in ('active', 'expiring') and deleted_at is null;

create table public.payments (
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references public.organizations (id) on delete cascade,
  lease_id            uuid not null references public.leases (id) on delete cascade,
  tenant_id           uuid not null references public.tenants (id) on delete cascade,
  property_id         uuid not null references public.properties (id) on delete cascade,
  amount              numeric(12,2) not null,
  kind                payment_kind   not null default 'rent',
  method              payment_method not null default 'unknown',
  status              payment_status not null default 'scheduled',
  due_on              date not null,
  paid_at             timestamptz,
  memo                text,
  external_reference  text,
  failure_reason      text,
  reverses_payment_id uuid references public.payments (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ── Vendors & maintenance ───────────────────────────────────────────────────

create table public.vendors (
  id                    uuid primary key default gen_random_uuid(),
  organization_id       uuid not null references public.organizations (id) on delete cascade,
  company_name          text not null,
  contact_name          text,
  email                 text,
  phone                 text,
  address_line1         text,
  address_city          text,
  address_province      text,
  address_postal_code   text,
  address_country       text default 'CA',
  trades                vendor_trade[] not null default '{}',
  rating                numeric(2,1) check (rating is null or rating between 0 and 5),
  response_time_hours   integer,
  hourly_rate           numeric(10,2),
  handles_emergencies   boolean not null default false,
  completed_job_count   integer not null default 0,
  is_insured            boolean not null default false,
  insurance_expires_at  date,
  is_preferred          boolean not null default false,
  notes                 text,
  created_at            timestamptz not null default now(),
  updated_at            timestamptz not null default now(),
  deleted_at            timestamptz
);

create table public.maintenance_requests (
  id                   uuid primary key default gen_random_uuid(),
  organization_id      uuid not null references public.organizations (id) on delete cascade,
  property_id          uuid not null references public.properties (id) on delete cascade,
  unit_id              uuid references public.units (id) on delete set null,
  tenant_id            uuid references public.tenants (id) on delete set null,
  reported_by_user_id  uuid references public.users (id) on delete set null,
  assigned_vendor_id   uuid references public.vendors (id) on delete set null,
  title                text not null check (length(trim(title)) between 1 and 200),
  details              text,
  category             vendor_trade     not null default 'unknown',
  priority             request_priority not null default 'medium',
  status               request_status   not null default 'new',
  photos               jsonb not null default '[]'::jsonb,   -- [Domain.Attachment]
  scheduled_for        timestamptz,
  resolved_at          timestamptz,
  closed_at            timestamptz,
  estimated_cost       numeric(12,2),
  actual_cost          numeric(12,2),
  tenant_reply_sent_at timestamptz,
  -- AI analysis block (nullable until the copilot has looked at it)
  summary              text,
  urgency_score        numeric(4,3) check (urgency_score is null or urgency_score between 0 and 1),
  category_confidence  numeric(4,3),
  suggested_actions    text[] not null default '{}',
  suggested_vendor_id  uuid references public.vendors (id) on delete set null,
  draft_tenant_reply   text,
  model_version        text,
  analyzed_at          timestamptz,
  created_at           timestamptz not null default now(),
  updated_at           timestamptz not null default now(),
  deleted_at           timestamptz
);

create table public.maintenance_updates (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  request_id       uuid not null references public.maintenance_requests (id) on delete cascade,
  author_user_id   uuid references public.users (id) on delete set null,
  author_tenant_id uuid references public.tenants (id) on delete set null,
  author_vendor_id uuid references public.vendors (id) on delete set null,
  kind             update_kind not null default 'comment',
  body             text,
  attachments      jsonb not null default '[]'::jsonb,   -- [Domain.Attachment]
  from_status      request_status,
  to_status        request_status,
  -- Internal notes are hidden from tenant-role readers by RLS, not by the client.
  is_internal      boolean not null default false,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now()
);

-- ── Documents ───────────────────────────────────────────────────────────────

create table public.documents (
  id                     uuid primary key default gen_random_uuid(),
  organization_id        uuid not null references public.organizations (id) on delete cascade,
  name                   text not null,
  category               document_category not null default 'other',
  -- StoredFile: bucket path + metadata. Bytes live in Storage, never in a column.
  file_id                uuid not null default gen_random_uuid(),
  file_kind              attachment_kind not null default 'other',
  file_storage_path      text not null,
  file_name              text not null,
  file_byte_size         bigint not null default 0 check (file_byte_size >= 0),
  file_uploaded_at       timestamptz not null default now(),
  -- Polymorphic owner (property / unit / lease / tenant / request)
  owner_type             entity_kind,
  owner_id               uuid,
  tags                   text[] not null default '{}',
  version                integer not null default 1 check (version > 0),
  supersedes_document_id uuid references public.documents (id) on delete set null,
  uploaded_by_user_id    uuid references public.users (id) on delete set null,
  is_visible_to_tenant   boolean not null default false,
  retain_until           date,
  signature_status       signature_status not null default 'not_required',
  signed_at              timestamptz,
  created_at             timestamptz not null default now(),
  updated_at             timestamptz not null default now(),
  deleted_at             timestamptz
);

-- ── Messaging ───────────────────────────────────────────────────────────────

create table public.conversations (
  id              uuid primary key default gen_random_uuid(),
  organization_id uuid not null references public.organizations (id) on delete cascade,
  kind            conversation_kind not null default 'direct',
  display_name    text not null default '',
  avatar_path     text,
  subject_type    entity_kind,
  subject_id      uuid,
  last_message_at timestamptz,
  created_at      timestamptz not null default now(),
  updated_at      timestamptz not null default now(),
  deleted_at      timestamptz
);

-- Explicit membership. This is what lets RLS answer "may this user read this
-- thread?" without trusting a conversation id supplied by the client.
create table public.conversation_participants (
  conversation_id uuid not null references public.conversations (id) on delete cascade,
  organization_id uuid not null references public.organizations (id) on delete cascade,
  user_id         uuid references public.users (id) on delete cascade,
  tenant_id       uuid references public.tenants (id) on delete cascade,
  last_read_at    timestamptz,
  created_at      timestamptz not null default now(),
  id              uuid primary key default gen_random_uuid(),
  role            participant_role not null default 'staff',
  check (user_id is not null or tenant_id is not null)
);

-- A person appears at most once per thread. Expressed as two partial unique
-- indexes because a PRIMARY KEY cannot contain expressions and NULLs would
-- otherwise slip duplicates past a plain unique constraint.
create unique index participants_unique_user
  on public.conversation_participants (conversation_id, user_id)
  where user_id is not null;
create unique index participants_unique_tenant
  on public.conversation_participants (conversation_id, tenant_id)
  where tenant_id is not null;

create table public.messages (
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references public.organizations (id) on delete cascade,
  conversation_id     uuid not null references public.conversations (id) on delete cascade,
  sender_id           uuid,
  sender_role         participant_role not null default 'staff',
  body                text not null default '',
  attachments         jsonb not null default '[]'::jsonb,   -- [Domain.Attachment]
  kind                message_kind    not null default 'text',
  delivery_status     delivery_status not null default 'sent',
  read_by             uuid[] not null default '{}',
  edited_at           timestamptz,
  reply_to_message_id uuid references public.messages (id) on delete set null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now(),
  deleted_at          timestamptz
);

-- ── Notifications ───────────────────────────────────────────────────────────

create table public.notifications (
  id                uuid primary key default gen_random_uuid(),
  organization_id   uuid not null references public.organizations (id) on delete cascade,
  recipient_user_id uuid not null references public.users (id) on delete cascade,
  category          notification_category not null default 'system',
  title             text not null,
  body              text not null default '',
  priority          notification_priority not null default 'normal',
  subject_type      entity_kind,
  subject_id        uuid,
  deep_link         text,
  read_at           timestamptz,
  pushed_at         timestamptz,
  dismissed_at      timestamptz,
  created_at        timestamptz not null default now(),
  updated_at        timestamptz not null default now()
);

-- ── Activity feed ───────────────────────────────────────────────────────────

create table public.activities (
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references public.organizations (id) on delete cascade,
  actor_user_id       uuid references public.users (id) on delete set null,
  actor_tenant_id     uuid references public.tenants (id) on delete set null,
  verb                activity_verb not null default 'unknown',
  subject_type        entity_kind,
  subject_id          uuid,
  summary             text not null default '',
  changes             jsonb not null default '{}'::jsonb,
  is_system_generated boolean not null default false,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

-- ── Tasks ───────────────────────────────────────────────────────────────────

create table public.tasks (
  id               uuid primary key default gen_random_uuid(),
  organization_id  uuid not null references public.organizations (id) on delete cascade,
  title            text not null,
  detail           text,
  status           task_status   not null default 'open',
  priority         task_priority not null default 'normal',
  due_on           date,
  assigned_user_id uuid references public.users (id) on delete set null,
  subject_type     entity_kind,
  subject_id       uuid,
  completed_at     timestamptz,
  created_at       timestamptz not null default now(),
  updated_at       timestamptz not null default now(),
  deleted_at       timestamptz
);

-- ============================================================================
--  Indexes
-- ============================================================================
--  Every RLS policy filters on organization_id, so it leads every composite
--  index — otherwise the policy forces a scan before the filter can help.

create index users_org_idx              on public.users (organization_id) where deleted_at is null;
create index properties_org_idx         on public.properties (organization_id, status) where deleted_at is null;
create index properties_name_trgm       on public.properties using gin (name gin_trgm_ops);
create index buildings_property_idx     on public.buildings (property_id) where deleted_at is null;
create index units_org_property_idx     on public.units (organization_id, property_id) where deleted_at is null;
create index units_status_idx           on public.units (organization_id, status) where deleted_at is null;
create index tenants_org_status_idx     on public.tenants (organization_id, status) where deleted_at is null;
create index tenants_name_trgm          on public.tenants using gin (full_name gin_trgm_ops);
create index tenants_portal_user_idx    on public.tenants (portal_user_id) where portal_user_id is not null;
create index leases_org_status_idx      on public.leases (organization_id, status) where deleted_at is null;
create index leases_unit_idx            on public.leases (unit_id);
create index leases_tenant_idx          on public.leases (primary_tenant_id);
create index leases_term_end_idx        on public.leases (organization_id, term_end) where deleted_at is null;
create index payments_lease_due_idx     on public.payments (lease_id, due_on desc);
create index payments_org_status_idx    on public.payments (organization_id, status, due_on);
create index requests_org_status_idx    on public.maintenance_requests (organization_id, status) where deleted_at is null;
create index requests_priority_idx      on public.maintenance_requests (organization_id, priority, created_at desc) where deleted_at is null;
create index requests_property_idx      on public.maintenance_requests (property_id) where deleted_at is null;
create index requests_tenant_idx        on public.maintenance_requests (tenant_id) where deleted_at is null;
create index requests_title_trgm        on public.maintenance_requests using gin (title gin_trgm_ops);
create index updates_request_idx        on public.maintenance_updates (request_id, created_at);
create index documents_org_idx          on public.documents (organization_id, category) where deleted_at is null;
create index documents_owner_idx        on public.documents (owner_type, owner_id) where deleted_at is null;
create index documents_tags_idx         on public.documents using gin (tags);
create index documents_name_trgm        on public.documents using gin (name gin_trgm_ops);
create index conversations_org_idx      on public.conversations (organization_id, last_message_at desc) where deleted_at is null;
create index participants_user_idx      on public.conversation_participants (user_id);
create index participants_tenant_idx    on public.conversation_participants (tenant_id);
create index messages_conversation_idx  on public.messages (conversation_id, created_at) where deleted_at is null;
create index notifications_recipient_idx on public.notifications (recipient_user_id, created_at desc);
create index notifications_unread_idx    on public.notifications (recipient_user_id) where read_at is null and dismissed_at is null;
create index activities_org_idx          on public.activities (organization_id, created_at desc);
create index tasks_org_status_idx        on public.tasks (organization_id, status, due_on) where deleted_at is null;
create index vendors_org_idx             on public.vendors (organization_id) where deleted_at is null;

-- ============================================================================
--  updated_at triggers
-- ============================================================================

do $$
declare t text;
begin
  foreach t in array array[
    'organizations','users','properties','buildings','units','tenants','leases',
    'payments','vendors','maintenance_requests','maintenance_updates','documents',
    'conversations','messages','notifications','activities','tasks'
  ]
  loop
    execute format(
      'create trigger %I before update on public.%I
         for each row execute function public.touch_updated_at()',
      t || '_touch_updated_at', t
    );
  end loop;
end;
$$;
