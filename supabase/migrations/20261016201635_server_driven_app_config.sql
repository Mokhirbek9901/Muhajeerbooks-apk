create table if not exists public.app_remote_config (
  key text primary key,
  value jsonb not null,
  description text not null default '',
  updated_at timestamptz not null default now()
);

alter table public.app_remote_config enable row level security;

revoke all on table public.app_remote_config from anon, authenticated;

create or replace function public.customer_app_config()
returns jsonb
language sql
stable
security definer
set search_path = public
as $$
  select coalesce(jsonb_object_agg(key, value), '{}'::jsonb)
  from public.app_remote_config;
$$;

revoke all on function public.customer_app_config() from public;
grant execute on function public.customer_app_config() to anon, authenticated;

insert into public.app_remote_config (key, value, description)
values
  ('config.refresh_minutes', '15'::jsonb, 'How often the app refreshes server-driven settings while open.'),
  ('features.muhajeer_ai_enabled', 'true'::jsonb, 'Show Muhajeer AI where supported by the installed build.'),
  ('features.preorder_enabled', 'true'::jsonb, 'Allow preorder surfaces where supported by the installed build.'),
  ('features.reviews_enabled', 'true'::jsonb, 'Allow book review surfaces where supported by the installed build.'),
  ('features.restock_enabled', 'true'::jsonb, 'Allow restock notification surfaces where supported by the installed build.'),
  ('features.story_share_enabled', 'true'::jsonb, 'Allow story sharing surfaces where supported by the installed build.'),
  ('ui.notification_permission_title', to_jsonb('Bildirishnomalarga ruxsat berasizmi?'::text), 'Notification permission explainer title.'),
  ('ui.notification_permission_body', to_jsonb('Muhajeer Books yangi xabarlar va muhim yangilanishlarni sizga bildirishnoma orqali yuborishi uchun ruxsat bering.'::text), 'Notification permission explainer body.'),
  ('ui.notification_permission_allow', to_jsonb('Ruxsat berish'::text), 'Notification permission allow button.'),
  ('ui.notification_permission_later', to_jsonb('Hozir emas'::text), 'Notification permission later button.'),
  ('ui.home_announcement_enabled', 'false'::jsonb, 'Reserved switch for a server-controlled home announcement.'),
  ('ui.home_announcement_title', to_jsonb(''::text), 'Reserved home announcement title.'),
  ('ui.home_announcement_body', to_jsonb(''::text), 'Reserved home announcement body.'),
  ('release.ios_store_url', to_jsonb('https://apps.apple.com/app/muhajeer-books/id6817641775'::text), 'Public App Store URL.'),
  ('release.android_store_url', to_jsonb('https://play.google.com/store/apps/details?id=com.muhajeerbooks.app'::text), 'Public Google Play URL.')
on conflict (key) do nothing;
