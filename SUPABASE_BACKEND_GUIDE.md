# ZivoConnect EMS — Supabase Backend Master Context & Copilot Guide

> **How to Use This Document with ChatGPT / Claude:**
> Copy and paste this document into a new chat with ChatGPT or Claude. Add the prompt:
> *"You are my Lead Backend Engineer for ZivoConnect EMS. Read this comprehensive Supabase specification carefully. It describes our live database schema, Row-Level Security (RLS) policies, multi-tenancy rules, Edge Functions, and offline synchronization mechanisms. Always adhere strictly to these patterns whenever writing migrations, queries, Edge Functions, or API integrations. Do not leak or assume credentials; all secrets will be handled manually."*

---

## 1. System Overview & Core Philosophy

**ZivoConnect EMS** is a multi-tenant Educational Management System (SaaS) built on top of **Supabase** (PostgreSQL 15+). It powers web and mobile client applications across 5 primary user roles:
1. `super_admin` — Platform operators overseeing all schools.
2. `school_admin` — School principals and administrative officers managing a single institution.
3. `teacher` — Educators managing classes, subjects, grades, LMS courses, and student attendance.
4. `parent` — Guardians monitoring multiple children (potentially across different schools).
5. `student` — Enrolled learners taking assignments, viewing marks, tracking buses, and utilizing AI tutoring.

### The 6 Golden Rules of the ZivoConnect Backend

1. **Strict Multi-Tenancy via `school_id`:**
   Every single table (except `schools` itself) possesses a `school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL`. All client queries and RLS policies scope data to the active institution.
2. **Offline-First Delta Sync (`updated_at` + `deleted_at`):**
   No hard deletes are performed in user-facing workflows. All tables have a nullable `deleted_at timestamptz`. Deletion is represented by setting `deleted_at = now()`. Every table has an automated trigger updating `updated_at = now()`. This allows mobile/desktop offline clients to synchronize deltas by querying records where `updated_at > :last_sync_timestamp`.
3. **Client-Generated UUID Primary Keys:**
   All tables use `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`. Clients (Flutter/Dart) generate UUID v4 values locally while offline and push them directly to Supabase during sync without collision risk.
4. **JWT-Driven Security via Custom Claims:**
   Authorization is handled by evaluating PostgreSQL Row Level Security (RLS) using session claims injected into `auth.jwt() -> 'app_metadata'`. The active tenant (`school_id`), role (`role`), and profile (`profile_id`) are attached to the access token upon login via an Auth Hook Edge Function (`set-user-claims`).
5. **No Direct `auth.users` References in Business Tables:**
   Business tables link to `public.profiles(id)` (`profile_id`), **NOT** directly to `auth.users(id)`. The table `public.profiles` maps `auth.users(id)` (`user_id`) to a specific `school_id` and `role`. A single human being (one Supabase auth account) can have distinct profiles across different schools (e.g., a teacher in School A who is also a parent in School B).
6. **Secrets Handling:**
   No production keys or passwords are stored in project prompts. Edge Functions utilize `Deno.env.get('SUPABASE_URL')` and `Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')`. Client apps use the public `anon` key only.

---

## 2. Environment Configuration (Sanitized)

When developing or extending code, reference the following environment variables:

```bash
# Supabase Project Endpoints
SUPABASE_URL="https://<YOUR_PROJECT_REF>.supabase.co"
SUPABASE_ANON_KEY="<YOUR_SUPABASE_ANON_KEY>"           # Publicly safe; RLS-enforced
SUPABASE_SERVICE_ROLE_KEY="<YOUR_SERVICE_ROLE_KEY>"   # Private; Edge Functions / Admin scripts ONLY
OPENROUTER_API_KEY="<YOUR_OPENROUTER_API_KEY>"         # Used for DeepSeek AI Tutor
```

---

## 3. Database Enums & Core Functions

### Enums

```sql
-- Role definitions across the entire platform
CREATE TYPE public.app_role AS ENUM (
    'super_admin',
    'school_admin',
    'teacher',
    'parent',
    'student'
);
```

### Automatic Timestamp Trigger Function

Every table in the database uses this trigger function to ensure `updated_at` is always accurate:

```sql
CREATE OR REPLACE FUNCTION public.update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;
```

### RLS Helper Functions (Security Definer)

These 4 PL/pgSQL functions power the Row-Level Security policies across all 51 tables:

#### 1. `public.get_active_school_id()`
Extracts `school_id` from the user's JWT `app_metadata`. If missing (e.g., during development or token refresh lag), it falls back to querying the first active profile for `auth.uid()`.
```sql
CREATE OR REPLACE FUNCTION public.get_active_school_id()
RETURNS uuid AS $$
DECLARE
    _school_id uuid;
BEGIN
    _school_id := (auth.jwt() -> 'app_metadata' ->> 'school_id')::uuid;
    
    IF _school_id IS NULL AND auth.uid() IS NOT NULL THEN
        SELECT school_id INTO _school_id
        FROM public.profiles
        WHERE user_id = auth.uid() AND deleted_at IS NULL
        LIMIT 1;
    END IF;
    
    RETURN _school_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

#### 2. `public.get_active_role()`
Extracts `role` from the JWT `app_metadata`. If missing, it falls back to querying `public.profiles` for the active school.
```sql
CREATE OR REPLACE FUNCTION public.get_active_role()
RETURNS public.app_role AS $$
DECLARE
    _role public.app_role;
    _school_id uuid;
