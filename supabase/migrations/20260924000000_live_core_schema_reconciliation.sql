-- ZivoConnect live backend reconciliation: core schema additions
-- Captures structures already present in production as of 2026-09-24.
-- This migration is designed to replay after the original 20260810 baseline.

-- -----------------------------------------------------------------------------
-- Roles added after the original baseline
-- -----------------------------------------------------------------------------
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'finance_manager';
ALTER TYPE public.app_role ADD VALUE IF NOT EXISTS 'registrar';

-- -----------------------------------------------------------------------------
-- School/tenant metadata added after the original baseline
-- -----------------------------------------------------------------------------
ALTER TABLE public.schools
  ADD COLUMN IF NOT EXISTS legal_name text,
  ADD COLUMN IF NOT EXISTS registration_number text,
  ADD COLUMN IF NOT EXISTS contact_email text,
  ADD COLUMN IF NOT EXISTS contact_phone text,
  ADD COLUMN IF NOT EXISTS address_line1 text,
  ADD COLUMN IF NOT EXISTS address_line2 text,
  ADD COLUMN IF NOT EXISTS city text,
  ADD COLUMN IF NOT EXISTS province text,
  ADD COLUMN IF NOT EXISTS country_code text NOT NULL DEFAULT 'ZW',
  ADD COLUMN IF NOT EXISTS timezone text NOT NULL DEFAULT 'Africa/Harare',
  ADD COLUMN IF NOT EXISTS default_currency text NOT NULL DEFAULT 'USD',
  ADD COLUMN IF NOT EXISTS logo_url text,
  ADD COLUMN IF NOT EXISTS website_url text,
  ADD COLUMN IF NOT EXISTS plan_code text NOT NULL DEFAULT 'starter',
  ADD COLUMN IF NOT EXISTS subscription_status text NOT NULL DEFAULT 'trial',
  ADD COLUMN IF NOT EXISTS trial_ends_at timestamptz,
  ADD COLUMN IF NOT EXISTS current_period_ends_at timestamptz;

DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_constraint
    WHERE conrelid = 'public.schools'::regclass
      AND conname = 'schools_subscription_status_check'
  ) THEN
    ALTER TABLE public.schools
      ADD CONSTRAINT schools_subscription_status_check
      CHECK (subscription_status IN ('trial','active','past_due','suspended','cancelled'));
  END IF;
END $$;

-- -----------------------------------------------------------------------------
-- Student/staff detail extensions
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.student_details (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  admission_number text,
  date_of_birth date,
  gender text CHECK (gender IS NULL OR gender IN ('female','male','other','prefer_not_to_say')),
  admission_date date,
  curriculum text,
  campus text,
  house text,
  nationality text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT student_details_student_unique UNIQUE (student_profile_id),
  CONSTRAINT student_details_admission_unique UNIQUE (school_id, admission_number)
);

CREATE TABLE IF NOT EXISTS public.staff_details (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  staff_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  employee_number text,
  job_title text,
  department text,
  employment_type text CHECK (
    employment_type IS NULL OR employment_type IN ('full_time','part_time','contract','temporary','other')
  ),
  hired_at date,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT staff_details_profile_unique UNIQUE (staff_profile_id),
  CONSTRAINT staff_details_employee_unique UNIQUE (school_id, employee_number)
);

