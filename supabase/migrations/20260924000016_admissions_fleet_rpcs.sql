-- ZivoConnect live backend reconciliation: admissions and fleet RPCs.

CREATE OR REPLACE FUNCTION public.get_admissions_pipeline()
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT jsonb_build_object(
    'new',(SELECT count(*) FROM public.admissions_applications WHERE school_id=sid AND deleted_at IS NULL AND status='applied'),
    'under_review',(SELECT count(*) FROM public.admissions_applications WHERE school_id=sid AND deleted_at IS NULL AND status IN ('review','info_requested')),
    'accepted',(SELECT count(*) FROM public.admissions_applications WHERE school_id=sid AND deleted_at IS NULL AND status='accepted' AND enrolled_student_profile_id IS NULL),
    'waitlisted',(SELECT count(*) FROM public.admissions_applications WHERE school_id=sid AND deleted_at IS NULL AND status='waitlisted'),
    'applications',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.created_at DESC) FROM (
      SELECT a.id,trim(concat_ws(' ',a.first_name,a.last_name)) applicant_name,a.status,a.created_at,a.updated_at,a.requested_class_id,
             c.name requested_class,a.requested_academic_year_id,a.parent_name,a.parent_email,a.parent_phone,a.previous_school,
             a.review_notes,a.reviewed_at,a.decision_at,a.enrolled_student_profile_id,
             (SELECT count(*) FROM public.admissions_documents d WHERE d.application_id=a.id AND d.deleted_at IS NULL) document_count,
             CASE WHEN a.status='applied' THEN 'new' WHEN a.status IN ('review','info_requested') THEN 'under_review'
                  WHEN a.status='accepted' AND a.enrolled_student_profile_id IS NULL THEN 'accepted'
                  WHEN a.status='accepted' AND a.enrolled_student_profile_id IS NOT NULL THEN 'enrolled' ELSE a.status END display_status
      FROM public.admissions_applications a
      LEFT JOIN public.classes c ON c.id=a.requested_class_id AND c.deleted_at IS NULL
      WHERE a.school_id=sid AND a.deleted_at IS NULL ORDER BY a.created_at DESC LIMIT 200
    ) x),'[]'::jsonb)
  ) INTO result;
  RETURN result;
END; $$;

