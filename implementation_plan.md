# Implementation Plan - Education Management System (EMS) SaaS platform

This document details the database architecture, security model, permissions model, and Supabase implementation plan for the multi-tenant Education Management System (EMS) SaaS platform.

## User Review Required

> [!IMPORTANT]
> **Key Architectural Decisions & RLS Strategy:**
> 1. **Tenant Isolation (`school_id`):** Every tenant table includes a `school_id` column. Row Level Security (RLS) policies enforce that users can only query/mutate records belonging to their active school.
> 2. **Session / Multi-Profile Support:** A user (auth credentials in `auth.users`) can have multiple profiles (e.g., a teacher in one school, a parent in another, or holding multiple roles). The active tenant (`school_id`) and `role` are read from the session's JWT `app_metadata` (populated via custom claims) or fall back to database queries.
> 3. **Offline-First Synchronization:** All tables use client-generated `UUID` primary keys, include `created_at`, `updated_at`, and a nullable `deleted_at` field (soft deletes) to allow simple timestamp-based delta syncs. Triggers automate the `updated_at` timestamps.

Please review the proposed schema, role permissions matrix, and verification plan.

## Design Confirmations (Based on User Feedback)

> [!NOTE]
> 1. **User Management Flow:**
>    - Super Admin is responsible for creating/provisioning **School Admins**.
>    - School Admins are responsible for manually creating/inviting **Teachers**, **Students**, and **Parents** within their respective schools.
> 2. **Multi-School Parent Dashboard:**
>    - Parents can have profiles across multiple schools linked to the same `auth.user`.
>    - The system supports a unified parent dashboard. The RLS policies for student-related data (grades, schedules, attendance) will allow read access to parents whose `auth.uid()` is linked to a profile that has a registered relationship with the student, regardless of the active session's `school_id`.
> 3. **Marketplace Isolation:**
>    - The School Marketplace is fully isolated per school. The `school_id` tenant boundary is strictly enforced for all marketplace items, orders, and transactions.

## Open Questions

All initial open questions have been resolved and incorporated into the design confirmations above.

## Proposed Changes

We will create a full Supabase environment inside the `supabase/` directory in the workspace. This includes migrations to configure enums, helper functions, core schemas, RLS policies, index optimizations, and module schemas.

---

### Database Schema Design

#### 1. Core Schema (`supabase/migrations/20260810000001_core_schema.sql`)
- **`schools`**: Tenant information, settings, status.
- **`profiles`**: User profiles containing name, contact info, and role mapping to `auth.users`.
- **`user_relationships`**: Maps parent profiles to student profiles.
- **`academic_years`**: Defines scholastic years (e.g., "2026-2027").
- **`classes`**: Grade levels or year levels.
- **`class_sections`**: Classroom groups (e.g., "Grade 10 - Section A").
- **`subjects`**: Subjects taught (e.g., "Mathematics", "Science").
- **`class_teachers`**: Maps teachers to class sections they manage.
- **`student_enrollments`**: Maps students to specific class sections for an academic year.

#### 2. Module Schema (`supabase/migrations/20260810000003_modules_schema.sql`)
- **LMS Module**: Courses, lessons, assignments, student submissions.
- **Live Classes**: Virtual meeting details and student attendance logging.
- **School Fees & Finance (Expanded)**:
  - Core Fees: Fee definitions, student invoices, invoice items, and payment transactions.
  - Bursaries & Scholarships: Bursary schemes and student bursary allocations.
  - Staff Payroll: Salaries, allowances, tax deductions, and payment runs.
  - Expenses & Budgets: Budget caps per department and general school expense logs.
- **Bus Tracking**: Routes, stops, student ridership mapping, and high-frequency telemetry logging.
- **AI Tutor**: Private student sessions, message logs, and learning profiles.
- **Marketplace**: Items for sale, orders, and individual order items.
- **Admissions Pipeline**: Applications, admission documents, and review statuses.
- **Gradebook & Reports**: Terms, assessment categories, assessments, grade records, and report cards.
- **Leave & Attendance**: Daily student attendance logs, staff clock-in/out logs, and staff leave requests.
- **Library Management**: Books catalog, borrow/return issues, and overdue book fines.
- **Behavioral & Incident Tracking**: Discipline incident logs, merits, and demerits.
- **Communication & Notifications**: Announcements, direct teacher-parent messaging, and push notification tokens.

