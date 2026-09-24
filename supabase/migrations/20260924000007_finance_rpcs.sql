-- ZivoConnect live backend reconciliation: finance RPCs.

CREATE OR REPLACE FUNCTION public.generate_invoices_from_fee_structure(
  p_fee_structure_id uuid,
  p_due_date date DEFAULT NULL,
  p_include_optional boolean DEFAULT false
)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  fs_school uuid;
  fs_year uuid;
  fs_class uuid;
  fs_section uuid;
  fs_currency text;
  fs_due date;
  fs_status text;
  fs_name text;
  due_value date;
  rec record;
  invoice_id_value uuid;
  created_count integer:=0;
  skipped_count integer:=0;
  created_ids uuid[]:=ARRAY[]::uuid[];
BEGIN
  IF role_name NOT IN ('school_admin','finance_manager','super_admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT school_id,academic_year_id,class_id,class_section_id,
         currency,default_due_date,status,name
  INTO fs_school,fs_year,fs_class,fs_section,
       fs_currency,fs_due,fs_status,fs_name
  FROM public.fee_structures
  WHERE id=p_fee_structure_id
    AND deleted_at IS NULL
    AND (role_name='super_admin' OR school_id=sid);

  IF fs_school IS NULL THEN
    RAISE EXCEPTION 'fee structure not found or not authorized';
  END IF;

  IF fs_status<>'active' THEN
    RAISE EXCEPTION 'fee structure must be active before invoice generation';
  END IF;

  due_value:=COALESCE(p_due_date,fs_due);
  IF due_value IS NULL THEN RAISE EXCEPTION 'a due date is required'; END IF;

  IF NOT EXISTS (
    SELECT 1 FROM public.fee_structure_items fsi
    WHERE fsi.fee_structure_id=p_fee_structure_id
      AND fsi.deleted_at IS NULL
      AND (p_include_optional OR fsi.is_required)
  ) THEN
    RAISE EXCEPTION 'fee structure has no billable items';
  END IF;

  FOR rec IN
    SELECT DISTINCT se.student_profile_id
    FROM public.student_enrollments se
    JOIN public.class_sections cs ON cs.id=se.class_section_id AND cs.deleted_at IS NULL
    JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    WHERE se.school_id=fs_school
      AND se.academic_year_id=fs_year
      AND se.status='active'
      AND se.deleted_at IS NULL
      AND (fs_section IS NULL OR se.class_section_id=fs_section)
      AND (fs_class IS NULL OR c.id=fs_class)
    ORDER BY se.student_profile_id
  LOOP
    invoice_id_value:=NULL;

    INSERT INTO public.invoices(
      school_id,student_profile_id,academic_year_id,total_amount,paid_amount,due_date,status,
      invoice_number,currency,fee_structure_id,notes
    )
    VALUES(
      fs_school,rec.student_profile_id,fs_year,0,0,due_value,'unpaid',
      'INV-'||upper(substr(replace(gen_random_uuid()::text,'-',''),1,12)),
      fs_currency,p_fee_structure_id,'Generated from fee structure: '||fs_name
    )
    ON CONFLICT (student_profile_id,fee_structure_id)
      WHERE deleted_at IS NULL AND fee_structure_id IS NOT NULL
    DO NOTHING
    RETURNING id INTO invoice_id_value;

    IF invoice_id_value IS NULL THEN
      skipped_count:=skipped_count+1;
      CONTINUE;
    END IF;

    INSERT INTO public.invoice_items(school_id,invoice_id,fee_type_id,amount)
    SELECT fs_school,invoice_id_value,fsi.fee_type_id,fsi.amount
    FROM public.fee_structure_items fsi
    WHERE fsi.fee_structure_id=p_fee_structure_id
      AND fsi.deleted_at IS NULL
      AND (p_include_optional OR fsi.is_required)
    ORDER BY fsi.sort_order,fsi.created_at;

    PERFORM public.recalculate_invoice_totals(invoice_id_value);
    created_count:=created_count+1;
    created_ids:=array_append(created_ids,invoice_id_value);
  END LOOP;

  RETURN jsonb_build_object(
    'fee_structure_id',p_fee_structure_id,
    'academic_year_id',fs_year,
    'currency',fs_currency,
    'due_date',due_value,
    'created_count',created_count,
    'skipped_existing_count',skipped_count,
    'invoice_ids',to_jsonb(created_ids)
  );
END;
$$;

CREATE OR REPLACE FUNCTION public.reconcile_payment_to_invoice(p_payment_id uuid, p_invoice_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SET search_path TO 'public'
AS $$
DECLARE
  role_name text := public.get_active_role()::text;
  payment_school uuid;
  invoice_school uuid;
  payment_currency text;
  invoice_currency text;
  saved jsonb;
BEGIN
  IF role_name NOT IN ('finance_manager','school_admin','super_admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT school_id, currency INTO payment_school, payment_currency
  FROM public.payments
  WHERE id=p_payment_id AND deleted_at IS NULL
  FOR UPDATE;

  SELECT school_id, currency INTO invoice_school, invoice_currency
  FROM public.invoices
  WHERE id=p_invoice_id AND deleted_at IS NULL;

  IF payment_school IS NULL OR invoice_school IS NULL THEN RAISE EXCEPTION 'payment or invoice not found'; END IF;
  IF payment_school <> invoice_school THEN RAISE EXCEPTION 'cross-school reconciliation is not allowed'; END IF;
  IF payment_currency <> invoice_currency THEN RAISE EXCEPTION 'payment and invoice currencies do not match'; END IF;

  UPDATE public.payments
     SET invoice_id=p_invoice_id,status='confirmed',updated_at=now()
   WHERE id=p_payment_id
   RETURNING to_jsonb(public.payments.*) INTO saved;

  RETURN saved;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_finance_dashboard_metrics()
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  sid uuid := public.get_active_school_id();
  role_name text := public.get_active_role()::text;
  ay_id uuid;
  ay_start date;
  ay_end date;
  result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','finance_manager','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;

  SELECT id,start_date,end_date INTO ay_id,ay_start,ay_end
  FROM public.academic_years
  WHERE school_id=sid AND is_current=true AND deleted_at IS NULL
  ORDER BY start_date DESC LIMIT 1;

  WITH scoped_invoices AS (
    SELECT i.* FROM public.invoices i
    WHERE i.school_id=sid AND i.deleted_at IS NULL
      AND (ay_id IS NULL OR i.academic_year_id=ay_id)
  ),
  inv AS (
    SELECT COALESCE(sum(total_amount),0) total_invoiced,
           COALESCE(sum(paid_amount),0) total_paid,
           COALESCE(sum(total_amount-paid_amount),0) outstanding,
           COALESCE(sum(total_amount-paid_amount) FILTER (WHERE due_date < current_date AND status <> 'paid'),0) overdue_amount,
           count(DISTINCT student_profile_id) FILTER (WHERE total_amount-paid_amount > 0) outstanding_accounts
    FROM scoped_invoices
  ),
  payment_mix AS (
    SELECT COALESCE(NULLIF(p.provider,''),NULLIF(p.payment_method,''),'Other') method,sum(p.amount) amount
    FROM public.payments p
    WHERE p.school_id=sid AND p.status='confirmed' AND p.deleted_at IS NULL
      AND (ay_start IS NULL OR p.paid_at::date >= ay_start)
      AND (ay_end IS NULL OR p.paid_at::date <= ay_end)
    GROUP BY 1
  ),
  payment_mix_total AS (SELECT COALESCE(sum(amount),0) total FROM payment_mix),
  attention AS (
    SELECT i.id invoice_id,i.invoice_number,i.student_profile_id,
           trim(concat_ws(' ',sp.first_name,sp.last_name)) student_name,
           c.name class_name,trim(concat_ws(' ',gp.first_name,gp.last_name)) guardian_name,
           i.currency,round(i.total_amount-i.paid_amount,2) balance,i.due_date,
           CASE WHEN i.due_date < current_date THEN 'overdue'
                WHEN i.due_date <= current_date + 7 THEN 'due_soon'
                ELSE 'outstanding' END attention_status
    FROM scoped_invoices i
    JOIN public.profiles sp ON sp.id=i.student_profile_id AND sp.deleted_at IS NULL
    LEFT JOIN public.student_enrollments se ON se.student_profile_id=i.student_profile_id AND se.academic_year_id=i.academic_year_id AND se.status='active' AND se.deleted_at IS NULL
    LEFT JOIN public.class_sections cs ON cs.id=se.class_section_id AND cs.deleted_at IS NULL
    LEFT JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    LEFT JOIN LATERAL (
      SELECT ur.parent_id FROM public.user_relationships ur
      WHERE ur.student_id=i.student_profile_id AND ur.deleted_at IS NULL
      ORDER BY ur.created_at LIMIT 1
    ) rel ON true
    LEFT JOIN public.profiles gp ON gp.id=rel.parent_id AND gp.deleted_at IS NULL
    WHERE i.total_amount-i.paid_amount > 0
    ORDER BY CASE WHEN i.due_date < current_date THEN 0 WHEN i.due_date <= current_date+7 THEN 1 ELSE 2 END,
             i.due_date,(i.total_amount-i.paid_amount) DESC
    LIMIT 12
  )
  SELECT jsonb_build_object(
    'academic_year_id',ay_id,
    'total_invoiced',inv.total_invoiced,
    'total_paid',inv.total_paid,
    'outstanding',inv.outstanding,
    'overdue',inv.overdue_amount,
    'collection_rate',CASE WHEN inv.total_invoiced > 0 THEN round((inv.total_paid/inv.total_invoiced)*100,1) ELSE 0 END,
    'outstanding_accounts',inv.outstanding_accounts,
    'expenses_this_month',COALESCE((SELECT sum(e.amount) FROM public.expenses e WHERE e.school_id=sid AND e.deleted_at IS NULL AND e.spent_at >= date_trunc('month',current_date)::date AND e.spent_at < (date_trunc('month',current_date)+interval '1 month')::date),0),
    'payments_today',COALESCE((SELECT sum(p.amount) FROM public.payments p WHERE p.school_id=sid AND p.status='confirmed' AND p.deleted_at IS NULL AND p.paid_at::date=current_date),0),
    'transactions_today',(SELECT count(*) FROM public.payments p WHERE p.school_id=sid AND p.status='confirmed' AND p.deleted_at IS NULL AND p.paid_at::date=current_date),
    'payments_this_week',COALESCE((SELECT sum(p.amount) FROM public.payments p WHERE p.school_id=sid AND p.status='confirmed' AND p.deleted_at IS NULL AND p.paid_at >= date_trunc('week',now())),0),
    'pending_review',(SELECT count(*) FROM public.payments p WHERE p.school_id=sid AND p.deleted_at IS NULL AND p.status='pending' AND p.invoice_id IS NULL),
    'reversed_this_month',(SELECT count(*) FROM public.payments p WHERE p.school_id=sid AND p.deleted_at IS NULL AND p.status='reversed' AND p.paid_at >= date_trunc('month',now())),
    'payment_methods',COALESCE((SELECT jsonb_agg(jsonb_build_object('method',pm.method,'amount',round(pm.amount,2),'percent',CASE WHEN pmt.total>0 THEN round((pm.amount/pmt.total)*100,1) ELSE 0 END) ORDER BY pm.amount DESC) FROM payment_mix pm CROSS JOIN payment_mix_total pmt),'[]'::jsonb),
    'accounts_requiring_attention',COALESCE((SELECT jsonb_agg(to_jsonb(a)) FROM attention a),'[]'::jsonb)
  ) INTO result FROM inv;

  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_fee_collections_report(
  p_academic_year_id uuid,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE plpgsql
STABLE
SET search_path TO 'public'
AS $$
DECLARE
  role_name text:=public.get_active_role()::text;
  sid uuid:=public.get_active_school_id();
  ay_start date; ay_end date; from_date date; to_date date; result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','finance_manager','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  SELECT start_date,end_date INTO ay_start,ay_end FROM public.academic_years
  WHERE id=p_academic_year_id AND school_id=sid AND deleted_at IS NULL;
  IF ay_start IS NULL THEN RAISE EXCEPTION 'academic year not found or not authorized'; END IF;
  from_date:=COALESCE(p_start_date,ay_start); to_date:=COALESCE(p_end_date,ay_end);
  IF from_date>to_date THEN RAISE EXCEPTION 'start date must be before or equal to end date'; END IF;

  WITH invoices_scope AS (
    SELECT * FROM public.invoices WHERE school_id=sid AND academic_year_id=p_academic_year_id AND deleted_at IS NULL
  ), payments_scope AS (
    SELECT p.* FROM public.payments p LEFT JOIN public.invoices i ON i.id=p.invoice_id
    WHERE p.school_id=sid AND p.deleted_at IS NULL AND p.status='confirmed'
      AND p.paid_at::date BETWEEN from_date AND to_date
      AND (p.invoice_id IS NULL OR i.academic_year_id=p_academic_year_id)
  ), by_currency AS (
    SELECT i.currency,COALESCE(sum(i.total_amount),0) invoiced,COALESCE(sum(i.paid_amount),0) paid,
           COALESCE(sum(i.total_amount-i.paid_amount),0) outstanding,
           COALESCE(sum(i.total_amount-i.paid_amount) FILTER (WHERE i.due_date<current_date AND i.status<>'paid'),0) overdue
    FROM invoices_scope i GROUP BY i.currency
  ), methods AS (
    SELECT p.currency,COALESCE(NULLIF(p.provider,''),NULLIF(p.payment_method,''),'Other') method,count(*) transactions,sum(p.amount) amount
    FROM payments_scope p GROUP BY p.currency,1
  ), daily AS (
    SELECT p.paid_at::date payment_date,p.currency,count(*) transactions,sum(p.amount) amount
    FROM payments_scope p GROUP BY p.paid_at::date,p.currency
  ), top_debtors AS (
    SELECT i.student_profile_id,trim(concat_ws(' ',sp.first_name,sp.last_name)) student_name,i.currency,
           round(sum(i.total_amount-i.paid_amount),2) outstanding,
           min(i.due_date) FILTER (WHERE i.status<>'paid') earliest_due_date
    FROM invoices_scope i JOIN public.profiles sp ON sp.id=i.student_profile_id AND sp.deleted_at IS NULL
    WHERE i.total_amount-i.paid_amount>0
    GROUP BY i.student_profile_id,sp.first_name,sp.last_name,i.currency
    ORDER BY outstanding DESC LIMIT 20
  )
  SELECT jsonb_build_object(
    'academic_year_id',p_academic_year_id,'start_date',from_date,'end_date',to_date,
    'by_currency',COALESCE((SELECT jsonb_agg(jsonb_build_object('currency',bc.currency,'invoiced',round(bc.invoiced,2),'paid',round(bc.paid,2),'outstanding',round(bc.outstanding,2),'overdue',round(bc.overdue,2),'collection_rate',CASE WHEN bc.invoiced>0 THEN round((bc.paid/bc.invoiced)*100,1) ELSE 0 END) ORDER BY bc.currency) FROM by_currency bc),'[]'::jsonb),
    'payment_methods',COALESCE((SELECT jsonb_agg(jsonb_build_object('currency',m.currency,'method',m.method,'transactions',m.transactions,'amount',round(m.amount,2)) ORDER BY m.currency,m.amount DESC) FROM methods m),'[]'::jsonb),
    'daily_collections',COALESCE((SELECT jsonb_agg(jsonb_build_object('date',d.payment_date,'currency',d.currency,'transactions',d.transactions,'amount',round(d.amount,2)) ORDER BY d.payment_date,d.currency) FROM daily d),'[]'::jsonb),
    'top_outstanding_accounts',COALESCE((SELECT jsonb_agg(to_jsonb(td) ORDER BY td.outstanding DESC) FROM top_debtors td),'[]'::jsonb)
  ) INTO result;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_fee_collections_report(
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
  sid uuid:=public.get_active_school_id(); result jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','finance_manager','registrar','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF NOT EXISTS (SELECT 1 FROM public.academic_years ay WHERE ay.id=p_academic_year_id AND ay.school_id=sid AND ay.deleted_at IS NULL) THEN
    RAISE EXCEPTION 'academic year not found or not authorized';
  END IF;

  WITH enroll AS (
    SELECT DISTINCT se.student_profile_id,se.class_section_id,c.name class_name,cs.name section_name
    FROM public.student_enrollments se
    JOIN public.class_sections cs ON cs.id=se.class_section_id AND cs.deleted_at IS NULL
    JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    WHERE se.school_id=sid AND se.academic_year_id=p_academic_year_id AND se.status='active' AND se.deleted_at IS NULL
  ), scoped_invoices AS (
    SELECT i.*,fs.term_id,e.class_section_id,e.class_name,e.section_name
    FROM public.invoices i
    LEFT JOIN public.fee_structures fs ON fs.id=i.fee_structure_id AND fs.deleted_at IS NULL
    LEFT JOIN enroll e ON e.student_profile_id=i.student_profile_id
    WHERE i.school_id=sid AND i.academic_year_id=p_academic_year_id AND i.deleted_at IS NULL
      AND (p_term_id IS NULL OR fs.term_id=p_term_id)
      AND (p_class_section_id IS NULL OR e.class_section_id=p_class_section_id)
  ), currency_rows AS (
    SELECT currency,count(*) invoices,count(DISTINCT student_profile_id) accounts,
           round(sum(total_amount),2) total_invoiced,round(sum(paid_amount),2) total_paid,
           round(sum(total_amount-paid_amount),2) outstanding,
           round(COALESCE(sum(total_amount-paid_amount) FILTER (WHERE due_date<current_date AND status<>'paid'),0),2) overdue,
           CASE WHEN sum(total_amount)>0 THEN round((sum(paid_amount)/sum(total_amount))*100,1) ELSE 0 END collection_rate
    FROM scoped_invoices GROUP BY currency
  ), class_rows AS (
    SELECT class_section_id,max(class_name) class_name,max(section_name) section_name,currency,
           count(*) invoices,count(DISTINCT student_profile_id) accounts,round(sum(total_amount),2) total_invoiced,
           round(sum(paid_amount),2) total_paid,round(sum(total_amount-paid_amount),2) outstanding,
           CASE WHEN sum(total_amount)>0 THEN round((sum(paid_amount)/sum(total_amount))*100,1) ELSE 0 END collection_rate
    FROM scoped_invoices GROUP BY class_section_id,currency
  ), method_rows AS (
    SELECT p.currency,COALESCE(NULLIF(p.provider,''),NULLIF(p.payment_method,''),'Other') method,
           count(*) transactions,round(sum(p.amount),2) amount
    FROM public.payments p JOIN scoped_invoices i ON i.id=p.invoice_id
    WHERE p.deleted_at IS NULL AND p.status='confirmed'
    GROUP BY p.currency,COALESCE(NULLIF(p.provider,''),NULLIF(p.payment_method,''),'Other')
  )
  SELECT jsonb_build_object(
    'academic_year_id',p_academic_year_id,'term_id',p_term_id,'class_section_id',p_class_section_id,
    'currencies',COALESCE((SELECT jsonb_agg(to_jsonb(cr) ORDER BY cr.currency) FROM currency_rows cr),'[]'::jsonb),
    'classes',COALESCE((SELECT jsonb_agg(to_jsonb(cr) ORDER BY cr.class_name,cr.section_name,cr.currency) FROM class_rows cr),'[]'::jsonb),
    'payment_methods',COALESCE((SELECT jsonb_agg(to_jsonb(mr) ORDER BY mr.currency,mr.amount DESC) FROM method_rows mr),'[]'::jsonb),
    'data_quality',jsonb_build_object(
      'invoices_without_fee_structure',(SELECT count(*) FROM public.invoices i WHERE i.school_id=sid AND i.academic_year_id=p_academic_year_id AND i.deleted_at IS NULL AND i.fee_structure_id IS NULL),
      'term_filter_excludes_unscoped_invoices',p_term_id IS NOT NULL
    )
  ) INTO result;
  RETURN result;
END;
$$;

CREATE OR REPLACE FUNCTION public.get_fee_collections_report_by_date(
  p_academic_year_id uuid,
  p_start_date date DEFAULT NULL,
  p_end_date date DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  SELECT public.get_fee_collections_report(p_academic_year_id,p_start_date,p_end_date);
$$;

CREATE OR REPLACE FUNCTION public.get_fee_collections_report_by_scope(
  p_academic_year_id uuid,
  p_term_id uuid DEFAULT NULL,
  p_class_section_id uuid DEFAULT NULL
)
RETURNS jsonb
LANGUAGE sql
STABLE
SET search_path TO 'public'
AS $$
  SELECT public.get_fee_collections_report(p_academic_year_id,p_term_id,p_class_section_id);
$$;
