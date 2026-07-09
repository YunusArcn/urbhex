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
import os
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
MAX_ITEMS_PER_CITY = 15  # hiz: ilk turda 15 haber (kalanlar sonraki turlarda gelir)

_UA = {"User-Agent": "UrbhexBot/0.1 (+https://urbhex.com)"}

# Ülke kodu → Google News yereli (hl, gl, ceid). Nereye bakılırsa ORANIN dili.
_LOCALES = {
    "tr": ("tr", "TR", "TR:tr"),
    "us": ("en-US", "US", "US:en"),
    "gb": ("en-GB", "GB", "GB:en"),
    "au": ("en-AU", "AU", "AU:en"),
    "ca": ("en-CA", "CA", "CA:en"),
    "in": ("en-IN", "IN", "IN:en"),
    "de": ("de", "DE", "DE:de"),
    "at": ("de", "AT", "AT:de"),
    "ch": ("de", "CH", "CH:de"),
    "fr": ("fr", "FR", "FR:fr"),
    "be": ("fr", "BE", "BE:fr"),
    "es": ("es", "ES", "ES:es"),
    "mx": ("es-419", "MX", "MX:es-419"),
    "ar": ("es-419", "AR", "AR:es-419"),
    "it": ("it", "IT", "IT:it"),
    "nl": ("nl", "NL", "NL:nl"),
    "pt": ("pt-PT", "PT", "PT:pt-150"),
    "br": ("pt-BR", "BR", "BR:pt-419"),
    "ru": ("ru", "RU", "RU:ru"),
    "ua": ("uk", "UA", "UA:uk"),
    "jp": ("ja", "JP", "JP:ja"),
    "kr": ("ko", "KR", "KR:ko"),
    "sa": ("ar", "SA", "SA:ar"),
    "ae": ("ar", "AE", "AE:ar"),
    "eg": ("ar", "EG", "EG:ar"),
    "az": ("az", "AZ", "AZ:az"),
}
_DEFAULT_LOCALE = ("en-US", "US", "US:en")  # bilinmeyen ülke → İngilizce

# Dil → asayiş sorgusu (YEREL dilde aranır; AI özeti her zaman Türkçe üretir).
_CRIME_QUERIES = {
    "tr": '(cinayet OR gasp OR hırsızlık OR kavga OR yaralandı OR "trafik kazası" OR uyuşturucu OR "silahlı saldırı")',
    "en": '(murder OR robbery OR shooting OR assault OR theft OR burglary OR stabbing OR "car crash")',
    "de": '(Mord OR Raubüberfall OR Schießerei OR Überfall OR Diebstahl OR Einbruch OR Messerangriff OR Verkehrsunfall)',
    "fr": '(meurtre OR braquage OR fusillade OR agression OR vol OR cambriolage OR "accident de la route")',
    "es": '(asesinato OR robo OR tiroteo OR agresión OR hurto OR "accidente de tráfico" OR apuñalamiento)',
    "it": '(omicidio OR rapina OR sparatoria OR aggressione OR furto OR "incidente stradale")',
    "nl": '(moord OR overval OR schietpartij OR mishandeling OR diefstal OR inbraak OR verkeersongeval)',
    "pt": '(assassinato OR assalto OR tiroteio OR agressão OR furto OR roubo OR "acidente de trânsito")',
    "ru": '(убийство OR ограбление OR стрельба OR нападение OR кража OR ДТП)',
    "uk": '(вбивство OR пограбування OR стрілянина OR напад OR крадіжка OR ДТП)',
    "ja": '(殺人 OR 強盗 OR 発砲 OR 暴行 OR 窃盗 OR 交通事故)',
    "ko": '(살인 OR 강도 OR 총격 OR 폭행 OR 절도 OR 교통사고)',
    "ar": '(قتل OR سطو OR إطلاق نار OR اعتداء OR سرقة OR "حادث مرور")',
    "az": '(qətl OR quldurluq OR atışma OR hücum OR oğurluq OR "yol qəzası")',
}


def _lang_of(country_code: str | None) -> str:
    hl, _, _ = _LOCALES.get((country_code or "").lower(), _DEFAULT_LOCALE)
    return hl.split("-")[0]


def _http_get(url: str) -> bytes:
    req = urllib.request.Request(url, headers=_UA)
    with urllib.request.urlopen(req, timeout=20) as resp:
        return resp.read()


