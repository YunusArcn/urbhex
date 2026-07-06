-- URBHEX Migration v8.0 — Üyelik kademesi (avatar halkası: bronz/gümüş/altın)
-- Supabase SQL Editor'de çalıştırın.
-- Ödeme sistemi (V2) bu kolonu güncelleyecek; lansmanda herkes 'bronz' başlar
-- ama tüm premium özellikler ücretsiz açıktır.

alter table profiles add column if not exists tier text not null default 'bronz';
-- geçerli değerler: 'bronz' | 'gumus' | 'altin'
