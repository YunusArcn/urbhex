-- URBHEX Migration v5.0 — Tarih filtresi + görünen alan haber listesi
-- Supabase SQL Editor'de çalıştırın.

-- Tarih filtreli hex skorları (bugün / 3 gün / 2 hafta / 1 ay / 1 yıl / tümü)
create or replace function hexes_in_bbox_since(
  min_lat double precision, min_lng double precision,
  max_lat double precision, max_lng double precision,
  since_days integer default 36500
)
returns table (
  h3_res9 text, h3_res7 text, lat double precision, lng double precision,
  incident_count bigint, top_event_type text,
  risk_score numeric, safety_score integer
)
language sql stable
as $$
  with agg as (
    select
      i.h3_res9,
      min(i.h3_res8) as h3_res8,
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
    where i.lat between min_lat and max_lat
      and i.lng between min_lng and max_lng
      and i.occurred_on >= current_date - since_days
    group by i.h3_res9
  )
  select
    a.h3_res9, a.h3_res7, a.lat, a.lng, a.incident_count, a.top_event_type,
    a.decayed / (coalesce(p.population, 70000) / 7.0) * 10000 as risk_score,
    greatest(1, least(100,
      100 - round(a.decayed / (coalesce(p.population, 70000) / 7.0) * 10000 * 2)
    ))::int as safety_score
  from agg a
  left join hex_population p on p.h3_res8 = a.h3_res8;
$$;

-- Görünen alandaki olay akışı (sol panel): en yeniden eskiye
create or replace function incidents_in_bbox(
  min_lat double precision, min_lng double precision,
  max_lat double precision, max_lng double precision,
  since_days integer default 36500,
  max_rows integer default 50
)
returns setof incidents
language sql stable
as $$
  select * from incidents
  where lat between min_lat and max_lat
    and lng between min_lng and max_lng
    and occurred_on >= current_date - since_days
  order by occurred_on desc
  limit max_rows;
$$;

-- Olay panelindeki tarih filtresi için incidents_in_hex'e de since eklendi
create or replace function incidents_in_hex_since(
  hex text, since_days integer default 36500,
  page_size int default 200, page_offset int default 0
)
returns setof incidents
language sql stable
as $$
  select * from incidents
  where h3_res9 = hex
    and occurred_on >= current_date - since_days
  order by occurred_on desc
  limit page_size offset page_offset;
$$;
