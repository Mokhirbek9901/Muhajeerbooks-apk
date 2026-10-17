insert into public.app_remote_config (key, value, description)
values
  ('release.force_update_enabled', 'true'::jsonb, 'Require customers to update when the official store reports a newer version.'),
  ('release.update_title', to_jsonb('Yangilanish kerak'::text), 'Mandatory update dialog title.'),
  ('release.update_message', to_jsonb('Muhajeer Books yangilandi. Ilovadan foydalanishni davom ettirish uchun so‘nggi versiyani o‘rnating.'::text), 'Mandatory update dialog message.'),
  ('release.update_button', to_jsonb('Yangilash'::text), 'Mandatory update dialog action label.')
on conflict (key) do update
set value = excluded.value,
    description = excluded.description,
    updated_at = now();
