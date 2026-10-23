-- Admin-only state transitions for native preorders.
-- Existing deposits, receipts, book inventory and customer comments are untouched.
alter table public.preorders drop constraint if exists preorders_status_check;
alter table public.preorders add constraint preorders_status_check
  check (status in ('waiting','contacted','converted','cancelled','accepted','arrived'));

create table if not exists private.admin_preorder_status_events (
  id bigint generated always as identity primary key,
  preorder_id bigint not null references public.preorders(id),
  old_status text not null,
  new_status text not null,
  admin_note text not null default '',
  changed_at timestamptz not null default now()
);
revoke all on private.admin_preorder_status_events from public,anon,authenticated;

create or replace function public.admin_native_preorder_set_status(
  p_secret text,
  p_id bigint,
  p_expected_status text,
  p_status text,
  p_note text default ''
) returns jsonb
language plpgsql security definer set search_path = ''
as $$
declare v_row public.preorders%rowtype;
        v_note text := trim(coalesce(p_note,''));
begin
  if public._admin_secret_ok(p_secret) is not true then
    raise exception 'Admin ruxsati yo‘q';
  end if;
  if p_id is null or p_status not in ('waiting','accepted','arrived','cancelled')
     or length(v_note)>500 then
    raise exception 'Holat yoki izoh noto‘g‘ri';
  end if;
  select * into v_row from public.preorders
    where id=p_id for update;
  if not found then raise exception 'Oldindan zakaz topilmadi'; end if;
  if exists(select 1 from private.admin_preorder_hidden h
     where h.source='native' and h.order_id=p_id::text) then
    raise exception 'Arxivdagi zakazni bu yerdan o‘zgartirib bo‘lmaydi';
  end if;
  if v_row.status is distinct from p_expected_status then
    raise exception 'Bu zakaz boshqa oynada yangilangan. Ro‘yxatni qayta oching.';
  end if;
  if v_row.status=p_status then
    return jsonb_build_object('status',v_row.status,'duplicate',true);
  end if;
  if not (
    (v_row.status='waiting' and p_status in ('accepted','cancelled')) or
    (v_row.status='contacted' and p_status in ('accepted','arrived','cancelled')) or
    (v_row.status='accepted' and p_status in ('arrived','cancelled')) or
    (v_row.status='arrived' and p_status='cancelled') or
    (v_row.status='cancelled' and p_status='waiting')
  ) then raise exception 'Avval qabul qiling yoki mos holatni tanlang'; end if;
  if p_status in ('cancelled','waiting') and length(v_note)<3 then
    raise exception 'Sababini yozing (kamida 3 belgi)';
  end if;
  update public.preorders set status=p_status where id=p_id;
  insert into private.admin_preorder_status_events
     (preorder_id,old_status,new_status,admin_note)
  values (p_id,v_row.status,p_status,v_note);
  return jsonb_build_object('status',p_status,'previous_status',v_row.status,
    'duplicate',false,'note_saved',v_note<>'');
end;
$$;
revoke all on function public.admin_native_preorder_set_status(text,bigint,text,text,text)
  from public,anon,authenticated;
grant execute on function public.admin_native_preorder_set_status(text,bigint,text,text,text)
  to service_role;
