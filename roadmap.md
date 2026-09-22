# EMS SaaS Platform Development Roadmap & Build Direction

This roadmap provides a phased, module-by-module implementation plan to build, test, and deploy the Education Management System (EMS) SaaS platform. It is designed to guide engineering teams and autonomous agents through a logical build order, ensuring dependencies are resolved before subsequent modules are built.

---

## ✅ Phase 1: Foundations & Multi-Tenant Core (Milestone 1) — COMPLETE

### 1.1 Local Environment & Infrastructure
- [x] Spin up Supabase project — **using Supabase Cloud** (local Docker TLS cert expired on dev machine — see [SETUP_GUIDE.md](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/SETUP_GUIDE.md)).
- [x] Generate all database migrations sequentially and draft [verify_schema.sql](file:///c:/Users/lawto/OneDrive/Desktop/Antigravity/School%20System/scratch/verify_schema.sql) to validate constraints, enums, triggers, and indices.
- [x] Deploy migrations to Supabase Cloud via SQL Editor (see SETUP_GUIDE.md Step 3).
- [x] Initialize the Flutter app (`my_flutter_app`), configure `supabase_flutter`, `flutter_riverpod`, `go_router`, `drift`, `shared_preferences`, `google_fonts`.
- [x] Established offline storage library (`drift`) in pubspec.yaml; local DB schema to be added in Phase 7.

### 1.2 Multi-Tenant Authentication & Session Engine
- [x] Implement **Profile Switcher** (ProfilePickerScreen) — multi-school session selection persisted in SharedPreferences.
- [x] Build login UI with Supabase authentication, animated entrance, form validation, forgot-password sheet.
- [x] Create Supabase Edge Functions for JWT custom claims (`set-user-claims`) and admin invite (`invite-user`).
- [x] Session context (`school_id`, `role`, `profile_id`) stored in `ActiveSessionNotifier` via Riverpod `StateNotifierProvider`.

### 1.3 Core Administration Views
- [x] **Super Admin Dashboard:** Create/view schools (tenants), invite school admins, stats cards, recent schools list.
- [x] **School Admin Dashboard:** Welcome banner, quick actions grid, recent users, role-filtered user list.
- [x] **Create User Flow:** Role picker (Teacher/Student/Parent), name/email/phone form, writes to Supabase `profiles` table.
- [x] **Academic Structure Menu:** Placeholder categories for Years, Classes, Subjects, Assignments, Enrollments (Phase 2 expansion).
- [x] **Teacher / Parent / Student Dashboards:** Role banners and module grids scaffolded for Phase 2+ expansion.

---

## ✅ Phase 2: Class Management & Enrollments (Milestone 2) — COMPLETE

### 2.1 Academic Structure Builder
- [x] **School Admin Views:**
  - UI to add/edit Classes, Sections, and Subjects (live Supabase reads/writes).
  - Form to link **Teachers** to Sections and Subjects (assigning Subject Teachers and Homeroom Teachers).
- [x] **Student enrollment:**
  - Enroll students to specific sections for the current academic year, assigning roll numbers and generating their status.

### 2.2 Global Relationships Mapping
- [x] **Student-Parent mapping:**
  - School Admin UI to link student profiles to parent profiles.
  - Validate that relationships map cleanly across schools using the unified `auth.uid()`.

---

## ✅ Phase 3: Core School Operations & Leave (Milestone 3) — COMPLETE

### 3.1 Attendance Management
- [x] **Teacher Interface:**
  - Daily roll-call screen with date picker and section picker (filtered to teacher's assigned sections).
  - Mark Attendance FAB opens per-student present/absent/late/excused sheet; upserts to `daily_attendance`.
  - Live list of attendance records with color-coded status chips.
- [x] **Student View:**
  - `StudentAttendanceScreen` — own attendance history with present/absent/late/excused stat cards and color-coded timeline, backed by real `daily_attendance` data.
- [x] **Parent View:**
  - `ParentAttendanceScreen` — tabbed view per child (via `user_relationships`), same stat-card calendar view for each linked student.
- [x] **Staff Attendance & Leaves:**
  - Clock In / Clock Out tab for teachers — upserts to `staff_attendance` with timestamps.
  - Teacher Leave tab shows own requests (filtered by `staff_profile_id`), with a Request Leave FAB (type, dates, reason) writing to `staff_leaves`.
  - School Admin Leave Review tab — lists all pending requests with Approve/Reject buttons wired to `updateLeaveStatus()`.

### 3.2 Digital Bulletin & Messaging
- [x] **Announcements Board:**
  - Live board reading from `announcements` table; RLS enforces `target_role` visibility per session role.
  - Post Announcement FAB (admin and teacher) — title, content, audience selector (all/teachers/parents/students) writes to `announcements`.
- [x] **Direct messaging:**
  - `direct_messages` table and RLS policies in place. Push token registration schema ready (`push_tokens`).
  - UI entry point scaffolded; full real-time chat thread is a Phase 4/5 enhancement.

---

## ✅ Phase 4: Academics, Dual-Curriculum Gradebook & LMS (Milestone 4) — COMPLETE

### 4.1 Dual-Curriculum Digital Gradebook (ZIMSEC & Cambridge International)
- [x] **Curriculum & Grading Setup (Admin/Teacher):**
  - Configure Exam Board / Curriculum per Class/Subject: **ZIMSEC** vs **Cambridge International (IGCSE / A-Level)**.
  - Define Grading Terms (Term 1, Term 2, Term 3) and Weights.
  - Configure Assessment Categories (e.g., ZIMSEC CALA + Exams vs Cambridge Coursework + Mocks).
- [x] **Curriculum Grading Engine:**
  - **ZIMSEC Engine:** Automatic conversion of raw marks to grades (`A` [75-100%], `B` [65-74%], `C` [50-64%], `D`, `E`, `U`) and points aggregate calculation (1-9 points scale).
  - **Cambridge Engine:** Automatic conversion to letter symbols (`A*` [90-100%], `A` [80-89%], `B`, `C`, `D`, `E`, `F`, `G`, `U`) and percentage mark averages.
- [x] **Grade Entry (Teacher):**
  - Spreadsheet-style grade entry matrix by Class Section, Subject, and Assessment with batch save.
  - Live preview of calculated grade symbol & points per student.
- [x] **Report Cards:**
  - Comprehensive termly report card generator aggregating coursework + exam marks per curriculum standard.
  - Principal review & approval workflow.
  - Parent/Student report card portal with downloadable/printable formatted cards.

### 4.2 Learning Management System (LMS)
- [x] **Course & Lesson Builder:** Course creation, lesson attachments (PDFs, videos, links), and assignment timelines.
- [x] **Student Submissions:** Homework portal supporting text submissions, URL inputs, and cloud document attachments.
- [x] **Grading Panel:** Teacher interface to review submissions, assign grade percentages, and input contextual feedback.

---

## ✅ Phase 5: Operations & Auxiliary Modules (Milestone 5) — COMPLETE

### 5.1 Bus Tracking & Fleet Telemetry
- [x] **Driver & Telemetry Service:**
  - Real-time GPS telemetry ping recording `(latitude, longitude, speed)` into `bus_telemetry`.
  - Driver telemetry simulation trigger for live demonstrative updates.
- [x] **Parent & Admin View:**
  - Live Radar Stats (Speed, GPS coordinates, Last Ping timestamp), Driver detail banner, and sequential Bus Stops schedule with progress indicator.

### 5.2 Isolated School Marketplace
- [x] **Item Listings (Sellers - Parents/Admins):**
  - Uniforms, textbooks, and event tickets marketplace. Form to list item with price, stock, condition, and description.
- [x] **Purchase Flow (Buyers):**
  - School-scoped item catalog grid, Cart management modal with quantity counters, and instant order checkout.
- [x] **Order Management:**
  - Real-time order tracking tab for buyers and sellers with status indicators (`pending`, `completed`, `cancelled`).

### 5.3 AI Tutor Integration & Learning Profiles
- [x] **AI Assistant:**
  - Interactive student-to-AI private tutoring chat with subject-specific context dropdowns and quick-prompt chips (e.g., Pythagorean Theorem, PEEL essay structure, Photosynthesis).
- [x] **Diagnostic Learning Profiles:**
  - Automated diagnostic profile summarising demonstrated strengths and priority focus areas for the student.

---

## ✅ Phase 6: Bursary, Payments & School Finance (Milestone 6) — COMPLETE

### 6.1 Billing & Invoicing
- [x] **Fee setup:** Admins define fee structures (e.g. Tuition, Bus Fee, Lab Fee).
- [x] **Bursary allocation:** Link scholarships/bursary schemes to student profiles to deduct fixed values or percentages.
- [x] **Invoice Engine:** Batch-generation of invoices for all students in a class section at the start of a term.

### 6.2 Payment Processing
- [x] **Parent Portal:** Multi-method settlement simulator (EcoCash, Visa/Mastercard, Bank Transfer, Stripe) to settle student invoices.
- [x] **Receipting:** Generate automated transaction ledgers and digital payment receipts with transaction references.

### 6.3 School Ledgers & Payroll
- [x] **Expenses:** Administrative expenditure logger and summary cards with category breakdown.
- [x] **Budgets:** Set department caps and compute real-time variance and utilization calculations.
- [x] **Staff Payroll:** Monthly salary voucher generator calculating base pay, allowances, deductions, and processed run status toggles.

---

## ✅ Phase 7: Offline-First Sync Engine & Launch (Milestone 7) — COMPLETE

### 7.1 Sync Engine Implementation
- [x] **Local Store & Outbox Queue:** Cache tenant tables with local outbox queue for offline querying and optimistic writes.
- [x] **Conflict Resolution & Queuing:** Timestamp-based conflict resolution (Server-Wins for Finance & Approvals, Last-Write-Wins for Attendance & Grading).
- [x] **Connectivity Interceptors:** Real-time sync status badges (`Online`, `Offline`, `Syncing`, `Error`) across all role shells and manual sync triggers.
- [x] **Delta Sync Syncing:** Client query architecture requesting database records updated after the last local sync timestamp (`updated_at > last_sync_time`).
- [x] **Tombstone Processing:** Delete local records matching rows returned with a non-null `deleted_at` field.

### 7.2 Release Preparation
- [x] Full multi-tenant isolation audit across Super Admin, School Admin, Teacher, Parent, and Student roles.
- [x] Complete end-to-end static analysis validation with zero lint errors.

- [ ] Setup production Supabase database instance and execute CI/CD migration deployments via GitHub actions.
- [ ] Launch staging Flutter apps to App Store & Google Play closed testing tracks.
