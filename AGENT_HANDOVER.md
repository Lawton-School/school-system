# ZivoConnect EMS � Complete Agent Handover Document

> **Purpose**: Full system handover. Any AI agent or developer picking up this project can understand every layer, locate every file, and resume development immediately after reading this document and loading the `.env` secrets.

---

## 0. Quick-Start Checklist

```
1. Load .env from the project root � all secrets are consolidated there.
2. Run: cd my_flutter_app && flutter pub get
3. Run: flutter run  (connects to the live Supabase cloud project)
4. The Supabase database is already fully deployed � no migrations to run.
5. Both Edge Functions are deployed to the live project.
```

---

## 1. Project Identity

| Property | Value |
|---|---|
| **Product Name** | ZivoConnect EMS |
| **Product Type** | Multi-tenant SaaS � Educational Management System |
| **Target Market** | Primary, secondary and tertiary institutions (Zimbabwe focus, Africa-ready) |
| **Version** | 1.0.0 |
| **Supabase Project Ref** | drxnnhjxjpyadwccaxnk |
| **Supabase Dashboard** | https://supabase.com/dashboard/project/drxnnhjxjpyadwccaxnk |
| **Supabase REST URL** | https://drxnnhjxjpyadwccaxnk.supabase.co |
| **AI Provider** | OpenRouter ? deepseek/deepseek-chat |
| **Workspace Root** | c:\Users\lawto\OneDrive\Desktop\Antigravity\School System\ |

---

## 2. All Secrets (.env)

**File:** `School System/.env`

```
SUPABASE_URL=https://drxnnhjxjpyadwccaxnk.supabase.co
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImRyeG5uaGp4anB5YWR3Y2NheG5rIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODYzMTc4NjEsImV4cCI6MjEwMTg5Mzg2MX0.q1vONwqQuqbYmn0GemxJimh5qkiRBIaKkgi5NyehkLU

OPENROUTER_API_KEY=<OPENROUTER_API_KEY>
```

**Key notes:**
- `SUPABASE_ANON_KEY` � used in the Flutter client (constants.dart). Safe for public use; RLS enforces data access.
- `SUPABASE_SERVICE_ROLE_KEY` � NEVER expose client-side. Used only inside Edge Functions (server-side).
- `OPENROUTER_API_KEY` - supply via `.env` / `--dart-define`; do not commit a live key. Before production, move to a Supabase Edge Function proxy (ai-chat-proxy).

---

## 3. Technology Stack

| Layer | Technology | Notes |
|---|---|---|
| Frontend | Flutter 3.x + Dart | Mobile / Tablet / Desktop responsive |
| State Management | Flutter Riverpod 2.x | StateNotifierProvider, FutureProvider, StreamProvider |
| Routing | go_router | Shell-route architecture + auth redirect guards |
| Typography | Google Fonts � Inter | Applied globally via AppTheme |
| Backend | Supabase Cloud | PostgreSQL 15+, Auth, Storage, Edge Functions |
| Database | PostgreSQL + RLS | Multi-tenancy via school_id row-level security |
| Auth | Supabase Auth + JWT Claims | Custom claims via set-user-claims Edge Function hook |
| Offline Sync | Drift (SQLite ORM) | Delta sync engine in sync_engine.dart |
| AI Tutor | OpenRouter ? DeepSeek | Model: deepseek/deepseek-chat |
| Preferences | shared_preferences | Active session (school_id, role, profile_id) |
| HTTP | dart:http | Used for OpenRouter AI calls in services.dart |

---

## 4. Full Repository File Map

