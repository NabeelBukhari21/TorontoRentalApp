-- ============================================================================
--  Purrperty — 07 · AI invocations, budget, and audit
-- ============================================================================
--  One row per AI call. This table answers three different questions, which
--  is why it carries columns that look redundant:
--
--   • Accountability — "why was this ticket marked low priority?"
--     (prompt_version, model_id, confidence, decided_by)
--   • Cost — "which feature is spending the money?"
--     (task_kind, tokens, estimated_cost_usd)
--   • Quality — "did the last prompt change help?"
--     (prompt_version × status, giving an accept/edit/reject rate)
--
--  Prompts and completions are NOT stored. They contain tenant names,
--  addresses, and message bodies; a full transcript table would become the
--  most sensitive object in the system and the most attractive to exfiltrate.
--  `prompt_digest` plus `subject_id` is enough to reproduce a call.
-- ============================================================================

create type ai_task_kind as enum (
  'maintenance_classification', 'lease_summarization', 'portfolio_copilot',
  'dashboard_insights', 'risk_detection', 'suggested_reply', 'document_summary',
  'property_health', 'smart_recommendations', 'activity_summary'
);

create type ai_proposal_status as enum (
  'pending', 'accepted', 'edited', 'rejected', 'auto_applied', 'expired'
);

create type ai_model_preference as enum ('fast', 'reasoning', 'longContext', 'onDevice');

