-- ZivoConnect live backend reconciliation: atomic Marketplace RPCs.

CREATE OR REPLACE FUNCTION public.place_marketplace_order(p_items jsonb)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  pid uuid:=public.get_active_profile_id();
  sid uuid:=public.get_active_school_id();
  buyer_school uuid;
  order_currency text;
  rec record;
  item_school uuid;
  item_status text;
  item_stock integer;
  item_price numeric;
  order_total numeric:=0;
  order_id_value uuid;
  saved jsonb;
BEGIN
  IF auth.uid() IS NULL OR pid IS NULL OR sid IS NULL THEN RAISE EXCEPTION 'authenticated active profile is required'; END IF;
  IF p_items IS NULL OR jsonb_typeof(p_items)<>'array' OR jsonb_array_length(p_items)=0 THEN RAISE EXCEPTION 'order must contain at least one item'; END IF;

  SELECT school_id INTO buyer_school FROM public.profiles
  WHERE id=pid AND user_id=auth.uid() AND deleted_at IS NULL AND status='active';
  IF buyer_school IS NULL OR buyer_school<>sid THEN RAISE EXCEPTION 'active buyer profile is invalid'; END IF;
  SELECT default_currency INTO order_currency FROM public.schools WHERE id=sid AND deleted_at IS NULL;

  FOR rec IN
    SELECT (e->>'item_id')::uuid item_id,sum((e->>'quantity')::integer)::integer quantity
    FROM jsonb_array_elements(p_items) e GROUP BY (e->>'item_id')::uuid ORDER BY ((e->>'item_id')::uuid)::text
  LOOP
    IF rec.quantity<=0 THEN RAISE EXCEPTION 'item quantity must be positive'; END IF;
    SELECT school_id,status,stock_quantity,price INTO item_school,item_status,item_stock,item_price
    FROM public.marketplace_items WHERE id=rec.item_id AND deleted_at IS NULL FOR UPDATE;
    IF item_school IS NULL OR item_school<>sid THEN RAISE EXCEPTION 'marketplace item not found or belongs to another school'; END IF;
    IF item_status<>'available' THEN RAISE EXCEPTION 'marketplace item % is not available',rec.item_id; END IF;
    IF item_stock<rec.quantity THEN RAISE EXCEPTION 'insufficient stock for marketplace item %',rec.item_id; END IF;
    order_total:=order_total+(item_price*rec.quantity);
  END LOOP;

  INSERT INTO public.marketplace_orders(school_id,buyer_profile_id,total_amount,status,currency,payment_status,fulfillment_status)
  VALUES(sid,pid,order_total,'pending',COALESCE(order_currency,'USD'),'unpaid','pending')
  RETURNING id INTO order_id_value;

  FOR rec IN
    SELECT (e->>'item_id')::uuid item_id,sum((e->>'quantity')::integer)::integer quantity
    FROM jsonb_array_elements(p_items) e GROUP BY (e->>'item_id')::uuid ORDER BY ((e->>'item_id')::uuid)::text
  LOOP
    SELECT price INTO item_price FROM public.marketplace_items WHERE id=rec.item_id FOR UPDATE;
    INSERT INTO public.marketplace_order_items(school_id,order_id,item_id,quantity,price_at_purchase)
    VALUES(sid,order_id_value,rec.item_id,rec.quantity,item_price);
    UPDATE public.marketplace_items
      SET stock_quantity=stock_quantity-rec.quantity,
          status=CASE WHEN stock_quantity-rec.quantity<=0 THEN 'sold_out' ELSE status END,
          updated_at=now()
    WHERE id=rec.item_id;
  END LOOP;

  SELECT jsonb_build_object(
    'order',to_jsonb(o),
    'items',COALESCE((SELECT jsonb_agg(to_jsonb(oi) ORDER BY oi.created_at)
                      FROM public.marketplace_order_items oi
                      WHERE oi.order_id=o.id AND oi.deleted_at IS NULL),'[]'::jsonb)
  ) INTO saved
  FROM public.marketplace_orders o WHERE o.id=order_id_value;
  RETURN saved;
END;
$$;

CREATE OR REPLACE FUNCTION public.cancel_marketplace_order(p_order_id uuid)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE
  pid uuid:=public.get_active_profile_id();
  sid uuid:=public.get_active_school_id();
  role_name text:=public.get_active_role()::text;
  order_school uuid;
  buyer_id uuid;
  payment_state text;
  order_state text;
  rec record;
  saved jsonb;
BEGIN
  IF auth.uid() IS NULL OR pid IS NULL THEN RAISE EXCEPTION 'authenticated active profile is required'; END IF;
  SELECT school_id,buyer_profile_id,payment_status,status
  INTO order_school,buyer_id,payment_state,order_state
  FROM public.marketplace_orders WHERE id=p_order_id AND deleted_at IS NULL FOR UPDATE;
  IF order_school IS NULL
     OR (buyer_id<>pid AND role_name NOT IN ('school_admin','super_admin'))
     OR (role_name<>'super_admin' AND order_school<>sid) THEN
    RAISE EXCEPTION 'order not found or not authorized';
  END IF;
  IF order_state='cancelled' THEN RAISE EXCEPTION 'order is already cancelled'; END IF;
  IF payment_state NOT IN ('unpaid','failed') THEN
    RAISE EXCEPTION 'paid or pending-payment orders require payment-provider cancellation/refund handling';
  END IF;

  FOR rec IN
    SELECT item_id,quantity FROM public.marketplace_order_items
    WHERE order_id=p_order_id AND deleted_at IS NULL ORDER BY item_id::text
  LOOP
    UPDATE public.marketplace_items
       SET stock_quantity=stock_quantity+rec.quantity,
           status=CASE WHEN status='sold_out' THEN 'available' ELSE status END,
           updated_at=now()
     WHERE id=rec.item_id;
  END LOOP;

  UPDATE public.marketplace_orders
     SET status='cancelled',fulfillment_status='cancelled',updated_at=now()
   WHERE id=p_order_id
   RETURNING to_jsonb(public.marketplace_orders.*) INTO saved;
  RETURN saved;
END;
$$;

CREATE OR REPLACE FUNCTION public.set_marketplace_fulfillment_status(p_order_id uuid,p_fulfillment_status text)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path TO 'public'
AS $$
DECLARE sid uuid:=public.get_active_school_id(); role_name text:=public.get_active_role()::text; saved jsonb;
BEGIN
  IF role_name NOT IN ('school_admin','super_admin') THEN RAISE EXCEPTION 'not authorized'; END IF;
  IF p_fulfillment_status NOT IN ('pending','processing','ready','collected') THEN RAISE EXCEPTION 'invalid fulfillment status'; END IF;
  UPDATE public.marketplace_orders
     SET fulfillment_status=p_fulfillment_status,
         status=CASE WHEN p_fulfillment_status='collected' THEN 'completed' ELSE status END,
         updated_at=now()
   WHERE id=p_order_id AND deleted_at IS NULL AND status<>'cancelled'
     AND (role_name='super_admin' OR school_id=sid)
   RETURNING to_jsonb(public.marketplace_orders.*) INTO saved;
  IF saved IS NULL THEN RAISE EXCEPTION 'order not found or not authorized'; END IF;
  RETURN saved;
END;
$$;