```
School System/
+-- .env                                     ALL SECRETS (see Section 2)
+-- .gitignore
+-- AGENT_HANDOVER.md                        THIS FILE
+-- SETUP_GUIDE.md                           Manual Supabase setup steps
+-- ZIVOCONNECT_SYSTEM_CONTEXT.md            Architecture context for AI assistants
+-- implementation_plan.md                   Original DB/RLS design blueprint
+-- roadmap.md                               Module-by-module phased roadmap
+-- task.md                                  Task checklist (historical)
+-- walkthrough.md                           Deployment walkthrough log
�
+-- supabase/
�   +-- config.toml                          Supabase CLI config (project ref set)
�   +-- master_setup.sql                     SINGLE-FILE complete schema (already executed live)
�   +-- functions/
�   �   +-- set-user-claims/index.ts         Auth Hook: injects school_id/role/profile_id into JWT
�   �   +-- invite-user/index.ts             Super Admin: invites school admin via email
�   +-- migrations/
�       +-- 20260810000000_init_enums_and_functions.sql
�       +-- 20260810000001_core_schema.sql
�       +-- 20260810000002_rls_policies.sql
�       +-- 20260810000003_modules_schema.sql
�       +-- 20260810000004_indexes_and_optimizations.sql
�
+-- scratch/
�   +-- verify_schema.sql                    Schema validation SQL (run in Supabase SQL Editor)
�   +-- apply_migrations_cdp.js              Node.js helper to apply migrations programmatically
�
+-- my_flutter_app/
    +-- pubspec.yaml                         Flutter dependencies
    +-- lib/
        +-- main.dart                        App entry point (Supabase init + ProviderScope)
        +-- core/
        �   +-- constants.dart               Supabase URL/keys, OpenRouter key, role strings, pref keys
        �   +-- theme.dart                   Full brand design system (colors, typography, components)
        �   +-- grading_engine.dart          ZIMSEC + Cambridge grading calculation logic
        �   +-- sync_engine.dart             Drift delta-sync engine (offline-first)
        +-- models/
        �   +-- models.dart                  All Dart model classes with fromMap/toMap
        +-- services/
        �   +-- services.dart                All Supabase service methods (~1900 lines)
        +-- providers/
        �   +-- providers.dart               All Riverpod providers + ActiveSessionNotifier
        +-- router/
        �   +-- router.dart                  go_router config + AppRoutes constants
        +-- widgets/
        �   +-- shared_widgets.dart          SyncStatusBadge, MetricCard, StatusChip, ErrorCard
        +-- screens/
            +-- auth/
            �   +-- login_screen.dart                Animated login (email/pass, forgot-password sheet)
            �   +-- profile_picker_screen.dart       Multi-school profile selector
            +-- super_admin/
            �   +-- super_admin_shell.dart           Tenant management, school creation, admin invite
            +-- school_admin/
            �   +-- school_admin_shell.dart          Main admin portal (users, operations, structure)
            �   +-- academic_years_screen.dart       CRUD for academic years
            �   +-- classes_sections_screen.dart     Classes + section management
            �   +-- subjects_screen.dart             Subject catalog management
            �   +-- teacher_assignment_screen.dart   Assign teachers to sections/subjects
            �   +-- student_enrollment_screen.dart   Enroll students into sections
            �   +-- parent_student_mapping_screen.dart  Link parents to students
            �   +-- gradebook_setup_screen.dart      Configure curriculum, terms, assessment categories
            �   +-- report_cards_screen.dart         Report card review, approval, and portal
            +-- teacher/
            �   +-- teacher_shell.dart               Teacher dashboard shell
            �   +-- teacher_operations_screen.dart   Attendance roll-call, leave requests, announcements
            �   +-- teacher_gradebook_screen.dart    Spreadsheet-style grade entry matrix
            �   +-- course_builder_screen.dart       LMS course/lesson/assignment builder
            +-- parent/
            �   +-- parent_shell.dart                Parent dashboard (children overview tabs)
            +-- student/
            �   +-- student_shell.dart               Full student dashboard (60KB - most complex screen)
            �   +-- student_lms_screen.dart          Course listing + submission portal
            �   +-- student_attendance_screen.dart   Own attendance calendar + stat cards
            �   +-- ai_tutor_screen.dart             AI Study Tutor chat interface
            +-- finance/
            �   +-- school_finance_screen.dart       Admin: fee setup, invoices, payroll, budgets, expenses
            �   +-- parent_fees_screen.dart          Parent: view invoices + multi-method payment modal
            +-- operations/
                +-- bus_tracking_screen.dart         Live GPS radar, driver info, bus stop schedule
                +-- marketplace_screen.dart          School-scoped buy/sell marketplace + cart + orders
                +-- sync_diagnostics_screen.dart     Offline sync status, error logs, manual sync trigger
```

---

