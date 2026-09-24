# ZivoConnect EMS — Integration Parity Matrix
## Screens 00–28 · Evidence-Based Status

> **Updated:** 2026-09-24
>
> **Source-of-truth order:** live Supabase → current GitHub branch → frozen Screens 00–28 → older handover/docs.
>
> **Status values**
> - `CONNECTED` — real backend data and actions are wired, no production mock dependency, tenant/role scope is authoritative.
> - `PARTIALLY CONNECTED` — useful real functionality exists, but an implementation/architecture gap remains.
> - `EXTERNAL DEPENDENCY` — completion depends on a third-party provider or hardware outside the current codebase.
> - `BLOCKED` — a verified prerequisite is missing.

---

## Current Architecture Baseline

- Flutter 3 / Dart, Riverpod, go_router, Supabase and Drift remain the application foundation.
- Security-critical AI calls now go through `ai-chat-proxy`; client-side OpenRouter calls are removed from the active application path.
- Profile switching uses the server-authoritative `switch-profile` Edge Function and refreshes auth before local context changes.
- Live Supabase migrations and Edge Functions have been reconciled into source control and replay successfully in CI.
- Flutter analyze/test/web-build and local Supabase migration replay are green on the latest validated branch head.
- Payment reconciliation, report-card lifecycle, marketplace checkout, admissions status/linking, library actions, behaviour actions, announcements lifecycle and school settings use server-authoritative RPCs where available.

---

## Screens 00–28