BEGIN
    _role := (auth.jwt() -> 'app_metadata' ->> 'role')::public.app_role;
    
    IF _role IS NULL AND auth.uid() IS NOT NULL THEN
        _school_id := public.get_active_school_id();
        SELECT role INTO _role
        FROM public.profiles
        WHERE user_id = auth.uid() AND school_id = _school_id AND deleted_at IS NULL
        LIMIT 1;
    END IF;
    
    RETURN _role;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

#### 3. `public.user_has_profile_in_school(school_id uuid, user_id uuid)`
Returns `true` if the specified user has an active, non-deleted profile in the target school.
```sql
CREATE OR REPLACE FUNCTION public.user_has_profile_in_school(school_id uuid, user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.profiles 
        WHERE public.profiles.school_id = user_has_profile_in_school.school_id 
          AND public.profiles.user_id = user_has_profile_in_school.user_id
          AND public.profiles.deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

#### 4. `public.user_is_parent_of_student(student_id uuid, user_id uuid)`
Enables cross-school parent visibility. Returns `true` if the calling user (`user_id`) is linked as a parent or guardian to `student_id` in `user_relationships`.
```sql
CREATE OR REPLACE FUNCTION public.user_is_parent_of_student(student_id uuid, user_id uuid)
RETURNS boolean AS $$
BEGIN
    RETURN EXISTS (
        SELECT 1 FROM public.user_relationships r
        JOIN public.profiles p ON r.parent_id = p.id
        WHERE r.student_id = user_is_parent_of_student.student_id
          AND p.user_id = user_is_parent_of_student.user_id
          AND r.deleted_at IS NULL
          AND p.deleted_at IS NULL
    );
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;
```

---

## 4. Complete Schema & Data Dictionary (51 Tables across 14 Domains)

All tables feature:
- `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
- `created_at timestamptz NOT NULL DEFAULT now()`
- `updated_at timestamptz NOT NULL DEFAULT now()`
- `deleted_at timestamptz` (soft deletion)
- Trigger `trigger_update_<table_name>_updated_at BEFORE UPDATE` calling `public.update_updated_at_column()`

---

### Domain 1: Multi-Tenancy & Identity Core

#### 1. `schools`
Institutions / tenant accounts on ZivoConnect.
- `id`: uuid (PK)
- `name`: text NOT NULL
- `subdomain`: text UNIQUE NOT NULL (e.g., `hararehigh`, `hillside`)
- `settings`: jsonb NOT NULL DEFAULT `'{}'::jsonb` (branding, colors, logo URLs, modules enabled)
- `status`: text NOT NULL DEFAULT `'active'` CHECK (`status IN ('active', 'suspended')`)

#### 2. `profiles`
The institution-specific identity for an authenticated user.
- `id`: uuid (PK)
- `user_id`: uuid REFERENCES `auth.users(id)` ON DELETE CASCADE
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `role`: `public.app_role` NOT NULL (`super_admin`, `school_admin`, `teacher`, `parent`, `student`)
- `first_name`: text NOT NULL
- `last_name`: text NOT NULL
- `email`: text
- `phone`: text
- `avatar_url`: text
- `status`: text NOT NULL DEFAULT `'active'` CHECK (`status IN ('active', 'inactive', 'suspended')`)
- **Constraints**: `UNIQUE (user_id, school_id, role)`

#### 3. `user_relationships`
Links parents/guardians to students. Crucial for cross-school parent views.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `parent_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `student_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `relationship_type`: text NOT NULL CHECK (`relationship_type IN ('father', 'mother', 'guardian', 'other')`)
- **Constraints**: `UNIQUE (parent_id, student_id)`

---

### Domain 2: Academic Hierarchy & Enrollment

#### 4. `academic_years`
Calendar or academic cycles (e.g. "2026 Academic Year").
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL (e.g. "2026-2027")
- `start_date`: date NOT NULL
- `end_date`: date NOT NULL
- `is_current`: boolean NOT NULL DEFAULT false
- **Constraints**: `CHECK (start_date < end_date)`

#### 5. `classes`
Grade levels or year groups (e.g. "Grade 10", "Form 4").
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `academic_year_id`: uuid REFERENCES `public.academic_years(id)` ON DELETE CASCADE NOT NULL

#### 6. `class_sections`
Specific class streams/rooms (e.g. "Form 4-Alpha", "Grade 10B").
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `class_id`: uuid REFERENCES `public.classes(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `room`: text

#### 7. `subjects`
Curriculum disciplines taught within the school (e.g. "Mathematics", "Science").
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `code`: text (e.g. "MATH-101")

#### 8. `class_teachers`
Assigns teachers to specific sections and subjects.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `class_section_id`: uuid REFERENCES `public.class_sections(id)` ON DELETE CASCADE NOT NULL
- `teacher_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `subject_id`: uuid REFERENCES `public.subjects(id)` ON DELETE CASCADE (nullable if homeroom teacher)
- `is_primary_homeroom_teacher`: boolean NOT NULL DEFAULT false

