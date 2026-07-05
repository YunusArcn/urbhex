-- URBHEX Migration v2.1 — sadece daha önce ESKİ şemayı çalıştırdıysanız gerekli.
-- (Tablonuz zaten h3_res8 sütunuyla oluştuysa bu dosyayı çalıştırmanıza gerek yok;
--  çalıştırmak yine de zararsızdır.)
-- Supabase SQL Editor'de çalıştırın.

-- 1) Eksikse h3_res8 sütununu ekle (eski kayıtlar için null'a izin verilir;
--    bot/backfill_res8.py bunları doldurur).
alter table incidents add column if not exists h3_res8 text;

-- 2) View'ı yeni sütunla yeniden kur.
create or replace view hex_scores as
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
