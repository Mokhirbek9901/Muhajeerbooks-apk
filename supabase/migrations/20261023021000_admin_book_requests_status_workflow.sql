-- Book requests already have new/reviewed/ordered/fulfilled states.
-- Add scoped admin read/update only; no customer SMS, deletions or bulk changes.
create or replace function public.admin_book_requests_list(p_secret text)
returns jsonb language plpgsql security definer set search_path = ''
as $$
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  return coalesce(
    (select jsonb_agg(
      jsonb_build_object(
        'id',r.id,'title',r.title,'author',r.author,
        'phone',r.phone,'status',r.status,'created_at',r.created_at
      ) order by r.created_at desc
    ) from (select * from public.book_requests order by created_at desc limit 500) r),
    '[]'::jsonb
  );
end;
$$;

create or replace function public.admin_book_request_set_status(
  p_secret text, p_id bigint, p_status text
) returns jsonb language plpgsql security definer set search_path = ''
as $$
declare v_id bigint;
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_status not in ('new','reviewed','ordered','fulfilled') then
    raise exception 'Noto‘g‘ri holat';
  end if;
  update public.book_requests
    set status=p_status
    where id=p_id
    returning id into v_id;
  if v_id is null then raise exception 'So‘rov topilmadi'; end if;
  return jsonb_build_object('id',v_id,'status',p_status);
end;
$$;

revoke all on function public.admin_book_requests_list(text) from public, anon, authenticated;
revoke all on function public.admin_book_request_set_status(text,bigint,text) from public, anon, authenticated;
grant execute on function public.admin_book_requests_list(text) to service_role;
grant execute on function public.admin_book_request_set_status(text,bigint,text) to service_role;