## 5. Backend Architecture (Supabase)

### 5.1 Database Tables (Complete List)

**Core Tenant and Identity**
| Table | Purpose |
|---|---|
| schools | Tenant records (name, subdomain, status, settings) |
| profiles | User profiles scoped to a school (user_id ? auth.users, role, school_id) |
| parent_student_relationships | Maps parent profile_id ? student profile_id |

**Academic Structure**
| Table | Purpose |
|---|---|
| academic_years | Scholastic years per school |
| grading_terms | Term 1/2/3 with date ranges and weights |
| classes | Grade levels (e.g. Grade 10) |
| class_sections | Classroom groups (e.g. Grade 10 - Section A) |
| subjects | Subject catalog per school |
| subject_teachers | Many-to-many: teacher profile ? section + subject |
| student_enrollments | Student ? class_section for an academic_year |

**Attendance and Leave**
| Table | Purpose |
|---|---|
| attendance_records | Daily student attendance (present/absent/late/excused) |
| staff_attendance | Teacher clock-in/clock-out timestamps |
| staff_leave_requests | Leave requests with type, dates, reason, status |

**Academics � Gradebook and LMS**
| Table | Purpose |
|---|---|
| assessment_categories | e.g. CALA, Final Exam, Coursework per subject/term |
| assessments | Individual assessments with max score and weight |
| grade_records | Student score per assessment |
| report_cards | Aggregated termly report card per student |
| courses | LMS courses linked to subject/section |
| lessons | Lessons within a course |
| assignments | Assignments with due dates and max scores |
| submissions | Student submission per assignment |

**Finance**
| Table | Purpose |
|---|---|
| fee_structures | Fee templates per school |
| fee_categories | Categories within a fee structure |
| invoices | Student invoice per term |
| invoice_items | Line items within an invoice |
| payments | Payment transactions (method, amount, reference) |
| bursary_schemes | Scholarship/bursary definitions |
| student_bursaries | Bursary allocation per student |
| payroll_runs | Monthly payroll execution records |
| salary_records | Individual staff salary per payroll run |
| expenses | School expenditure logs |
| budgets | Department budget caps with utilization |

**Operations**
| Table | Purpose |
|---|---|
| buses | Fleet vehicles (plate, capacity, driver) |
| bus_routes | Named routes with stop sequences |
| bus_telemetry | High-frequency GPS pings |
| school_announcements | Bulletin board posts (target_role audience filter) |
| direct_messages | Teacher/Parent messaging (RLS enforced) |
| push_tokens | FCM/APNs device tokens for push notifications |
| ai_conversations | AI Tutor session per student |
| marketplace_items | Items for sale (school-scoped) |
| orders | Buyer purchase records |
| order_items | Line items per order |
| admissions | Student application pipeline |

### 5.2 Row Level Security Model

Every tenant table has RLS enabled. Policies use two helper functions:

```sql
-- Returns active school_id from JWT app_metadata
public.get_active_school_id() -- returns uuid

-- Returns active role from JWT app_metadata
public.get_active_role() -- returns text
```

Tenant isolation rule � every policy includes:
```sql
school_id = public.get_active_school_id()
```

Cross-school parent access: parent_student_relationships allows parents to read children's data across multiple schools by matching auth.uid() against linked profile IDs.

### 5.3 Enums

```
user_role:         super_admin | school_admin | teacher | parent | student
attendance_status: present | absent | late | excused
invoice_status:    draft | sent | paid | overdue | cancelled
payment_method:    ecocash | stripe | bank_transfer | cash | voucher
curriculum_type:   zimsec | cambridge_igcse | cambridge_alevel
ticket_status:     open | in_progress | resolved | closed
leave_status:      pending | approved | rejected
```

### 5.4 Edge Functions

**set-user-claims** � `supabase/functions/set-user-claims/index.ts`
- Trigger: Supabase Auth Hook ? "Custom Access Token"
- Action: Queries profiles table, injects {school_id, role, profile_id} into JWT app_metadata
- Required config: Supabase Dashboard ? Authentication ? Hooks ? Add hook

