# ZivoConnect EMS — Phase 012 Parity Matrix
## Screens 00–28 Integration & Authoritative Backend Tracking

> **Last Updated:** 2026-09-22 — Phase 012 Backend Integration & Zero-Mock Architecture
>
> **Status Values:**
> - `CONNECTED` — Real backend data, typed models, functioning UI, offline cache & actions wired.
> - `PARTIALLY CONNECTED` — Real backend queries/RPC partially wired; some actions, filters or offline states pending.
> - `EXTERNAL DEPENDENCY` — Real UI and adapters built, but relies on third-party provider (e.g., payment gateway, SMS/FCM, GPS hardware).
> - `BLOCKED` — Missing prerequisite or verified backend conflict.

---

### Phase 012 Architecture Summary

| Layer | File(s) | Purpose |
|---|---|---|
| **Models** | `lib/models/models.dart` | `TeacherDashboardMetrics`, `ParentDashboardData`, `AuthorizedChild`, `DirectMessageItem`, `FinanceCurrencySummary`, `PaymentModel`, + all Phase 1–6 models |
| **RPC Client** | `lib/services/rpc_client.dart` | Typed wrappers for all Supabase `rpc()` calls (Screens 01–28) |
| **Teacher Repository** | `lib/repositories/teacher_repository.dart` | Fetch dashboard metrics, roll call, gradebook, gradebook setup; offline Drift queue |
| **Parent Repository** | `lib/repositories/parent_repository.dart` | Fetch authorized children (via `user_relationships`), parent dashboard, student 360, invoices, payments |
| **Messaging Repository** | `lib/repositories/messaging_repository.dart` | Conversations, thread, send, Supabase Realtime channel, deduplication |
| **Teacher Controllers** | `lib/controllers/teacher_controllers.dart` | `teacherDashboardControllerProvider`, roll call provider, gradebook provider, setup provider |
| **Parent Controllers** | `lib/controllers/parent_controllers.dart` | `parentChildrenProvider`, `activeSelectedChildProvider`, `parentDashboardDataProvider`, `parentMessagesControllerProvider`, invoice/payment/360 providers |
| **Providers** | `lib/providers/providers.dart` | `activeSessionProvider`, `rpcClientProvider`, `supabaseClientProvider`, `appDatabaseProvider`, all Phase 1–6 FutureProviders |
| **Sync Engine** | `lib/core/sync_engine.dart` | Offline mutation queue to Drift `OfflineQueueEntries` to Supabase |

---

### Screens 00–28 Status

