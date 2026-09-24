-- ZivoConnect live backend reconciliation: core dashboard/directory RPCs.

CREATE OR REPLACE FUNCTION public.get_school_admin_dashboard_metrics()
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  sid uuid := public.get_active_school_id();
  role_name text := public.get_active_role()::text;
  students_count bigint;
  teachers_count bigint;
  classes_count bigint;
  attendance_total bigint;
  attendance_present bigint;
  announcements_count bigint;
  outstanding_total numeric;
  result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT count(*) INTO students_count FROM public.profiles
  WHERE school_id=sid AND role='student'::public.app_role AND deleted_at IS NULL AND status='active';
  SELECT count(*) INTO teachers_count FROM public.profiles
  WHERE school_id=sid AND role='teacher'::public.app_role AND deleted_at IS NULL AND status='active';
  SELECT count(*) INTO classes_count FROM public.class_sections
  WHERE school_id=sid AND deleted_at IS NULL;
  SELECT count(*),count(*) FILTER (WHERE status='present')
  INTO attendance_total,attendance_present
  FROM public.daily_attendance
  WHERE school_id=sid AND date=current_date AND deleted_at IS NULL;
  SELECT count(*) INTO announcements_count FROM public.announcements
  WHERE school_id=sid AND status='published' AND deleted_at IS NULL;
  SELECT COALESCE(sum(total_amount-paid_amount),0) INTO outstanding_total
  FROM public.invoices
  WHERE school_id=sid AND status<>'paid' AND deleted_at IS NULL;

  SELECT jsonb_build_object(
    'students',students_count,
    'total_students',students_count,
    'teachers',teachers_count,
    'total_teachers',teachers_count,
    'active_classes',classes_count,
    'total_classes',classes_count,
    'attendance_today_total',attendance_total,
    'attendance_today_present',attendance_present,
    'attendance_rate',CASE WHEN attendance_total>0 THEN round((attendance_present::numeric/attendance_total::numeric)*100,1) ELSE 0 END,
    'outstanding_fees',outstanding_total,
    'outstanding_fees_by_currency',COALESCE((
      SELECT jsonb_agg(jsonb_build_object('currency',currency,'outstanding',round(sum(total_amount-paid_amount),2)) ORDER BY currency)
      FROM public.invoices
      WHERE school_id=sid AND status<>'paid' AND deleted_at IS NULL
      GROUP BY school_id
    ),'[]'::jsonb),
    'published_announcements',announcements_count,
    'recent_activity',COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.occurred_at DESC)
      FROM (
        SELECT ae.id,ae.event_type,ae.title,ae.description,ae.subject_profile_id,ae.actor_profile_id,ae.occurred_at
        FROM public.activity_events ae
        WHERE ae.school_id=sid AND ae.deleted_at IS NULL
        ORDER BY ae.occurred_at DESC LIMIT 10
      ) x
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_teacher_dashboard_metrics()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  sid uuid:=public.get_active_school_id();
  pid uuid:=public.get_active_profile_id();
  role_name text:=public.get_active_role()::text;
  tz text;
  local_date date;
  local_time time;
  result jsonb;
