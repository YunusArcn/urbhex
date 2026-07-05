-- URBHEX Migration v3.0 — Üyelik, profil ve favori bölgeler
-- Supabase SQL Editor'de çalıştırın.
-- Google girişi için ayrıca: Dashboard → Authentication → Providers → Google → Enable
-- (Google Cloud Console'dan OAuth Client ID/Secret gerekir; e-posta doğrulama
--  Authentication → Providers → Email altında "Confirm email" açık olmalı.)

-- =====================================================
-- 1. PROFİLLER (auth.users ile 1-1)
-- =====================================================
create table if not exists profiles (
  id           uuid primary key references auth.users(id) on delete cascade,
  display_name text,
  avatar_url   text,
  created_at   timestamptz not null default now()
);

alter table profiles enable row level security;

create policy "own profile read"   on profiles for select using (auth.uid() = id);
create policy "own profile insert" on profiles for insert with check (auth.uid() = id);
create policy "own profile update" on profiles for update using (auth.uid() = id);

-- Yeni kullanıcı kaydolunca profil satırı otomatik açılır.
create or replace function handle_new_user()
returns trigger language plpgsql security definer set search_path = public
as $$
begin
  insert into profiles (id, display_name, avatar_url)
  values (new.id,
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email, '@', 1)),
          new.raw_user_meta_data->>'avatar_url')
  on conflict (id) do nothing;
  return new;
end;
$$;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function handle_new_user();

-- =====================================================
-- 2. FAVORİ BÖLGELER (hex bazlı; ileride premium alarm bayrağı hazır)
-- =====================================================
create table if not exists favorites (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null references auth.users(id) on delete cascade,
  h3_res9      text not null,
  label        text not null default 'Favori bölgem',
  lat          double precision not null,
  lng          double precision not null,
  alert_enabled boolean not null default false, -- V2: premium push bildirimi
  created_at   timestamptz not null default now(),
  unique (user_id, h3_res9)
);

alter table favorites enable row level security;

create policy "own favorites read"   on favorites for select using (auth.uid() = user_id);
create policy "own favorites insert" on favorites for insert with check (auth.uid() = user_id);
create policy "own favorites delete" on favorites for delete using (auth.uid() = user_id);
create policy "own favorites update" on favorites for update using (auth.uid() = user_id);