CREATE TABLE IF NOT EXISTS public.student_documents (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  student_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category text NOT NULL,
  file_name text NOT NULL,
  file_url text NOT NULL,
  mime_type text,
  file_size_bytes bigint,
  uploaded_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  verification_status text NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending','verified','rejected')),
  verified_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  verified_at timestamptz,
  visibility text NOT NULL DEFAULT 'admin'
    CHECK (visibility IN ('admin','guardian','student','staff')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

-- -----------------------------------------------------------------------------
-- Timetable / activity
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.timetable_entries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
  class_section_id uuid NOT NULL REFERENCES public.class_sections(id) ON DELETE CASCADE,
  subject_id uuid NOT NULL REFERENCES public.subjects(id) ON DELETE CASCADE,
  teacher_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  day_of_week smallint NOT NULL CHECK (day_of_week BETWEEN 1 AND 7),
  start_time time NOT NULL,
  end_time time NOT NULL,
  room text,
  effective_from date,
  effective_to date,
  is_active boolean NOT NULL DEFAULT true,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT timetable_time_check CHECK (start_time < end_time)
);

CREATE TABLE IF NOT EXISTS public.activity_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  actor_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  subject_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE,
  event_type text NOT NULL,
  title text NOT NULL,
  description text,
  source_table text,
  source_id uuid,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb,
  occurred_at timestamptz NOT NULL DEFAULT now(),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.profile_activity (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  last_active_at timestamptz NOT NULL DEFAULT now(),
  platform text,
  app_version text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT profile_activity_profile_unique UNIQUE (profile_id)
);

-- -----------------------------------------------------------------------------
-- Finance structure added after the original baseline
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.fee_structures (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  academic_year_id uuid NOT NULL REFERENCES public.academic_years(id) ON DELETE CASCADE,
  term_id uuid REFERENCES public.grading_terms(id) ON DELETE SET NULL,
  class_id uuid REFERENCES public.classes(id) ON DELETE CASCADE,
  class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE,
  name text NOT NULL,
  currency text NOT NULL DEFAULT 'USD',
  default_due_date date,
  status text NOT NULL DEFAULT 'draft' CHECK (status IN ('draft','active','archived')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.fee_structure_items (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  fee_structure_id uuid NOT NULL REFERENCES public.fee_structures(id) ON DELETE CASCADE,
  fee_type_id uuid NOT NULL REFERENCES public.fee_types(id) ON DELETE RESTRICT,
  amount numeric NOT NULL CHECK (amount >= 0),
  is_required boolean NOT NULL DEFAULT true,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT fee_structure_items_unique UNIQUE (fee_structure_id, fee_type_id)
);

CREATE TABLE IF NOT EXISTS public.school_payment_methods (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  code text NOT NULL,
  display_name text NOT NULL,
  is_enabled boolean NOT NULL DEFAULT true,
  public_config jsonb NOT NULL DEFAULT '{}'::jsonb,
  sort_order integer NOT NULL DEFAULT 0,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT school_payment_methods_unique UNIQUE (school_id, code)
);

CREATE TABLE IF NOT EXISTS public.payroll_runs (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  period_start date NOT NULL,
  period_end date NOT NULL,
  payment_date date,
  status text NOT NULL DEFAULT 'draft'
    CHECK (status IN ('draft','processing','processed','cancelled')),
  created_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  processed_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  processed_at timestamptz,
  notes text,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT payroll_runs_period_check CHECK (period_start <= period_end)
);

-- -----------------------------------------------------------------------------
-- Notifications / communication support
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.notifications (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  recipient_profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  category text NOT NULL,
  title text NOT NULL,
  body text,
  priority text NOT NULL DEFAULT 'normal' CHECK (priority IN ('normal','high','urgent')),
  data jsonb NOT NULL DEFAULT '{}'::jsonb,
  action_path text,
  source_table text,
  source_id uuid,
  read_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

CREATE TABLE IF NOT EXISTS public.notification_preferences (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  preferences jsonb NOT NULL DEFAULT '{"push":true,"finance":true,"messages":true,"academics":true,"transport":true,"attendance":true,"announcements":true}'::jsonb,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT notification_preferences_profile_unique UNIQUE (profile_id)
);

CREATE TABLE IF NOT EXISTS public.notification_deliveries (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  notification_id uuid NOT NULL REFERENCES public.notifications(id) ON DELETE CASCADE,
  channel text NOT NULL CHECK (channel IN ('push','email')),
  status text NOT NULL DEFAULT 'queued' CHECK (status IN ('queued','sent','failed','skipped')),
  provider_message_id text,
  last_error text,
  attempted_at timestamptz,
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz
);

-- -----------------------------------------------------------------------------
-- School calendar
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.school_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  title text NOT NULL,
  description text,
  start_at timestamptz NOT NULL,
  end_at timestamptz,
  location text,
  audience text NOT NULL DEFAULT 'all'
    CHECK (audience IN ('all','staff','teachers','parents','students','school_admins')),
  class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE,
  created_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  status text NOT NULL DEFAULT 'published' CHECK (status IN ('draft','published','cancelled')),
  created_at timestamptz NOT NULL DEFAULT now(),
  updated_at timestamptz NOT NULL DEFAULT now(),
  deleted_at timestamptz,
  CONSTRAINT school_events_time_check CHECK (end_at IS NULL OR start_at <= end_at)
);

-- -----------------------------------------------------------------------------
-- AI usage audit / rate-limit support
-- -----------------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS public.ai_usage_events (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  school_id uuid NOT NULL REFERENCES public.schools(id) ON DELETE CASCADE,
  profile_id uuid NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  role public.app_role NOT NULL,
  mode text NOT NULL,
  model text NOT NULL,
  input_chars integer NOT NULL DEFAULT 0 CHECK (input_chars >= 0),
  output_chars integer NOT NULL DEFAULT 0 CHECK (output_chars >= 0),
  prompt_tokens integer CHECK (prompt_tokens IS NULL OR prompt_tokens >= 0),
  completion_tokens integer CHECK (completion_tokens IS NULL OR completion_tokens >= 0),
  total_tokens integer CHECK (total_tokens IS NULL OR total_tokens >= 0),
  status text NOT NULL DEFAULT 'started'
    CHECK (status IN ('started','succeeded','failed','rate_limited')),
  provider_status integer,
  created_at timestamptz NOT NULL DEFAULT now(),
  completed_at timestamptz,
  metadata jsonb NOT NULL DEFAULT '{}'::jsonb
);

-- -----------------------------------------------------------------------------
-- RLS is enabled immediately; policies are reconciled in the following migration.
-- -----------------------------------------------------------------------------
ALTER TABLE public.student_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.staff_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.timetable_entries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activity_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profile_activity ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_structures ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.fee_structure_items ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_payment_methods ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.payroll_runs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.notification_deliveries ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.school_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.ai_usage_events ENABLE ROW LEVEL SECURITY;

-- -----------------------------------------------------------------------------
-- Live indexes that materially define uniqueness / hot paths.
-- -----------------------------------------------------------------------------
CREATE INDEX IF NOT EXISTS idx_student_details_tenant_sync
  ON public.student_details (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_student_details_deleted_sync
  ON public.student_details (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_staff_details_tenant_sync
  ON public.staff_details (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_staff_details_deleted_sync
  ON public.staff_details (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_student_documents_student
  ON public.student_documents (student_profile_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_student_documents_tenant_sync
  ON public.student_documents (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_student_documents_deleted_sync
  ON public.student_documents (updated_at) WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_timetable_lookup
  ON public.timetable_entries (school_id, class_section_id, day_of_week, start_time)
  WHERE deleted_at IS NULL AND is_active = true;
CREATE INDEX IF NOT EXISTS idx_timetable_tenant_sync
  ON public.timetable_entries (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_timetable_deleted_sync
  ON public.timetable_entries (updated_at) WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_activity_school
  ON public.activity_events (school_id, occurred_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_activity_subject
  ON public.activity_events (subject_profile_id, occurred_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_activity_events_actor
  ON public.activity_events (actor_profile_id)
  WHERE deleted_at IS NULL AND actor_profile_id IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_activity_tenant_sync
  ON public.activity_events (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_activity_deleted_sync
  ON public.activity_events (updated_at) WHERE deleted_at IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_activity_source_event_unique
  ON public.activity_events (source_table, source_id, event_type)
  WHERE deleted_at IS NULL AND source_table IS NOT NULL AND source_id IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_profile_activity_last_active
  ON public.profile_activity (last_active_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_profile_activity_school_active
  ON public.profile_activity (school_id, last_active_at DESC) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_fee_structures_tenant_sync
  ON public.fee_structures (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_fee_structures_deleted_sync
  ON public.fee_structures (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_fee_structure_items_tenant_sync
  ON public.fee_structure_items (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_fee_structure_items_deleted_sync
  ON public.fee_structure_items (updated_at) WHERE deleted_at IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_payment_methods_tenant_sync
  ON public.school_payment_methods (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_payroll_runs_tenant_sync
  ON public.payroll_runs (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_payroll_runs_deleted_sync
  ON public.payroll_runs (updated_at) WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_notifications_recipient
  ON public.notifications (recipient_profile_id, created_at DESC) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_unread
  ON public.notifications (recipient_profile_id, created_at DESC)
  WHERE deleted_at IS NULL AND read_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_tenant_sync
  ON public.notifications (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_notifications_deleted_sync
  ON public.notifications (updated_at) WHERE deleted_at IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_notifications_source_once
  ON public.notifications (recipient_profile_id, source_table, source_id)
  WHERE deleted_at IS NULL AND source_table IS NOT NULL AND source_id IS NOT NULL;
CREATE UNIQUE INDEX IF NOT EXISTS idx_notification_preferences_active_profile_unique
  ON public.notification_preferences (profile_id) WHERE deleted_at IS NULL;

CREATE INDEX IF NOT EXISTS idx_school_events_time
  ON public.school_events (school_id, start_at)
  WHERE deleted_at IS NULL AND status = 'published';
CREATE INDEX IF NOT EXISTS idx_school_events_tenant_sync
  ON public.school_events (school_id, updated_at) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_school_events_deleted_sync
  ON public.school_events (updated_at) WHERE deleted_at IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ai_usage_profile_created
  ON public.ai_usage_events (profile_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_school_created
  ON public.ai_usage_events (school_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_ai_usage_status_created
  ON public.ai_usage_events (status, created_at DESC);

-- -----------------------------------------------------------------------------
-- Keep updated_at behavior consistent with production.
-- -----------------------------------------------------------------------------
DO $$
DECLARE
  t text;
BEGIN
  FOREACH t IN ARRAY ARRAY[
    'student_details','staff_details','student_documents','timetable_entries',
    'activity_events','profile_activity','fee_structures','fee_structure_items',
    'school_payment_methods','payroll_runs','notifications','notification_preferences',
    'notification_deliveries','school_events'
  ]
  LOOP
    EXECUTE format('DROP TRIGGER IF EXISTS trigger_update_%I_updated_at ON public.%I', t, t);
    EXECUTE format(
      'CREATE TRIGGER trigger_update_%I_updated_at BEFORE UPDATE ON public.%I FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column()',
      t, t
    );
  END LOOP;
END $$;