#### 9. `student_enrollments`
Enrolls a student profile into a section for an academic year.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `class_section_id`: uuid REFERENCES `public.class_sections(id)` ON DELETE CASCADE NOT NULL
- `academic_year_id`: uuid REFERENCES `public.academic_years(id)` ON DELETE CASCADE NOT NULL
- `roll_number`: text
- `status`: text NOT NULL DEFAULT `'active'` CHECK (`status IN ('active', 'withdrawn', 'suspended', 'graduated')`)
- **Constraints**: `UNIQUE (student_profile_id, academic_year_id)`

---

### Domain 3: Learning Management System (LMS)

#### 10. `courses`
Digital learning spaces created by teachers.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `description`: text
- `teacher_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE SET NULL

#### 11. `lessons`
Chapters/modules within an LMS course.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `course_id`: uuid REFERENCES `public.courses(id)` ON DELETE CASCADE NOT NULL
- `title`: text NOT NULL
- `content_url`: text (Storage bucket link or rich content)
- `order_index`: integer NOT NULL DEFAULT 0

#### 12. `assignments`
Tasks/homework associated with a lesson.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `lesson_id`: uuid REFERENCES `public.lessons(id)` ON DELETE CASCADE NOT NULL
- `title`: text NOT NULL
- `description`: text
- `due_date`: timestamptz NOT NULL
- `max_points`: numeric NOT NULL CHECK (`max_points >= 0`)

#### 13. `submissions`
Student submissions for an assignment.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `assignment_id`: uuid REFERENCES `public.assignments(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `submitted_at`: timestamptz NOT NULL DEFAULT now()
- `content_url`: text NOT NULL
- `grade`: numeric CHECK (`grade >= 0`)
- `feedback`: text
- `graded_by_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE SET NULL
- **Constraints**: `UNIQUE (assignment_id, student_profile_id)`

---

### Domain 4: Live Classes & Virtual Sessions

#### 14. `live_classes`
Virtual video classrooms (Zoom, Jitsi, Google Meet).
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `class_section_id`: uuid REFERENCES `public.class_sections(id)` ON DELETE CASCADE NOT NULL
- `subject_id`: uuid REFERENCES `public.subjects(id)` ON DELETE CASCADE NOT NULL
- `teacher_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE SET NULL
- `title`: text NOT NULL
- `meeting_url`: text NOT NULL
- `scheduled_at`: timestamptz NOT NULL
- `duration_minutes`: integer NOT NULL DEFAULT 45 CHECK (`duration_minutes > 0`)
- `status`: text NOT NULL DEFAULT `'scheduled'` CHECK (`status IN ('scheduled', 'live', 'completed', 'cancelled')`)

#### 15. `live_attendance`
Tracks who joined the live broadcast.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `live_class_id`: uuid REFERENCES `public.live_classes(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `joined_at`: timestamptz
- `left_at`: timestamptz
- `status`: text NOT NULL DEFAULT `'absent'` CHECK (`status IN ('present', 'absent', 'tardy')`)
- **Constraints**: `UNIQUE (live_class_id, student_profile_id)`

---

### Domain 5: Financial Operations, Bursaries & Payroll

#### 16. `fee_types`
Fee definitions (Tuition, Boarding, Sports Levy, Uniform).
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `description`: text
- `amount`: numeric NOT NULL CHECK (`amount >= 0`)

#### 17. `invoices`
Invoices billed to students per academic year.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `academic_year_id`: uuid REFERENCES `public.academic_years(id)` ON DELETE CASCADE NOT NULL
- `total_amount`: numeric NOT NULL DEFAULT 0 CHECK (`total_amount >= 0`)
- `paid_amount`: numeric NOT NULL DEFAULT 0 CHECK (`paid_amount >= 0`)
- `due_date`: date NOT NULL
- `status`: text NOT NULL DEFAULT `'unpaid'` CHECK (`status IN ('paid', 'partial', 'unpaid')`)
- **Constraints**: `CHECK (paid_amount <= total_amount)`

#### 18. `invoice_items`
Breakdown line items making up an invoice.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `invoice_id`: uuid REFERENCES `public.invoices(id)` ON DELETE CASCADE NOT NULL
- `fee_type_id`: uuid REFERENCES `public.fee_types(id)` ON DELETE RESTRICT NOT NULL
- `amount`: numeric NOT NULL CHECK (`amount >= 0`)

#### 19. `payments`
Receipts for payments made against invoices.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `invoice_id`: uuid REFERENCES `public.invoices(id)` ON DELETE CASCADE NOT NULL
- `amount`: numeric NOT NULL CHECK (`amount > 0`)
- `payment_method`: text NOT NULL (e.g. "ecocash", "bank_transfer", "cash", "paynow")
- `transaction_reference`: text UNIQUE
- `paid_at`: timestamptz NOT NULL DEFAULT now()

#### 20. `bursaries`
Scholarship / discount programs.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `discount_percentage`: numeric CHECK (`discount_percentage BETWEEN 0 AND 100`)
- `discount_amount`: numeric CHECK (`discount_amount >= 0`)
- **Constraints**: `CHECK ((discount_percentage IS NOT NULL AND discount_amount IS NULL) OR (discount_percentage IS NULL AND discount_amount IS NOT NULL))`

#### 21. `student_bursaries`
Assigns a bursary to a student for a year.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `bursary_id`: uuid REFERENCES `public.bursaries(id)` ON DELETE CASCADE NOT NULL
- `academic_year_id`: uuid REFERENCES `public.academic_years(id)` ON DELETE CASCADE NOT NULL
- **Constraints**: `UNIQUE (student_profile_id, bursary_id, academic_year_id)`

#### 22. `staff_payroll`
Salary payment disbursements for school staff.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `staff_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `base_salary`: numeric NOT NULL CHECK (`base_salary >= 0`)
- `allowances`: numeric NOT NULL DEFAULT 0 CHECK (`allowances >= 0`)
- `deductions`: numeric NOT NULL DEFAULT 0 CHECK (`deductions >= 0`)
- `payment_date`: date NOT NULL
- `status`: text NOT NULL DEFAULT `'pending'` CHECK (`status IN ('pending', 'processed', 'cancelled')`)

#### 23. `expenses`
Operational spending records.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `title`: text NOT NULL
- `category`: text NOT NULL (e.g. "Utilities", "Maintenance", "Transport", "Supplies")
- `amount`: numeric NOT NULL CHECK (`amount >= 0`)
- `spent_by_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE SET NULL
- `spent_at`: date NOT NULL
- `receipt_url`: text

#### 24. `budgets`
Departmental allocations per academic year.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `department_name`: text NOT NULL
- `academic_year_id`: uuid REFERENCES `public.academic_years(id)` ON DELETE CASCADE NOT NULL
- `allocated_amount`: numeric NOT NULL CHECK (`allocated_amount >= 0`)
- `spent_amount`: numeric NOT NULL DEFAULT 0 CHECK (`spent_amount >= 0`)
- **Constraints**: `UNIQUE (school_id, department_name, academic_year_id)`

---

### Domain 6: Transportation & GPS Bus Tracking

#### 25. `bus_routes`
School bus transit routes.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `route_name`: text NOT NULL
- `driver_name`: text
- `driver_phone`: text
- `vehicle_number`: text NOT NULL

#### 26. `bus_stops`
Geographic waypoints along a bus route.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `route_id`: uuid REFERENCES `public.bus_routes(id)` ON DELETE CASCADE NOT NULL
- `stop_name`: text NOT NULL
- `latitude`: numeric NOT NULL
- `longitude`: numeric NOT NULL
- `order_index`: integer NOT NULL DEFAULT 0

#### 27. `bus_students`
Registers which bus and stop a student belongs to.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `route_id`: uuid REFERENCES `public.bus_routes(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `stop_id`: uuid REFERENCES `public.bus_stops(id)` ON DELETE SET NULL
- **Constraints**: `UNIQUE (student_profile_id)`

#### 28. `bus_telemetry`
High-frequency GPS tracking points broadcast by driver device/OBD tracker.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `route_id`: uuid REFERENCES `public.bus_routes(id)` ON DELETE CASCADE NOT NULL
- `latitude`: numeric NOT NULL
- `longitude`: numeric NOT NULL
- `speed`: numeric NOT NULL DEFAULT 0 CHECK (`speed >= 0`)
- `recorded_at`: timestamptz NOT NULL DEFAULT now()

---

### Domain 7: AI Personal Tutor & Adaptive Learning

#### 29. `ai_sessions`
Conversational chat sessions between a student and the AI Tutor.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `subject_id`: uuid REFERENCES `public.subjects(id)` ON DELETE SET NULL

#### 30. `ai_messages`
Individual message turn in an AI tutoring dialogue.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `session_id`: uuid REFERENCES `public.ai_sessions(id)` ON DELETE CASCADE NOT NULL
- `sender`: text NOT NULL CHECK (`sender IN ('user', 'ai')`)
- `content`: text NOT NULL

#### 31. `student_learning_profiles`
Knowledge mastery models built by the AI to track strengths and weaknesses.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `strengths`: jsonb NOT NULL DEFAULT `'[]'::jsonb`
- `weaknesses`: jsonb NOT NULL DEFAULT `'[]'::jsonb`
- `last_evaluated_at`: timestamptz NOT NULL DEFAULT now()
- **Constraints**: `UNIQUE (student_profile_id)`

---

### Domain 8: School Marketplace & Uniform Shop

#### 32. `marketplace_items`
Uniforms, textbooks, stationery, and second-hand items.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `title`: text NOT NULL
- `description`: text
- `price`: numeric NOT NULL CHECK (`price >= 0`)
- `stock_quantity`: integer NOT NULL DEFAULT 1 CHECK (`stock_quantity >= 0`)
- `image_url`: text
- `seller_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `status`: text NOT NULL DEFAULT `'available'` CHECK (`status IN ('available', 'sold_out', 'hidden')`)

#### 33. `marketplace_orders`
Orders placed for marketplace goods.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `buyer_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `total_amount`: numeric NOT NULL CHECK (`total_amount >= 0`)
- `status`: text NOT NULL DEFAULT `'pending'` CHECK (`status IN ('pending', 'completed', 'cancelled')`)

#### 34. `marketplace_order_items`
Line items of an order.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `order_id`: uuid REFERENCES `public.marketplace_orders(id)` ON DELETE CASCADE NOT NULL
- `item_id`: uuid REFERENCES `public.marketplace_items(id)` ON DELETE RESTRICT NOT NULL
- `quantity`: integer NOT NULL CHECK (`quantity > 0`)
- `price_at_purchase`: numeric NOT NULL CHECK (`price_at_purchase >= 0`)

---

### Domain 9: Admissions & Registration Pipeline

#### 35. `admissions_applications`
Prospective student application submissions.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `first_name`: text NOT NULL
- `last_name`: text NOT NULL
- `date_of_birth`: date NOT NULL
- `email`: text NOT NULL
- `phone`: text
- `parent_name`: text NOT NULL
- `status`: text NOT NULL DEFAULT `'applied'` CHECK (`status IN ('applied', 'review', 'accepted', 'rejected')`)

#### 36. `admissions_documents`
Scanned attachments (birth certificate, previous school reports, IDs).
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `application_id`: uuid REFERENCES `public.admissions_applications(id)` ON DELETE CASCADE NOT NULL
- `document_type`: text NOT NULL CHECK (`document_type IN ('birth_certificate', 'prior_report', 'id_copy', 'other')`)
- `document_url`: text NOT NULL

---

### Domain 10: Gradebook, Assessments & Report Cards

#### 37. `grading_terms`
Academic terms/semesters (e.g. "Term 1", "Term 2", "Semester 1").
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `academic_year_id`: uuid REFERENCES `public.academic_years(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `weight`: numeric NOT NULL DEFAULT 1 CHECK (`weight >= 0`)

#### 38. `assessment_categories`
Weighting bins (e.g. "Exams", "Class Tests", "Continuous Assessment").
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `name`: text NOT NULL
- `weight`: numeric NOT NULL DEFAULT 1 CHECK (`weight >= 0`)

#### 39. `assessments`
Specific tests, exams, or coursework.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `class_section_id`: uuid REFERENCES `public.class_sections(id)` ON DELETE CASCADE NOT NULL
- `subject_id`: uuid REFERENCES `public.subjects(id)` ON DELETE CASCADE NOT NULL
- `term_id`: uuid REFERENCES `public.grading_terms(id)` ON DELETE CASCADE NOT NULL
- `category_id`: uuid REFERENCES `public.assessment_categories(id)` ON DELETE CASCADE NOT NULL
- `title`: text NOT NULL
- `max_points`: numeric NOT NULL CHECK (`max_points > 0`)
- `date_administered`: date NOT NULL

#### 40. `grade_records`
Marks awarded to individual students.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `assessment_id`: uuid REFERENCES `public.assessments(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `points_obtained`: numeric NOT NULL CHECK (`points_obtained >= 0`)
- `teacher_remarks`: text
- **Constraints**: `UNIQUE (assessment_id, student_profile_id)`

#### 41. `report_cards`
Consolidated term evaluations with GPA and principal sign-off.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `academic_year_id`: uuid REFERENCES `public.academic_years(id)` ON DELETE CASCADE NOT NULL
- `term_id`: uuid REFERENCES `public.grading_terms(id)` ON DELETE CASCADE NOT NULL
- `gpa`: numeric CHECK (`gpa BETWEEN 0 AND 4.0`)
- `teacher_comments`: text
- `principal_approved`: boolean NOT NULL DEFAULT false
- **Constraints**: `UNIQUE (student_profile_id, academic_year_id, term_id)`

---

### Domain 11: Attendance & Staff Leaves

#### 42. `daily_attendance`
Daily roll call for students.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `class_section_id`: uuid REFERENCES `public.class_sections(id)` ON DELETE CASCADE NOT NULL
- `date`: date NOT NULL DEFAULT current_date
- `status`: text NOT NULL CHECK (`status IN ('present', 'absent', 'late', 'excused')`)
- `remarks`: text
- **Constraints**: `UNIQUE (student_profile_id, date)`

#### 43. `staff_attendance`
Biometric / digital clock-in for teachers and administrative staff.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `staff_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `date`: date NOT NULL DEFAULT current_date
- `clock_in`: timestamptz
- `clock_out`: timestamptz
- `status`: text NOT NULL DEFAULT `'present'` CHECK (`status IN ('present', 'late', 'absent')`)
- **Constraints**: `UNIQUE (staff_profile_id, date)`

#### 44. `staff_leaves`
Staff leave requests and approvals.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `staff_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `leave_type`: text NOT NULL CHECK (`leave_type IN ('sick', 'annual', 'unpaid', 'other')`)
- `start_date`: date NOT NULL
- `end_date`: date NOT NULL
- `status`: text NOT NULL DEFAULT `'pending'` CHECK (`status IN ('pending', 'approved', 'rejected')`)
- `reason`: text
- `approved_by_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE SET NULL
- **Constraints**: `CHECK (start_date <= end_date)`

---

### Domain 12: Library Management

#### 45. `library_books`
Catalog of library assets.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `title`: text NOT NULL
- `author`: text NOT NULL
- `isbn`: text
- `stock_quantity`: integer NOT NULL DEFAULT 1 CHECK (`stock_quantity >= 0`)
- `available_quantity`: integer NOT NULL DEFAULT 1 CHECK (`available_quantity >= 0`)

#### 46. `library_issues`
Circulation records for borrowed books.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `book_id`: uuid REFERENCES `public.library_books(id)` ON DELETE CASCADE NOT NULL
- `borrower_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `issued_at`: timestamptz NOT NULL DEFAULT now()
- `due_at`: timestamptz NOT NULL
- `returned_at`: timestamptz
- `status`: text NOT NULL DEFAULT `'issued'` CHECK (`status IN ('issued', 'returned', 'overdue')`)

#### 47. `library_fines`
Overdue / damaged book penalties.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `issue_id`: uuid REFERENCES `public.library_issues(id)` ON DELETE CASCADE NOT NULL
- `amount`: numeric NOT NULL CHECK (`amount >= 0`)
- `status`: text NOT NULL DEFAULT `'unpaid'` CHECK (`status IN ('unpaid', 'paid')`)

---

### Domain 13: Student Behavioral Tracking

#### 48. `behavioral_logs`
Disciplinary and merit system records.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `student_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `logged_by_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE SET NULL
- `type`: text NOT NULL CHECK (`type IN ('merit', 'demerit', 'incident')`)
- `points`: integer NOT NULL DEFAULT 0
- `description`: text NOT NULL
- `incident_date`: date NOT NULL DEFAULT current_date

---

### Domain 14: Communication & Notifications

#### 49. `announcements`
Broadcast notices targeting all or specific roles.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `title`: text NOT NULL
- `content`: text NOT NULL
- `author_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE SET NULL
- `target_role`: text NOT NULL CHECK (`target_role IN ('all', 'teachers', 'parents', 'students')`)

#### 50. `direct_messages`
In-app communication between profiles within a school.
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `sender_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `recipient_profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `message`: text NOT NULL

#### 51. `push_tokens`
Device push registration tokens (FCM / APNs).
- `school_id`: uuid REFERENCES `public.schools(id)` ON DELETE CASCADE NOT NULL
- `profile_id`: uuid REFERENCES `public.profiles(id)` ON DELETE CASCADE NOT NULL
- `token`: text NOT NULL
- `platform`: text NOT NULL CHECK (`platform IN ('ios', 'android', 'web')`)
- **Constraints**: `UNIQUE (profile_id, token)`

---

## 5. Row-Level Security (RLS) Policy Matrix

Every table has Row Level Security enabled (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`).

| Resource Group | SELECT Permissions | INSERT / UPDATE / DELETE Permissions |
|---|---|---|
| **`schools`** | Active school members (`school_id`), users with any profile in the school, or `super_admin`. | INSERT/DELETE: `super_admin` only.<br>UPDATE: `super_admin` or `school_admin` of that school. |
| **`profiles`** | Own profile (`user_id = auth.uid()`), school peers (`school_id = active`), parent viewing children across schools, or `super_admin`. | INSERT/DELETE: `school_admin` (in their school) or `super_admin`.<br>UPDATE: Self (`user_id = auth.uid()`), `school_admin`, or `super_admin`. |
| **`user_relationships`** | Parent/Student viewing their own links, `school_admin`, `teacher`, or `super_admin`. | `school_admin` or `super_admin`. |
| **Academic Structures** (`academic_years`, `classes`, `class_sections`, `subjects`, `class_teachers`) | All members with a profile in the school. | `school_admin` or `super_admin`. |
| **`student_enrollments`** | Student (self), Parent (their children), `teacher`, `school_admin`, `super_admin`. | `school_admin` or `super_admin`. |
| **LMS** (`courses`, `lessons`, `assignments`) | All authenticated members of that school. | `teacher` and `school_admin`. |
| **`submissions`** | Student (own submissions), Parent (children submissions), `teacher`, `school_admin`. | Student (submit work), Teacher/Admin (grading & remarks). |
| **Finance** (`invoices`, `payments`, `bursaries`) | Billed student, Parent of student, `school_admin`, `super_admin`. | `school_admin` (write invoices, bursaries).<br>Student/Parent can INSERT payments with check. |
| **Transport** (`bus_routes`, `bus_stops`, `bus_telemetry`) | All school members can read route/stops/telemetry. | `bus_students` read by parent/student/admin.<br>Telemetry INSERT: Driver profile/Admin. |
| **AI Tutor** (`ai_sessions`, `ai_messages`) | Student owner of session only. | Student owner of session only. |
| **`marketplace_items`** | Visible if `school_id = active` AND `status = 'available'`. | Item seller (own items), or `school_admin`. |
| **`marketplace_orders`** | Buyer profile, or `school_admin`. | School members can insert orders for items in their school. |
| **`admissions_applications`** | Submitting applicant (matching `email = auth.email()`), or `school_admin`. | Public/applicant can insert into target school; Admin manages. |
| **Gradebook** (`grade_records`, `report_cards`) | Student (self), Parent (children), Teacher, School Admin. | `grade_records`: Teacher & Admin.<br>`report_cards`: Admin only (principal approval). |
| **Attendance** (`daily_attendance`) | Student (self), Parent (children), Teacher, School Admin. | Teacher & School Admin. |
| **Staff Payroll & Leaves** | Respective staff member (self), or School Admin. | School Admin (approvals/management); Staff can request leaves. |
| **Communication** (`announcements`) | Scoped to active `school_id` and matching `target_role` ('all' or user's role). | Teacher and School Admin. |
| **`direct_messages`** | Sender or Recipient profile only. | Sender profile (matching own profile). |
| **`push_tokens`** | Own profile only (`profile_id`). | Own profile only. |

---

## 6. Edge Functions Architecture

All Edge Functions run in Deno on Supabase's edge runtime.

### Function 1: `set-user-claims` (Auth Hook)
- **Path:** `supabase/functions/set-user-claims/index.ts`
- **Trigger:** Configured in Supabase Dashboard → Authentication → Hooks → **Custom Access Token**.
- **Purpose:** On user login or token refresh, it fetches the user's primary active profile and injects `school_id`, `role`, and `profile_id` into the JWT `app_metadata`. This eliminates redundant database lookups in RLS policies.

```typescript
import { createClient } from 'npm:@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  try {
    const body = await req.json()
    const { user_id, event } = body

    if (event !== 'login' && event !== 'token_refresh' && event !== 'user_updated') {
      return new Response(JSON.stringify({ message: 'skipped' }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    if (!user_id) {
      return new Response(JSON.stringify({ error: 'user_id is required' }), { status: 400 })
    }

    // Runs server-side using service role key
    const supabase = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    // Fetch primary active profile
    const { data: profile, error } = await supabase
      .from('profiles')
      .select('id, school_id, role, schools(name, subdomain)')
      .eq('user_id', user_id)
      .is('deleted_at', null)
      .eq('status', 'active')
      .order('created_at', { ascending: true })
      .limit(1)
      .single()

    if (error || !profile) {
      return new Response(JSON.stringify({ app_metadata: {} }), {
        headers: { 'Content-Type': 'application/json' },
        status: 200,
      })
    }

    const claims = {
      school_id: profile.school_id,
      role: profile.role,
      profile_id: profile.id,
    }

    return new Response(JSON.stringify({ app_metadata: claims }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
```

---

### Function 2: `invite-user`
- **Path:** `supabase/functions/invite-user/index.ts`
- **Trigger:** Invoked via HTTP POST from Super Admin dashboard.
- **Purpose:** Uses `supabaseAdmin.auth.admin.inviteUserByEmail(email)` to send an email invitation. Verified against caller's JWT `app_metadata.role == 'super_admin'`.

```typescript
import { createClient } from 'npm:@supabase/supabase-js@2'

Deno.serve(async (req: Request) => {
  try {
    const { email } = await req.json()
    if (!email) {
      return new Response(JSON.stringify({ error: 'email is required' }), { status: 400 })
    }

    const authHeader = req.headers.get('Authorization')
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const supabaseAdmin = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '',
    )

    const token = authHeader.replace('Bearer ', '')
    const { data: { user }, error: userErr } = await supabaseAdmin.auth.getUser(token)

    if (userErr || !user) {
      return new Response(JSON.stringify({ error: 'Unauthorized' }), { status: 401 })
    }

    const callerRole = user.app_metadata?.role
    if (callerRole !== 'super_admin') {
      return new Response(JSON.stringify({ error: 'Only super admins can invite users' }), { status: 403 })
    }

    const { data, error } = await supabaseAdmin.auth.admin.inviteUserByEmail(email)

    if (error) {
      return new Response(JSON.stringify({ error: error.message }), { status: 400 })
    }

    return new Response(JSON.stringify({ success: true, user: { id: data.user.id, email: data.user.email } }), {
      headers: { 'Content-Type': 'application/json' },
      status: 200,
    })
  } catch (err) {
    return new Response(JSON.stringify({ error: err.message }), {
      headers: { 'Content-Type': 'application/json' },
      status: 500,
    })
  }
})
```

---

## 7. Performance & Synchronization Indexes

The database contains two specialized classes of partial indexes designed for high-scale multi-tenancy and mobile offline sync:

### 1. Active Tenant-Scoped Partial Indexes (`WHERE deleted_at IS NULL`)
Standard operational queries only query non-deleted records within a school. These indexes avoid scanning dead/deleted tuples:

```sql
-- Profiles & Roles
CREATE INDEX idx_profiles_tenant_sync ON public.profiles (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_user_id ON public.profiles (user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_role ON public.profiles (role) WHERE deleted_at IS NULL;

-- Relationships & Enrollments
CREATE INDEX idx_relationships_tenant_sync ON public.user_relationships (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_relationships_parent_id ON public.user_relationships (parent_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_relationships_student_id ON public.user_relationships (student_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_enrollments_tenant_sync ON public.student_enrollments (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_enrollments_lookup ON public.student_enrollments (academic_year_id, status) WHERE deleted_at IS NULL;

-- Finance & Invoices
CREATE INDEX idx_invoices_student_year ON public.invoices (student_profile_id, academic_year_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_tenant_sync ON public.invoices (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_payments_invoice ON public.payments (invoice_id) WHERE deleted_at IS NULL;

-- High-Frequency Telemetry & Messaging
CREATE INDEX idx_bus_telemetry_route_time ON public.bus_telemetry (route_id, recorded_at DESC);
CREATE INDEX idx_direct_messages_sender_recipient ON public.direct_messages (school_id, sender_profile_id, recipient_profile_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_announcements_target ON public.announcements (school_id, target_role, created_at DESC) WHERE deleted_at IS NULL;
```

### 2. Offline Delta Tombstone Indexes (`WHERE deleted_at IS NOT NULL`)
When offline clients sync with Supabase, they need to know which records were deleted since their last sync. These partial indexes provide instantaneous tombstone lookup:

```sql
CREATE INDEX idx_schools_deleted_sync ON public.schools (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_profiles_deleted_sync ON public.profiles (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_relationships_deleted_sync ON public.user_relationships (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_enrollments_deleted_sync ON public.student_enrollments (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_courses_deleted_sync ON public.courses (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_lessons_deleted_sync ON public.lessons (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_assignments_deleted_sync ON public.assignments (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_submissions_deleted_sync ON public.submissions (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_invoices_deleted_sync ON public.invoices (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_payments_deleted_sync ON public.payments (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_daily_attendance_deleted_sync ON public.daily_attendance (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX idx_direct_messages_deleted_sync ON public.direct_messages (updated_at) WHERE deleted_at IS NOT NULL;
```

---

## 8. Client-Side Querying & Integration Conventions

When writing frontend queries (in Flutter/Dart `supabase_flutter` or JavaScript/TypeScript):

### Pattern A: Standard Read Query
Always filter `deleted_at.is(null)` and `school_id.eq(activeSchoolId)`:

```dart
// Flutter / Dart example
final response = await supabase
    .from('assignments')
    .select('*, lesson:lessons(title, course:courses(name))')
    .eq('school_id', currentSchoolId)
    .isFilter('deleted_at', null)
    .order('due_date', ascending: true);
```

### Pattern B: Soft Delete Execution
Never call `.delete()` directly from client code. Perform an update:

```dart
// Soft delete an item
await supabase
    .from('marketplace_items')
    .update({'deleted_at': DateTime.now().toUtc().toIso8601String()})
    .eq('id', itemId);
```

### Pattern C: Delta Sync Query (Offline-to-Online)
To fetch changes made since `:lastSyncTimestamp`:

```dart
// 1. Fetch updated/created records
final activeRecords = await supabase
    .from('daily_attendance')
    .select()
    .eq('school_id', currentSchoolId)
    .isFilter('deleted_at', null)
    .gt('updated_at', lastSyncTimestamp.toIso8601String());

// 2. Fetch tombstones (deleted items)
final deletedRecords = await supabase
    .from('daily_attendance')
    .select('id')
    .eq('school_id', currentSchoolId)
    .not('deleted_at', 'is', null)
    .gt('updated_at', lastSyncTimestamp.toIso8601String());
```

---

## 9. Instructions for ChatGPT / Backend Copilot

When asked to extend or write backend features for ZivoConnect EMS, follow these rules:

1. **When generating new tables:**
   - Always include `id uuid PRIMARY KEY DEFAULT gen_random_uuid()`
   - Always include `school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL`
   - Always include `created_at timestamptz NOT NULL DEFAULT now()`
   - Always include `updated_at timestamptz NOT NULL DEFAULT now()`
   - Always include `deleted_at timestamptz`
   - Always attach the `trigger_update_<table_name>_updated_at` trigger
   - Always run `ALTER TABLE public.<table_name> ENABLE ROW LEVEL SECURITY;`
   - Add appropriate RLS policies referencing `public.get_active_school_id()` and `public.get_active_role()`
   - Add a partial tenant index: `CREATE INDEX idx_<table_name>_tenant_sync ON public.<table_name> (school_id, updated_at) WHERE deleted_at IS NULL;`

2. **When writing Edge Functions:**
   - Use `npm:@supabase/supabase-js@2` via Deno ESM imports
   - Validate authorization headers or session JWTs before executing business logic
   - If calling third-party APIs (e.g. EcoCash, Paynow, OpenRouter, Firebase Cloud Messaging), extract secrets from `Deno.env.get(...)`
   - Handle errors gracefully and return appropriate HTTP status codes (400, 401, 403, 500)

3. **When writing RPC Stored Procedures:**
   - Mark functions `SECURITY DEFINER` only when elevated privileges are necessary (e.g., cross-tenant aggregation or user provisioning)
   - Set `SET search_path = public` to prevent search path hijacking attacks
   - Never accept an arbitrary `school_id` from unauthenticated parameters; always cross-verify against `public.get_active_school_id()` or the caller's verified profile.
