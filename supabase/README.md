# Purrperty — Supabase backend

Everything the app talks to, and how to stand it up.

## 1. Create the project

1. Create a project at [supabase.com/dashboard](https://supabase.com/dashboard). Pick a region near your users (`ca-central-1` for Toronto).
2. Copy the **Project URL** and the **anon public** key from Project Settings → API.

> Take the **anon** key, not the `service_role` key. The service key bypasses every policy in `03_rls.sql`, and anything shipped in an app binary should be assumed public.

## 2. Run the migrations

In order. Either paste each file into the SQL Editor, or use the CLI:

```bash
supabase link --project-ref <your-ref>
supabase db push
```

| File | What it does |
|---|---|
| `20260724000100_extensions_and_enums.sql` | `pgcrypto`, `pg_trgm`, and every enum type |
| `20260724000200_tables.sql` | 19 tables, indexes, `updated_at` triggers |
| `20260724000300_rls.sql` | Identity helpers, org stamping, RLS policies |
| `20260724000400_functions_storage_views.sql` | Signup trigger, org RPCs, storage buckets, aggregate views |
| `20260724000500_trend_rpcs.sql` | Occupancy and revenue chart functions |

Enum values are copied from the `rawValue` of the Swift `Domain` enums. **If you change one, change both** — a mismatch decodes silently to `.unknown` rather than failing loudly.

## 3. Configure the app

Create `RentalApp/RentalApp/Supabase.xcconfig` (already gitignored):

```
SUPABASE_URL = https:/$()/your-project.supabase.co
SUPABASE_ANON_KEY = eyJhbGciOi...
```

The `/$()/` is not a typo — xcconfig treats `//` as a comment, and that empty variable breaks up the sequence.

Then:

1. Project → Info → Configurations → set **Supabase.xcconfig** for Debug and Release.
2. Target → Info → add two entries: `SUPABASE_URL` = `$(SUPABASE_URL)` and `SUPABASE_ANON_KEY` = `$(SUPABASE_ANON_KEY)`.
3. Target → Info → URL Types → add scheme `rentos` (also needed for deep links and the OAuth callback).

A missing value crashes at launch with instructions rather than failing as a confusing 401 later.

## 4. Auth settings

In Authentication → Providers / URL Configuration:

- **Email**: on. Turn *Confirm email* off for development, on for production — `SupabaseAuthService.signUp` handles both (it reports "check your email" when no session comes back).
- **Redirect URLs**: add `rentos://auth-callback` and `rentos://password-reset`.
- **Apple / Google**: optional; the app's social buttons call `signInWithOAuth`.
- **MFA**: enable TOTP to exercise the `.mfaRequired` branch.

## 5. Verify

Sign up in the app. You should see:

- a row in `auth.users`, and one in `public.users` created by the `on_auth_user_created` trigger, with role `viewer` and a null `organization_id`;
- the app route to the org-setup wizard (that null org is exactly what `AuthSession.needsOrganization` keys on);
- after finishing setup, your `users` row promoted to `owner` with the new `organization_id`.

Prove RLS works — as a signed-in user in the SQL editor:

```sql
-- Should return only your own organization's rows.
select count(*) from public.properties;

-- Should return 0, not an error: the policy hides other orgs rather
-- than admitting they exist.
select count(*) from public.properties
where organization_id <> public.current_org_id();
```

And confirm the org can't be forged — this insert succeeds but the trigger rewrites the id:

```sql
insert into public.properties (organization_id, name)
values ('00000000-0000-0000-0000-000000000000', 'Forged')
returning organization_id;   -- comes back as YOUR org, not the zero uuid
```

## Security model

- **The client is assumed hostile.** The anon key is public by design; every table is behind RLS and grants nothing on its own.
- **`organization_id` is never accepted from the client.** A `BEFORE INSERT` trigger overwrites it with `current_org_id()`, so a forged value is ignored rather than merely rejected.
- **Roles are server-side.** `users.role` is set by `create_organization()` and `set_member_role()`; the latter is owner-only and refuses to demote the last owner. Nothing in `raw_user_meta_data` influences authorization.
- **The app's `AppRole` is computed, not stored.** `current_app_role()` derives it from the rows that actually grant access, so the UI can't drift from what RLS will allow.
- **Storage is private.** All four buckets are non-public; access is by signed URL, and object paths must begin with the caller's organization id.
- **Internal maintenance notes** (`is_internal`) are filtered by policy, not by the client — a hand-written REST call can't read them either.
- **Notifications have no INSERT policy.** Only triggers and service-role functions create them, so one user can't spam another's feed.

## Status

| Domain | Backend |
|---|---|
| Authentication, MFA, biometrics | Supabase |
| Organization creation + membership | Supabase |
| Properties, Units | Supabase |
| Tenants, Leases, Maintenance, Documents, Notifications, Messaging | schema + RLS ready; repositories still in-memory |

The remaining repositories are swapped one line at a time in `AppContainer.supabaseGraph()`. `AppContainer.live(backend: .inMemory)` still returns the full mock graph, and previews always use it.
