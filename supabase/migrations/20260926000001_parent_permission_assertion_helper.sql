CREATE OR REPLACE FUNCTION public.parent_can_access_module(p_student_profile_id uuid,p_module text)
RETURNS boolean LANGUAGE sql STABLE SET search_path='public' AS $$
 SELECT CASE
   WHEN public.get_active_role()::text='parent'
   THEN public.parent_has_student_permission(public.get_active_profile_id(),p_student_profile_id,p_module)
   ELSE true
 END;
$$;

CREATE OR REPLACE FUNCTION public.assert_parent_student_permission(p_student_profile_id uuid,p_permission text)
RETURNS void LANGUAGE plpgsql STABLE SET search_path='public' AS $$
BEGIN
 IF public.get_active_role()::text='parent'
 AND NOT public.parent_has_student_permission(public.get_active_profile_id(),p_student_profile_id,p_permission)
 THEN RAISE EXCEPTION 'not authorized for %',p_permission USING ERRCODE='42501';
 END IF;
END $$;

REVOKE ALL ON FUNCTION public.assert_parent_student_permission(uuid,text) FROM PUBLIC,anon;
GRANT EXECUTE ON FUNCTION public.assert_parent_student_permission(uuid,text) TO authenticated;