BEGIN
  IF role_name NOT IN ('teacher','school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT COALESCE(timezone,'Africa/Harare') INTO tz FROM public.schools WHERE id=sid;
  local_date := (now() AT TIME ZONE tz)::date;
  local_time := (now() AT TIME ZONE tz)::time;

  WITH schedule AS (
    SELECT te.id timetable_id,te.class_section_id,te.subject_id,te.start_time,te.end_time,te.room,
           s.name subject_name,cs.name section_name,c.name class_name,
           (SELECT count(*) FROM public.student_enrollments se
            WHERE se.class_section_id=te.class_section_id
              AND se.academic_year_id=te.academic_year_id
              AND se.status='active' AND se.deleted_at IS NULL) student_count,
           CASE
             WHEN local_time>=te.end_time THEN 'completed'
             WHEN local_time BETWEEN te.start_time AND te.end_time THEN 'in_progress'
             ELSE 'upcoming'
           END raw_status
    FROM public.timetable_entries te
    JOIN public.subjects s ON s.id=te.subject_id AND s.deleted_at IS NULL
    JOIN public.class_sections cs ON cs.id=te.class_section_id AND cs.deleted_at IS NULL
    JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    WHERE te.school_id=sid
      AND te.teacher_profile_id=pid
      AND te.day_of_week=extract(isodow from local_date)::int
      AND te.is_active=true AND te.deleted_at IS NULL
      AND (te.effective_from IS NULL OR te.effective_from<=local_date)
      AND (te.effective_to IS NULL OR te.effective_to>=local_date)
  ),
  next_row AS (
    SELECT timetable_id FROM schedule WHERE start_time>local_time ORDER BY start_time LIMIT 1
  ),
  schedule_labeled AS (
    SELECT sc.*,CASE WHEN sc.timetable_id=(SELECT timetable_id FROM next_row) THEN 'next' ELSE sc.raw_status END status
    FROM schedule sc
  ),
  pending_attendance AS (
    SELECT count(DISTINCT sc.class_section_id) count_pending
    FROM schedule sc
    WHERE NOT EXISTS (
      SELECT 1 FROM public.daily_attendance da
      WHERE da.class_section_id=sc.class_section_id AND da.date=local_date AND da.deleted_at IS NULL
    )
  ),
  grading AS (
    SELECT count(*) FILTER (WHERE sub.grade IS NULL) submissions_to_mark,
           count(DISTINCT sub.assignment_id) FILTER (WHERE sub.grade IS NULL) assignments_to_mark
    FROM public.submissions sub
    JOIN public.assignments a ON a.id=sub.assignment_id AND a.deleted_at IS NULL
    JOIN public.lessons l ON l.id=a.lesson_id AND l.deleted_at IS NULL
    JOIN public.courses co ON co.id=l.course_id AND co.deleted_at IS NULL
    WHERE sub.school_id=sid AND co.teacher_profile_id=pid AND sub.deleted_at IS NULL
  ),
  messages AS (
    SELECT count(*) unread,
           count(DISTINCT dm.sender_profile_id) FILTER (WHERE sp.role='parent'::public.app_role) parent_senders
    FROM public.direct_messages dm
    JOIN public.profiles sp ON sp.id=dm.sender_profile_id AND sp.deleted_at IS NULL
    WHERE dm.recipient_profile_id=pid AND dm.read_at IS NULL AND dm.deleted_at IS NULL
  )
  SELECT jsonb_build_object(
    'assigned_sections',(SELECT count(DISTINCT class_section_id) FROM public.class_teachers WHERE school_id=sid AND teacher_profile_id=pid AND deleted_at IS NULL),
    'assigned_subjects',(SELECT count(DISTINCT subject_id) FROM public.class_teachers WHERE school_id=sid AND teacher_profile_id=pid AND subject_id IS NOT NULL AND deleted_at IS NULL),
    'today_sessions',(SELECT count(*) FROM schedule),
    'classes_today',(SELECT count(*) FROM schedule),
    'classes_completed',(SELECT count(*) FROM schedule WHERE end_time<=local_time),
    'classes_remaining',(SELECT count(*) FROM schedule WHERE end_time>local_time),
    'attendance_pending',(SELECT count_pending FROM pending_attendance),
    'pending_grading',COALESCE((SELECT submissions_to_mark FROM grading),0),
    'submissions_to_mark',COALESCE((SELECT submissions_to_mark FROM grading),0),
    'assignments_to_mark',COALESCE((SELECT assignments_to_mark FROM grading),0),
    'unread_messages',COALESCE((SELECT unread FROM messages),0),
    'unread_parent_senders',COALESCE((SELECT parent_senders FROM messages),0),
    'local_date',local_date,
    'timezone',tz,
    'schedule',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'timetable_id',sl.timetable_id,
        'class_section_id',sl.class_section_id,
        'subject_id',sl.subject_id,
        'subject',sl.subject_name,
        'class_name',sl.class_name,
        'section_name',sl.section_name,
        'start_time',sl.start_time,
        'end_time',sl.end_time,
        'room',sl.room,
        'student_count',sl.student_count,
        'status',sl.status
      ) ORDER BY sl.start_time) FROM schedule_labeled sl
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_attendance_roll_call(
  p_class_section_id uuid,
  p_date date DEFAULT CURRENT_DATE
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  ay_id uuid;
  result jsonb;
BEGIN
  IF role_name NOT IN ('teacher','school_admin','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT c.academic_year_id INTO ay_id
  FROM public.class_sections cs
  JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
  WHERE cs.id=p_class_section_id AND cs.school_id=sid AND cs.deleted_at IS NULL;

  IF ay_id IS NULL THEN RAISE EXCEPTION 'class section not found or not authorized'; END IF;

  WITH students AS (
    SELECT p.id profile_id,p.first_name,p.last_name,p.avatar_url,sd.admission_number,se.roll_number
    FROM public.student_enrollments se
    JOIN public.profiles p ON p.id=se.student_profile_id AND p.deleted_at IS NULL
    LEFT JOIN public.student_details sd ON sd.student_profile_id=p.id AND sd.deleted_at IS NULL
    WHERE se.school_id=sid AND se.class_section_id=p_class_section_id AND se.academic_year_id=ay_id
      AND se.status='active' AND se.deleted_at IS NULL
  ), roll AS (
    SELECT s.*,da.id attendance_id,da.status,da.remarks,da.updated_at
    FROM students s
    LEFT JOIN public.daily_attendance da
      ON da.student_profile_id=s.profile_id
     AND da.class_section_id=p_class_section_id
     AND da.date=p_date
     AND da.deleted_at IS NULL
  ), stats AS (
    SELECT count(*) expected,count(attendance_id) marked,
           count(*) FILTER (WHERE status='present') present,
           count(*) FILTER (WHERE status='absent') absent,
           count(*) FILTER (WHERE status='late') late,
           count(*) FILTER (WHERE status='excused') excused
    FROM roll
  )
  SELECT jsonb_build_object(
    'class_section_id',p_class_section_id,
    'academic_year_id',ay_id,
    'date',p_date,
    'expected_students',(SELECT expected FROM stats),
    'marked_students',(SELECT marked FROM stats),
    'unmarked_students',(SELECT expected-marked FROM stats),
    'present',(SELECT present FROM stats),
    'absent',(SELECT absent FROM stats),
    'late',(SELECT late FROM stats),
    'excused',(SELECT excused FROM stats),
    'is_complete',(SELECT expected>0 AND marked=expected FROM stats),
    'students',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'profile_id',r.profile_id,'first_name',r.first_name,'last_name',r.last_name,
        'avatar_url',r.avatar_url,'admission_number',r.admission_number,'roll_number',r.roll_number,
        'attendance_id',r.attendance_id,'status',r.status,'remarks',r.remarks,'updated_at',r.updated_at
      ) ORDER BY r.last_name,r.first_name) FROM roll r
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_students_directory(p_academic_year_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  ay_start date; ay_end date; default_ccy text; result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','finance_manager','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT ay.start_date,ay.end_date INTO ay_start,ay_end
  FROM public.academic_years ay
  WHERE ay.id=p_academic_year_id AND ay.school_id=sid AND ay.deleted_at IS NULL;
  IF ay_start IS NULL THEN RAISE EXCEPTION 'academic year not found or not authorized'; END IF;
  SELECT COALESCE(s.default_currency,'USD') INTO default_ccy FROM public.schools s WHERE s.id=sid AND s.deleted_at IS NULL;

  WITH enrollments AS (
    SELECT DISTINCT ON (se.student_profile_id)
      se.student_profile_id,se.class_section_id,se.status enrollment_status,cs.name section_name,c.name class_name
    FROM public.student_enrollments se
    JOIN public.class_sections cs ON cs.id=se.class_section_id AND cs.deleted_at IS NULL
    JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    WHERE se.school_id=sid AND se.academic_year_id=p_academic_year_id AND se.deleted_at IS NULL
    ORDER BY se.student_profile_id,CASE WHEN se.status='active' THEN 0 ELSE 1 END,se.updated_at DESC
  ), attendance AS (
    SELECT da.student_profile_id,count(*) records,
           count(*) FILTER (WHERE da.status='present') present,
           count(*) FILTER (WHERE da.status='late') late
    FROM public.daily_attendance da
    WHERE da.school_id=sid AND da.deleted_at IS NULL AND da.date BETWEEN ay_start AND ay_end
    GROUP BY da.student_profile_id
  ), finance AS (
    SELECT i.student_profile_id,
           COALESCE(sum(i.total_amount-i.paid_amount) FILTER (WHERE i.currency=default_ccy),0) balance,
           bool_or(i.due_date<current_date AND i.status<>'paid' AND i.currency=default_ccy) has_overdue,
           bool_or(i.due_date BETWEEN current_date AND current_date+7 AND i.status<>'paid' AND i.currency=default_ccy) due_soon,
           count(*) FILTER (WHERE i.currency=default_ccy) invoice_count
    FROM public.invoices i
    WHERE i.school_id=sid AND i.academic_year_id=p_academic_year_id AND i.deleted_at IS NULL
    GROUP BY i.student_profile_id
  ), guardian AS (
    SELECT DISTINCT ON (ur.student_id) ur.student_id,
           trim(concat_ws(' ',gp.first_name,gp.last_name)) guardian_name,
           gp.phone guardian_phone,gp.email guardian_email
    FROM public.user_relationships ur
    JOIN public.profiles gp ON gp.id=ur.parent_id AND gp.deleted_at IS NULL
    WHERE ur.school_id=sid AND ur.deleted_at IS NULL
    ORDER BY ur.student_id,ur.created_at
  ), rows AS (
    SELECT p.id profile_id,trim(concat_ws(' ',p.first_name,p.last_name)) student_name,
           p.first_name,p.last_name,p.avatar_url,p.status,
           sd.admission_number student_id,sd.curriculum,
           e.class_section_id,e.class_name,e.section_name,e.enrollment_status,
           g.guardian_name,g.guardian_phone,g.guardian_email,
           CASE WHEN COALESCE(a.records,0)>0 THEN round(((COALESCE(a.present,0)+COALESCE(a.late,0))::numeric/a.records)*100,1) ELSE NULL END attendance_rate,
           CASE WHEN COALESCE(a.records,0)>0 THEN round((COALESCE(a.present,0)::numeric/a.records)*100,1) ELSE NULL END strict_present_rate,
           default_ccy currency,round(COALESCE(f.balance,0),2) fee_balance,
           CASE
             WHEN COALESCE(f.invoice_count,0)=0 THEN 'no_invoice'
             WHEN COALESCE(f.balance,0)<=0 THEN 'paid'
             WHEN COALESCE(f.has_overdue,false) THEN 'overdue'
             WHEN COALESCE(f.due_soon,false) THEN 'due_soon'
             ELSE 'balance'
           END fee_status
    FROM public.profiles p
    JOIN enrollments e ON e.student_profile_id=p.id
    LEFT JOIN public.student_details sd ON sd.student_profile_id=p.id AND sd.deleted_at IS NULL
    LEFT JOIN attendance a ON a.student_profile_id=p.id
    LEFT JOIN finance f ON f.student_profile_id=p.id
    LEFT JOIN guardian g ON g.student_id=p.id
    WHERE p.school_id=sid AND p.role='student'::public.app_role AND p.deleted_at IS NULL
  )
  SELECT jsonb_build_object(
    'academic_year_id',p_academic_year_id,
    'currency',default_ccy,
    'students',COALESCE((SELECT jsonb_agg(to_jsonb(r) ORDER BY r.last_name,r.first_name) FROM rows r),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_classes_sections_overview(p_academic_year_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  ay_start date; ay_end date; result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT start_date,end_date INTO ay_start,ay_end FROM public.academic_years
  WHERE id=p_academic_year_id AND school_id=sid AND deleted_at IS NULL;
  IF ay_start IS NULL THEN RAISE EXCEPTION 'academic year not found or not authorized'; END IF;

  WITH sections AS (
    SELECT cs.id section_id,cs.name section_name,cs.room,c.id class_id,c.name class_name
    FROM public.class_sections cs
    JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    WHERE cs.school_id=sid AND c.academic_year_id=p_academic_year_id AND cs.deleted_at IS NULL
  ), enroll AS (
    SELECT class_section_id,count(*) students
    FROM public.student_enrollments
    WHERE school_id=sid AND academic_year_id=p_academic_year_id AND status='active' AND deleted_at IS NULL
    GROUP BY class_section_id
  ), teacher_rollup AS (
    SELECT ct.class_section_id,count(DISTINCT ct.teacher_profile_id) teachers,
           count(DISTINCT ct.subject_id) FILTER (WHERE ct.subject_id IS NOT NULL) subjects,
           max(trim(concat_ws(' ',p.first_name,p.last_name))) FILTER (WHERE ct.is_primary_homeroom_teacher) primary_teacher
    FROM public.class_teachers ct
    JOIN public.profiles p ON p.id=ct.teacher_profile_id AND p.deleted_at IS NULL
    WHERE ct.school_id=sid AND ct.deleted_at IS NULL
    GROUP BY ct.class_section_id
  ), att AS (
    SELECT da.class_section_id,count(*) records,
           count(*) FILTER (WHERE da.status='present') present,
           count(*) FILTER (WHERE da.status='late') late
    FROM public.daily_attendance da
    WHERE da.school_id=sid AND da.deleted_at IS NULL AND da.date BETWEEN ay_start AND ay_end
    GROUP BY da.class_section_id
  ), section_rows AS (
    SELECT s.section_id,s.section_name,s.room,s.class_id,s.class_name,
           COALESCE(e.students,0) students,COALESCE(t.teachers,0) teachers,COALESCE(t.subjects,0) subjects,t.primary_teacher,
           CASE WHEN COALESCE(a.records,0)>0 THEN round(((COALESCE(a.present,0)+COALESCE(a.late,0))::numeric/a.records)*100,1) ELSE NULL END attendance_rate
    FROM sections s
    LEFT JOIN enroll e ON e.class_section_id=s.section_id
    LEFT JOIN teacher_rollup t ON t.class_section_id=s.section_id
    LEFT JOIN att a ON a.class_section_id=s.section_id
  ), class_rows AS (
    SELECT sr.class_id,max(sr.class_name) class_name,sum(sr.students) students,
           jsonb_agg(jsonb_build_object(
             'section_id',sr.section_id,'section_name',sr.section_name,'room',sr.room,
             'students',sr.students,'primary_teacher',sr.primary_teacher,
             'teachers',sr.teachers,'subjects',sr.subjects,'attendance_rate',sr.attendance_rate,'status','active'
           ) ORDER BY sr.section_name) sections
    FROM section_rows sr
    GROUP BY sr.class_id
  )
  SELECT jsonb_build_object(
    'academic_year_id',p_academic_year_id,
    'classes',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'class_id',cr.class_id,'class_name',cr.class_name,'students',cr.students,'sections',cr.sections
      ) ORDER BY cr.class_name) FROM class_rows cr
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;