**invite-user** � `supabase/functions/invite-user/index.ts`
- Trigger: Called from Flutter via supabaseClient.functions.invoke('invite-user')
- Action: Validates caller is super_admin (JWT check), then calls auth.admin.inviteUserByEmail()
- Only accessible to Super Admin role

### 5.5 Indexes

40+ composite B-tree and partial indexes targeting:
- All school_id tenant columns (every major table)
- updated_at columns (offline delta sync timestamp queries)
- deleted_at IS NULL partial indexes (soft-delete filtering)
- user_id on profiles (Profile Picker query)
- Compound: (school_id, section_id, date) on attendance_records

---

## 6. Frontend Architecture (Flutter)

### 6.1 App Entry � main.dart

1. WidgetsFlutterBinding.ensureInitialized()
2. Load SharedPreferences
3. Initialize Supabase with 15-second timeout (using keys from AppConstants)
4. Mount ProviderScope with sharedPreferencesProvider override
5. Run ZivoConnectApp � wraps MaterialApp.router using routerProvider

### 6.2 Session and Auth Flow

```
User opens app
  |
go_router redirect guard checks:
  +- auth.currentUser == null?  ? /login
  +- activeSession == null?     ? /profile-picker
  +- session exists?            ? /[role-dashboard]
```

ActiveSession model (persisted in SharedPreferences):
```dart
class ActiveSession {
  final String schoolId;
  final String schoolName;
  final String profileId;
  final String role;  // one of AppRoles.*
}
```

ActiveSessionNotifier (Riverpod StateNotifierProvider):
- _loadFromPrefs() � restores session on boot
- setActiveSession() � called from ProfilePickerScreen after user selects a profile
- clearSession() � called on logout

### 6.3 Design System � theme.dart

| Token | Hex | Usage |
|---|---|---|
| primary | #6366F1 | Indigo � buttons, icons, active nav |
| secondary | #10B981 | Emerald � success states, finance |
| accent | #F59E0B | Amber � warnings, highlights |
| danger | #EF4444 | Red � errors, deletions |
| backgroundDark | #0A0E1A | Dark mode scaffold |
| backgroundLight | #F8F9FB | Light mode scaffold |
| cardDark | #1A2236 | Dark mode card surface |
| Font | Inter | Google Fonts, applied globally |

Both dark and light ThemeData objects defined. App currently uses AppTheme.lightTheme (set in main.dart).

### 6.4 Routing � router.dart

| Shell | Routes inside |
|---|---|
| SuperAdminShell | /super-admin, /super-admin/schools, /super-admin/schools/create |
| SchoolAdminShell | /school-admin + all Phase 2-7 sub-routes |
| TeacherShell | /teacher, /teacher/operations |
| ParentShell | /parent, /parent/fees |
| StudentShell | /student, /student/ai-tutor |

Auth routes (no shell): /login, /profile-picker

### 6.5 Riverpod Providers � providers.dart

| Provider | Purpose |
|---|---|
| supabaseClientProvider | Supabase singleton |
| sharedPreferencesProvider | Overridden at boot |
| authStateProvider | Auth state stream |
| currentUserProvider | Current auth user |
| activeSessionProvider | Active school/role session |
| authServiceProvider | Auth operations |
| profileServiceProvider | Profile CRUD |
| schoolServiceProvider | School/tenant CRUD |
| academicServiceProvider | Academic structure CRUD |
| attendanceServiceProvider | Attendance records |
| gradeServiceProvider | Gradebook operations |
| financeServiceProvider | Fees, invoices, payments |
| lmsServiceProvider | LMS courses/lessons/assignments |
| aiTutorServiceProvider | OpenRouter AI chat |
| busServiceProvider | Bus telemetry + routes |
| marketplaceServiceProvider | Marketplace items/orders |

### 6.6 Grading Engine � grading_engine.dart

ZIMSEC Engine:
- A (75-100%), B (65-74%), C (50-64%), D (40-49%), E (30-39%), U (<30%)
- Points scale: 1 (A) through 9 (U)
- Aggregate: sum of best subject points

Cambridge International Engine:
- A* (90-100%), A (80-89%), B (70-79%), C (60-69%), D (50-59%), E (40-49%), F (30-39%), G (20-29%), U (<20%)
- Score: percentage average across all components

---

## 7. Module Status and Completion

