-- Count web push and APNs attempts in the same dashboard row.
-- Acceptance by Apple or a push service is not proof that a user opened it.
create or replace function public.admin_push_message_finish(
  p_secret text,p_id uuid,p_success integer,p_failure integer
) returns boolean language plpgsql security definer set search_path='public' as $$
begin
  if not public._admin_secret_ok(p_secret) then raise exception 'Ruxsat yo‘q'; end if;
  update public.push_messages
    set total_count=greatest(coalesce(p_success,0),0)+greatest(coalesce(p_failure,0),0),
        success_count=greatest(coalesce(p_success,0),0),
        failure_count=greatest(coalesce(p_failure,0),0)
    where id=p_id;
  return found;
end $$;
