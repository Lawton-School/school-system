-- ==========================================
-- parent-student global verification helper
-- ==========================================
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


-- =====================================================================
-- 1. LMS MODULE
-- =====================================================================
CREATE TABLE public.courses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    description text,
    teacher_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.lessons (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    course_id uuid REFERENCES public.courses(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    content_url text,
    order_index integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.assignments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    lesson_id uuid REFERENCES public.lessons(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    description text,
    due_date timestamptz NOT NULL,
    max_points numeric NOT NULL CHECK (max_points >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.submissions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    assignment_id uuid REFERENCES public.assignments(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    submitted_at timestamptz NOT NULL DEFAULT now(),
    content_url text NOT NULL,
    grade numeric CHECK (grade >= 0),
    feedback text,
    graded_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_assignment_submission_per_student UNIQUE (assignment_id, student_profile_id)
);


-- =====================================================================
-- 2. LIVE CLASSES MODULE
-- =====================================================================
CREATE TABLE public.live_classes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE NOT NULL,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE NOT NULL,
    teacher_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    title text NOT NULL,
    meeting_url text NOT NULL,
    scheduled_at timestamptz NOT NULL,
    duration_minutes integer NOT NULL DEFAULT 45 CHECK (duration_minutes > 0),
    status text NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'live', 'completed', 'cancelled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.live_attendance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    live_class_id uuid REFERENCES public.live_classes(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    joined_at timestamptz,
    left_at timestamptz,
    status text NOT NULL DEFAULT 'absent' CHECK (status IN ('present', 'absent', 'tardy')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_live_attendance_per_class UNIQUE (live_class_id, student_profile_id)
);


-- =====================================================================
-- 3. FEES, BURSARIES & FINANCE MODULE (EXPANDED)
-- =====================================================================
CREATE TABLE public.fee_types (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    description text,
    amount numeric NOT NULL CHECK (amount >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.invoices (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE CASCADE NOT NULL,
    total_amount numeric NOT NULL DEFAULT 0 CHECK (total_amount >= 0),
    paid_amount numeric NOT NULL DEFAULT 0 CHECK (paid_amount >= 0),
    due_date date NOT NULL,
    status text NOT NULL DEFAULT 'unpaid' CHECK (status IN ('paid', 'partial', 'unpaid')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT paid_less_than_total CHECK (paid_amount <= total_amount)
);

CREATE TABLE public.invoice_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    invoice_id uuid REFERENCES public.invoices(id) ON DELETE CASCADE NOT NULL,
    fee_type_id uuid REFERENCES public.fee_types(id) ON DELETE RESTRICT NOT NULL,
    amount numeric NOT NULL CHECK (amount >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.payments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    invoice_id uuid REFERENCES public.invoices(id) ON DELETE CASCADE NOT NULL,
    amount numeric NOT NULL CHECK (amount > 0),
    payment_method text NOT NULL,
    transaction_reference text UNIQUE,
    paid_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- Bursaries & Scholarships
CREATE TABLE public.bursaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL,
    discount_percentage numeric CHECK (discount_percentage BETWEEN 0 AND 100),
    discount_amount numeric CHECK (discount_amount >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT check_percentage_or_amount CHECK (
        (discount_percentage IS NOT NULL AND discount_amount IS NULL) OR 
        (discount_percentage IS NULL AND discount_amount IS NOT NULL)
    )
);

CREATE TABLE public.student_bursaries (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    bursary_id uuid REFERENCES public.bursaries(id) ON DELETE CASCADE NOT NULL,
    academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE CASCADE NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_student_bursary_per_year UNIQUE (student_profile_id, bursary_id, academic_year_id)
);

-- Staff Payroll
CREATE TABLE public.staff_payroll (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    staff_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    base_salary numeric NOT NULL CHECK (base_salary >= 0),
    allowances numeric NOT NULL DEFAULT 0 CHECK (allowances >= 0),
    deductions numeric NOT NULL DEFAULT 0 CHECK (deductions >= 0),
    payment_date date NOT NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'processed', 'cancelled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- Expense Tracking
CREATE TABLE public.expenses (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    category text NOT NULL,
    amount numeric NOT NULL CHECK (amount >= 0),
    spent_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    spent_at date NOT NULL,
    receipt_url text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- Budgets
CREATE TABLE public.budgets (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    department_name text NOT NULL,
    academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE CASCADE NOT NULL,
    allocated_amount numeric NOT NULL CHECK (allocated_amount >= 0),
    spent_amount numeric NOT NULL DEFAULT 0 CHECK (spent_amount >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_department_budget UNIQUE (school_id, department_name, academic_year_id)
);


-- =====================================================================
-- 4. BUS TRACKING MODULE
-- =====================================================================
CREATE TABLE public.bus_routes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    route_name text NOT NULL,
    driver_name text,
    driver_phone text,
    vehicle_number text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.bus_stops (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    route_id uuid REFERENCES public.bus_routes(id) ON DELETE CASCADE NOT NULL,
    stop_name text NOT NULL,
    latitude numeric NOT NULL,
    longitude numeric NOT NULL,
    order_index integer NOT NULL DEFAULT 0,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.bus_students (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    route_id uuid REFERENCES public.bus_routes(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    stop_id uuid REFERENCES public.bus_stops(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_bus_student UNIQUE (student_profile_id)
);

CREATE TABLE public.bus_telemetry (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    route_id uuid REFERENCES public.bus_routes(id) ON DELETE CASCADE NOT NULL,
    latitude numeric NOT NULL,
    longitude numeric NOT NULL,
    speed numeric NOT NULL DEFAULT 0 CHECK (speed >= 0),
    recorded_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);


-- =====================================================================
-- 5. AI TUTOR MODULE
-- =====================================================================
CREATE TABLE public.ai_sessions (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.ai_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    session_id uuid REFERENCES public.ai_sessions(id) ON DELETE CASCADE NOT NULL,
    sender text NOT NULL CHECK (sender IN ('user', 'ai')),
    content text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.student_learning_profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    strengths jsonb NOT NULL DEFAULT '[]'::jsonb,
    weaknesses jsonb NOT NULL DEFAULT '[]'::jsonb,
    last_evaluated_at timestamptz NOT NULL DEFAULT now(),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_learning_profile UNIQUE (student_profile_id)
);


-- =====================================================================
-- 6. SCHOOL MARKETPLACE MODULE
-- =====================================================================
CREATE TABLE public.marketplace_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    description text,
    price numeric NOT NULL CHECK (price >= 0),
    stock_quantity integer NOT NULL DEFAULT 1 CHECK (stock_quantity >= 0),
    image_url text,
    seller_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    status text NOT NULL DEFAULT 'available' CHECK (status IN ('available', 'sold_out', 'hidden')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.marketplace_orders (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    buyer_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    total_amount numeric NOT NULL CHECK (total_amount >= 0),
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'completed', 'cancelled')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.marketplace_order_items (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    order_id uuid REFERENCES public.marketplace_orders(id) ON DELETE CASCADE NOT NULL,
    item_id uuid REFERENCES public.marketplace_items(id) ON DELETE RESTRICT NOT NULL,
    quantity integer NOT NULL CHECK (quantity > 0),
    price_at_purchase numeric NOT NULL CHECK (price_at_purchase >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);


-- =====================================================================
-- 7. ADMISSIONS PIPELINE
-- =====================================================================
CREATE TABLE public.admissions_applications (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    date_of_birth date NOT NULL,
    email text NOT NULL,
    phone text,
    parent_name text NOT NULL,
    status text NOT NULL DEFAULT 'applied' CHECK (status IN ('applied', 'review', 'accepted', 'rejected')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.admissions_documents (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    application_id uuid REFERENCES public.admissions_applications(id) ON DELETE CASCADE NOT NULL,
    document_type text NOT NULL CHECK (document_type IN ('birth_certificate', 'prior_report', 'id_copy', 'other')),
    document_url text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);


-- =====================================================================
-- 8. GRADEBOOK & REPORTS MODULE
-- =====================================================================
CREATE TABLE public.grading_terms (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL, -- e.g. "Term 1"
    weight numeric NOT NULL DEFAULT 1 CHECK (weight >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.assessment_categories (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL, -- e.g. "Exams", "Homework"
    weight numeric NOT NULL DEFAULT 1 CHECK (weight >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.assessments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE NOT NULL,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE NOT NULL,
    term_id uuid REFERENCES public.grading_terms(id) ON DELETE CASCADE NOT NULL,
    category_id uuid REFERENCES public.assessment_categories(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    max_points numeric NOT NULL CHECK (max_points > 0),
    date_administered date NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.grade_records (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    assessment_id uuid REFERENCES public.assessments(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    points_obtained numeric NOT NULL CHECK (points_obtained >= 0),
    teacher_remarks text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_grade_per_student UNIQUE (assessment_id, student_profile_id)
);

CREATE TABLE public.report_cards (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE CASCADE NOT NULL,
    term_id uuid REFERENCES public.grading_terms(id) ON DELETE CASCADE NOT NULL,
    gpa numeric CHECK (gpa BETWEEN 0 AND 4.0),
    teacher_comments text,
    principal_approved boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_report_card_per_term UNIQUE (student_profile_id, academic_year_id, term_id)
);


-- =====================================================================
-- 9. LEAVE & ATTENDANCE MODULE
-- =====================================================================
CREATE TABLE public.daily_attendance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL DEFAULT current_date,
    status text NOT NULL CHECK (status IN ('present', 'absent', 'late', 'excused')),
    remarks text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_daily_attendance UNIQUE (student_profile_id, date)
);

CREATE TABLE public.staff_attendance (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    staff_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    date date NOT NULL DEFAULT current_date,
    clock_in timestamptz,
    clock_out timestamptz,
    status text NOT NULL DEFAULT 'present' CHECK (status IN ('present', 'late', 'absent')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_staff_attendance UNIQUE (staff_profile_id, date)
);

CREATE TABLE public.staff_leaves (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    staff_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    leave_type text NOT NULL CHECK (leave_type IN ('sick', 'annual', 'unpaid', 'other')),
    start_date date NOT NULL,
    end_date date NOT NULL,
    status text NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'approved', 'rejected')),
    reason text,
    approved_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT check_leave_dates CHECK (start_date <= end_date)
);


-- =====================================================================
-- 10. LIBRARY MANAGEMENT MODULE
-- =====================================================================
CREATE TABLE public.library_books (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    author text NOT NULL,
    isbn text,
    stock_quantity integer NOT NULL DEFAULT 1 CHECK (stock_quantity >= 0),
    available_quantity integer NOT NULL DEFAULT 1 CHECK (available_quantity >= 0),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.library_issues (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    book_id uuid REFERENCES public.library_books(id) ON DELETE CASCADE NOT NULL,
    borrower_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    issued_at timestamptz NOT NULL DEFAULT now(),
    due_at timestamptz NOT NULL,
    returned_at timestamptz,
    status text NOT NULL DEFAULT 'issued' CHECK (status IN ('issued', 'returned', 'overdue')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.library_fines (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    issue_id uuid REFERENCES public.library_issues(id) ON DELETE CASCADE NOT NULL,
    amount numeric NOT NULL CHECK (amount >= 0),
    status text NOT NULL DEFAULT 'unpaid' CHECK (status IN ('unpaid', 'paid')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);


-- =====================================================================
-- 11. BEHAVIORAL & INCIDENT TRACKING MODULE
-- =====================================================================
CREATE TABLE public.behavioral_logs (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    logged_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    type text NOT NULL CHECK (type IN ('merit', 'demerit', 'incident')),
    points integer NOT NULL DEFAULT 0,
    description text NOT NULL,
    incident_date date NOT NULL DEFAULT current_date,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);


-- =====================================================================
-- 12. COMMUNICATION & NOTIFICATIONS MODULE
-- =====================================================================
CREATE TABLE public.announcements (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    title text NOT NULL,
    content text NOT NULL,
    author_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
    target_role text NOT NULL CHECK (target_role IN ('all', 'teachers', 'parents', 'students')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.direct_messages (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    sender_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    recipient_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    message text NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

CREATE TABLE public.push_tokens (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    token text NOT NULL,
    platform text NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_push_token UNIQUE (profile_id, token)
);


-- ==========================================
-- Attach updated_at triggers to all modules
-- ==========================================
CREATE TRIGGER trigger_update_courses_updated_at BEFORE UPDATE ON public.courses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_lessons_updated_at BEFORE UPDATE ON public.lessons FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_assignments_updated_at BEFORE UPDATE ON public.assignments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_submissions_updated_at BEFORE UPDATE ON public.submissions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_live_classes_updated_at BEFORE UPDATE ON public.live_classes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_live_attendance_updated_at BEFORE UPDATE ON public.live_attendance FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_fee_types_updated_at BEFORE UPDATE ON public.fee_types FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_invoices_updated_at BEFORE UPDATE ON public.invoices FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_invoice_items_updated_at BEFORE UPDATE ON public.invoice_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_payments_updated_at BEFORE UPDATE ON public.payments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_bursaries_updated_at BEFORE UPDATE ON public.bursaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_student_bursaries_updated_at BEFORE UPDATE ON public.student_bursaries FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_staff_payroll_updated_at BEFORE UPDATE ON public.staff_payroll FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_expenses_updated_at BEFORE UPDATE ON public.expenses FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_budgets_updated_at BEFORE UPDATE ON public.budgets FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_bus_routes_updated_at BEFORE UPDATE ON public.bus_routes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_bus_stops_updated_at BEFORE UPDATE ON public.bus_stops FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_bus_students_updated_at BEFORE UPDATE ON public.bus_students FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_bus_telemetry_updated_at BEFORE UPDATE ON public.bus_telemetry FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_ai_sessions_updated_at BEFORE UPDATE ON public.ai_sessions FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_ai_messages_updated_at BEFORE UPDATE ON public.ai_messages FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_student_learning_profiles_updated_at BEFORE UPDATE ON public.student_learning_profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_marketplace_items_updated_at BEFORE UPDATE ON public.marketplace_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_marketplace_orders_updated_at BEFORE UPDATE ON public.marketplace_orders FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_marketplace_order_items_updated_at BEFORE UPDATE ON public.marketplace_order_items FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_admissions_applications_updated_at BEFORE UPDATE ON public.admissions_applications FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_admissions_documents_updated_at BEFORE UPDATE ON public.admissions_documents FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_grading_terms_updated_at BEFORE UPDATE ON public.grading_terms FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_assessment_categories_updated_at BEFORE UPDATE ON public.assessment_categories FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_assessments_updated_at BEFORE UPDATE ON public.assessments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_grade_records_updated_at BEFORE UPDATE ON public.grade_records FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_report_cards_updated_at BEFORE UPDATE ON public.report_cards FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_daily_attendance_updated_at BEFORE UPDATE ON public.daily_attendance FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_staff_attendance_updated_at BEFORE UPDATE ON public.staff_attendance FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_staff_leaves_updated_at BEFORE UPDATE ON public.staff_leaves FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_library_books_updated_at BEFORE UPDATE ON public.library_books FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_library_issues_updated_at BEFORE UPDATE ON public.library_issues FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_library_fines_updated_at BEFORE UPDATE ON public.library_fines FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_behavioral_logs_updated_at BEFORE UPDATE ON public.behavioral_logs FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();

CREATE TRIGGER trigger_update_announcements_updated_at BEFORE UPDATE ON public.announcements FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_direct_messages_updated_at BEFORE UPDATE ON public.direct_messages FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_push_tokens_updated_at BEFORE UPDATE ON public.push_tokens FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();


-- =====================================================================
-- ENABLE ROW LEVEL SECURITY
-- =====================================================================
ALTER TABLE public.courses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.lessons ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.submissions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.live_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_types ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invoice_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bursaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_bursaries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_payroll ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.expenses ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.budgets ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_routes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_stops ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_students ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.bus_telemetry ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_learning_profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_orders ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.marketplace_order_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admissions_applications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.admissions_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grading_terms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessment_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.assessments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.grade_records ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.report_cards ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.daily_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_attendance ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_leaves ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_books ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_issues ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.library_fines ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.behavioral_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.direct_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.push_tokens ENABLE ROW LEVEL SECURITY;


-- =====================================================================
-- RLS POLICIES FOR MODULES
-- =====================================================================

-- General Policy Blueprint:
-- Super admin bypasses all.
-- School members must match school_id.
-- Parents can read data of their children across schools.

-- 1. LMS Modules
CREATE POLICY courses_select ON public.courses FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY courses_all ON public.courses FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY lessons_select ON public.lessons FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY lessons_all ON public.lessons FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY assignments_select ON public.assignments FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY assignments_all ON public.assignments FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY submissions_select ON public.submissions FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        -- Students can see their own submissions
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        -- Parents can view children submissions
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY submissions_write ON public.submissions FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );

-- 2. Live Classes
CREATE POLICY live_classes_select ON public.live_classes FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY live_classes_all ON public.live_classes FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY live_attendance_select ON public.live_attendance FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY live_attendance_all ON public.live_attendance FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

-- 3. Fees & Finance
CREATE POLICY fee_types_select ON public.fee_types FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY fee_types_all ON public.fee_types FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY invoices_select ON public.invoices FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY invoices_all ON public.invoices FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY invoice_items_select ON public.invoice_items FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR EXISTS (
            SELECT 1 FROM public.invoices i
            WHERE i.id = invoice_items.invoice_id
              AND (i.student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
              OR public.user_is_parent_of_student(i.student_profile_id, auth.uid()))
        )
    );
CREATE POLICY invoice_items_all ON public.invoice_items FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY payments_select ON public.payments FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR EXISTS (
            SELECT 1 FROM public.invoices i
            WHERE i.id = payments.invoice_id
              AND (i.student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
              OR public.user_is_parent_of_student(i.student_profile_id, auth.uid()))
        )
    );
CREATE POLICY payments_write ON public.payments FOR INSERT TO authenticated
    WITH CHECK (
        public.get_active_role() = 'super_admin'
        -- Allows students/parents to record payments
        OR (school_id = public.get_active_school_id() AND public.user_has_profile_in_school(school_id, auth.uid()))
    );

CREATE POLICY bursaries_select ON public.bursaries FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY bursaries_all ON public.bursaries FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY student_bursaries_select ON public.student_bursaries FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY student_bursaries_all ON public.student_bursaries FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY payroll_select ON public.staff_payroll FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR staff_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );
CREATE POLICY payroll_all ON public.staff_payroll FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY expenses_select ON public.expenses FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));
CREATE POLICY expenses_all ON public.expenses FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY budgets_select ON public.budgets FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));
CREATE POLICY budgets_all ON public.budgets FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

-- 4. Bus Tracking
CREATE POLICY bus_routes_select ON public.bus_routes FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY bus_routes_all ON public.bus_routes FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY bus_stops_select ON public.bus_stops FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY bus_stops_all ON public.bus_stops FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY bus_students_select ON public.bus_students FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY bus_students_all ON public.bus_students FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY telemetry_select ON public.bus_telemetry FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY telemetry_write ON public.bus_telemetry FOR INSERT TO authenticated
    WITH CHECK (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')) -- or driver role if added
    );

-- 5. AI Tutor
CREATE POLICY ai_sessions_select ON public.ai_sessions FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );
CREATE POLICY ai_sessions_write ON public.ai_sessions FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );

CREATE POLICY ai_messages_select ON public.ai_messages FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR EXISTS (
            SELECT 1 FROM public.ai_sessions s
            WHERE s.id = ai_messages.session_id
              AND s.student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        )
    );
CREATE POLICY ai_messages_write ON public.ai_messages FOR INSERT TO authenticated
    WITH CHECK (
        public.get_active_role() = 'super_admin'
        OR EXISTS (
            SELECT 1 FROM public.ai_sessions s
            WHERE s.id = ai_messages.session_id
              AND s.student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        )
    );

CREATE POLICY learning_profiles_select ON public.student_learning_profiles FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY learning_profiles_all ON public.student_learning_profiles FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
    );

-- 6. Marketplace (Fully Isolated by school_id)
CREATE POLICY marketplace_items_select ON public.marketplace_items FOR SELECT TO authenticated
    USING (school_id = public.get_active_school_id() AND status = 'available');
CREATE POLICY marketplace_items_all ON public.marketplace_items FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND seller_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL))
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

CREATE POLICY marketplace_orders_select ON public.marketplace_orders FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND buyer_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL))
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );
CREATE POLICY marketplace_orders_write ON public.marketplace_orders FOR INSERT TO authenticated
    WITH CHECK (school_id = public.get_active_school_id() AND public.user_has_profile_in_school(school_id, auth.uid()));

CREATE POLICY marketplace_order_items_select ON public.marketplace_order_items FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR EXISTS (
            SELECT 1 FROM public.marketplace_orders o
            WHERE o.id = marketplace_order_items.order_id
              AND o.school_id = public.get_active_school_id()
              AND (o.buyer_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
                   OR public.get_active_role() = 'school_admin')
        )
    );
CREATE POLICY marketplace_order_items_write ON public.marketplace_order_items FOR INSERT TO authenticated
    WITH CHECK (school_id = public.get_active_school_id() AND public.user_has_profile_in_school(school_id, auth.uid()));

-- 7. Admissions
CREATE POLICY applications_select ON public.admissions_applications FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR email = (SELECT email FROM auth.users WHERE id = auth.uid())
    );
CREATE POLICY applications_all ON public.admissions_applications FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

CREATE POLICY applications_insert ON public.admissions_applications FOR INSERT TO authenticated
    WITH CHECK (school_id = public.get_active_school_id());

CREATE POLICY admissions_documents_select ON public.admissions_documents FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR EXISTS (
            SELECT 1 FROM public.admissions_applications a
            WHERE a.id = admissions_documents.application_id
              AND a.email = (SELECT email FROM auth.users WHERE id = auth.uid())
        )
    );
CREATE POLICY admissions_documents_all ON public.admissions_documents FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

-- 8. Gradebook & Reports
CREATE POLICY grading_terms_select ON public.grading_terms FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY grading_terms_all ON public.grading_terms FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY categories_select ON public.assessment_categories FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY categories_all ON public.assessment_categories FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY assessments_select ON public.assessments FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY assessments_all ON public.assessments FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY grades_select ON public.grade_records FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY grades_all ON public.grade_records FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY report_cards_select ON public.report_cards FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY report_cards_all ON public.report_cards FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

-- 9. Leave & Attendance
CREATE POLICY daily_attendance_select ON public.daily_attendance FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY daily_attendance_all ON public.daily_attendance FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY staff_attendance_select ON public.staff_attendance FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR staff_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );
CREATE POLICY staff_attendance_all ON public.staff_attendance FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

CREATE POLICY staff_leaves_select ON public.staff_leaves FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR staff_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );
CREATE POLICY staff_leaves_all ON public.staff_leaves FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
        OR staff_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );

-- 10. Library
CREATE POLICY library_books_select ON public.library_books FOR SELECT TO authenticated
    USING (public.get_active_role() = 'super_admin' OR public.user_has_profile_in_school(school_id, auth.uid()));
CREATE POLICY library_books_all ON public.library_books FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY library_issues_select ON public.library_issues FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR borrower_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(borrower_profile_id, auth.uid())
    );
CREATE POLICY library_issues_all ON public.library_issues FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

CREATE POLICY library_fines_select ON public.library_fines FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR EXISTS (
            SELECT 1 FROM public.library_issues i
            WHERE i.id = library_fines.issue_id
              AND (i.borrower_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
                   OR public.user_is_parent_of_student(i.borrower_profile_id, auth.uid()))
        )
    );
CREATE POLICY library_fines_all ON public.library_fines FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin'));

-- 11. Behavioral Tracking
CREATE POLICY behavioral_logs_select ON public.behavioral_logs FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR public.user_is_parent_of_student(student_profile_id, auth.uid())
    );
CREATE POLICY behavioral_logs_all ON public.behavioral_logs FOR ALL TO authenticated
    USING (public.get_active_role() = 'super_admin' OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher')));

-- 12. Communication & Announcements
CREATE POLICY announcements_select ON public.announcements FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        -- Checks target role visibility
        OR (
            school_id = public.get_active_school_id()
            AND (
                target_role = 'all'
                OR target_role = public.get_active_role()::text
            )
        )
    );
CREATE POLICY announcements_all ON public.announcements FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
    );

CREATE POLICY messages_select ON public.direct_messages FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR sender_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        OR recipient_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );
CREATE POLICY messages_write ON public.direct_messages FOR INSERT TO authenticated
    WITH CHECK (
        sender_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );

CREATE POLICY push_tokens_select ON public.push_tokens FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );
CREATE POLICY push_tokens_all ON public.push_tokens FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );
