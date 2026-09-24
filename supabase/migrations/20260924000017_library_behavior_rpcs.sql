-- ZivoConnect live backend reconciliation: Library and Behaviour/Pastoral RPCs.

CREATE OR REPLACE FUNCTION public.get_library_dashboard()
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT jsonb_build_object(
    'books',COALESCE((SELECT sum(stock_quantity) FROM public.library_books WHERE school_id=sid AND deleted_at IS NULL),0),
    'available',COALESCE((SELECT sum(available_quantity) FROM public.library_books WHERE school_id=sid AND deleted_at IS NULL),0),
    'issued',(SELECT count(*) FROM public.library_issues WHERE school_id=sid AND deleted_at IS NULL AND returned_at IS NULL AND status IN ('issued','overdue')),
    'overdue',(SELECT count(*) FROM public.library_issues WHERE school_id=sid AND deleted_at IS NULL AND returned_at IS NULL AND due_at<now()),
    'due_today',(SELECT count(*) FROM public.library_issues WHERE school_id=sid AND deleted_at IS NULL AND returned_at IS NULL AND due_at::date=current_date),
    'catalog',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.title) FROM (
      SELECT id,title,author,category,isbn,stock_quantity,available_quantity,shelf_code,cover_url,
             CASE WHEN available_quantity<=0 THEN 'unavailable'
                  WHEN available_quantity<=GREATEST(1,ceil(stock_quantity*0.2)::int) THEN 'low_stock'
                  ELSE 'available' END stock_status
      FROM public.library_books WHERE school_id=sid AND deleted_at IS NULL ORDER BY title LIMIT 100
    ) x),'[]'::jsonb),
    'overdue_items',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.due_at) FROM (
      SELECT li.id issue_id,li.book_id,b.title,li.borrower_profile_id,trim(concat_ws(' ',p.first_name,p.last_name)) borrower_name,
             li.due_at,GREATEST(0,(current_date-li.due_at::date)) days_overdue,li.status
      FROM public.library_issues li JOIN public.library_books b ON b.id=li.book_id AND b.deleted_at IS NULL
      JOIN public.profiles p ON p.id=li.borrower_profile_id AND p.deleted_at IS NULL
      WHERE li.school_id=sid AND li.deleted_at IS NULL AND li.returned_at IS NULL AND li.due_at<now()
      ORDER BY li.due_at LIMIT 30
    ) x),'[]'::jsonb)
  ) INTO result;
  RETURN result;
END; $$;