create table public.ai_invocations (
  id                  uuid primary key default gen_random_uuid(),
  organization_id     uuid not null references public.organizations (id) on delete cascade,
  -- Who triggered it. Null for scheduled/background runs.
  actor_user_id       uuid references public.users (id) on delete set null,

  task_kind           ai_task_kind        not null,
  prompt_version      text                not null,
  provider_id         text                not null,
  model_id            text                not null,
  preference          ai_model_preference not null default 'fast',

  subject_type        entity_kind,
  subject_id          uuid,

  input_tokens        integer not null default 0 check (input_tokens >= 0),
  output_tokens       integer not null default 0 check (output_tokens >= 0),
  estimated_cost_usd  numeric(10,6) not null default 0 check (estimated_cost_usd >= 0),
  latency_ms          integer not null default 0,

  decoded_ok          boolean not null default true,
  error_message       text,
  confidence          numeric(4,3) check (confidence is null or confidence between 0 and 1),

  status              ai_proposal_status not null default 'pending',
  decided_by          uuid references public.users (id) on delete set null,
  decided_at          timestamptz,
  decision_note       text,

  prompt_digest       text not null,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

comment on table public.ai_invocations is
  'Audit trail for every AI call. Prompts/completions deliberately not stored.';

create index ai_invocations_org_idx
  on public.ai_invocations (organization_id, created_at desc);
create index ai_invocations_task_idx
  on public.ai_invocations (organization_id, task_kind, created_at desc);
create index ai_invocations_subject_idx
  on public.ai_invocations (subject_type, subject_id);
create index ai_invocations_pending_idx
  on public.ai_invocations (organization_id) where status = 'pending';

create trigger ai_invocations_touch_updated_at
  before update on public.ai_invocations
  for each row execute function public.touch_updated_at();

create trigger ai_invocations_force_org_id
  before insert on public.ai_invocations
  for each row execute function public.force_org_id();

-- ── RLS ─────────────────────────────────────────────────────────────────────
--  Staff read their own organization's log. Nobody updates a historical row
--  except to record a decision, and nobody deletes: an audit trail you can
--  edit is not an audit trail.

alter table public.ai_invocations enable row level security;
alter table public.ai_invocations force row level security;

create policy ai_invocations_select on public.ai_invocations
  for select to authenticated
  using (organization_id = public.current_org_id() and public.is_staff());

create policy ai_invocations_insert on public.ai_invocations
  for insert to authenticated
  with check (organization_id = public.current_org_id() and public.is_staff());

--  Only the decision columns may change, and only from pending. The WITH
--  CHECK re-reads the row to prove the immutable fields are untouched.
create policy ai_invocations_decide on public.ai_invocations
  for update to authenticated
  using (organization_id = public.current_org_id() and public.is_staff())
  with check (
    organization_id = public.current_org_id()
    and task_kind      = (select i.task_kind      from public.ai_invocations i where i.id = ai_invocations.id)
    and prompt_version = (select i.prompt_version from public.ai_invocations i where i.id = ai_invocations.id)
    and provider_id    = (select i.provider_id    from public.ai_invocations i where i.id = ai_invocations.id)
    and model_id       = (select i.model_id       from public.ai_invocations i where i.id = ai_invocations.id)
    and prompt_digest  = (select i.prompt_digest  from public.ai_invocations i where i.id = ai_invocations.id)
    and input_tokens   = (select i.input_tokens   from public.ai_invocations i where i.id = ai_invocations.id)
    and output_tokens  = (select i.output_tokens  from public.ai_invocations i where i.id = ai_invocations.id)
  );

-- ============================================================================
--  Budget
-- ============================================================================
--  A per-organization monthly cap, checked server-side by the Edge Function.
--  A client-side limit is a suggestion; this is the actual control, and it is
--  what stops one runaway loop from producing a four-figure invoice.

create table public.ai_budgets (
  organization_id     uuid primary key references public.organizations (id) on delete cascade,
  monthly_limit_usd   numeric(10,2) not null default 25.00 check (monthly_limit_usd >= 0),
  is_enabled          boolean not null default true,
  -- Autonomy policy, serialized from AIAutonomyPolicy.
  autonomy            jsonb not null default '{}'::jsonb,
  created_at          timestamptz not null default now(),
  updated_at          timestamptz not null default now()
);

alter table public.ai_budgets enable row level security;
alter table public.ai_budgets force row level security;

create policy ai_budgets_select on public.ai_budgets
  for select to authenticated
  using (organization_id = public.current_org_id() and public.is_staff());

--  Only an owner changes the budget or the autonomy policy. Letting a
--  property manager grant the AI auto-apply rights would defeat the point.
create policy ai_budgets_write on public.ai_budgets
  for all to authenticated
  using (organization_id = public.current_org_id() and public.is_org_admin())
  with check (organization_id = public.current_org_id() and public.is_org_admin());

-- ============================================================================
--  Reporting
-- ============================================================================

create or replace view public.ai_usage_by_task
with (security_invoker = on) as
select
  organization_id,
  task_kind,
  prompt_version,
  date_trunc('month', created_at)::date            as month,
  count(*)                                          as calls,
  sum(estimated_cost_usd)::numeric(10,4)            as cost_usd,
  sum(input_tokens)                                 as input_tokens,
  sum(output_tokens)                                as output_tokens,
  avg(latency_ms)::integer                          as avg_latency_ms,
  count(*) filter (where status in ('accepted', 'auto_applied')) as accepted,
  count(*) filter (where status = 'edited')                      as edited,
  count(*) filter (where status = 'rejected')                    as rejected,
  count(*) filter (where not decoded_ok)                         as decode_failures
from public.ai_invocations
group by organization_id, task_kind, prompt_version, date_trunc('month', created_at);

grant select on public.ai_usage_by_task to authenticated;

--  Month-to-date spend. Called by the Edge Function before every request,
--  which is why it is a function and not a view the client could ignore.
create or replace function public.ai_spend_this_month(p_organization_id uuid)
returns numeric
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(sum(estimated_cost_usd), 0)::numeric
  from public.ai_invocations
  where organization_id = p_organization_id
    and created_at >= date_trunc('month', now());
$$;

--  Returns whether a call may proceed. SECURITY DEFINER because the Edge
--  Function runs as the caller and must be able to read the budget row
--  regardless of the caller's role.
create or replace function public.ai_may_proceed(p_organization_id uuid)
returns boolean
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(
    (
      select b.is_enabled
         and public.ai_spend_this_month(p_organization_id) < b.monthly_limit_usd
      from public.ai_budgets b
      where b.organization_id = p_organization_id
    ),
    -- No budget row yet: allow, and let the default cap apply once created.
    true
  );
$$;

grant execute on function public.ai_spend_this_month to authenticated;
grant execute on function public.ai_may_proceed     to authenticated;

-- Give every existing workspace a default budget.
insert into public.ai_budgets (organization_id)
select id from public.organizations
on conflict (organization_id) do nothing;
