"""Urbhex boru hattı orkestratörü.

Akış: Tara → (yeni haber yoksa dur, maliyet 0) → AI ayrıştır → Tekilleştir → Kaydet.
Zamanlama: cron / systemd timer ile 6 saatte bir çalıştırılır:
    0 */6 * * * cd /opt/urbhex/bot && python main.py
"""
import asyncio
from difflib import SequenceMatcher

import db
import geo
from config import ASAYIS_KEYWORDS
from parser import is_same_incident, parse_article
from scraper import scrape_new_articles


def process_article(article) -> str:
    # Ücretsiz ön filtre: asayiş kelimesi yoksa AI'a gönderme (token maliyeti: 0).
    text_lower = article.text.lower()
    if not any(k in text_lower for k in ASAYIS_KEYWORDS):
        return "atlandi"

    parsed = parse_article(article.text)
    if parsed is None:
        return "atlandi"

    # Yerel Kocaeli basını il belirtmeyebilir → varsayılan Kocaeli/Türkiye.
    il = parsed.il or "Kocaeli"
    ulke = parsed.ulke or "Türkiye"
    hex_info = geo.resolve_hex(parsed.mahalle, parsed.ilce, il, ulke=ulke,
                               ulke_kodu="tr" if ulke == "Türkiye" else None)
    if hex_info is None:
        # Bölgeyle eşlenemeyen haber (trafik kazası dahil her tür): raporla, boyama.
        db.report_unmatched(article.url, article.source,
                            f"konum_cozulemedi:{parsed.mahalle or '-'}/{parsed.ilce or '-'}/{il}")
        return "konumsuz"

    occurred = parsed.tarih.isoformat()

    # Tekilleştirme — 1. geniş filtre (±1 gün, res-7), 2. benzerlik, 3. kaynak dizisi
    # difflib ücretsizdir: çok benzer → AI'sız birleştir; orta benzer → AI'a sor.
    for candidate in db.find_dedup_candidates(occurred, hex_info["h3_res7"], parsed.olay_turu):
        ratio = SequenceMatcher(None, candidate["summary"], parsed.kisa_ozet).ratio()
        if ratio >= 0.65 or (ratio >= 0.35 and is_same_incident(candidate["summary"], parsed.kisa_ozet)):
            db.append_source(candidate["id"], candidate["source_urls"], article.url)
            return "birlestirildi"

    db.insert_incident({
        "occurred_on": occurred,
        "event_type": parsed.olay_turu,
        "summary": parsed.kisa_ozet,
        "district": ", ".join(p for p in (parsed.ilce, il) if p),
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

    stats = {"eklendi": 0, "birlestirildi": 0, "atlandi": 0, "konumsuz": 0, "hata": 0}
    for article in articles:
        try:
            stats[process_article(article)] += 1
        except Exception as exc:  # tek haber hatası boru hattını durdurmasın
            print(f"[main] {article.url} işlenemedi: {exc}")
            stats["hata"] += 1
    print(f"[main] Bitti: {stats}")


if __name__ == "__main__":
    asyncio.run(run())