CREATE OR REPLACE FUNCTION public.issue_library_book(p_book_id uuid,p_borrower_profile_id uuid,p_due_at timestamptz,p_notes text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); book_school uuid; available_count integer; borrower_school uuid; saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_due_at<=now() THEN RAISE EXCEPTION 'due date must be in the future'; END IF;
  SELECT school_id,available_quantity INTO book_school,available_count FROM public.library_books
  WHERE id=p_book_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid) FOR UPDATE;
  IF book_school IS NULL THEN RAISE EXCEPTION 'book not found or not authorized'; END IF;
  IF available_count<=0 THEN RAISE EXCEPTION 'book is not currently available'; END IF;
  SELECT school_id INTO borrower_school FROM public.profiles WHERE id=p_borrower_profile_id AND deleted_at IS NULL AND status='active';
  IF borrower_school IS NULL OR borrower_school<>book_school THEN RAISE EXCEPTION 'borrower does not belong to this school'; END IF;
  INSERT INTO public.library_issues(school_id,book_id,borrower_profile_id,due_at,status,issued_by_profile_id,notes)
  VALUES(book_school,p_book_id,p_borrower_profile_id,p_due_at,'issued',public.get_active_profile_id(),p_notes)
  RETURNING to_jsonb(public.library_issues.*) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.return_library_book(p_issue_id uuid,p_notes text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); current_status text; issue_school uuid; saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT school_id,status INTO issue_school,current_status FROM public.library_issues
  WHERE id=p_issue_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid) FOR UPDATE;
  IF issue_school IS NULL THEN RAISE EXCEPTION 'library issue not found or not authorized'; END IF;
  IF current_status='returned' THEN RAISE EXCEPTION 'book has already been returned'; END IF;
  UPDATE public.library_issues SET status='returned',returned_at=COALESCE(returned_at,now()),received_by_profile_id=public.get_active_profile_id(),
    notes=COALESCE(p_notes,notes),updated_at=now() WHERE id=p_issue_id
  RETURNING to_jsonb(public.library_issues.*) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.create_library_fine(p_issue_id uuid,p_amount numeric,p_reason text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); issue_school uuid; saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_amount<0 THEN RAISE EXCEPTION 'fine amount cannot be negative'; END IF;
  SELECT school_id INTO issue_school FROM public.library_issues
  WHERE id=p_issue_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid);
  IF issue_school IS NULL THEN RAISE EXCEPTION 'library issue not found or not authorized'; END IF;
  INSERT INTO public.library_fines(school_id,issue_id,amount,status,reason)
  VALUES(issue_school,p_issue_id,p_amount,'unpaid',p_reason)
  RETURNING to_jsonb(public.library_fines.*) INTO saved;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_library_fine_paid(p_fine_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  UPDATE public.library_fines SET status='paid',paid_at=COALESCE(paid_at,now()),updated_at=now()
  WHERE id=p_fine_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid)
  RETURNING to_jsonb(public.library_fines.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'fine not found or not authorized'; END IF;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.get_behavior_dashboard()
RETURNS jsonb LANGUAGE plpgsql STABLE SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); range_start date; range_end date; result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT gt.start_date,gt.end_date INTO range_start,range_end
  FROM public.grading_terms gt JOIN public.academic_years ay ON ay.id=gt.academic_year_id AND ay.is_current=true AND ay.deleted_at IS NULL
  WHERE gt.school_id=sid AND gt.deleted_at IS NULL AND gt.start_date IS NOT NULL AND gt.end_date IS NOT NULL
    AND current_date BETWEEN gt.start_date AND gt.end_date ORDER BY gt.sequence NULLS LAST LIMIT 1;
  IF range_start IS NULL THEN
    SELECT ay.start_date,ay.end_date INTO range_start,range_end FROM public.academic_years ay
    WHERE ay.school_id=sid AND ay.is_current=true AND ay.deleted_at IS NULL ORDER BY ay.start_date DESC LIMIT 1;
  END IF;
  SELECT jsonb_build_object(
    'start_date',range_start,'end_date',range_end,
    'open_followups',(SELECT count(*) FROM public.behavioral_logs WHERE school_id=sid AND deleted_at IS NULL AND status='follow_up' AND incident_date BETWEEN range_start AND range_end),
    'resolved',(SELECT count(*) FROM public.behavioral_logs WHERE school_id=sid AND deleted_at IS NULL AND status='resolved' AND incident_date BETWEEN range_start AND range_end),
    'merit_notes',(SELECT count(*) FROM public.behavioral_logs WHERE school_id=sid AND deleted_at IS NULL AND type='merit' AND incident_date BETWEEN range_start AND range_end),
    'guardian_followup',(SELECT count(*) FROM public.behavioral_logs WHERE school_id=sid AND deleted_at IS NULL AND status IN ('open','follow_up') AND guardian_notified_at IS NULL AND incident_date BETWEEN range_start AND range_end),
    'incidents',COALESCE((SELECT jsonb_agg(to_jsonb(x) ORDER BY x.incident_date DESC,x.created_at DESC) FROM (
      SELECT bl.id,bl.student_profile_id,trim(concat_ws(' ',sp.first_name,sp.last_name)) student_name,bl.type,bl.severity,bl.status,bl.points,
             bl.description,bl.incident_date,trim(concat_ws(' ',rp.first_name,rp.last_name)) reported_by,bl.guardian_notified_at,bl.resolved_at,bl.created_at
      FROM public.behavioral_logs bl JOIN public.profiles sp ON sp.id=bl.student_profile_id AND sp.deleted_at IS NULL
      LEFT JOIN public.profiles rp ON rp.id=bl.logged_by_profile_id AND rp.deleted_at IS NULL
      WHERE bl.school_id=sid AND bl.deleted_at IS NULL ORDER BY bl.incident_date DESC,bl.created_at DESC LIMIT 100
    ) x),'[]'::jsonb)
  ) INTO result;
  RETURN result;
END; $$;

CREATE OR REPLACE FUNCTION public.update_behavior_case(p_behavior_id uuid,p_status text,p_follow_up_notes text DEFAULT NULL)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_status NOT IN ('open','follow_up','resolved') THEN RAISE EXCEPTION 'invalid behavior status'; END IF;
  UPDATE public.behavioral_logs SET status=p_status,follow_up_notes=COALESCE(p_follow_up_notes,follow_up_notes),
    resolved_at=CASE WHEN p_status='resolved' THEN COALESCE(resolved_at,now()) ELSE NULL END,
    resolved_by_profile_id=CASE WHEN p_status='resolved' THEN COALESCE(resolved_by_profile_id,public.get_active_profile_id()) ELSE NULL END,
    updated_at=now()
  WHERE id=p_behavior_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid)
  RETURNING to_jsonb(public.behavioral_logs.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'behavior record not found or not authorized'; END IF;
  RETURN saved;
END; $$;

CREATE OR REPLACE FUNCTION public.mark_behavior_guardian_notified(p_behavior_id uuid)
RETURNS jsonb LANGUAGE plpgsql SET search_path TO 'public' AS $$
DECLARE role_name text:=public.get_active_role()::text; sid uuid:=public.get_active_school_id(); saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','teacher','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  UPDATE public.behavioral_logs SET guardian_notified_at=COALESCE(guardian_notified_at,now()),updated_at=now()
  WHERE id=p_behavior_id AND deleted_at IS NULL AND (role_name='super_admin' OR school_id=sid)
  RETURNING to_jsonb(public.behavioral_logs.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'behavior record not found or not authorized'; END IF;
  RETURN saved;
END; $$;