CREATE OR REPLACE FUNCTION public.set_admission_status(p_application_id uuid,p_status text,p_review_notes text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); current_status text; enrolled_id uuid; saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('applied','review','info_requested','accepted','waitlisted','rejected') THEN RAISE EXCEPTION 'invalid admission status'; END IF;
  SELECT status,enrolled_student_profile_id INTO current_status,enrolled_id FROM public.admissions_applications
  WHERE id=p_application_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid) FOR UPDATE;
  IF current_status IS NULL THEN RAISE EXCEPTION 'application not found or not authorized'; END IF;
  IF enrolled_id IS NOT NULL AND p_status<>'accepted' THEN RAISE EXCEPTION 'an enrolled application cannot be moved out of accepted status'; END IF;
  UPDATE public.admissions_applications SET status=p_status,review_notes=COALESCE(p_review_notes,review_notes),reviewed_by_profile_id=public.get_active_profile_id(),
    reviewed_at=CASE WHEN p_status IN ('review','info_requested','waitlisted') THEN now() ELSE reviewed_at END,
    decision_at=CASE WHEN p_status IN ('accepted','rejected') THEN now() WHEN p_status NOT IN ('accepted','rejected') THEN NULL ELSE decision_at END,
    updated_at=now() WHERE id=p_application_id RETURNING to_jsonb(public.admissions_applications.*) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.link_admission_to_enrolled_student(p_application_id uuid,p_student_profile_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); app_school uuid; student_school uuid; app_status text; saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT school_id,status INTO app_school,app_status FROM public.admissions_applications
  WHERE id=p_application_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid) FOR UPDATE;
  IF app_school IS NULL THEN RAISE EXCEPTION 'application not found or not authorized'; END IF;
  IF app_status<>'accepted' THEN RAISE EXCEPTION 'application must be accepted before enrollment can be linked'; END IF;
  SELECT school_id INTO student_school FROM public.profiles WHERE id=p_student_profile_id AND role='student'::public.app_role AND deleted_at IS NULL;
  IF student_school IS NULL OR student_school<>app_school THEN RAISE EXCEPTION 'student profile does not belong to the application school'; END IF;
  UPDATE public.admissions_applications SET enrolled_student_profile_id=p_student_profile_id,decision_at=COALESCE(decision_at,now()),
    reviewed_by_profile_id=COALESCE(reviewed_by_profile_id,public.get_active_profile_id()),reviewed_at=COALESCE(reviewed_at,now()),updated_at=now()
  WHERE id=p_application_id RETURNING to_jsonb(public.admissions_applications.*) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.get_fleet_dashboard()
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  WITH latest AS (
    SELECT DISTINCT ON (bt.route_id) bt.route_id,bt.latitude,bt.longitude,bt.speed,bt.heading,bt.accuracy_meters,bt.recorded_at
    FROM public.bus_telemetry bt WHERE bt.school_id=sid AND bt.deleted_at IS NULL ORDER BY bt.route_id,bt.recorded_at DESC
  ), vehicles AS (
    SELECT br.id route_id,br.route_name,br.vehicle_number,br.driver_name,br.driver_phone,br.driver_profile_id,br.capacity,br.status route_status,
           l.latitude,l.longitude,l.speed,l.heading,l.accuracy_meters,l.recorded_at,EXTRACT(EPOCH FROM (now()-l.recorded_at))/60.0 minutes_since_update,
           CASE WHEN br.status<>'active' THEN br.status WHEN l.recorded_at IS NULL OR l.recorded_at<now()-interval '10 minutes' THEN 'stale'
                WHEN COALESCE(l.speed,0)>1 THEN 'moving' ELSE 'stopped' END telemetry_status,
           (SELECT count(*) FROM public.bus_students bs WHERE bs.route_id=br.id AND bs.deleted_at IS NULL) assigned_students
    FROM public.bus_routes br LEFT JOIN latest l ON l.route_id=br.id WHERE br.school_id=sid AND br.deleted_at IS NULL
  )
  SELECT jsonb_build_object(
    'active_buses',(SELECT count(*) FROM vehicles WHERE route_status='active'),
    'moving',(SELECT count(*) FROM vehicles WHERE route_status='active' AND telemetry_status='moving'),
    'stopped',(SELECT count(*) FROM vehicles WHERE route_status='active' AND telemetry_status='stopped'),
    'stale',(SELECT count(*) FROM vehicles WHERE route_status='active' AND telemetry_status='stale'),
    'routes',(SELECT count(*) FROM public.bus_routes WHERE school_id=sid AND deleted_at IS NULL AND status='active'),
    'students_assigned',(SELECT count(*) FROM public.bus_students WHERE school_id=sid AND deleted_at IS NULL),
    'attention',(SELECT count(*) FROM vehicles WHERE route_status='active' AND telemetry_status='stale'),
    'vehicles',COALESCE((SELECT jsonb_agg(jsonb_build_object('route_id',v.route_id,'route_name',v.route_name,'vehicle_number',v.vehicle_number,
      'driver_name',v.driver_name,'driver_phone',v.driver_phone,'capacity',v.capacity,'assigned_students',v.assigned_students,'status',v.telemetry_status,
      'latitude',v.latitude,'longitude',v.longitude,'speed',v.speed,'heading',v.heading,'accuracy_meters',v.accuracy_meters,'recorded_at',v.recorded_at,
      'minutes_since_update',CASE WHEN v.minutes_since_update IS NULL THEN NULL ELSE round(v.minutes_since_update::numeric,1) END) ORDER BY v.route_name) FROM vehicles v),'[]'::jsonb)
  ) INTO result;
  RETURN result;
END; $$;
