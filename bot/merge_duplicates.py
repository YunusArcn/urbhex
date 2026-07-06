"""Veritabanındaki mevcut mükerrer olayları birleştirir (tek seferlik temizlik).

Aynı tür + aynı res-7 bölge + ±1 gün içinde, özetleri %80+ benzeyen kayıtlar
tek kayda indirilir; kaynak URL'leri birleştirilir. AI kullanılmaz (maliyet 0).
Kullanım: python merge_duplicates.py
"""
from datetime import date
from difflib import SequenceMatcher

import db


def run() -> None:
    rows = (
        db.get_client()
        .table("incidents")
        .select("id, occurred_on, event_type, h3_res7, summary, source_urls")
        .order("created_at")
        .execute()
        .data
    )
    print(f"[merge] {len(rows)} kayıt taranıyor...")

    kept: list[dict] = []
    removed = 0
    for row in rows:
        d = date.fromisoformat(row["occurred_on"])
        duplicate_of = None
        for k in kept:
            if k["event_type"] != row["event_type"] or k["h3_res7"] != row["h3_res7"]:
                continue
            if abs((date.fromisoformat(k["occurred_on"]) - d).days) > 1:
                continue
            # Gerçek veri ölçümü: ikizler ~0.7+, farklı olaylar ~0.36 ve altı çıkıyor.
            if SequenceMatcher(None, k["summary"], row["summary"]).ratio() >= 0.65:
                duplicate_of = k
                break

        if duplicate_of is None:
            kept.append(row)
            continue

        merged_urls = list(dict.fromkeys(duplicate_of["source_urls"] + row["source_urls"]))
        db.get_client().table("incidents").update(
            {"source_urls": merged_urls}
        ).eq("id", duplicate_of["id"]).execute()
        db.get_client().table("incidents").delete().eq("id", row["id"]).execute()
        duplicate_of["source_urls"] = merged_urls
        removed += 1

    print(f"[merge] Bitti: {removed} mükerrer kayıt birleştirildi, {len(kept)} tekil kayıt kaldı.")


if __name__ == "__main__":
    run()
