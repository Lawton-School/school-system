-- ZivoConnect live backend reconciliation: admissions/fleet extensions added after the original baseline.

ALTER TABLE public.admissions_applications
  ADD COLUMN IF NOT EXISTS requested_class_id uuid REFERENCES public.classes(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS requested_academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS parent_email text,
  ADD COLUMN IF NOT EXISTS parent_phone text,
  ADD COLUMN IF NOT EXISTS previous_school text,
  ADD COLUMN IF NOT EXISTS review_notes text,
  ADD COLUMN IF NOT EXISTS reviewed_by_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS reviewed_at timestamptz,
  ADD COLUMN IF NOT EXISTS decision_at timestamptz,
  ADD COLUMN IF NOT EXISTS enrolled_student_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL;

ALTER TABLE public.admissions_applications DROP CONSTRAINT IF EXISTS admissions_applications_status_check;
ALTER TABLE public.admissions_applications
  ADD CONSTRAINT admissions_applications_status_check
  CHECK (status IN ('applied','review','info_requested','accepted','waitlisted','rejected'));

ALTER TABLE public.bus_routes
  ADD COLUMN IF NOT EXISTS driver_profile_id uuid REFERENCES public.profiles(id) ON DELETE SET NULL,
  ADD COLUMN IF NOT EXISTS capacity integer,
  ADD COLUMN IF NOT EXISTS status text NOT NULL DEFAULT 'active';
ALTER TABLE public.bus_routes DROP CONSTRAINT IF EXISTS bus_routes_capacity_check;
ALTER TABLE public.bus_routes ADD CONSTRAINT bus_routes_capacity_check CHECK (capacity IS NULL OR capacity>0);
ALTER TABLE public.bus_routes DROP CONSTRAINT IF EXISTS bus_routes_status_check;
ALTER TABLE public.bus_routes ADD CONSTRAINT bus_routes_status_check CHECK (status IN ('active','inactive','maintenance'));

ALTER TABLE public.bus_telemetry
  ADD COLUMN IF NOT EXISTS heading numeric,
  ADD COLUMN IF NOT EXISTS accuracy_meters numeric,
  ADD COLUMN IF NOT EXISTS source text;

-- Preserve the exact production constraint for Phase 1 reconciliation.
-- NOTE: register_push_token() currently accepts desktop platforms as well; this
-- mismatch is intentionally documented and not silently changed here.
ALTER TABLE public.push_tokens DROP CONSTRAINT IF EXISTS push_tokens_platform_check;
ALTER TABLE public.push_tokens
  ADD CONSTRAINT push_tokens_platform_check CHECK (platform IN ('ios','android','web'));
