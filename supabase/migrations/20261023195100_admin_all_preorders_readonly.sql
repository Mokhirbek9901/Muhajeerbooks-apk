-- Read-only and paginated historical native preorders for iOS TestFlight admin.
-- No order state, stock, receipts or customer messages are modified.
create or replace function public.admin_preorders_all_list(
  p_secret text, p_limit integer default 200, p_offset integer default 0
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_rows jsonb; v_total integer;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_limit is null or p_limit not between 1 and 200 or
     p_offset is null or p_offset < 0 then
    raise exception 'Sahifalash parametrlari noto‘g‘ri';
  end if;
  select count(*)::integer into v_total from public.preorders;
  select coalesce(
    jsonb_agg(to_jsonb(t) order by t.created_at desc, t.id desc),
    '[]'::jsonb
  ) into v_rows
  from (
    select p.id, p.book_id, coalesce(b.title,'Kitob') as title,
      p.customer_name, p.phone, p.quantity, p.status,
      p.deposit_amount, p.payment_proof_path, p.note,
      coalesce(b.preorder_arrival_note,'') as arrival_note,
      p.created_at
    from public.preorders p
    left join public.books b on b.id=p.book_id
    order by p.created_at desc,p.id desc
    limit p_limit offset p_offset
  ) as t;
  return jsonb_build_object('rows',v_rows,'total',v_total);
end;
$$;

revoke all on function public.admin_preorders_all_list(text,integer,integer)
  from public, anon, authenticated;
grant execute on function public.admin_preorders_all_list(text,integer,integer)
  to service_role;
