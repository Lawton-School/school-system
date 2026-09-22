-- 1. Schools Table (Tenants)
CREATE TABLE public.schools (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    name text NOT NULL,
    subdomain text UNIQUE NOT NULL,
    settings jsonb NOT NULL DEFAULT '{}'::jsonb,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'suspended')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- 2. Profiles Table (Users)
CREATE TABLE public.profiles (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id uuid REFERENCES auth.users(id) ON DELETE CASCADE,
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    role public.app_role NOT NULL,
    first_name text NOT NULL,
    last_name text NOT NULL,
    email text,
    phone text,
    avatar_url text,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'inactive', 'suspended')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_user_school_role UNIQUE (user_id, school_id, role)
);

-- 3. User Relationships Table (Parent-Student links)
CREATE TABLE public.user_relationships (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    parent_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    student_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    relationship_type text NOT NULL CHECK (relationship_type IN ('father', 'mother', 'guardian', 'other')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_parent_student_relationship UNIQUE (parent_id, student_id)
);

-- 4. Academic Years Table
CREATE TABLE public.academic_years (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL, -- e.g., "2026-2027"
    start_date date NOT NULL,
    end_date date NOT NULL,
    is_current boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT start_before_end CHECK (start_date < end_date)
);

-- 5. Classes Table
CREATE TABLE public.classes (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL, -- e.g., "Grade 10"
    academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE CASCADE NOT NULL,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- 6. Class Sections Table
CREATE TABLE public.class_sections (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    class_id uuid REFERENCES public.classes(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL, -- e.g., "Section A"
    room text,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- 7. Subjects Table
CREATE TABLE public.subjects (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    name text NOT NULL, -- e.g., "Mathematics"
    code text, -- e.g., "MATH101"
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- 8. Class Teachers Table
CREATE TABLE public.class_teachers (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE NOT NULL,
    teacher_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    subject_id uuid REFERENCES public.subjects(id) ON DELETE CASCADE,
    is_primary_homeroom_teacher boolean NOT NULL DEFAULT false,
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz
);

-- 9. Student Enrollments Table
CREATE TABLE public.student_enrollments (
    id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    school_id uuid REFERENCES public.schools(id) ON DELETE CASCADE NOT NULL,
    student_profile_id uuid REFERENCES public.profiles(id) ON DELETE CASCADE NOT NULL,
    class_section_id uuid REFERENCES public.class_sections(id) ON DELETE CASCADE NOT NULL,
    academic_year_id uuid REFERENCES public.academic_years(id) ON DELETE CASCADE NOT NULL,
    roll_number text,
    status text NOT NULL DEFAULT 'active' CHECK (status IN ('active', 'withdrawn', 'suspended', 'graduated')),
    created_at timestamptz NOT NULL DEFAULT now(),
    updated_at timestamptz NOT NULL DEFAULT now(),
    deleted_at timestamptz,
    CONSTRAINT unique_student_enrollment_per_year UNIQUE (student_profile_id, academic_year_id)
);

-- Apply automatic updated_at triggers to all core tables
CREATE TRIGGER trigger_update_schools_updated_at BEFORE UPDATE ON public.schools FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_profiles_updated_at BEFORE UPDATE ON public.profiles FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_user_relationships_updated_at BEFORE UPDATE ON public.user_relationships FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_academic_years_updated_at BEFORE UPDATE ON public.academic_years FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_classes_updated_at BEFORE UPDATE ON public.classes FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_class_sections_updated_at BEFORE UPDATE ON public.class_sections FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_subjects_updated_at BEFORE UPDATE ON public.subjects FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_class_teachers_updated_at BEFORE UPDATE ON public.class_teachers FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
CREATE TRIGGER trigger_update_student_enrollments_updated_at BEFORE UPDATE ON public.student_enrollments FOR EACH ROW EXECUTE FUNCTION public.update_updated_at_column();
