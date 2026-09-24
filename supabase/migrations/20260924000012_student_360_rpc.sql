-- ZivoConnect live backend reconciliation: Student 360 summary RPC.

CREATE OR REPLACE FUNCTION public.get_student_360_summary(p_student_profile_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  sid uuid;
  current_year_id uuid;
  current_year_start date;
  current_year_end date;
  result jsonb;
BEGIN
  SELECT p.school_id INTO sid
  FROM public.profiles p
  WHERE p.id=p_student_profile_id
    AND p.role='student'::public.app_role
    AND p.deleted_at IS NULL;

  IF sid IS NULL THEN RAISE EXCEPTION 'student not found or not authorized'; END IF;

  SELECT ay.id,ay.start_date,ay.end_date
  INTO current_year_id,current_year_start,current_year_end
  FROM public.academic_years ay
  WHERE ay.school_id=sid AND ay.is_current=true AND ay.deleted_at IS NULL
  ORDER BY ay.start_date DESC LIMIT 1;

  result:=jsonb_build_object(
    'student',(
      SELECT jsonb_build_object(
        'profile_id',p.id,'school_id',p.school_id,'first_name',p.first_name,'last_name',p.last_name,
        'email',p.email,'phone',p.phone,'avatar_url',p.avatar_url,'status',p.status,
        'admission_number',sd.admission_number,'date_of_birth',sd.date_of_birth,'gender',sd.gender,
        'admission_date',sd.admission_date,'curriculum',sd.curriculum,'campus',sd.campus,
        'house',sd.house,'nationality',sd.nationality
      )
      FROM public.profiles p
      LEFT JOIN public.student_details sd ON sd.student_profile_id=p.id AND sd.deleted_at IS NULL
      WHERE p.id=p_student_profile_id AND p.deleted_at IS NULL
      LIMIT 1
    ),
    'enrollment',(
      SELECT to_jsonb(e)
      FROM (
        SELECT se.id AS enrollment_id,se.status,se.roll_number,se.academic_year_id,
               ay.name AS academic_year,se.class_section_id,cs.name AS section_name,cs.room,
               c.id AS class_id,c.name AS class_name
        FROM public.student_enrollments se
        JOIN public.class_sections cs ON cs.id=se.class_section_id AND cs.deleted_at IS NULL
        JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
        JOIN public.academic_years ay ON ay.id=se.academic_year_id AND ay.deleted_at IS NULL
        WHERE se.student_profile_id=p_student_profile_id AND se.deleted_at IS NULL
        ORDER BY CASE WHEN se.status='active' THEN 0 ELSE 1 END,ay.start_date DESC,se.created_at DESC
        LIMIT 1
      ) e
    ),
    'guardians',COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'relationship_id',ur.id,'relationship_type',ur.relationship_type,
        'profile_id',gp.id,'first_name',gp.first_name,'last_name',gp.last_name,
        'email',gp.email,'phone',gp.phone,'avatar_url',gp.avatar_url
      ) ORDER BY gp.first_name,gp.last_name)
      FROM public.user_relationships ur
      JOIN public.profiles gp ON gp.id=ur.parent_id AND gp.deleted_at IS NULL
      WHERE ur.student_id=p_student_profile_id AND ur.deleted_at IS NULL
    ),'[]'::jsonb),
    'finance',jsonb_build_object(
      'academic_year_id',current_year_id,
      'by_currency',COALESCE((
        SELECT jsonb_agg(to_jsonb(f) ORDER BY f.currency)
        FROM (
          SELECT i.currency,
                 round(COALESCE(sum(i.total_amount),0),2) AS total_invoiced,
                 round(COALESCE(sum(i.paid_amount),0),2) AS total_paid,
                 round(COALESCE(sum(i.total_amount-i.paid_amount),0),2) AS outstanding,
                 CASE WHEN COALESCE(sum(i.total_amount),0)>0
                      THEN round((sum(i.paid_amount)/sum(i.total_amount))*100,1) ELSE 0 END AS settled_percent,
                 count(*) FILTER (WHERE i.due_date<current_date AND i.status<>'paid') AS overdue_count,
                 min(i.due_date) FILTER (WHERE i.status<>'paid' AND i.due_date>=current_date) AS next_due_date
          FROM public.invoices i
          WHERE i.student_profile_id=p_student_profile_id
            AND i.deleted_at IS NULL
            AND (current_year_id IS NULL OR i.academic_year_id=current_year_id)
          GROUP BY i.currency
        ) f
      ),'[]'::jsonb),
      'latest_payment',(
        SELECT to_jsonb(lp)
        FROM (
          SELECT p.id,p.invoice_id,p.amount,p.currency,p.payment_method,p.provider,
                 COALESCE(p.provider_reference,p.transaction_reference) AS reference,
                 p.status,p.paid_at,p.receipt_url
          FROM public.payments p
          JOIN public.invoices i ON i.id=p.invoice_id AND i.student_profile_id=p_student_profile_id AND i.deleted_at IS NULL
          WHERE p.deleted_at IS NULL AND p.status='confirmed'
            AND (current_year_id IS NULL OR i.academic_year_id=current_year_id)
          ORDER BY p.paid_at DESC LIMIT 1
        ) lp
      )
    ),
    'attendance',jsonb_build_object(
      'academic_year_id',current_year_id,
      'recorded_days',(
        SELECT count(*) FROM public.daily_attendance da
        WHERE da.student_profile_id=p_student_profile_id AND da.deleted_at IS NULL
          AND (current_year_start IS NULL OR da.date>=current_year_start)
          AND (current_year_end IS NULL OR da.date<=current_year_end)
      ),
      'present',(
        SELECT count(*) FROM public.daily_attendance da
        WHERE da.student_profile_id=p_student_profile_id AND da.status='present' AND da.deleted_at IS NULL
          AND (current_year_start IS NULL OR da.date>=current_year_start)
          AND (current_year_end IS NULL OR da.date<=current_year_end)
      ),
      'late',(
        SELECT count(*) FROM public.daily_attendance da
        WHERE da.student_profile_id=p_student_profile_id AND da.status='late' AND da.deleted_at IS NULL
          AND (current_year_start IS NULL OR da.date>=current_year_start)
          AND (current_year_end IS NULL OR da.date<=current_year_end)
      ),
      'absent',(
        SELECT count(*) FROM public.daily_attendance da
        WHERE da.student_profile_id=p_student_profile_id AND da.status='absent' AND da.deleted_at IS NULL
          AND (current_year_start IS NULL OR da.date>=current_year_start)
          AND (current_year_end IS NULL OR da.date<=current_year_end)
      ),
      'excused',(
        SELECT count(*) FROM public.daily_attendance da
        WHERE da.student_profile_id=p_student_profile_id AND da.status='excused' AND da.deleted_at IS NULL
          AND (current_year_start IS NULL OR da.date>=current_year_start)
          AND (current_year_end IS NULL OR da.date<=current_year_end)
      ),
      'attendance_rate',(
        SELECT CASE WHEN count(*)=0 THEN 0
          ELSE round((count(*) FILTER (WHERE da.status IN ('present','late'))::numeric/count(*)::numeric)*100,1) END
        FROM public.daily_attendance da
        WHERE da.student_profile_id=p_student_profile_id AND da.deleted_at IS NULL
          AND (current_year_start IS NULL OR da.date>=current_year_start)
          AND (current_year_end IS NULL OR da.date<=current_year_end)
      ),
      'strict_present_rate',(
        SELECT CASE WHEN count(*)=0 THEN 0
          ELSE round((count(*) FILTER (WHERE da.status='present')::numeric/count(*)::numeric)*100,1) END
        FROM public.daily_attendance da
        WHERE da.student_profile_id=p_student_profile_id AND da.deleted_at IS NULL
          AND (current_year_start IS NULL OR da.date>=current_year_start)
          AND (current_year_end IS NULL OR da.date<=current_year_end)
      ),
      'last_20_recorded_days',COALESCE((
        SELECT jsonb_agg(to_jsonb(a) ORDER BY a.date)
        FROM (
          SELECT da.id,da.date,da.status,da.remarks,da.class_section_id
          FROM public.daily_attendance da
          WHERE da.student_profile_id=p_student_profile_id AND da.deleted_at IS NULL
          ORDER BY da.date DESC LIMIT 20
        ) a
      ),'[]'::jsonb)
    ),
    'academics',jsonb_build_object(
      'latest_report_card',(
        SELECT to_jsonb(rc)
        FROM (
          SELECT r.id,r.academic_year_id,ay.name AS academic_year,r.term_id,gt.name AS term,
                 r.gpa,r.average_percentage,r.overall_grade,r.attendance_rate,r.status,
                 r.teacher_comments,r.approved_at,r.published_at,r.summary
          FROM public.report_cards r
          LEFT JOIN public.academic_years ay ON ay.id=r.academic_year_id
          LEFT JOIN public.grading_terms gt ON gt.id=r.term_id
          WHERE r.student_profile_id=p_student_profile_id AND r.deleted_at IS NULL
          ORDER BY CASE WHEN r.status='published' THEN 0 ELSE 1 END,COALESCE(r.published_at,r.updated_at) DESC
          LIMIT 1
        ) rc
      ),
      'recent_grades',COALESCE((
        SELECT jsonb_agg(to_jsonb(g) ORDER BY g.recorded_at DESC)
        FROM (
          SELECT gr.id AS grade_record_id,gr.assessment_id,a.title AS assessment_title,a.date_administered,
                 s.id AS subject_id,s.name AS subject,gr.points_obtained,a.max_points,
                 CASE WHEN a.max_points>0 THEN round((gr.points_obtained/a.max_points)*100,1) ELSE NULL END AS percentage,
                 gr.teacher_remarks,gr.updated_at AS recorded_at
          FROM public.grade_records gr
          JOIN public.assessments a ON a.id=gr.assessment_id AND a.deleted_at IS NULL
          JOIN public.subjects s ON s.id=a.subject_id AND s.deleted_at IS NULL
          LEFT JOIN public.grading_terms gt ON gt.id=a.term_id AND gt.deleted_at IS NULL
          WHERE gr.student_profile_id=p_student_profile_id AND gr.deleted_at IS NULL
            AND (current_year_id IS NULL OR gt.academic_year_id=current_year_id)
          ORDER BY gr.updated_at DESC LIMIT 20
        ) g
      ),'[]'::jsonb)
    ),
    'documents',COALESCE((
      SELECT jsonb_agg(to_jsonb(d) ORDER BY d.created_at DESC)
      FROM (
        SELECT sd.id,sd.category,sd.file_name,sd.file_url,sd.mime_type,sd.file_size_bytes,
               sd.verification_status,sd.verified_at,sd.visibility,sd.created_at
        FROM public.student_documents sd
        WHERE sd.student_profile_id=p_student_profile_id AND sd.deleted_at IS NULL
        ORDER BY sd.created_at DESC LIMIT 20
      ) d
    ),'[]'::jsonb),
    'behavior',COALESCE((
      SELECT jsonb_agg(to_jsonb(b) ORDER BY b.incident_date DESC,b.created_at DESC)
      FROM (
        SELECT bl.id,bl.type,bl.points,bl.description,bl.incident_date,bl.severity,bl.status,
               bl.guardian_notified_at,bl.resolved_at,bl.created_at
        FROM public.behavioral_logs bl
        WHERE bl.student_profile_id=p_student_profile_id AND bl.deleted_at IS NULL
        ORDER BY bl.incident_date DESC,bl.created_at DESC LIMIT 20
      ) b
    ),'[]'::jsonb),
    'activity',COALESCE((
      SELECT jsonb_agg(to_jsonb(ev) ORDER BY ev.occurred_at DESC)
      FROM (
        SELECT ae.id,ae.event_type,ae.title,ae.description,ae.source_table,ae.source_id,
               ae.metadata,ae.occurred_at,ae.actor_profile_id,
               trim(concat_ws(' ',ap.first_name,ap.last_name)) AS actor_name
        FROM public.activity_events ae
        LEFT JOIN public.profiles ap ON ap.id=ae.actor_profile_id AND ap.deleted_at IS NULL
        WHERE ae.subject_profile_id=p_student_profile_id AND ae.deleted_at IS NULL
        ORDER BY ae.occurred_at DESC LIMIT 30
      ) ev
    ),'[]'::jsonb)
  );

  RETURN result;
END;
$$;
