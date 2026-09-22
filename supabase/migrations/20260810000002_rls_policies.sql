-- 1. Create RLS Helper Functions
CREATE OR REPLACE FUNCTION public.get_active_school_id()
RETURNS uuid AS $$
DECLARE
    _school_id uuid;
BEGIN
    -- Read from JWT app_metadata first (populated via custom claims or hook)
    _school_id := (auth.jwt() -> 'app_metadata' ->> 'school_id')::uuid;
    
    -- Fallback: query database for first profile associated with this user
    IF _school_id IS NULL AND auth.uid() IS NOT NULL THEN
        SELECT school_id INTO _school_id
        FROM public.profiles
        WHERE user_id = auth.uid() AND deleted_at IS NULL
        LIMIT 1;
    END IF;
    
    RETURN _school_id;
END;
$$ LANGUAGE plpgsql STABLE SECURITY DEFINER;

CREATE OR REPLACE FUNCTION public.get_active_role()
RETURNS public.app_role AS $$
DECLARE
    _role public.app_role;
    _school_id uuid;
BEGIN
    -- Read from JWT app_metadata first (populated via custom claims or hook)
    _role := (auth.jwt() -> 'app_metadata' ->> 'role')::public.app_role;
    
    -- Fallback: query profiles based on active school
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

-- Helper to check if a user has a profile in a school
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


-- 2. Enable RLS on all tables
ALTER TABLE public.schools ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.profiles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_relationships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.academic_years ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.classes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_sections ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.subjects ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.class_teachers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.student_enrollments ENABLE ROW LEVEL SECURITY;


-- 3. RLS Policies

-- ==================== SCHOOLS ====================
CREATE POLICY schools_select ON public.schools
    FOR SELECT TO authenticated
    USING (
        id = public.get_active_school_id() 
        OR public.get_active_role() = 'super_admin'
        -- Allows reading metadata of any school where the user has a profile
        OR public.user_has_profile_in_school(id, auth.uid())
    );

CREATE POLICY schools_insert ON public.schools
    FOR INSERT TO authenticated
    WITH CHECK (public.get_active_role() = 'super_admin');

CREATE POLICY schools_update ON public.schools
    FOR UPDATE TO authenticated
    USING (
        public.get_active_role() = 'super_admin' 
        OR (id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

CREATE POLICY schools_delete ON public.schools
    FOR DELETE TO authenticated
    USING (public.get_active_role() = 'super_admin');


-- ==================== PROFILES ====================
CREATE POLICY profiles_select ON public.profiles
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        -- Own profile
        OR user_id = auth.uid()
        -- Direct visibility within active school for members
        OR (school_id = public.get_active_school_id() AND public.user_has_profile_in_school(school_id, auth.uid()))
        -- Parent querying children's profiles across schools
        OR id IN (
            SELECT student_id 
            FROM public.user_relationships 
            WHERE parent_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
              AND deleted_at IS NULL
        )
    );

CREATE POLICY profiles_insert ON public.profiles
    FOR INSERT TO authenticated
    WITH CHECK (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

CREATE POLICY profiles_update ON public.profiles
    FOR UPDATE TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR user_id = auth.uid() -- Can update self
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

CREATE POLICY profiles_delete ON public.profiles
    FOR DELETE TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );


-- ==================== USER RELATIONSHIPS ====================
CREATE POLICY relationships_select ON public.user_relationships
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        -- Parent can view their own relationships
        OR parent_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        -- Student can view their own relationships
        OR student_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
    );

CREATE POLICY relationships_insert ON public.user_relationships
    FOR INSERT TO authenticated
    WITH CHECK (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

CREATE POLICY relationships_update ON public.user_relationships
    FOR UPDATE TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

CREATE POLICY relationships_delete ON public.user_relationships
    FOR DELETE TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );


-- ==================== METADATA & ACADEMIC STRUCTURES ====================
-- Applies to: academic_years, classes, class_sections, subjects, class_teachers
-- Readable by school admin, teachers, students, parents associated with the school.

-- Academic Years
CREATE POLICY academic_years_select ON public.academic_years
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR public.user_has_profile_in_school(school_id, auth.uid())
    );

CREATE POLICY academic_years_all ON public.academic_years
    FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

-- Classes
CREATE POLICY classes_select ON public.classes
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR public.user_has_profile_in_school(school_id, auth.uid())
    );

CREATE POLICY classes_all ON public.classes
    FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

-- Class Sections
CREATE POLICY class_sections_select ON public.class_sections
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR public.user_has_profile_in_school(school_id, auth.uid())
    );

CREATE POLICY class_sections_all ON public.class_sections
    FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

-- Subjects
CREATE POLICY subjects_select ON public.subjects
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR public.user_has_profile_in_school(school_id, auth.uid())
    );

CREATE POLICY subjects_all ON public.subjects
    FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );

-- Class Teachers
CREATE POLICY class_teachers_select ON public.class_teachers
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR public.user_has_profile_in_school(school_id, auth.uid())
    );

CREATE POLICY class_teachers_all ON public.class_teachers
    FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );


-- ==================== STUDENT ENROLLMENTS ====================
CREATE POLICY enrollments_select ON public.student_enrollments
    FOR SELECT TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        -- School members with active profile can read enrollments in their school
        OR (school_id = public.get_active_school_id() AND public.get_active_role() IN ('school_admin', 'teacher'))
        -- Student reading their own enrollment
        OR student_profile_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
        -- Parent reading child's enrollment
        OR student_profile_id IN (
            SELECT student_id 
            FROM public.user_relationships 
            WHERE parent_id IN (SELECT id FROM public.profiles WHERE user_id = auth.uid() AND deleted_at IS NULL)
              AND deleted_at IS NULL
        )
    );

CREATE POLICY enrollments_all ON public.student_enrollments
    FOR ALL TO authenticated
    USING (
        public.get_active_role() = 'super_admin'
        OR (school_id = public.get_active_school_id() AND public.get_active_role() = 'school_admin')
    );
