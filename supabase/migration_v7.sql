-- URBHEX Migration v7.0 — Güvenlik Alarmı (Premium; lansmanda ücretsiz)
-- Ev/İş konum kaydı + yakın olay bildirimleri + e-posta altyapısı
-- Supabase SQL Editor'de çalıştırın.

-- 1) Favorilere tür eklendi: 'ev' | 'is' | 'diger'
alter table favorites add column if not exists kind text not null default 'diger';
alter table favorites alter column alert_enabled set default true; -- lansman: herkes açık

-- 2) profiles.email — bot e-posta gönderebilsin diye (PostgREST auth.users'ı okuyamaz)
alter table profiles add column if not exists email text;
update profiles p set email = u.email
from auth.users u where u.id = p.id and p.email is null;

create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into profiles (id, display_name, avatar_url, email)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
          new.raw_user_meta_data->>'avatar_url',
          new.email)
  on conflict (id) do update set email = excluded.email;
  return new;
end;
$$;

-- 3) Bildirimler
create table if not exists notifications (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null references auth.users(id) on delete cascade,
  incident_id    uuid references incidents(id) on delete cascade,
  favorite_label text,
  title          text not null,
  body           text not null,
  read           boolean not null default false,
  created_at     timestamptz not null default now()
);

create index if not exists idx_notifications_user on notifications (user_id, read, created_at desc);

alter table notifications enable row level security;
create policy "own notifications read"   on notifications for select using (auth.uid() = user_id);
create policy "own notifications update" on notifications for update using (auth.uid() = user_id);
-- INSERT politikası yok: bildirimleri yalnız bot yazar (service role).