| Module | Status | Key Files |
|---|---|---|
| Multi-Tenant Auth and RLS | COMPLETE | login_screen.dart, profile_picker_screen.dart, set-user-claims |
| Super Admin Portal | COMPLETE | super_admin_shell.dart |
| School Admin Portal | COMPLETE | school_admin_shell.dart + 8 sub-screens |
| Academic Years and Terms | COMPLETE | academic_years_screen.dart |
| Classes and Sections | COMPLETE | classes_sections_screen.dart |
| Subjects | COMPLETE | subjects_screen.dart |
| Teacher Assignments | COMPLETE | teacher_assignment_screen.dart |
| Student Enrollment | COMPLETE | student_enrollment_screen.dart |
| Parent-Student Mapping | COMPLETE | parent_student_mapping_screen.dart |
| Dual-Curriculum Gradebook | COMPLETE | gradebook_setup_screen.dart, teacher_gradebook_screen.dart |
| Report Cards | COMPLETE | report_cards_screen.dart |
| LMS (Courses/Lessons) | COMPLETE | course_builder_screen.dart, student_lms_screen.dart |
| Teacher Attendance Roll-call | COMPLETE | teacher_operations_screen.dart |
| Student Attendance Calendar | COMPLETE | student_attendance_screen.dart |
| Staff Clock-in/Out and Leave | COMPLETE | teacher_operations_screen.dart |
| School Finance (Admin) | COMPLETE | school_finance_screen.dart |
| Parent Fee Portal | COMPLETE | parent_fees_screen.dart |
| Bus Tracking | COMPLETE | bus_tracking_screen.dart |
| Marketplace | COMPLETE | marketplace_screen.dart |
| AI Study Tutor | COMPLETE | ai_tutor_screen.dart |
| Announcements Board | COMPLETE | teacher_operations_screen.dart + admin shell |
| Student Dashboard | COMPLETE + POLISHED | student_shell.dart (60KB, responsive mobile/tablet/desktop) |
| Offline Sync Engine | DESIGNED � needs wiring | sync_engine.dart + sync_diagnostics_screen.dart |
| Direct Messaging (Chat) | SCAFFOLDED � no UI | DB schema + RLS ready |
| Push Notifications | SCAFFOLDED � no UI | push_tokens table ready; no FCM integration |
| Admissions Pipeline | SCAFFOLDED � no UI | DB schema ready |
| Library Management | SCAFFOLDED � no UI | DB schema ready |
| Behavior and Incidents | SCAFFOLDED � no UI | DB schema ready |

---

## 8. Multi-Tenancy Mental Model

```
auth.users (1 auth user can have many profiles)
    |
profiles (N) � each scoped to a school_id
    |
ActiveSession � Flutter picks ONE profile as the active context
    |
Every Supabase query: .eq('school_id', session.schoolId)
    |
RLS double-checks: school_id = get_active_school_id() from JWT
```

Profile Switcher flow (users with multiple school memberships):
1. User logs in ? set-user-claims injects first profile into JWT
2. ProfilePickerScreen fetches ALL profiles for auth.uid()
3. User selects a profile ? ActiveSessionNotifier.setActiveSession() persists it
4. All subsequent queries use session.schoolId from SharedPreferences

---

## 9. Known Constraints and Technical Debt

| Issue | Impact | Recommended Fix |
|---|---|---|
| OPENROUTER_API_KEY hardcoded in constants.dart | Key exposed in APK/IPA binary | Create Supabase Edge Function ai-chat-proxy to call OpenRouter server-side |
| SUPABASE_ANON_KEY hardcoded in constants.dart | Intentional � anon key is public; RLS protects data | Acceptable pattern |
| Offline sync engine designed but not wired | Offline writes do not sync back | Complete sync_engine.dart wiring (Phase A) |
| Direct messaging UI not built | Feature incomplete | Build real-time chat UI using Supabase Realtime |
| No push notification integration | No mobile alerts | Wire Firebase Cloud Messaging to push_tokens table |
| No automated tests | Regression risk | Add unit tests for grading engine; integration tests for auth |
| No CI/CD pipeline | Manual deployments | GitHub Actions ? supabase db push + Flutter build |
| Local Docker Supabase not working | Dev machine TLS issue | Use Supabase Cloud for dev/staging/prod (already doing this) |