---

### Security & Permissions Model

We define a database ENUM `app_role` representing:
- `super_admin`: Platform owner, full access to all schools and records.
- `school_admin`: Full access to their assigned school.
- `teacher`: Read/write access to classes, assignments, grades, and attendance they manage.
- `parent`: Read-only access to their children's profiles, attendance, grades, fees, and tracking.
- `student`: Read-only access to classes, assignments, fees, routes; write access to own submissions.

#### RLS Engine Helper Functions
We will create helper functions to optimize RLS queries:
- `public.get_active_school_id()`: Retrieves `school_id` from JWT `app_metadata` or queries `profiles`.
- `public.get_active_role()`: Retrieves `app_role` from JWT `app_metadata` or queries `profiles`.

#### Core Permissions Matrix
Each table has RLS enabled with policies matching the matrix below:

| Table | Super Admin | School Admin | Teacher | Parent | Student |
| :--- | :--- | :--- | :--- | :--- | :--- |
| **schools** | ALL | READ / UPDATE (own) | READ | READ | READ |
| **profiles** | ALL | ALL (own school) | READ (all), UPDATE (own) | READ (children + self) | READ (teachers + self) |
| **student_enrollments**| ALL | ALL | READ / WRITE (own classes) | READ (children) | READ (self) |
| **assignments** | ALL | ALL | ALL (own courses) | READ (children) | READ (self) |
| **submissions** | ALL | ALL | READ / GRADE (own classes)| READ (children) | READ / WRITE (own) |
| **invoices / payments** | ALL | ALL | NONE | READ (children) | READ (self) |
| **bus_telemetry** | ALL | ALL | READ | READ (children) | READ (self) |

---

### Components & Files to Create

#### [NEW] [20260810000000_init_enums_and_functions.sql](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000000_init_enums_and_functions.sql)
Defines enums, RLS utility functions, and the automated `updated_at` trigger function.

#### [NEW] [20260810000001_core_schema.sql](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000001_core_schema.sql)
Creates core tables (`schools`, `profiles`, classes, enrollments, etc.) with default UUIDs, indexes, and soft-delete/offline fields.

#### [NEW] [20260810000002_rls_policies.sql](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000002_rls_policies.sql)
Enables RLS on core tables and implements policy checks for all roles.

#### [NEW] [20260810000003_modules_schema.sql](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000003_modules_schema.sql)
Creates tables and RLS policies for the LMS, Live Classes, Fees, Bus Tracking, AI Tutor, and Marketplace modules.

#### [NEW] [20260810000004_indexes_and_optimizations.sql](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/migrations/20260810000004_indexes_and_optimizations.sql)
Adds indexes to maximize performance for tenant-scoped reads, joins, and offline delta sync queries.

#### [NEW] [config.toml](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/supabase/config.toml)
Base config file to initialize the local Supabase container environment.

#### [NEW] [verify_schema.sql](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/scratch/verify_schema.sql)
Scratch script to validate enums, tables, columns, RLS state, and role restrictions.

#### [NEW] [roadmap.md](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/roadmap.md)
Comprehensive module-by-module platform development roadmap and build directions.

---

## Verification Plan

### Automated Tests / Verification Queries
1. **Local Migration Run**: Verify migrations apply cleanly with `supabase db reset` (or run them sequentially using a local PG database).
2. **Schema Verification Script**: Run a SQL verification script to check that all tables have `school_id`, `updated_at`, `deleted_at`, RLS enabled, and appropriate indexes.
3. **RLS Test Suite**: Create a scratch SQL script simulating logins for different roles and verifying that:
   - A `school_admin` cannot view/insert records for another school.
   - A `student` cannot modify grades or view other students' invoices.
   - A `parent` can only view their own child's records.

### Manual Verification
- We can inspect the Supabase Studio DB schema visually or write a node helper script to test the policies with client mocks.
