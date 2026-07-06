"""Bölge tarama işçisi: scan_requests kuyruğu → şehir tespiti → Google News → harita.

Akış (kullanıcı haritada "Bu bölgede haber tara" dedikçe):
  1. Kuyruktan bekleyen bbox alınır.
  2. Bbox merkezinden şehir/il tespit edilir (Nominatim reverse, ücretsiz).
  3. Google News RSS'ten o ilin asayiş haberleri çekilir (ücretsiz, anahtarsız):
     https://news.google.com/rss/search?q=<il + asayiş kelimeleri>&hl=tr&gl=TR
  4. Başlık+özet AI'dan geçer (Haiku — kısa metin, düşük maliyet) → H3 → kayıt.
  5. İstek done/failed işaretlenir.

Böylece sistem KOCAELİ'YE BAĞLI DEĞİLDİR: Bursa'ya, Ankara'ya, nereye
bakılırsa botun kaynağı o ilin Google News akışı olur.

Kullanım: python scan_worker.py     (Actions'ta saatlik; lokalde elle)
"""
import asyncio
import json
import re
import urllib.parse
import urllib.request
import xml.etree.ElementTree as ET
from datetime import datetime, timezone
from difflib import SequenceMatcher
from email.utils import parsedate_to_datetime

import db
import geo
from config import ASAYIS_KEYWORDS
from parser import is_same_incident, parse_article

MAX_REQUESTS_PER_RUN = 5
MAX_ITEMS_PER_CITY = 25  # token guvenligi: sehir basina en fazla 25 haber AI'a gider

_UA = {"User-Agent": "UrbhexBot/0.1 (+https://urbhex.com)"}


def _http_get(url: str) -> bytes:
    req = urllib.request.Request(url, headers=_UA)
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.read()


def detect_city(lat: float, lng: float) -> str | None:
    """Bbox merkezindeki ili bulur (zoom=8 ≈ il seviyesi)."""
    params = urllib.parse.urlencode(
        {"lat": lat, "lon": lng, "zoom": 8, "format": "json"})
    data = json.loads(_http_get(
        f"https://nominatim.openstreetmap.org/reverse?{params}"))
    addr = data.get("address", {})
    return addr.get("province") or addr.get("state") or addr.get("city")


def fetch_google_news(city: str) -> list[dict]:
    """Google News RSS: ilin son asayiş haberleri (başlık, link, tarih, özet)."""
    query = f'"{city}" (cinayet OR gasp OR hırsızlık OR kavga OR yaralandı OR "trafik kazası" OR uyuşturucu OR "silahlı saldırı") when:7d'
    url = ("https://news.google.com/rss/search?q="
           f"{urllib.parse.quote(query)}&hl=tr&gl=TR&ceid=TR:tr")
    root = ET.fromstring(_http_get(url))
    items = []
    for item in root.iter("item"):
        title = item.findtext("title") or ""
        link = item.findtext("link") or ""
        desc = re.sub(r"<[^>]+>", " ", item.findtext("description") or "")
        pub = item.findtext("pubDate")
        try:
            pub_date = parsedate_to_datetime(pub) if pub else datetime.now(timezone.utc)
        except Exception:
            pub_date = datetime.now(timezone.utc)
        items.append({
            "title": title, "link": link, "desc": desc.strip(),
            "date": pub_date.date().isoformat(),
        })
    return items


def process_item(item: dict, city: str, known: set[str]) -> str:
    if item["link"] in known:
        return "atlandi"
    text = f"{item['title']}\n\n{item['desc']}\n\nYayın tarihi: {item['date']}"
    if not any(k in text.lower() for k in ASAYIS_KEYWORDS):
        return "atlandi"

    parsed = parse_article(text)
    if parsed is None:
        return "atlandi"

    il = parsed.il or city  # haber il vermezse tespit edilen şehir kullanılır
    hex_info = geo.resolve_hex(parsed.mahalle, parsed.ilce, il)
    if hex_info is None:
        db.report_unmatched(item["link"], "google_news",
                            f"konum_cozulemedi:{parsed.mahalle or '-'}/{parsed.ilce or '-'}/{il}")
        return "konumsuz"

    occurred = parsed.tarih.isoformat()
    for cand in db.find_dedup_candidates(occurred, hex_info["h3_res7"], parsed.olay_turu):
        ratio = SequenceMatcher(None, cand["summary"], parsed.kisa_ozet).ratio()
        if ratio >= 0.65 or (ratio >= 0.35 and is_same_incident(cand["summary"], parsed.kisa_ozet)):
            db.append_source(cand["id"], cand["source_urls"], item["link"])
            return "birlestirildi"

    db.insert_incident({
        "occurred_on": occurred,
        "event_type": parsed.olay_turu,
        "summary": parsed.kisa_ozet,
        "district": ", ".join(p for p in (parsed.ilce, il) if p),
        "source_urls": [item["link"]],
        **hex_info,
    })
    return "eklendi"


async def run() -> None:
    client = db.get_client()
    pending = (client.table("scan_requests").select("*")
               .eq("status", "pending").order("requested_at")
               .limit(MAX_REQUESTS_PER_RUN).execute().data)
    if not pending:
        print("[scan_worker] Bekleyen tarama isteği yok.")
        return

    known = db.known_source_urls()
    for req in pending:
        client.table("scan_requests").update({"status": "processing"}).eq("id", req["id"]).execute()
        try:
            city = detect_city(
                (req["min_lat"] + req["max_lat"]) / 2,
                (req["min_lng"] + req["max_lng"]) / 2,
            )
            if not city:
                raise ValueError("şehir tespit edilemedi")
            print(f"[scan_worker] Bölge: {city} — Google News taranıyor...")

            stats = {"eklendi": 0, "birlestirildi": 0, "atlandi": 0, "konumsuz": 0}
            for item in fetch_google_news(city)[:MAX_ITEMS_PER_CITY]:
                try:
                    result = process_item(item, city, known)
                    stats[result] += 1
                    known.add(item["link"])
                except Exception as exc:
                    print(f"[scan_worker] haber hatası: {exc}")

            client.table("scan_requests").update({
                "status": "done",
                "found_count": stats["eklendi"] + stats["birlestirildi"],
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", req["id"]).execute()
            print(f"[scan_worker] {city}: {stats}")
        except Exception as exc:
            print(f"[scan_worker] istek başarısız: {exc}")
            client.table("scan_requests").update({
                "status": "failed",
                "processed_at": datetime.now(timezone.utc).isoformat(),
            }).eq("id", req["id"]).execute()


if __name__ == "__main__":
    import sys

    if "--loop" in sys.argv:
        # Gelistirme modu: kuyrugu 20 sn'de bir isler — uygulamadaki
        # "Bu bolgede haber tara" butonu aninda sonuc verir.
        async def _loop() -> None:
            print("[scan_worker] Döngü modu: kuyruk 20 sn'de bir kontrol ediliyor (Ctrl+C ile çık).")
            while True:
                await run()
                await asyncio.sleep(20)

        asyncio.run(_loop())
    else:
        asyncio.run(run())