---

## 10. Seeded Data in Live Database

| Record | Details |
|---|---|
| School (Platform) | ZivoConnect Platform Management � platform tenant |
| School (Demo) | Greenwood High School � demo/test tenant |
| Super Admin | admin@zivoconnect.com � role: super_admin |

To reset the Super Admin password: Supabase Dashboard ? Authentication ? Users ? Find user ? Send password reset email.

---

## 11. Deploying Edge Functions (on a new machine)

```bash
npm install -g supabase
supabase login
supabase link --project-ref drxnnhjxjpyadwccaxnk
supabase functions deploy set-user-claims
supabase functions deploy invite-user
```

Alternatively: paste the TypeScript source into Supabase Dashboard ? Edge Functions ? New Function.

After deployment, configure the Auth Hook:
Dashboard ? Authentication ? Hooks ? Add "Custom Access Token" ? Select set-user-claims

---

## 12. Running and Building the Flutter App

```bash
cd "c:\Users\lawto\OneDrive\Desktop\Antigravity\School System\my_flutter_app"

# Restore dependencies
flutter pub get

# Run (connects to live Supabase project)
flutter run

# Run on Chrome
flutter run -d chrome

# Build Android APK
flutter build apk --release

# Build iOS
flutter build ios --release
```

Requirements: Flutter SDK 3.x (Dart 3.x), JDK 17+ for Android builds.

---

## 13. Key Flutter Dependencies

| Package | Purpose |
|---|---|
| supabase_flutter | Supabase client + auth |
| flutter_riverpod | State management |
| go_router | Declarative routing |
| drift | SQLite ORM for offline storage |
| shared_preferences | Session persistence |
| google_fonts | Inter typography |
| http | HTTP client for OpenRouter AI calls |

---

## 14. Remaining Roadmap

See also: roadmap.md for full phase detail.

### Phase A � Offline Sync Wiring (HIGH PRIORITY)
- Wire sync_engine.dart to each service method � attach Drift local DB writes on every mutation
- Implement outbox queue processing on connectivity restore
- Test delta sync: server timestamps vs. local updated_at
- Validate tombstone processing (soft-delete records syncing deleted_at)

### Phase B � Real-Time Direct Messaging
- Build chat thread UI in parent_shell.dart and teacher_operations_screen.dart
- Use Supabase Realtime: supabaseClient.channel('messages').on(...) subscriptions
- Read/unread state management

### Phase C � Push Notifications (Firebase + APNs)
- Integrate firebase_messaging Flutter package
- Register device tokens to push_tokens table on login
- Create Supabase Edge Function send-push to dispatch FCM messages
- Triggers: new announcement, new message, invoice due, report card published

### Phase D � Admissions Pipeline UI
- Application submission form (student/parent self-service)
- Admin review queue (accept/waitlist/reject with notes)
- Auto-enrollment on acceptance

### Phase E � Library Management UI
- Book catalog CRUD (admin)
- Issue/return flow with due date tracking
- Overdue fine calculation and payment integration

### Phase F � Behavior and Incident Tracking UI
- Incident log form (teacher reports student behavior events)
- Merit/demerit point system per student
- Admin behavior summary dashboard

### Phase G � Production Hardening
- Move OPENROUTER_API_KEY to a Supabase Edge Function proxy (ai-chat-proxy)
- Set up GitHub Actions CI/CD: supabase db push on migration changes; Flutter build on release tags
- Unit tests for grading_engine.dart
- Integration tests for auth flow and profile picking
- Full multi-tenant RLS audit with test scripts

### Phase H � App Store Launch
- Configure Android signing keystore in android/app/build.gradle
- Configure iOS provisioning profiles in ios/Runner.xcodeproj
- Submit to Google Play (closed testing track first)
- Submit to Apple App Store (TestFlight first)
- Set up separate production Supabase project with environment-specific keys

---

## 15. Architecture Decisions Log

