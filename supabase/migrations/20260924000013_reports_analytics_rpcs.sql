-- ZivoConnect live backend reconciliation: Reports & Analytics RPCs.

CREATE OR REPLACE FUNCTION public.get_attendance_report(
  p_academic_year_id uuid,
  p_term_id uuid DEFAULT NULL,
  p_class_section_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text := public.get_active_role()::text;
  sid uuid := public.get_active_school_id();
  range_start date;
  range_end date;
  result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT ay.start_date,ay.end_date INTO range_start,range_end
  FROM public.academic_years ay
  WHERE ay.id=p_academic_year_id AND ay.school_id=sid AND ay.deleted_at IS NULL;
  IF range_start IS NULL THEN RAISE EXCEPTION 'academic year not found or not authorized'; END IF;

  IF p_term_id IS NOT NULL THEN
    SELECT COALESCE(gt.start_date,range_start),COALESCE(gt.end_date,range_end)
    INTO range_start,range_end
    FROM public.grading_terms gt
    WHERE gt.id=p_term_id AND gt.academic_year_id=p_academic_year_id AND gt.school_id=sid AND gt.deleted_at IS NULL;
    IF NOT FOUND THEN RAISE EXCEPTION 'term not found or not authorized'; END IF;
  END IF;

  WITH scoped AS (
    SELECT da.*,cs.name section_name,c.name class_name
    FROM public.daily_attendance da
    JOIN public.class_sections cs ON cs.id=da.class_section_id AND cs.deleted_at IS NULL
    JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    WHERE da.school_id=sid AND da.deleted_at IS NULL
      AND da.date BETWEEN range_start AND range_end
      AND c.academic_year_id=p_academic_year_id
      AND (p_class_section_id IS NULL OR da.class_section_id=p_class_section_id)
  ), summary AS (
    SELECT count(*) records,
           count(*) FILTER (WHERE status='present') present,
           count(*) FILTER (WHERE status='late') late,
           count(*) FILTER (WHERE status='absent') absent,
           count(*) FILTER (WHERE status='excused') excused
    FROM scoped
  ), section_rows AS (
    SELECT s.class_section_id,max(s.class_name) class_name,max(s.section_name) section_name,
           count(DISTINCT s.student_profile_id) students_with_records,count(*) records,
           count(*) FILTER (WHERE s.status='present') present,
           count(*) FILTER (WHERE s.status='late') late,
           count(*) FILTER (WHERE s.status='absent') absent,
           count(*) FILTER (WHERE s.status='excused') excused
    FROM scoped s GROUP BY s.class_section_id
  )
  SELECT jsonb_build_object(
    'academic_year_id',p_academic_year_id,'term_id',p_term_id,'class_section_id',p_class_section_id,
    'start_date',range_start,'end_date',range_end,
    'summary',(
      SELECT jsonb_build_object(
        'records',records,'present',present,'late',late,'absent',absent,'excused',excused,
        'present_rate',CASE WHEN records>0 THEN round((present::numeric/records)*100,1) ELSE 0 END,
        'attendance_rate',CASE WHEN records>0 THEN round(((present+late)::numeric/records)*100,1) ELSE 0 END,
        'absent_rate',CASE WHEN records>0 THEN round((absent::numeric/records)*100,1) ELSE 0 END,
        'late_rate',CASE WHEN records>0 THEN round((late::numeric/records)*100,1) ELSE 0 END,
        'excused_rate',CASE WHEN records>0 THEN round((excused::numeric/records)*100,1) ELSE 0 END
      ) FROM summary
    ),
    'classes',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'class_section_id',sr.class_section_id,'class_name',sr.class_name,'section_name',sr.section_name,
        'students',sr.students_with_records,'records',sr.records,
        'present_rate',CASE WHEN sr.records>0 THEN round((sr.present::numeric/sr.records)*100,1) ELSE 0 END,
        'attendance_rate',CASE WHEN sr.records>0 THEN round(((sr.present+sr.late)::numeric/sr.records)*100,1) ELSE 0 END,
        'absent_rate',CASE WHEN sr.records>0 THEN round((sr.absent::numeric/sr.records)*100,1) ELSE 0 END,
        'late_rate',CASE WHEN sr.records>0 THEN round((sr.late::numeric/sr.records)*100,1) ELSE 0 END,
        'excused_rate',CASE WHEN sr.records>0 THEN round((sr.excused::numeric/sr.records)*100,1) ELSE 0 END
      ) ORDER BY sr.class_name,sr.section_name) FROM section_rows sr
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_academic_performance_report(
  p_academic_year_id uuid,
  p_term_id uuid DEFAULT NULL,
  p_class_section_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.academic_years ay WHERE ay.id=p_academic_year_id AND ay.school_id=sid AND ay.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'academic year not found or not authorized';
  END IF;

  WITH report_scope AS (
    SELECT rc.*,se.class_section_id,cs.name section_name,c.name class_name
    FROM public.report_cards rc
    JOIN public.student_enrollments se
      ON se.student_profile_id=rc.student_profile_id
     AND se.academic_year_id=rc.academic_year_id
     AND se.status='active' AND se.deleted_at IS NULL
    JOIN public.class_sections cs ON cs.id=se.class_section_id AND cs.deleted_at IS NULL
    JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    WHERE rc.school_id=sid AND rc.academic_year_id=p_academic_year_id
      AND rc.deleted_at IS NULL AND rc.status IN ('approved','published')
      AND (p_term_id IS NULL OR rc.term_id=p_term_id)
      AND (p_class_section_id IS NULL OR se.class_section_id=p_class_section_id)
  ), class_perf AS (
    SELECT class_section_id,max(class_name) class_name,max(section_name) section_name,
           count(*) students_with_results,round(avg(average_percentage),1) average_percentage,
           round(avg(attendance_rate),1) average_attendance
    FROM report_scope GROUP BY class_section_id
  ), subject_rows AS (
    SELECT (subject->>'subject_id')::uuid subject_id,subject->>'subject' subject_name,
           NULLIF(subject->>'final_average','')::numeric final_average
    FROM report_scope rs
    CROSS JOIN LATERAL jsonb_array_elements(COALESCE(rs.summary->'subjects','[]'::jsonb)) subject
  ), subject_perf AS (
    SELECT subject_id,max(subject_name) subject_name,count(final_average) students_graded,
           round(avg(final_average),1) average_percentage
    FROM subject_rows WHERE final_average IS NOT NULL GROUP BY subject_id
  ), grade_dist AS (
    SELECT overall_grade,count(*) students FROM report_scope
    WHERE overall_grade IS NOT NULL GROUP BY overall_grade
  )
  SELECT jsonb_build_object(
    'academic_year_id',p_academic_year_id,'term_id',p_term_id,'class_section_id',p_class_section_id,
    'summary',jsonb_build_object(
      'students_with_results',(SELECT count(*) FROM report_scope),
      'average_percentage',COALESCE((SELECT round(avg(average_percentage),1) FROM report_scope),0),
      'average_attendance',COALESCE((SELECT round(avg(attendance_rate),1) FROM report_scope),0),
      'highest_average',(SELECT max(average_percentage) FROM report_scope),
      'lowest_average',(SELECT min(average_percentage) FROM report_scope)
    ),
    'classes',COALESCE((SELECT jsonb_agg(to_jsonb(cp) ORDER BY cp.class_name,cp.section_name) FROM class_perf cp),'[]'::jsonb),
    'subjects',COALESCE((SELECT jsonb_agg(to_jsonb(sp) ORDER BY sp.average_percentage DESC NULLS LAST,sp.subject_name) FROM subject_perf sp),'[]'::jsonb),
    'grade_distribution',COALESCE((
      SELECT jsonb_agg(jsonb_build_object('grade',gd.overall_grade,'students',gd.students) ORDER BY gd.overall_grade)
      FROM grade_dist gd
    ),'[]'::jsonb)
  ) INTO result;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_reports_analytics(
  p_report_type text,
  p_academic_year_id uuid,
  p_term_id uuid DEFAULT NULL,
  p_class_section_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  normalized text:=regexp_replace(lower(trim(p_report_type)),'[^a-z0-9]+','_','g');
BEGIN
  normalized:=trim(both '_' from normalized);

  IF normalized IN ('attendance','attendance_trends','attendance_trend') THEN
    RETURN jsonb_build_object('report_type','attendance_trends','data',public.get_attendance_report(p_academic_year_id,p_term_id,p_class_section_id));
  ELSIF normalized IN ('academic','academic_performance','academics') THEN
    RETURN jsonb_build_object('report_type','academic_performance','data',public.get_academic_performance_report(p_academic_year_id,p_term_id,p_class_section_id));
  ELSIF normalized IN ('fees','fee_collections','fee_collection','finance') THEN
    RETURN jsonb_build_object('report_type','fee_collections','data',public.get_fee_collections_report(p_academic_year_id,p_term_id,p_class_section_id));
  END IF;

  RAISE EXCEPTION 'unsupported report type: %',p_report_type;
END;
$$;
