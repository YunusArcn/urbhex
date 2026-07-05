-- URBHEX Supabase Şeması v2.0 (H3 Eklentisiz Versiyon)
-- Supabase SQL Editor'de çalıştırın.
-- DİKKAT: 'h3' eklentisi bağımlılığı kaldırıldı. Python botunuz veri eklerken
-- h3_res9, h3_res8 ve h3_res7 verilerini text olarak göndermelidir.

-- =====================================================
-- 1. OLAYLAR (incidents)
-- =====================================================
create table if not exists incidents (
  id           uuid primary key default gen_random_uuid(),
  occurred_on  date not null,
  event_type   text not null,
  summary      text not null,            
  district     text not null default 'Izmit',
  h3_res9      text not null,            -- ~0.1 km2 (sokak seviyesi)
  h3_res8      text not null,            -- YENİ: Nüfus eşlemesi için Python'dan gelmeli
  h3_res7      text not null,            -- ~5 km2 (kümeleme seviyesi)
  lat          double precision not null,
  lng          double precision not null,
  source_urls  text[] not null default '{}',
  created_at   timestamptz not null default now()
);

create index if not exists idx_incidents_dedup on incidents (occurred_on, h3_res9, event_type);
create index if not exists idx_incidents_latlng on incidents (lat, lng);
create index if not exists idx_incidents_h3_res7 on incidents (h3_res7);

-- =====================================================
-- 2. OLAY AĞIRLIKLARI
-- =====================================================
create table if not exists event_weights (
  event_type text primary key,
  weight     numeric not null
);

insert into event_weights (event_type, weight) values
  ('cinayet', 10.0),
  ('silahli_saldiri', 7.0),
  ('gasp', 6.0),
  ('yaralama', 5.0),
  ('haneye_tecavuz', 5.0),
  ('kavga', 4.0),
  ('hirsizlik', 3.0),
  ('uyusturucu', 3.0),
  ('trafik_kazasi', 2.0),
  ('diger', 1.0)
on conflict (event_type) do nothing;

-- =====================================================
-- 3. GLOBAL NÜFUS (Kontur Population)
-- =====================================================
create table if not exists hex_population (
  h3_res8    text primary key,
  population integer not null check (population >= 0)
);

-- =====================================================
-- 4. KONUMU ÇÖZÜLEMEYEN HABERLER
-- =====================================================
create table if not exists unmatched_news (
  id         uuid primary key default gen_random_uuid(),
  url        text not null unique,
  source     text,
  reason     text not null,   
  created_at timestamptz not null default now()
);

-- =====================================================
-- 5. SKOR VIEW (Eklentisiz)
-- =====================================================
create or replace view hex_scores as
with agg as (
  select
    i.h3_res9,
    min(i.h3_res8) as h3_res8, -- Direkt tablodan çekiyoruz
    min(i.h3_res7) as h3_res7,
    min(i.lat) as lat,
    min(i.lng) as lng,
    count(*) as incident_count,
    mode() within group (order by i.event_type) as top_event_type,
    sum(
      coalesce(w.weight, 1.0)
      * exp(- (current_date - i.occurred_on) * ln(10) / 1095.0)
    ) as decayed
  from incidents i
  left join event_weights w on w.event_type = i.event_type
  group by i.h3_res9
)
select
  a.h3_res9, a.h3_res7, a.lat, a.lng, a.incident_count, a.top_event_type,
  a.decayed / (coalesce(p.population, 70000) / 7.0) * 10000 as risk_score,
  greatest(1, least(100,
    100 - round(a.decayed / (coalesce(p.population, 70000) / 7.0) * 10000 * 2)
  ))::int as safety_score
from agg a
left join hex_population p on p.h3_res8 = a.h3_res8; -- Fonksiyon yerine direkt eşleşme

-- =====================================================
-- 6. RPC'ler
-- =====================================================
create or replace function hexes_in_bbox(
  min_lat double precision, min_lng double precision,
  max_lat double precision, max_lng double precision
)
returns setof hex_scores
language sql stable
as $$
  select * from hex_scores
  where lat between min_lat and max_lat
    and lng between min_lng and max_lng;
$$;

create or replace function incidents_in_hex(hex text, page_size int default 20, page_offset int default 0)
returns setof incidents
language sql stable
as $$
  select * from incidents
  where h3_res9 = hex
  order by occurred_on desc
  limit page_size offset page_offset;
$$;

-- =====================================================
-- 7. RLS 
-- =====================================================
alter table incidents enable row level security;
alter table event_weights enable row level security;
alter table hex_population enable row level security;
alter table unmatched_news enable row level security;

create policy "public read incidents" on incidents for select using (true);
create policy "public read weights" on event_weights for select using (true);
create policy "public read population" on hex_population for select using (true);