| Decision | Rationale |
|---|---|
| Supabase Cloud (not local Docker) | Dev machine TLS cert expired; cloud is simpler for team collaboration |
| Client-generated UUIDs | Enables offline-first writes before server sync |
| school_id in every table | Simplest, most performant multi-tenancy pattern for PostgreSQL RLS |
| Soft deletes (deleted_at) | Required for delta-sync tombstone processing |
| Riverpod 2.x (not Provider or Bloc) | Best pattern for reactive Supabase streams and async state |
| Shell Routes in go_router | Persistent navigation shells per role without rebuilding nav bars |
| OpenRouter (not direct OpenAI) | Allows model switching (DeepSeek, GPT-4, Claude) without client changes |
| Single services.dart file | Intentional monolith for prototype speed; split into feature services in Phase G |
| Single models.dart file | Same rationale as services � simplifies code generation |

---

## 16. Handover Notes

- **Owner:** lawto
- **Project Folder:** c:\Users\lawto\OneDrive\Desktop\Antigravity\School System\
- **Live Supabase Project:** drxnnhjxjpyadwccaxnk (ZivoConnect EMS)
- **All secrets:** Consolidated in .env at the project root
- **Design spec for AI agents:** See ZIVOCONNECT_SYSTEM_CONTEXT.md Section 7 for code-generation guidelines
- **Naming convention:** snake_case for DB tables/columns, camelCase for Dart variables, PascalCase for Dart classes
- **Code style:** Follow existing patterns in services.dart and providers.dart exactly � no custom lint rules configured yet

---

## 17. Seeded Login Accounts

All accounts below exist in the **live Supabase project** (`drxnnhjxjpyadwccaxnk`).
Passwords are intentionally not committed; reset them in Supabase Auth or load them from the local `.env` when needed.

> Account records are from `scratch/seed_full_flow.js` and `scratch/seed_super_admin.sql`.

---

### Platform / Super Admin Accounts

| Name | Email | Role | Tenant |
|---|---|---|---|
| Platform SuperAdmin | `superadmin@zivoconnect.com` | super_admin | ZivoConnect Platform Management |
| Lawton Admin | `school@lawton.co.za` | super_admin | ZivoConnect Platform Management |

> `school@lawton.co.za` was created separately via `seed_super_admin.sql`; reset its password through Supabase Auth if needed.
> `admin@zivoconnect.com` was the original placeholder from early seeding � use the accounts above to log in.

---

### Greenwood High School � School Admin

| Name | Email | Role | Tenant |
|---|---|---|---|
| Grace Okonkwo | `admin@greenwood.edu` | school_admin | Greenwood High School |

---

### Greenwood High School � Teachers

| Name | Email | Role | Subjects / Notes |
|---|---|---|---|
| James Smith | `teacher.smith@greenwood.edu` | teacher | Primary teacher � linked to class sections |
| Sarah Jones | `teacher.jones@greenwood.edu` | teacher | Secondary teacher � linked to class sections |

---

### Greenwood High School � Parents

| Name | Email | Role | Linked Students |
|---|---|---|---|
| Robert Johnson | `parent.johnson@gmail.com` | parent | Alice Johnson |
| Linda Williams | `parent.williams@gmail.com` | parent | Bob Williams |

---

### Greenwood High School � Students

| Name | Email | Role | Parent |
|---|---|---|---|
| Alice Johnson | `student.alice@greenwood.edu` | student | Robert Johnson |
| Bob Williams | `student.bob@greenwood.edu` | student | Linda Williams |
| Carol Mensah | `student.carol@greenwood.edu` | student | (no parent linked) |

---

### School / Tenant UUIDs (Live Database)

| School | UUID |
|---|---|
| ZivoConnect Platform Management | `06e3b4d4-7813-46a4-a27f-1b8a552ac24e` |
| Greenwood High School | See Supabase Dashboard ? Table Editor ? schools ? row `subdomain = greenwood` |

---

### Notes on Credentials

- All accounts were created with `email_confirm: true` � no email verification required to log in.
- The app's Profile Picker will show all profiles linked to the authenticated `auth.user`.
- If a login fails, check Supabase Dashboard ? Authentication ? Users to confirm the account exists and is not banned.
- To re-seed from scratch, run: `node scratch/seed_full_flow.js`

---

*Document generated: 2026-09-21 | ZivoConnect EMS v1.0.0*
