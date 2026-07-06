-- URBHEX Migration v6.0 — Konum hassasiyeti (il merkezi yığılması düzeltmesi)
-- Supabase SQL Editor'de çalıştırın.

-- Her olayın konum hassasiyeti: 'mahalle' | 'ilce' | 'il'
alter table incidents add column if not exists precision text not null default 'mahalle';

-- Hex boyama: İL hassasiyetli olaylar sokak hex'i BOYAMAZ (il merkezinde
-- sahte kırmızı yığın oluşturuyordu). Panel/sayımlarda görünmeye devam ederler.
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
      and coalesce(i.precision, 'mahalle') <> 'il'
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