| # | Screen Name | Flutter File | Repository | Provider | Supabase RPC / Table | Realtime | Status | Remaining Issue |
|---|---|---|---|---|---|---|---|---|
| **00** | Design System & Tokens | `lib/core/theme.dart` | N/A | N/A | N/A | No | **CONNECTED** | None |
| **01** | School Admin Command Center | `lib/screens/school_admin/school_admin_shell.dart` | RpcClient | `schoolAdminMetricsProvider` | `get_school_admin_dashboard_metrics()` | No | **PARTIALLY CONNECTED** | Detailed staff list / recent activity still raw-map parsing |
| **02** | Student 360 Unified Record | *(file to create)* | RpcClient | `student360Provider(id)` | `get_student_360_summary(student_profile_id)` | No | **PARTIALLY CONNECTED** | Full 8-tab Stitch view not yet implemented; RPC stub complete |
| **03** | Teacher Dashboard | `lib/screens/teacher/teacher_shell.dart` | `TeacherRepository` | `teacherDashboardControllerProvider` | `get_teacher_dashboard_metrics()` | No | **CONNECTED** | Zero hardcoded mocks. All KPIs, schedule, assignments, classes, announcements live |
| **04** | Teacher Attendance Roll Call | `lib/screens/teacher/teacher_operations_screen.dart` | `TeacherRepository` | `teacherRollCallProvider` | `get_attendance_roll_call()` + `daily_attendance` upsert | No | **CONNECTED** | Offline queue to Drift `OfflineQueueEntries` to sync engine |
| **05** | Teacher Gradebook | `lib/screens/teacher/teacher_gradebook_screen.dart` | `TeacherRepository` | `teacherGradebookProvider` | `get_teacher_gradebook()` + `grade_records` upsert | No | **CONNECTED** | Score validation (0 <= score <= max), live upsert, offline fallback |
| **06** | Parent Dashboard | `lib/screens/parent/parent_shell.dart` | `ParentRepository` | `parentDashboardDataProvider` + `parentChildrenProvider` | `get_parent_dashboard()` + `user_relationships` | No | **CONNECTED** | Child switcher from `user_relationships`. Zero mock children. Multi-currency fees |
| **07** | Parent Academics | `lib/screens/parent/parent_academics_screen.dart` | `ParentRepository` | `student360SummaryProvider(id)` | `get_student_360_summary()` | No | **CONNECTED** | Subjects, assessments, report card summary, KPI averages all live |
| **08** | Parent Fees & Payments | `lib/screens/finance/parent_fees_screen.dart` | `ParentRepository` | `studentInvoicesProvider` + `studentPaymentsProvider` | `invoices` + `payments` | No | **CONNECTED** | Balance = `total_amount - paid_amount`. Server-authoritative |
| **09** | Parent Messages | `lib/screens/parent/parent_messages_screen.dart` | `MessagingRepository` | `parentMessagesControllerProvider` | `direct_messages` + `profiles` | **Yes** | **CONNECTED** | Realtime INSERT on `recipient_profile_id`. Deduplication, lifecycle disposal, thread view |
| **10** | Super Admin Platform Overview | `lib/screens/super_admin/super_admin_shell.dart` | RpcClient | `superAdminMetricsProvider` | `get_super_admin_platform_metrics()` | No | **PARTIALLY CONNECTED** | KPI parsing complete; MAU from heartbeat wired |
| **11** | Super Admin Schools Directory | `lib/screens/super_admin/super_admin_shell.dart` | RpcClient | `superAdminSchoolsProvider` | `get_super_admin_schools_directory()` | No | **PARTIALLY CONNECTED** | School list rendering wired; tenant action dialogs pending |
| **12** | Finance Dashboard | `lib/screens/finance/school_finance_screen.dart` | RpcClient | `financeDashboardMetricsProvider` | `get_finance_dashboard_metrics()` | No | **PARTIALLY CONNECTED** | KPI cards live. Multi-currency charts pending |
| **13** | Invoices Management | `lib/screens/finance/invoices_screen.dart` | SupabaseClient | `invoicesProvider` | `invoices` + `invoice_items` + `fee_types` | No | **PARTIALLY CONNECTED** | Table live. Batch invoice generation dialog pending |
| **14** | Payments Ledger & Reconciliation | `lib/screens/finance/payments_ledger_screen.dart` | RpcClient | `paymentsLedgerProvider` | `payments` + `reconcile_payment_to_invoice()` | No | **PARTIALLY CONNECTED** | Ledger live. Unmatched reconciliation UI pending |
| **15** | Admissions Pipeline | `lib/screens/operations/admissions_screen.dart` | RpcClient | `admissionsPipelineProvider` | `get_admissions_pipeline()` | No | **PARTIALLY CONNECTED** | RPC stub and provider exist; Kanban board UI pending |
| **16** | Direct Messaging (Staff) | *(file to create)* | `MessagingRepository` | `parentMessagesControllerProvider` | `direct_messages` + Realtime | **Yes** | **PARTIALLY CONNECTED** | Repository fully implemented via Screen 09. Staff-facing view screen pending |
| **17** | Notification Centre | `lib/screens/school_admin/notifications_screen.dart` | RpcClient | `notificationsProvider` | `notifications` + `mark_all_notifications_read()` | No | **PARTIALLY CONNECTED** | List and mark-read wired; push/FCM = EXTERNAL DEPENDENCY |
| **18** | Fleet & Bus Tracking | `lib/screens/operations/bus_tracking_screen.dart` | SupabaseClient | `busTelemetryProvider` | `get_fleet_dashboard()` + `bus_telemetry` | **Yes** | **PARTIALLY CONNECTED** | Route list + live telemetry bound. GPS hardware = EXTERNAL DEPENDENCY |
| **19** | School Marketplace | `lib/screens/operations/marketplace_screen.dart` | SupabaseClient | `marketplaceItemsProvider` | `marketplace_items` + `marketplace_orders` | No | **PARTIALLY CONNECTED** | Catalog live. Payment gateway = EXTERNAL DEPENDENCY |
| **20** | Library Management | *(file to create)* | RpcClient | `libraryDashboardProvider` | `get_library_dashboard()` | No | **PARTIALLY CONNECTED** | RPC stub complete; screen implementation pending |
| **21** | Behaviour & Pastoral Support | *(file to create)* | RpcClient | `behaviorDashboardProvider` | `get_behavior_dashboard()` | No | **PARTIALLY CONNECTED** | RPC stub complete; screen implementation pending |
| **22** | Reports & Analytics | `lib/screens/school_admin/school_reports_screen.dart` | RpcClient | Inline in screen | `get_attendance_report()` + `get_academic_performance_report()` + `get_fee_collections_report()` | No | **CONNECTED** | All 3 report tabs wired to live RPCs. Filters: year, term, section. Table rendering live |
| **23** | School Settings | *(file to create)* | SupabaseClient | `schoolSettingsProvider` | `schools` table (`settings` JSONB) | No | **PARTIALLY CONNECTED** | Model scaffolded; settings form UI pending |
| **24** | Students Directory | *(file to create)* | RpcClient | `studentsDirectoryProvider` | `get_students_directory(academic_year_id)` | No | **PARTIALLY CONNECTED** | RPC stub complete; searchable directory UI pending |
| **25** | Classes & Sections Overview | `lib/screens/school_admin/classes_sections_screen.dart` | SupabaseClient | `classSectionsProvider` | `class_sections` + `get_classes_sections_overview()` | No | **PARTIALLY CONNECTED** | CRUD UI wired. Live enrolled-count cards from RPC pending |
| **26** | Gradebook Setup | `lib/screens/school_admin/gradebook_setup_screen.dart` | `TeacherRepository` | `teacherGradebookSetupProvider` | `get_gradebook_setup()` | No | **CONNECTED** | Category weights, assessment weights, validation wired to live RPC |
| **27** | Report Cards Management | `lib/screens/school_admin/report_cards_screen.dart` | RpcClient | `reportCardsOverviewProvider` | `get_report_cards_overview()` + `set_report_card_status()` + `bulk_publish_report_cards()` | No | **PARTIALLY CONNECTED** | Overview table live. Approval workflow and bulk publish wired |
| **28** | Announcements | `lib/screens/operations/announcements_screen.dart` | SupabaseClient | `announcementsProvider` | `announcements` table | No | **PARTIALLY CONNECTED** | List query wired. Realtime updates and role-audience filters pending |

