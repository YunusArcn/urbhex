"""Bir ilin haber arşivini Google News'ten TOPLU çeker (il tohumlama).

Google News RSS sorgu başına ~100 sonuçla sınırlıdır; bu betik olay türü
başına AYRI sorgu atarak tavanı aşar ve son N günün arşivini doldurur.
Tekilleştirme ve konum hassasiyeti normal boru hattından aynen geçer.

Kullanım:
  python backfill_city.py Kocaeli
  python backfill_city.py Bursa --days 60
"""
import argparse
import asyncio
from collections import Counter

import db
from scan_worker import fetch_google_news, process_item

# Tür başına ayrı sorgu → tür başına ~100 sonuç hakkı.
KEYWORD_QUERIES = [
    "cinayet", "gasp", "hırsızlık", "kavga", '"trafik kazası"',
    "uyuşturucu operasyon", '"silahlı saldırı"', "bıçaklı yaralandı",
    "gözaltı asayiş", "dolandırıcılık tutuklandı",
]


# İngilizce tohumlama sorguları (ülke kodu tr değilse kullanılır)
KEYWORD_QUERIES_EN = [
    "murder", "robbery", "shooting", "assault", "theft", "burglary",
    "stabbing", '"car crash"', "carjacking", "arrested police",
]


async def run(city: str, days: int, country: str | None, cc: str) -> None:
    known = db.known_source_urls()
    seen_links: set[str] = set()
    stats: Counter = Counter()

    queries = KEYWORD_QUERIES if cc == "tr" else KEYWORD_QUERIES_EN
    for kw in queries:
        query = f'"{city}" {kw} when:{days}d'
        try:
            items = fetch_google_news(city, query=query, country_code=cc)
        except Exception as exc:
            print(f"[backfill] sorgu hatası ({kw}): {exc}")
            continue
        fresh = [i for i in items if i["link"] not in seen_links]
        seen_links.update(i["link"] for i in fresh)
        print(f"[backfill] '{kw}': {len(fresh)} yeni link")
        for item in fresh:
            try:
                result = process_item(item, city, known,
                                      country=country, country_code=cc)
                stats[result] += 1
                known.add(item["link"])
            except Exception as exc:
                stats["hata"] += 1
                print(f"[backfill] haber hatası: {exc}")

    print(f"\n[backfill] {city} ({days} gün) BİTTİ: {dict(stats)}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("city", help="Şehir/il adı, örn: Kocaeli, Chicago")
    ap.add_argument("--days", type=int, default=30)
    ap.add_argument("--country", default="Türkiye", help="Ülke adı (geocoding bağlamı)")
    ap.add_argument("--cc", default="tr", help="Ülke kodu: tr, us, gb, de...")
    args = ap.parse_args()
    asyncio.run(run(args.city, args.days, args.country, args.cc.lower()))
