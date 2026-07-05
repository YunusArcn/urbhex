"""GDELT 2.0 küresel olay hattı: olay → koordinat → H3 → Supabase.

GDELT her 15 dakikada bir dünya basınını tarayıp olayları koordinatlı CSV
olarak yayınlar (ücretsiz, API anahtarı gerekmez). Bu betik son dosyayı indirir,
asayiş/şiddet olaylarını (CAMEO kök kodları) filtreler, H3 hex'e çevirir ve kaydeder.

Çalıştırma: python gdelt.py            (cron: */15 dakikada bir)
Not: Yerel İzmit scraper'ı (main.py) mahalle hassasiyeti için çalışmaya devam eder;
GDELT şehir/ilçe hassasiyetinde küresel katmandır.
"""
import asyncio
import csv
import io
import zipfile

import aiohttp
import h3

import db
from config import H3_RES_COARSE, H3_RES_FINE, H3_RES_POP

LASTUPDATE_URL = "http://data.gdeltproject.org/gdeltv2/lastupdate.txt"

# GDELT 2.0 export tablosu sütun indeksleri (61 sütun, tab ayraçlı)
COL_EVENT_ID = 0
COL_DAY = 1            # YYYYMMDD
COL_EVENT_ROOT = 28    # CAMEO kök kodu
COL_GEO_TYPE = 51      # 3=USCITY, 4=WORLDCITY (nokta hassasiyeti) — 1/2 ülke/eyalet geneli, atla
COL_GEO_NAME = 52
COL_GEO_LAT = 56
COL_GEO_LNG = 57
COL_SOURCE_URL = 60

# CAMEO kök kodu → Urbhex olay türü eşlemesi (asayiş dışı kodlar elenir)
CAMEO_TO_EVENT_TYPE = {
    "17": "diger",       # zorlama/el koyma
    "18": "yaralama",    # saldırı (assault)
    "19": "yaralama",    # çatışma
    "20": "cinayet",     # kitlesel şiddet
}


async def _fetch_latest_export() -> bytes:
    """lastupdate.txt'den en güncel export zip'inin adresini bulup indirir."""
    async with aiohttp.ClientSession() as session:
        async with session.get(LASTUPDATE_URL, timeout=aiohttp.ClientTimeout(total=30)) as resp:
            resp.raise_for_status()
            manifest = await resp.text()
        export_url = next(
            line.split()[-1] for line in manifest.splitlines() if line.endswith(".export.CSV.zip")
        )
        async with session.get(export_url, timeout=aiohttp.ClientTimeout(total=120)) as resp:
            resp.raise_for_status()
            return await resp.read()


def _parse_events(zip_bytes: bytes) -> list[dict]:
    """Zip içindeki CSV'den asayiş olaylarını ayıklar."""
    incidents = []
    with zipfile.ZipFile(io.BytesIO(zip_bytes)) as zf:
        raw = zf.read(zf.namelist()[0]).decode("utf-8", errors="replace")

    for row in csv.reader(io.StringIO(raw), delimiter="\t"):
        if len(row) < 61:
            continue
        event_type = CAMEO_TO_EVENT_TYPE.get(row[COL_EVENT_ROOT])
        if event_type is None:
            continue  # asayiş dışı olay
        if row[COL_GEO_TYPE] not in ("3", "4"):
            continue  # şehir hassasiyeti yoksa hex'e oturtma — yanlış boyama yapma
        try:
            lat, lng = float(row[COL_GEO_LAT]), float(row[COL_GEO_LNG])
        except ValueError:
            continue

        h3_res9 = h3.latlng_to_cell(lat, lng, H3_RES_FINE)
        center_lat, center_lng = h3.cell_to_latlng(h3_res9)
        day = row[COL_DAY]
        incidents.append({
            "occurred_on": f"{day[:4]}-{day[4:6]}-{day[6:8]}",
            "event_type": event_type,
            "summary": f"Uluslararasi basinda raporlanan olay ({row[COL_GEO_NAME]}). Detay icin kaynaga bakiniz.",
            "district": row[COL_GEO_NAME][:120] or "Bilinmiyor",
            "h3_res9": h3_res9,
            "h3_res8": h3.cell_to_parent(h3_res9, H3_RES_POP),  # nüfus eşlemesi (şema v2)
            "h3_res7": h3.latlng_to_cell(lat, lng, H3_RES_COARSE),
            "lat": center_lat,   # hex merkezi (KVKK: nokta adres yazılmaz)
            "lng": center_lng,
            "source_urls": [row[COL_SOURCE_URL]],
        })
    return incidents


def _store(incidents: list[dict]) -> dict:
    """Tekilleştirerek kaydeder: aynı gün+hex+tür varsa kaynak URL'si eklenir."""
    stats = {"eklendi": 0, "birlestirildi": 0}
    known = db.known_source_urls()
    for inc in incidents:
        url = inc["source_urls"][0]
        if url in known:
            continue
        candidates = db.find_dedup_candidates(inc["occurred_on"], inc["h3_res9"], inc["event_type"])
        if candidates:
            db.append_source(candidates[0]["id"], candidates[0]["source_urls"], url)
            stats["birlestirildi"] += 1
        else:
            db.insert_incident(inc)
            stats["eklendi"] += 1
        known.add(url)
    return stats


async def run() -> None:
    zip_bytes = await _fetch_latest_export()
    incidents = _parse_events(zip_bytes)
    print(f"[gdelt] Son 15 dakikada {len(incidents)} asayiş olayı bulundu.")
    if incidents:
        print(f"[gdelt] Bitti: {_store(incidents)}")


if __name__ == "__main__":
    asyncio.run(run())