---

### Hardcoded Mock Audit — Phase 012 Remediation

| Fixture | Location | Resolution |
|---|---|---|
| `Tariro Moyo` | `parent_shell.dart` | REMOVED — replaced by `user_relationships` query |
| `Kuda Moyo` | `parent_shell.dart` | REMOVED — replaced by `user_relationships` query |
| `94.6%` attendance | `parent_shell.dart` | REMOVED — replaced by `get_parent_dashboard()` RPC KPI |
| `$320` fees | `parent_shell.dart` | REMOVED — replaced by `FinanceCurrencySummary.formattedOutstanding` |
| `Classes Today = 5` | `teacher_shell.dart` | REMOVED — replaced by `TeacherDashboardMetrics.classesToday` from RPC |
| `Attendance = 2` | `teacher_shell.dart` | REMOVED — replaced by `TeacherDashboardMetrics.attendancePending` from RPC |
| `To Mark = 18` | `teacher_shell.dart` | REMOVED — replaced by `TeacherDashboardMetrics.submissionsToMark` from RPC |
| `Messages = 4` | `teacher_shell.dart` | REMOVED — replaced by `TeacherDashboardMetrics.unreadMessages` from RPC |
| Static schedule items | `teacher_shell.dart` | REMOVED — replaced by `TeacherDashboardMetrics.schedule` list from RPC |
| `1420` students | `school_admin_shell.dart` | REMOVED — replaced by `total_students` from `get_school_admin_dashboard_metrics()` |
| `96.2%` attendance | `school_admin_shell.dart` | REMOVED — replaced by `attendance_rate` from RPC |
| `Mr E. Chiwara`, `Cambridge IGCSE` | `parent_academics_screen.dart` | REMOVED — replaced by `get_student_360_summary()` live data |

---

### Implementation Progression Roadmap

- DONE **Stage 1 (Foundation):** `RpcClient`, `ActiveSessionController`, `AppDatabase` (Drift), `SyncEngine`, heartbeat `touch_active_profile`.
- DONE **Stage 2 (Teacher):** Screens 03, 04, 05, 26 — CONNECTED via `TeacherRepository` + `teacherDashboardControllerProvider`.
- DONE **Stage 3 (Admin Core):** Screen 01, 22, 25, 26, 27 — CONNECTED or PARTIALLY CONNECTED.
- DONE **Stage 4 (Parent):** Screens 06, 07, 08, 09 — CONNECTED via `ParentRepository` + `MessagingRepository`.
- DONE **Stage 5 (Finance):** Screens 12, 13, 14 — PARTIALLY CONNECTED.
- PENDING **Stage 6 (Operations):** Screens 15, 16, 17, 18, 19, 20, 21, 23 — RPCs stubbed; UI screens pending.
- PENDING **Stage 7 (Super Admin):** Screens 10, 11 — PARTIALLY CONNECTED.
- PENDING **Stage 8 (Final Parity & QA):** Implement remaining screens (02, 15–17, 20–24), integration tests, CI.
