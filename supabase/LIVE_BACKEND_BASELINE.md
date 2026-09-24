# ZivoConnect Live Backend Baseline

Reconciliation date: 2026-09-24

This document records the production Supabase backend state that the Phase 1 reconciliation migrations and Edge Function sources are intended to reproduce. Production was treated as read-only during this reconciliation; the migrations in this branch were captured from live metadata and function definitions and were not applied back to production.

## Project

- Supabase project ref: `drxnnhjxjpyadwccaxnk`
- PostgreSQL major version: 17
- Public tables: 66
- Public tables with RLS disabled: 0

## Application roles

The live `public.app_role` enum contains:

- `super_admin`
- `school_admin`
- `teacher`
- `parent`
- `student`
- `finance_manager`
- `registrar`

## Realtime

The live `supabase_realtime` publication contains exactly these ZivoConnect public tables:

- `announcements`
- `bus_telemetry`
- `direct_messages`
- `notifications`

`payments` is not part of the Realtime publication and must not be treated as Realtime-enabled by the Flutter client unless deliberately changed in a future migration.

## Storage

Production has two private document buckets:

- `student-documents`
- `admissions-documents`

Both use a 20 MiB file-size limit and allow PDF, JPEG, PNG, WebP, legacy Word (`.doc`) and modern Word (`.docx`) MIME types.

Expected path conventions:

- Student documents: `[school_id]/[student_profile_id]/...`
- Admissions documents: `[school_id]/[application_id]/...`

Unauthenticated applicant uploads are not supported by the current policy model. If public applicant upload is required later, use a signed-upload/server-authorized flow rather than making a bucket public.

## Edge Functions

Live JWT-protected Edge Functions captured in source control:

- `ai-chat-proxy` — production version 2, `verify_jwt = true`
- `switch-profile` — production version 1, `verify_jwt = true`

The AI provider credential remains a server-side secret and must never be bundled into Flutter.

## Backend reconciliation scope

The reconciliation migrations capture the post-baseline production additions in logical layers:

1. Missing tables, tenant metadata, indexes and new roles.
2. Later columns/constraints on baseline tables.
3. Active profile / tenant context helper functions.
4. New-table RLS policies.
5. Private trigger functions.
6. Trigger dependency functions and production automation triggers.
7. Finance RPCs.
8. Gradebook and report-card RPCs.
9. Student term-report calculation.
10. Teacher Gradebook RPC.
11. School/Teacher dashboards and directories.
12. Student 360.
13. Reports & Analytics.
14. Parent academics and fees.
15. Parent Dashboard.
16. Admissions and Fleet.
17. Library and Behaviour/Pastoral Support.
18. Announcements and School Settings.
19. Marketplace actions.
20. Notifications, preferences and push-token RPCs.
21. Super Admin RPCs.
22. Storage and Realtime configuration.
23. RPC execute grants/revokes.
24. Admissions/Fleet table extensions found during the final schema comparison.
25. Later RLS policies on baseline tables for Registrar, Finance Manager, library, behaviour and staff visibility.

## Known production inconsistency: push platforms

The live `register_push_token(p_token, p_platform)` RPC accepts:

- `android`
- `ios`
- `web`
- `windows`
- `macos`
- `linux`

However, the live `push_tokens_platform_check` table constraint currently permits only:

- `android`
- `ios`
- `web`

Phase 1 intentionally preserves the production table constraint instead of silently changing production behavior during reconciliation. This must be resolved as a deliberate follow-up migration before desktop push registration is considered supported.

## Source-of-truth rule after Phase 1

For future implementation work, use this priority when sources disagree:

1. Verified live Supabase contract / reconciled migration source
2. Current GitHub Flutter/backend source
3. Frozen Screens 00–28
4. Phase 012 parity matrix
5. Older handover/architecture documentation

## Validation status

The definitions were captured from live PostgreSQL metadata (`pg_get_functiondef`, constraints, policies, publication membership, Storage metadata) and deployed Edge Function source.

The complete migration chain was replayed successfully from scratch on 2026-09-24 in an isolated Docker-backed local Supabase instance through GitHub Actions using `supabase db reset --local`. No production credentials or production database writes were used for this validation.

Phase 1 therefore has both source-capture evidence and a successful clean migration replay. Functional role-by-role behavior remains part of the later acceptance-testing phase rather than this source-reconciliation phase.
