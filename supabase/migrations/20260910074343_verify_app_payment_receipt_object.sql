create or replace function public.require_app_payment_receipt()
returns trigger
language plpgsql
security definer
set search_path = public, pg_temp
as $$
begin
  if coalesce(new.source,'app') = 'app' then
    if coalesce(new.payment_proof_path,'') = '' then
      raise exception 'To‘lov cheki skrinshoti majburiy';
    end if;

    if new.payment_proof_path !~ '^receipts/[A-Za-z0-9._/-]+$' then
      raise exception 'To‘lov cheki manzili noto‘g‘ri';
    end if;

    if not exists (
      select 1
      from storage.objects o
      where o.bucket_id = 'payment-receipts'
        and o.name = new.payment_proof_path
    ) then
      raise exception 'To‘lov cheki serverga yuklanmagan. Qayta urinib ko‘ring';
    end if;
  end if;
  return new;
end;
$$;

revoke all on function public.require_app_payment_receipt() from public, anon, authenticated;

create unique index if not exists orders_app_payment_proof_unique_idx
on public.orders (payment_proof_path)
where source = 'app' and payment_proof_path <> '';