def detect_city(lat: float, lng: float) -> tuple[str | None, str | None, str | None]:
    """Bbox merkezindeki (şehir/eyalet, ülke adı, ülke kodu) — DÜNYA GENELİ."""
    params = urllib.parse.urlencode(
        {"lat": lat, "lon": lng, "zoom": 8, "format": "json",
         "accept-language": "en"})
    data = json.loads(_http_get(
        f"https://nominatim.openstreetmap.org/reverse?{params}"))
    addr = data.get("address", {})
    city = (addr.get("province") or addr.get("state") or addr.get("city")
            or addr.get("county"))
    return city, addr.get("country"), addr.get("country_code")


def fetch_google_news(
    city: str,
    query: str | None = None,
    days: int = 7,
    country_code: str | None = "tr",
) -> list[dict]:
    """Google News RSS: şehrin asayiş haberleri — ÜLKEYE GÖRE dil ve yerel.

    query verilmezse ülke diline uygun asayiş sorgusu kurulur; backfill_city.py
    özel sorgular geçirir (RSS'in ~100 sonuç tavanını aşmak için).
    """
    hl, gl, ceid = _LOCALES.get((country_code or "").lower(), _DEFAULT_LOCALE)
    if query is None:
        crime = _CRIME_QUERIES.get(_lang_of(country_code), _CRIME_QUERIES["en"])
        query = f'"{city}" {crime} when:{days}d'
    url = ("https://news.google.com/rss/search?q="
           f"{urllib.parse.quote(query)}&hl={hl}&gl={gl}&ceid={ceid}")
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


def _fetch_article_body(link: str) -> str | None:
    """Google News linkini takip edip haberin GERÇEK sayfasından tam metni çeker.

    Mahalle/sokak adı genelde RSS özetinde değil tam metinde geçer —
    hex'in il merkezine değil olayın mahallesine oturması bunu gerektirir.
    """
    try:
        from scraper import _extract_body  # gövde ayıklama mantığı tek yerde

        html = _http_get(link).decode("utf-8", errors="replace")
        body = _extract_body(html)
        return body if len(body) > 250 else None
    except Exception:
        return None


def process_item(
    item: dict,
    city: str,
    known: set[str],
    country: str | None = None,
    country_code: str | None = None,
) -> str:
    if item["link"] in known:
        return "atlandi"
    # Önce ucuz ön filtre başlık+özet üzerinden; geçerse tam metni çek.
    header = f"{item['title']}\n\n{item['desc']}"
    if not any(k in header.lower() for k in ASAYIS_KEYWORDS):
        return "atlandi"
    body = _fetch_article_body(item["link"])
    text = f"{item['title']}\n\n{body or item['desc']}\n\nYayın tarihi: {item['date']}"

    parsed = parse_article(text)
    if parsed is None:
        return "atlandi"

    il = parsed.il or city  # haber il vermezse tespit edilen şehir kullanılır
    hex_info = geo.resolve_hex(parsed.mahalle, parsed.ilce, il,
                               ulke=country, ulke_kodu=country_code)
    if hex_info is None:
        db.report_unmatched(item["link"], "google_news",
                            f"konum_cozulemedi:{parsed.mahalle or '-'}/{parsed.ilce or '-'}/{il}/{country or '-'}")
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
            city, country, cc = detect_city(
                (req["min_lat"] + req["max_lat"]) / 2,
                (req["min_lng"] + req["max_lng"]) / 2,
            )
            if not city:
                raise ValueError("şehir tespit edilemedi")
            print(f"[scan_worker] Bölge: {city}, {country} ({cc}) — Google News taranıyor...")

            stats = {"eklendi": 0, "birlestirildi": 0, "atlandi": 0, "konumsuz": 0}
            for item in fetch_google_news(city, country_code=cc)[:MAX_ITEMS_PER_CITY]:
                try:
                    result = process_item(item, city, known,
                                          country=country, country_code=cc)
                    stats[result] += 1
                    known.add(item["link"])
                except Exception as exc:
                    if "credit balance" in str(exc).lower() and not (
                            os.environ.get("GEMINI_API_KEY")
                            or os.environ.get("GROQ_API_KEY")):
                        print("[scan_worker] DURDU: Anthropic kredisi bitti ve "
                              "ücretsiz sağlayıcı yok! GEMINI/GROQ anahtarı "
                              "ekleyin veya kredi yükleyin.")
                        raise SystemExit(2) from exc
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
