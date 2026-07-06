"""Mevcut kayıtlardaki il-merkezi yığınlarını işaretler (tek seferlik onarım).

Sezgisel: BİREBİR aynı koordinatta 4+ olay varsa orası büyük olasılıkla bir
il/ilçe merkezi fallback noktasıdır (gerçek sokak olayları farklı hex'lere
dağılır). Bu kayıtların precision'ı 'il' yapılır → sokak hex'i boyamazlar.
Kullanım: python backfill_precision.py
"""
from collections import Counter

import db

STACK_THRESHOLD = 4


def run() -> None:
    client = db.get_client()
    rows = client.table("incidents").select("id, lat, lng").execute().data
    counts = Counter((r["lat"], r["lng"]) for r in rows)
    stacked_coords = {coord for coord, n in counts.items() if n >= STACK_THRESHOLD}
    print(f"[precision] {len(rows)} kayıt; {len(stacked_coords)} yığın noktası bulundu.")

    updated = 0
    for r in rows:
        if (r["lat"], r["lng"]) in stacked_coords:
            client.table("incidents").update({"precision": "il"}).eq("id", r["id"]).execute()
            updated += 1
    print(f"[precision] {updated} kayıt 'il' hassasiyetine çekildi (hex boyamaz, panelde kalır).")


if __name__ == "__main__":
    run()
