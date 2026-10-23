-- Increment receiving, never replace stock absolute value. The existing BEFORE
-- UPDATE reservation trigger automatically assigns accepted preorders first.
create or replace function public.admin_preorder_receive_batch(
  p_secret text, p_book_id uuid, p_quantity integer
) returns jsonb language plpgsql security definer set search_path=''
as $$
declare v_book public.books%rowtype; v_reserved integer;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q'; end if;
  if p_book_id is null or p_quantity is null or p_quantity not between 1 and 2000 then
    raise exception 'Yangi partiya soni 1–2000 oralig‘ida bo‘lsin';
  end if;
  select * into v_book from public.books where id=p_book_id for update;
  if not found then raise exception 'Kitob topilmadi'; end if;
  if v_book.stock>1000000-p_quantity then raise exception 'Ombor soni juda katta'; end if;
  update public.books set stock=stock+p_quantity
    where id=p_book_id returning * into v_book;
  select coalesce(sum(h.quantity),0) into v_reserved
    from private.preorder_stock_holds h
    where h.book_id=p_book_id;
  return jsonb_build_object('book_id',p_book_id,'received',p_quantity,
    'available_stock',v_book.stock,'preorders_reserved_total',v_reserved);
end;
$$;
revoke all on function public.admin_preorder_receive_batch(text,uuid,integer)
 from public,anon,authenticated;
grant execute on function public.admin_preorder_receive_batch(text,uuid,integer)
 to service_role;