| # | Screen | Current implementation | Status | Remaining verified gap |
|---|---|---|---|---|
| **00** | Design System & Tokens | `lib/core/theme.dart` + shared Stitch widgets | **CONNECTED** | None |
| **01** | School Admin Command Center | Live admin metrics + real quick-action routes | **PARTIALLY CONNECTED** | Some secondary activity/staff presentation still uses compatibility/raw-map paths |
| **02** | Student 360 Unified Record | Authoritative `get_student_360_summary()` exists and is consumed by student/parent flows | **PARTIALLY CONNECTED** | Dedicated frozen standalone Screen 02 view is still missing |
| **03** | Teacher Dashboard | `TeacherRepository` + live dashboard RPC | **CONNECTED** | None material |
| **04** | Teacher Attendance Roll Call | Verified roll-call RPC + correct `student_profile_id` mutation contract + offline queue fallback | **CONNECTED** | Broader offline engine improvements are platform-wide, not screen-specific |
| **05** | Teacher Gradebook | Verified gradebook RPC + `teacher_remarks`/correct conflict key + server validation | **CONNECTED** | None material |
| **06** | Parent Dashboard | Linked-child context + authoritative parent dashboard contract | **CONNECTED** | None material |
| **07** | Parent Academics | Uses `get_parent_academics()` authoritative subject/assessment/report-card payload | **CONNECTED** | None material |
| **08** | Parent Fees & Payments | Real multi-currency account data from `get_parent_fees()` | **PARTIALLY CONNECTED / EXTERNAL DEPENDENCY** | Real checkout/payment gateway + webhook not connected; UI no longer fakes confirmed payment |
| **09** | Parent Messages | `MessagingRepository`, realtime, dedupe, retry-safe compose, mobile conversation switching | **CONNECTED** | Message attachments require a storage provider/bucket |
| **10** | Super Admin Platform Overview | Authoritative platform metrics RPC | **PARTIALLY CONNECTED** | Final role acceptance and action coverage still pending |
| **11** | Super Admin Schools Directory | Directory now reads authoritative schools-directory RPC; school status action is server-authoritative | **PARTIALLY CONNECTED** | Final subscription/action acceptance still pending |
| **12** | Finance/Bursar Dashboard | Currency-aware backend `currency_totals[]` wired to KPI rendering | **PARTIALLY CONNECTED** | `expenses` table has no currency column, so expense analytics cannot yet be truly multi-currency |
| **13** | Invoices Management | Dedicated routed screen + live invoice/currency fields + server batch generation | **CONNECTED** | None material |
| **14** | Payments Ledger & Reconciliation | Dedicated routed ledger + nullable unmatched payments + server reconciliation RPC | **CONNECTED** | Incoming gateway/webhook ingestion is an external integration |
| **15** | Admissions Pipeline | Dedicated routed pipeline + status transitions + accepted-student linking | **CONNECTED** | Unauthenticated applicant document upload needs a signed-upload flow if required |
| **16** | Direct Messaging (Staff) | Dedicated screen/controller/repository + same-school contact discovery + realtime; DB write policy hardened | **CONNECTED** | Message attachments require storage provider/bucket |
| **17** | Notification Centre | `get_notification_center()`, mark-read/all-read RPCs + profile-scoped realtime | **CONNECTED / EXTERNAL DEPENDENCY** | Push delivery requires FCM/APNs credentials/provider |
| **18** | Fleet & Bus Tracking | Real routes/stops + realtime `bus_telemetry` + stale telemetry handling | **PARTIALLY CONNECTED / EXTERNAL DEPENDENCY** | GPS hardware/provider required; some Supabase/realtime lifecycle remains inside widget |
| **19** | School Marketplace | Server-authoritative atomic order RPC + real catalog/orders + currency display | **PARTIALLY CONNECTED / EXTERNAL DEPENDENCY** | Item listing still uses legacy service path; marketplace images/payment provider not provisioned |
| **20** | Library Management | Dedicated routed screen + dashboard RPC + issue/return/fine RPCs + role-gated actions | **CONNECTED** | None material |
| **21** | Behaviour & Pastoral Support | Dedicated routed screen + behaviour dashboard + update/guardian workflows | **CONNECTED** | None material |
| **22** | Reports & Analytics | Verified attendance, academic-performance and scoped fee-report RPCs | **PARTIALLY CONNECTED** | Screen still calls `RpcClient` directly instead of controller/repository layer |
| **23** | School Settings | Dedicated routed form + `get_school_configuration()` / `patch_school_configuration()` allow-list | **CONNECTED** | Platform subscription fields intentionally read-only |
| **24** | Students Directory | Dedicated searchable/filterable directory backed by `get_students_directory()` | **CONNECTED** | Mutations intentionally remain in Enrollment workflow |
| **25** | Classes & Sections | Real classes/sections data and create actions | **PARTIALLY CONNECTED** | Create mutations still call legacy academic service directly from widget |
| **26** | Gradebook Setup | `get_gradebook_setup()` drives weight matrix and validity | **PARTIALLY CONNECTED** | Term/category creation still has legacy direct-service paths |
| **27** | Report Cards Management | Server-authoritative generate/status/bulk-publish lifecycle | **CONNECTED** | None material |
| **28** | Announcements | Dedicated management screen + server draft/status RPCs + school-scoped realtime | **CONNECTED / EXTERNAL DEPENDENCY** | Attachment storage is intentionally disabled until a dedicated bucket/provider exists |

---

## Current Priority Register

### Architecture cleanup still required
1. Screen 22: move report execution behind controller/repository.
2. Screen 25: move class/section mutations behind repository/controller.
3. Screen 26: move grading-term/category mutations behind repository/controller.
4. Screen 18: move realtime/channel and route/stop mutation lifecycle out of widget.
5. Screen 19: move item-listing mutation out of widget/legacy service.

### External dependencies — do not fake completion
- Parent payment checkout/provider webhook.
- Push delivery via FCM/APNs.
- GPS hardware/provider for fleet telemetry.
- Message, marketplace and announcement attachment/image storage buckets/providers.
- Optional unauthenticated admissions document signed-upload flow.

### Platform-wide work after screen parity
- Realtime lifecycle acceptance across profile/school/logout switches.
- Offline-first verification and safe conflict handling.
- Role-by-role acceptance testing for Super Admin, School Admin, Teacher, Student, Parent, Finance Manager and Registrar.
- Expand automated tests beyond the minimal historical suite.
- Final secret/mock scans and final parity review before merge.

---

## Guardrails

- Do not invent RPC names, parameters, JSON keys, tables, roles, enums or Drift structures.
- Do not combine money across currencies.
- Do not queue payment reconciliation or report publication offline.
- Do not claim external-provider features are complete until the provider is actually connected.
- Do not redesign the frozen Screen 00–28 visual source of truth during backend/integration work.
- Do not work directly on `main`.
