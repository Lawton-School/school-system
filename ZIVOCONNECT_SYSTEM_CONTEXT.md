# ZivoConnect EMS — System Architecture & Context Guide

> **Purpose of this Document**: Provide an AI assistant (such as ChatGPT, Claude, etc.) with a complete, precise context of the ZivoConnect Education Management System (EMS) SaaS platform to assist in planning, architectural discussions, sprint tasks, and feature design.

---

## 1. Executive Summary & Vision

**ZivoConnect** is an enterprise-grade, multi-tenant Educational Management System (EMS) SaaS built for primary, secondary, and tertiary educational institutions. It delivers offline-first synchronization, role-tailored user experiences (Super Admin, School Admin, Teacher, Student, Parent, Finance, Registrar), automated academic gradebooks (ZIMSEC, Cambridge, etc.), learning management (LMS), real-time attendance, fee collection, AI-powered tutoring, campus marketplace, and fleet/bus tracking.

---

## 2. Core Technology Stack

| Layer | Technologies Used |
|---|---|
| **Frontend Mobile & Web** | **Flutter 3.x** (Dart) with responsive layouts (Mobile, Tablet, Desktop) |
| **State Management** | **Flutter Riverpod** (`StateNotifierProvider`, `FutureProvider.family`, `StreamProvider`) |
| **Typography & Theme** | Modern light theme default (`#F6F7FB` background, `#6557F5` primary indigo, Inter font) |
| **Routing** | `go_router` + Flutter Navigator |
| **Backend as a Service** | **Supabase** (Managed PostgreSQL 15+, Supabase Auth, Storage, Edge Functions) |
| **Database & Security** | PostgreSQL with strict **Row Level Security (RLS)** multi-tenancy (`school_id` isolation) |
| **Offline-First & Local DB** | **Drift** (SQLite ORM) with a custom bi-directional Sync Engine (`sync_engine.dart`) |
| **Auth & Claims** | Supabase Auth + JWT custom claims (`set-user-claims` Edge Function) + `ProfilePicker` |

---

## 3. Multi-Tenancy & User Roles Architecture

### A. Multi-Tenancy Model
Every record in tenant-specific tables is scoped with `school_id UUID NOT NULL REFERENCES schools(id)`. PostgreSQL Row Level Security (RLS) ensures:
- Users cannot query or mutate data belonging to other schools.
- Super Admins can access and monitor across schools.
- A single Supabase Auth user (`auth.users`) can hold multiple profiles (e.g., Parent at School A and Teacher at School B) managed via `ProfilePickerScreen` and `activeSessionProvider`.

### B. User Roles
1. **Super Admin**: System owner across all school tenants, licenses, subscriptions, and platform diagnostics.
2. **School Admin (Principal/Director)**: Full operational control of their specific school: terms, teachers, class sections, subjects, timetables, and admissions.
3. **Teacher**: Gradebook entry, attendance tracking, lesson creation, assignment grading, and student report cards.
4. **Student**: Course progress, assignment submissions, daily schedule, report card viewing, attendance, AI Tutor.
5. **Parent**: Multi-student monitoring, tuition invoices & fee settlements, children's attendance, and report cards.
6. **Finance Manager**: Fee structures, invoice generation, multi-gateway payments (EcoCash, Stripe, Bank, Cash Voucher), and ledger reconciliations.

---

## 4. Frontend Application Structure

The Flutter application is structured in clean modular layers:

```
my_flutter_app/
├── lib/
│   ├── core/
│   │   ├── constants.dart        # Preferences keys, routes, role strings
│   │   ├── theme.dart            # Brand colors, typography, Light & Dark themes
│   │   ├── grading_engine.dart   # Calculation logic for ZIMSEC / Cambridge GPA
│   │   └── sync_engine.dart      # Local Drift SQLite delta sync engine
│   ├── models/
│   │   └── models.dart           # Complete Dart model definitions & fromMap/toMap
│   ├── services/
│   │   └── services.dart         # Direct Supabase database service methods
│   ├── providers/
│   │   └── providers.dart        # Riverpod providers for auth, session, and modules
│   ├── router/
│   │   └── router.dart           # Route definitions and redirect guards
│   ├── screens/
│   │   ├── auth/                 # Login, Forgot Password, Profile Picker
│   │   ├── super_admin/          # School tenants management, SaaS metrics
│   │   ├── school_admin/         # Academic years, terms, classes, staff, gradebooks
│   │   ├── teacher/              # Teacher shell, attendance marker, gradebook
│   │   ├── student/              # Student dashboard, LMS, attendance, AI tutor
│   │   ├── parent/               # Children overview, multi-student switches
│   │   ├── finance/              # School finance, student fee billing & payment sheets
│   │   └── operations/           # Bus tracking, marketplace/store, diagnostics
│   └── widgets/
│       └── shared_widgets.dart   # Sync badges, metric cards, status chips
```

