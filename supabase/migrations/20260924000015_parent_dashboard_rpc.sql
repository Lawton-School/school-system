-- ZivoConnect live backend reconciliation: Parent Dashboard RPC.

CREATE OR REPLACE FUNCTION public.get_parent_dashboard(p_student_profile_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid;
  ay_id uuid;
  section_id uuid;
  tz text;
  local_date date;
  local_time time;
  base jsonb;
  result jsonb;
BEGIN
  IF role_name NOT IN ('parent','student','school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT school_id INTO sid FROM public.profiles
  WHERE id=p_student_profile_id AND role='student'::public.app_role AND deleted_at IS NULL;
  IF sid IS NULL THEN RAISE EXCEPTION 'student not found or not authorized'; END IF;

  IF role_name='parent' AND NOT public.user_is_parent_of_student(p_student_profile_id,auth.uid()) THEN
    RAISE EXCEPTION 'not authorized';
  END IF;
  IF role_name='student' AND p_student_profile_id<>public.get_active_profile_id() THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT COALESCE(timezone,'Africa/Harare') INTO tz FROM public.schools WHERE id=sid;
  local_date:=(now() AT TIME ZONE tz)::date;
  local_time:=(now() AT TIME ZONE tz)::time;

  SELECT id INTO ay_id FROM public.academic_years
  WHERE school_id=sid AND is_current=true AND deleted_at IS NULL
  ORDER BY start_date DESC LIMIT 1;

  SELECT se.class_section_id INTO section_id
  FROM public.student_enrollments se
  WHERE se.student_profile_id=p_student_profile_id AND se.academic_year_id=ay_id
    AND se.status='active' AND se.deleted_at IS NULL
  ORDER BY se.updated_at DESC LIMIT 1;

  base:=public.get_student_360_summary(p_student_profile_id);

  WITH reports AS (
    SELECT r.id,r.term_id,r.average_percentage,r.overall_grade,r.attendance_rate,r.status,r.published_at,r.updated_at,
           row_number() OVER (ORDER BY COALESCE(r.published_at,r.updated_at) DESC) rn
    FROM public.report_cards r
    WHERE r.student_profile_id=p_student_profile_id AND r.deleted_at IS NULL AND r.status IN ('approved','published')
  ), assignment_rows AS (
    SELECT a.id,a.title,a.due_date,a.max_points,s.name subject,
           sub.id submission_id,sub.status submission_status,sub.grade
    FROM public.assignments a
    JOIN public.lessons l ON l.id=a.lesson_id AND l.deleted_at IS NULL
    JOIN public.courses c ON c.id=l.course_id AND c.deleted_at IS NULL
    LEFT JOIN public.subjects s ON s.id=c.subject_id AND s.deleted_at IS NULL
    LEFT JOIN public.submissions sub
      ON sub.assignment_id=a.id AND sub.student_profile_id=p_student_profile_id AND sub.deleted_at IS NULL
    WHERE a.school_id=sid AND a.deleted_at IS NULL AND a.status='published'
      AND c.status='published' AND c.class_section_id=section_id
  ), next_lesson AS (
    SELECT te.id timetable_id,te.start_time,te.end_time,te.room,s.name subject,
           trim(concat_ws(' ',tp.first_name,tp.last_name)) teacher_name
    FROM public.timetable_entries te
    JOIN public.subjects s ON s.id=te.subject_id AND s.deleted_at IS NULL
    LEFT JOIN public.profiles tp ON tp.id=te.teacher_profile_id AND tp.deleted_at IS NULL
    WHERE te.class_section_id=section_id
      AND te.day_of_week=extract(isodow from local_date)::int
      AND te.is_active=true AND te.deleted_at IS NULL
      AND te.end_time>local_time
      AND (te.effective_from IS NULL OR te.effective_from<=local_date)
      AND (te.effective_to IS NULL OR te.effective_to>=local_date)
    ORDER BY te.start_time LIMIT 1
  ), latest_grade AS (
    SELECT gr.id grade_record_id,a.title assessment_title,s.name subject,gr.points_obtained,a.max_points,
           CASE WHEN a.max_points>0 THEN round((gr.points_obtained/a.max_points)*100,1) ELSE NULL END percentage,
           gr.teacher_remarks,gr.updated_at
    FROM public.grade_records gr
    JOIN public.assessments a ON a.id=gr.assessment_id AND a.deleted_at IS NULL
    JOIN public.subjects s ON s.id=a.subject_id AND s.deleted_at IS NULL
    WHERE gr.student_profile_id=p_student_profile_id AND gr.deleted_at IS NULL
    ORDER BY gr.updated_at DESC LIMIT 1
  ), next_fee AS (
    SELECT i.id invoice_id,i.invoice_number,i.currency,round(i.total_amount-i.paid_amount,2) balance,i.due_date
    FROM public.invoices i
    WHERE i.student_profile_id=p_student_profile_id AND i.deleted_at IS NULL AND i.status<>'paid'
      AND i.due_date>=current_date AND (ay_id IS NULL OR i.academic_year_id=ay_id)
    ORDER BY i.due_date LIMIT 1
  ), latest_announcement AS (
    SELECT id,title,content,priority,published_at,scheduled_at,expires_at,target_role
    FROM public.announcements
    WHERE school_id=sid AND deleted_at IS NULL
    ORDER BY COALESCE(published_at,scheduled_at,created_at) DESC LIMIT 1
  )
  SELECT base || jsonb_build_object(
    'dashboard',jsonb_build_object(
      'current_average',(SELECT average_percentage FROM reports WHERE rn=1),
      'current_grade',(SELECT overall_grade FROM reports WHERE rn=1),
      'previous_average',(SELECT average_percentage FROM reports WHERE rn=2),
      'academic_change',CASE
        WHEN (SELECT average_percentage FROM reports WHERE rn=1) IS NOT NULL
         AND (SELECT average_percentage FROM reports WHERE rn=2) IS NOT NULL
        THEN round((SELECT average_percentage FROM reports WHERE rn=1)-(SELECT average_percentage FROM reports WHERE rn=2),1)
        ELSE NULL END,
      'assignments_due',(SELECT count(*) FROM assignment_rows WHERE submission_id IS NULL AND due_date>=now()),
      'assignments_overdue',(SELECT count(*) FROM assignment_rows WHERE submission_id IS NULL AND due_date<now()),
      'next_lesson',(SELECT to_jsonb(n) FROM next_lesson n),
      'latest_result',(SELECT to_jsonb(g) FROM latest_grade g),
      'next_fee',(SELECT to_jsonb(f) FROM next_fee f),
      'latest_announcement',(SELECT to_jsonb(a) FROM latest_announcement a),
      'upcoming_assignments',COALESCE((
        SELECT jsonb_agg(to_jsonb(x) ORDER BY x.due_date)
        FROM (
          SELECT id,title,subject,due_date,max_points,
                 CASE WHEN submission_id IS NOT NULL THEN 'submitted'
                      WHEN due_date<now() THEN 'overdue' ELSE 'pending' END status
          FROM assignment_rows
          WHERE submission_id IS NULL OR due_date>=now()-interval '7 days'
          ORDER BY due_date LIMIT 10
        ) x
      ),'[]'::jsonb)
    )
  ) INTO result;

  RETURN result;
END;
$$;
