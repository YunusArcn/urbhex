-- HABITEX Supabase Şeması v1.0
-- Supabase SQL Editor'de çalıştırın.

-- =====================================================
-- 1. OLAYLAR (incidents)
-- KVKK: Şahıs ismi ve açık adres ASLA yazılmaz.
-- lat/lng = H3 hex MERKEZİ (olay adresi değil, ~300m hassasiyet).
-- =====================================================
create table if not exists incidents (
  id           uuid primary key default gen_random_uuid(),
  occurred_on  date not null,
  event_type   text not null,           -- 'hirsizlik', 'gasp', 'yaralama', 'cinayet', 'uyusturucu', 'diger'
  summary      text not null,           -- AI'ın ürettiği 2 cümlelik anonim özet
  district     text not null default 'Izmit',
  h3_res9      text not null,           -- ~0.1 km2 (sokak seviyesi)
  h3_res7      text not null,           -- ~5 km2 (ilçe genel bakış)
  lat          double precision not null, -- hex merkezi
  lng          double precision not null, -- hex merkezi
  source_urls  text[] not null default '{}', -- tekilleştirme: aynı olayın tüm kaynakları
  created_at   timestamptz not null default now()
);

-- Tekilleştirme birincil filtresi: aynı gün + aynı hex + aynı tür
create index if not exists idx_incidents_dedup on incidents (occurred_on, h3_res9, event_type);
-- Bounding box sorgusu (haritada görünen alan)
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
  ('gasp', 6.0),
  ('yaralama', 5.0),
  ('haneye_tecavuz', 5.0),
  ('hirsizlik', 3.0),
  ('uyusturucu', 3.0),
  ('diger', 1.0)
on conflict (event_type) do nothing;

-- =====================================================
-- 3. NÜFUS (hex bazlı — TÜİK/Kontur'dan doldurulur)
-- =====================================================
create table if not exists hex_population (
  h3_res9    text primary key,
  population integer not null check (population > 0)
);

-- =====================================================
-- 4. SKOR VIEW
-- Formül: sum(ağırlık * zaman_decay) / nüfus * 10000
-- Decay: bugün %100, 3 yıl (1095 gün) sonra ~%10 → exp(-gün * ln(10)/1095)
-- =====================================================
create or replace view hex_scores as
select
  i.h3_res9,
  min(i.lat) as lat,
  min(i.lng) as lng,
  count(*)   as incident_count,
  sum(
    coalesce(w.weight, 1.0)
    * exp(- (current_date - i.occurred_on) * ln(10) / 1095.0)
  ) / coalesce(max(p.population), 10000) * 10000 as risk_score
from incidents i
left join event_weights w on w.event_type = i.event_type
left join hex_population p on p.h3_res9 = i.h3_res9
group by i.h3_res9;

-- =====================================================
-- 5. BBOX RPC — harita sadece görünen alanı çeker
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
-- 6. RLS — herkes okur, sadece service role yazar
-- =====================================================
alter table incidents enable row level security;
alter table event_weights enable row level security;
alter table hex_population enable row level security;

create policy "public read incidents" on incidents for select using (true);
create policy "public read weights" on event_weights for select using (true);
create policy "public read population" on hex_population for select using (true);
-- INSERT/UPDATE politikası yok: bot service_role key ile yazar (RLS bypass).