---

## 5. Completed Database Modules (Supabase SQL)

The backend migrations in `supabase/migrations/` contain:

1. **`20260810000000_init_enums_and_functions.sql`**:
   - Enums: `user_role`, `attendance_status`, `invoice_status`, `payment_method`, `curriculum_type`, `ticket_status`.
   - Global trigger functions: automatic `updated_at`, audit logging, and soft-delete filters.

2. **`20260810000001_core_schema.sql`**:
   - `schools`, `profiles`, `parent_student_relationships`.
   - `academic_years`, `grading_terms`, `classes`, `class_sections`, `subjects`, `subject_teachers`.
   - `student_enrollments`, `attendance_records`, `staff_attendance`, `staff_leave_requests`.

3. **`20260810000002_rls_policies.sql`**:
   - Strict tenant isolation policies utilizing `current_setting('app.current_school_id')` and JWT metadata.

4. **`20260810000003_modules_schema.sql`**:
   - **Academic Gradebook**: `assessment_categories`, `assessments`, `grade_records`, `report_cards`.
   - **LMS (Learning Management)**: `courses`, `lessons`, `assignments`, `submissions`.
   - **Finance & Fees**: `fee_structures`, `fee_categories`, `invoices`, `invoice_items`, `payments`.
   - **Operations & AI**: `school_announcements`, `buses`, `bus_routes`, `ai_conversations`, `marketplace_items`, `orders`.

5. **`20260810000004_indexes_and_optimizations.sql`**:
   - B-tree and composite indices for high-frequency queries and offline sync delta timestamps.

---

## 6. Current Implementation Status

| Feature Area | Current Status | Notes |
|---|---|---|
| **Multi-Tenant Auth & RLS** | ✅ Complete | Profile switching, claims handling, role routing working |
| **School Admin Portal** | ✅ Complete | Terms, classes, sections, teacher assignments implemented |
| **Academic Gradebook** | ✅ Complete | Weighting formulas, term records, report cards ready |
| **Finance & Billing** | ✅ Complete | Multi-currency invoice generation, payment modal implemented |
| **Student Dashboard** | ✅ Complete & Polished | High-fidelity responsive UI (mobile, tablet, desktop) matching exact Figma/custom spec |
| **Student LMS & Homework** | ✅ Implemented | Course listings, document/URL submission dialogs active |
| **Student Attendance Calendar** | ✅ Implemented | Color-coded status calendar per student |
| **AI Study Tutor** | ✅ Implemented | Chat interface with personalized study prompts |
| **Local Offline Sync Engine** | ⚙️ In Progress | Drift database models & delta-sync engine designed |

---

## 7. Guidelines for AI Planning & Code Generation

When discussing or generating code for ZivoConnect:
1. **Design Aesthetic**: Use a clean, modern **light theme** (`#F6F7FB` background, pure white cards `#FFFFFF`, `#6557F5` primary indigo, dark slate `#172033` headings, and muted slate `#74809A` captions).
2. **State Management**: Always use **Riverpod 2.x**. Prefer `ref.watch()` in build methods and `ref.read()` inside callbacks.
3. **Multi-Tenancy Guard**: Every Supabase query must include or verify `school_id` from `session.schoolId`.
4. **Responsiveness**: Always consider **Mobile (`<640px`)**, **Tablet (`640-1023px`)**, and **Desktop (`≥1024px`)** viewports.
5. **No Placeholders**: Write robust error handling, loading states, and production-ready components.
