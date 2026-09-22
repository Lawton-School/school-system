-- =====================================================================
-- PERFORMANCE INDEXES & OPTIMIZATIONS
-- =====================================================================

-- 1. Tenant Scoping & Soft Delete Partial Indexes
-- These optimize the standard queries which always filter by school_id and deleted_at IS NULL.

-- Schools
CREATE INDEX idx_schools_status ON public.schools (status) WHERE deleted_at IS NULL;

-- Profiles
CREATE INDEX idx_profiles_tenant_sync ON public.profiles (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_user_id ON public.profiles (user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_profiles_role ON public.profiles (role) WHERE deleted_at IS NULL;

-- User Relationships
CREATE INDEX idx_relationships_tenant_sync ON public.user_relationships (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_relationships_parent_id ON public.user_relationships (parent_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_relationships_student_id ON public.user_relationships (student_id) WHERE deleted_at IS NULL;

-- Student Enrollments
CREATE INDEX idx_enrollments_tenant_sync ON public.student_enrollments (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_enrollments_student_profile_id ON public.student_enrollments (student_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_enrollments_class_section_id ON public.student_enrollments (class_section_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_enrollments_lookup ON public.student_enrollments (academic_year_id, status) WHERE deleted_at IS NULL;


-- 2. LMS Indexes
CREATE INDEX idx_courses_tenant_sync ON public.courses (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_courses_teacher ON public.courses (teacher_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_lessons_course ON public.lessons (course_id, order_index) WHERE deleted_at IS NULL;
CREATE INDEX idx_assignments_lesson ON public.assignments (lesson_id, due_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_submissions_lookup ON public.submissions (assignment_id, student_profile_id) WHERE deleted_at IS NULL;


-- 3. Live Classes Indexes
CREATE INDEX idx_live_classes_lookup ON public.live_classes (class_section_id, scheduled_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_live_attendance_lookup ON public.live_attendance (live_class_id, student_profile_id) WHERE deleted_at IS NULL;


-- 4. Fees, Bursaries & Finance Indexes
CREATE INDEX idx_invoices_student_year ON public.invoices (student_profile_id, academic_year_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoices_tenant_sync ON public.invoices (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_invoice_items_invoice ON public.invoice_items (invoice_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_payments_invoice ON public.payments (invoice_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_student_bursaries_lookup ON public.student_bursaries (student_profile_id, academic_year_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_staff_payroll_lookup ON public.staff_payroll (staff_profile_id, payment_date) WHERE deleted_at IS NULL;
CREATE INDEX idx_expenses_lookup ON public.expenses (school_id, category, spent_at) WHERE deleted_at IS NULL;
CREATE INDEX idx_budgets_lookup ON public.budgets (school_id, academic_year_id) WHERE deleted_at IS NULL;


-- 5. Bus Tracking Indexes
CREATE INDEX idx_bus_stops_route ON public.bus_stops (route_id, order_index) WHERE deleted_at IS NULL;
CREATE INDEX idx_bus_students_lookup ON public.bus_students (student_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_bus_students_route ON public.bus_students (route_id) WHERE deleted_at IS NULL;
-- Telemetry is high write-frequency. Compound index speeds up fetching historical trace runs.
CREATE INDEX idx_bus_telemetry_route_time ON public.bus_telemetry (route_id, recorded_at DESC);


-- 6. AI Tutor Indexes
CREATE INDEX idx_ai_sessions_student ON public.ai_sessions (student_profile_id, subject_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_ai_messages_session ON public.ai_messages (session_id, created_at) WHERE deleted_at IS NULL;


-- 7. School Marketplace Indexes
-- Compound index to fetch only available listings inside a school
CREATE INDEX idx_marketplace_items_listing ON public.marketplace_items (school_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_marketplace_orders_buyer ON public.marketplace_orders (buyer_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_marketplace_order_items_order ON public.marketplace_order_items (order_id) WHERE deleted_at IS NULL;


-- 8. Admissions Indexes
CREATE INDEX idx_admissions_lookup ON public.admissions_applications (school_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_admissions_email ON public.admissions_applications (email) WHERE deleted_at IS NULL;
CREATE INDEX idx_admissions_docs_app ON public.admissions_documents (application_id) WHERE deleted_at IS NULL;


-- 9. Gradebook & Reports Indexes
CREATE INDEX idx_assessments_lookup ON public.assessments (class_section_id, subject_id, term_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_grade_records_student ON public.grade_records (student_profile_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_grade_records_assessment ON public.grade_records (assessment_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_report_cards_lookup ON public.report_cards (student_profile_id, academic_year_id) WHERE deleted_at IS NULL;


-- 10. Leave & Attendance Indexes
-- Speeds up daily roster views
CREATE INDEX idx_daily_attendance_roster ON public.daily_attendance (class_section_id, date, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_staff_attendance_lookup ON public.staff_attendance (staff_profile_id, date) WHERE deleted_at IS NULL;
CREATE INDEX idx_staff_leaves_lookup ON public.staff_leaves (staff_profile_id, status) WHERE deleted_at IS NULL;


-- 11. Library Indexes
CREATE INDEX idx_library_issues_borrower ON public.library_issues (borrower_profile_id, status) WHERE deleted_at IS NULL;
CREATE INDEX idx_library_issues_book ON public.library_issues (book_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_library_fines_issue ON public.library_fines (issue_id) WHERE deleted_at IS NULL;


-- 12. Behavioral Tracking Indexes
CREATE INDEX idx_behavioral_student ON public.behavioral_logs (student_profile_id, type) WHERE deleted_at IS NULL;


-- 13. Communication Indexes
CREATE INDEX idx_announcements_target ON public.announcements (school_id, target_role, created_at DESC) WHERE deleted_at IS NULL;
-- Bi-directional index for DM message streams
CREATE INDEX idx_direct_messages_sender_recipient ON public.direct_messages (school_id, sender_profile_id, recipient_profile_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX idx_push_tokens_profile ON public.push_tokens (profile_id) WHERE deleted_at IS NULL;


-- =====================================================================
-- GENERAL OFFLINE DELTA SYNC INDEX
-- =====================================================================
-- Helps sync clients fetch deleted records (tombstones) across the entire schema quickly.
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
