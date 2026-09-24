-- ZivoConnect finance dashboard: add authoritative per-currency invoice totals.
-- Existing scalar totals remain for backwards compatibility only. New Flutter
-- clients must render currency_totals and must not combine currencies.
-- Expenses are explicitly marked unscoped because the current expenses table
-- does not store a currency column.

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
  IF role_name NOT IN ('school_admin','finance_manager','super_admin') THEN
    RAISE EXCEPTION 'not authorized';
  END IF;

  SELECT id,start_date,end_date
  INTO ay_id,ay_start,ay_end
  FROM public.academic_years
  WHERE school_id=sid AND is_current=true AND deleted_at IS NULL
  ORDER BY start_date DESC
  LIMIT 1;

  WITH scoped_invoices AS (
    SELECT i.*
    FROM public.invoices i
    WHERE i.school_id=sid
      AND i.deleted_at IS NULL
      AND (ay_id IS NULL OR i.academic_year_id=ay_id)
  ),
  inv AS (
    SELECT
      COALESCE(sum(total_amount),0) total_invoiced,
      COALESCE(sum(paid_amount),0) total_paid,
      COALESCE(sum(total_amount-paid_amount),0) outstanding,
      COALESCE(sum(total_amount-paid_amount) FILTER (
        WHERE due_date < current_date AND status <> 'paid'
      ),0) overdue_amount,
      count(DISTINCT student_profile_id) FILTER (
        WHERE total_amount-paid_amount > 0
      ) outstanding_accounts
    FROM scoped_invoices
  ),
  inv_by_currency AS (
    SELECT
      COALESCE(NULLIF(trim(currency),''),'UNSPECIFIED') currency,
      round(COALESCE(sum(total_amount),0),2) total_invoiced,
      round(COALESCE(sum(paid_amount),0),2) total_paid,
      round(COALESCE(sum(total_amount-paid_amount),0),2) outstanding,
      round(COALESCE(sum(total_amount-paid_amount) FILTER (
        WHERE due_date < current_date AND status <> 'paid'
      ),0),2) overdue,
      count(DISTINCT student_profile_id) FILTER (
        WHERE total_amount-paid_amount > 0
      ) outstanding_accounts,
      CASE WHEN COALESCE(sum(total_amount),0) > 0
        THEN round((sum(paid_amount)/sum(total_amount))*100,1)
        ELSE 0 END collection_rate
    FROM scoped_invoices
    GROUP BY COALESCE(NULLIF(trim(currency),''),'UNSPECIFIED')
  ),
  payment_mix AS (
    SELECT
      COALESCE(NULLIF(p.provider,''),NULLIF(p.payment_method,''),'Other') method,
      sum(p.amount) amount
    FROM public.payments p
    WHERE p.school_id=sid
      AND p.status='confirmed'
      AND p.deleted_at IS NULL
      AND (ay_start IS NULL OR p.paid_at::date >= ay_start)
      AND (ay_end IS NULL OR p.paid_at::date <= ay_end)
    GROUP BY 1
  ),
  payment_mix_total AS (
    SELECT COALESCE(sum(amount),0) total FROM payment_mix
  ),
  attention AS (
    SELECT
      i.id invoice_id,
      i.invoice_number,
      i.student_profile_id,
      trim(concat_ws(' ',sp.first_name,sp.last_name)) student_name,
      c.name class_name,
      trim(concat_ws(' ',gp.first_name,gp.last_name)) guardian_name,
      i.currency,
      round(i.total_amount-i.paid_amount,2) balance,
      i.due_date,
      CASE
        WHEN i.due_date < current_date THEN 'overdue'
        WHEN i.due_date <= current_date + 7 THEN 'due_soon'
        ELSE 'outstanding'
      END attention_status
    FROM scoped_invoices i
    JOIN public.profiles sp ON sp.id=i.student_profile_id AND sp.deleted_at IS NULL
    LEFT JOIN public.student_enrollments se
      ON se.student_profile_id=i.student_profile_id
     AND se.academic_year_id=i.academic_year_id
     AND se.status='active' AND se.deleted_at IS NULL
    LEFT JOIN public.class_sections cs ON cs.id=se.class_section_id AND cs.deleted_at IS NULL
    LEFT JOIN public.classes c ON c.id=cs.class_id AND c.deleted_at IS NULL
    LEFT JOIN LATERAL (
      SELECT ur.parent_id
      FROM public.user_relationships ur
      WHERE ur.student_id=i.student_profile_id AND ur.deleted_at IS NULL
      ORDER BY ur.created_at
      LIMIT 1
    ) rel ON true
    LEFT JOIN public.profiles gp ON gp.id=rel.parent_id AND gp.deleted_at IS NULL
    WHERE i.total_amount-i.paid_amount > 0
    ORDER BY
      CASE WHEN i.due_date < current_date THEN 0
           WHEN i.due_date <= current_date+7 THEN 1 ELSE 2 END,
      i.due_date,
      (i.total_amount-i.paid_amount) DESC
    LIMIT 12
  )
  SELECT jsonb_build_object(
    'academic_year_id', ay_id,
    'total_invoiced', inv.total_invoiced,
    'total_paid', inv.total_paid,
    'outstanding', inv.outstanding,
    'overdue', inv.overdue_amount,
    'collection_rate',
      CASE WHEN inv.total_invoiced > 0
        THEN round((inv.total_paid/inv.total_invoiced)*100,1)
        ELSE 0 END,
    'outstanding_accounts', inv.outstanding_accounts,
    'currency_count', (SELECT count(*) FROM inv_by_currency),
    'currency_totals', COALESCE((
      SELECT jsonb_agg(to_jsonb(x) ORDER BY x.currency)
      FROM inv_by_currency x
    ), '[]'::jsonb),
    'expenses_this_month', COALESCE((
      SELECT sum(e.amount) FROM public.expenses e
      WHERE e.school_id=sid
        AND e.deleted_at IS NULL
        AND e.spent_at >= date_trunc('month',current_date)::date
        AND e.spent_at < (date_trunc('month',current_date)+interval '1 month')::date
    ),0),
    'expenses_currency_scoped', false,
    'payments_today', COALESCE((
      SELECT sum(p.amount) FROM public.payments p
      WHERE p.school_id=sid AND p.status='confirmed' AND p.deleted_at IS NULL
        AND p.paid_at::date=current_date
    ),0),
    'transactions_today', (
      SELECT count(*) FROM public.payments p
      WHERE p.school_id=sid AND p.status='confirmed' AND p.deleted_at IS NULL
        AND p.paid_at::date=current_date
    ),
    'payments_this_week', COALESCE((
      SELECT sum(p.amount) FROM public.payments p
      WHERE p.school_id=sid AND p.status='confirmed' AND p.deleted_at IS NULL
        AND p.paid_at >= date_trunc('week',now())
    ),0),
    'pending_review', (
      SELECT count(*) FROM public.payments p
      WHERE p.school_id=sid AND p.deleted_at IS NULL
        AND p.status='pending' AND p.invoice_id IS NULL
    ),
    'reversed_this_month', (
      SELECT count(*) FROM public.payments p
      WHERE p.school_id=sid AND p.deleted_at IS NULL
        AND p.status='reversed'
        AND p.paid_at >= date_trunc('month',now())
    ),
    'payment_methods', COALESCE((
      SELECT jsonb_agg(jsonb_build_object(
        'method',pm.method,
        'amount',round(pm.amount,2),
        'percent',CASE WHEN pmt.total>0 THEN round((pm.amount/pmt.total)*100,1) ELSE 0 END
      ) ORDER BY pm.amount DESC)
      FROM payment_mix pm CROSS JOIN payment_mix_total pmt
    ),'[]'::jsonb),
    'accounts_requiring_attention', COALESCE((
      SELECT jsonb_agg(to_jsonb(a)) FROM attention a
    ),'[]'::jsonb)
  )
  INTO result
  FROM inv;

  RETURN result;
END;
$$;
