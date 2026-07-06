-- URBHEX Migration v4.0 — Talep üzerine bölge tarama (lazy loading)
-- Supabase SQL Editor'de çalıştırın.

create table if not exists scan_requests (
  id           uuid primary key default gen_random_uuid(),
  min_lat      double precision not null,
  min_lng      double precision not null,
  max_lat      double precision not null,
  max_lng      double precision not null,
  status       text not null default 'pending',  -- pending | processing | done | failed
  found_count  integer,
  requested_at timestamptz not null default now(),
  processed_at timestamptz
);

create index if not exists idx_scan_requests_status on scan_requests (status, requested_at);

alter table scan_requests enable row level security;

-- Herkes tarama isteyebilir ve durumunu izleyebilir; işleme sadece bot (service role).
create policy "public insert scan" on scan_requests for insert with check (true);
create policy "public read scan"   on scan_requests for select using (true);
