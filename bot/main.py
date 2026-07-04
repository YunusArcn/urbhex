"""Habitex boru hattı orkestratörü.

Akış: Tara → (yeni haber yoksa dur, maliyet 0) → AI ayrıştır → Tekilleştir → Kaydet.
Zamanlama: cron / systemd timer ile 6 saatte bir çalıştırılır:
    0 */6 * * * cd /opt/habitex/bot && python main.py
"""
import asyncio

import db
import geo
from parser import is_same_incident, parse_article
from scraper import scrape_new_articles


def process_article(article) -> str:
    parsed = parse_article(article.text)
    if parsed is None:
        return "atlandi"

    hex_info = geo.resolve_hex(parsed.mahalle)
    occurred = parsed.tarih.isoformat()

    # Tekilleştirme — 1. birincil filtre, 2. anlamsal eşleştirme, 3. kaynak dizisi
    for candidate in db.find_dedup_candidates(occurred, hex_info["h3_res9"], parsed.olay_turu):
        if is_same_incident(candidate["summary"], parsed.kisa_ozet):
            db.append_source(candidate["id"], candidate["source_urls"], article.url)
            return "birlestirildi"

    db.insert_incident({
        "occurred_on": occurred,
        "event_type": parsed.olay_turu,
        "summary": parsed.kisa_ozet,
        "district": parsed.ilce or "Izmit",
        "source_urls": [article.url],
        **hex_info,
    })
    return "eklendi"


async def run() -> None:
    known = db.known_source_urls()
    articles = await scrape_new_articles(known)
    print(f"[main] {len(articles)} yeni haber bulundu.")
    if not articles:
        return  # AI'a gitme — maliyet: 0

    stats = {"eklendi": 0, "birlestirildi": 0, "atlandi": 0, "hata": 0}
    for article in articles:
        try:
            stats[process_article(article)] += 1
        except Exception as exc:  # tek haber hatası boru hattını durdurmasın
            print(f"[main] {article.url} işlenemedi: {exc}")
            stats["hata"] += 1
    print(f"[main] Bitti: {stats}")


if __name__ == "__main__":
    asyncio.run(run())
