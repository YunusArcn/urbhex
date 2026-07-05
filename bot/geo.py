"""Mahalle/ilçe adı → koordinat → H3 hex çözümü.

Çözüm sırası:
  1) Yerel sözlük (sık geçen İzmit mahalleleri — ağ isteği yok)
  2) geo_cache.json (daha önce çözülmüş adlar — ağ isteği yok)
  3) Nominatim/OSM coğrafi kodlama (ücretsiz; 1 istek/sn kuralına uyulur)

Mahalle yoksa ilçe merkezi kullanılır (hassasiyet düşer ama olay haritada görünür).
Kocaeli sınır kutusu dışına düşen sonuçlar reddedilir (yanlış il eşleşmesi olmaz).
"""
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

import h3

from config import H3_RES_COARSE, H3_RES_FINE, H3_RES_POP

_CACHE_FILE = Path(__file__).with_name("geo_cache.json")
# left(lng), top(lat), right(lng), bottom(lat) — Kocaeli ili
_KOCAELI_VIEWBOX = "29.20,41.30,30.40,40.50"

# Sık geçen İzmit mahalle merkezleri (lat, lng) — Nominatim'e gitmeden çözülür.
IZMIT_MAHALLE_MERKEZLERI: dict[str, tuple[float, float]] = {
    "yahya kaptan": (40.7729, 29.9530),
    "kadikoy": (40.7726, 29.9350),
    "yenisehir": (40.7772, 29.9663),
    "alikahya": (40.7900, 30.0180),
    "cedit": (40.7660, 29.9260),
    "bekirpasa": (40.7810, 29.9450),
    "gundogdu": (40.7940, 29.9560),
    "erenler": (40.7750, 29.9760),
    "korfez mahallesi": (40.7620, 29.9180),
    "tepekoy": (40.7580, 29.9420),
    "orhan": (40.7690, 29.9480),
    "kabaoglu": (40.8210, 29.9720),
}

_TR_MAP = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")


def _normalize(name: str) -> str:
    return name.translate(_TR_MAP).lower().replace("mahallesi", "").replace("mah.", "").strip()


def _load_cache() -> dict:
    if _CACHE_FILE.exists():
        return json.loads(_CACHE_FILE.read_text(encoding="utf-8"))
    return {}


def _save_cache(cache: dict) -> None:
    _CACHE_FILE.write_text(json.dumps(cache, ensure_ascii=False, indent=1), encoding="utf-8")


def _nominatim(query: str) -> tuple[float, float] | None:
    """OSM Nominatim sorgusu. Kocaeli kutusu dışı sonuç kabul edilmez."""
    params = urllib.parse.urlencode({
        "q": query,
        "format": "json",
        "limit": 1,
        "countrycodes": "tr",
        "viewbox": _KOCAELI_VIEWBOX,
        "bounded": 1,
    })
    req = urllib.request.Request(
        f"https://nominatim.openstreetmap.org/search?{params}",
        headers={"User-Agent": "UrbhexBot/0.1 (+https://urbhex.com)"},
    )
    with urllib.request.urlopen(req, timeout=15) as resp:
        results = json.loads(resp.read())
    time.sleep(1.1)  # Nominatim adil kullanım politikası: en fazla 1 istek/sn
    if results:
        return float(results[0]["lat"]), float(results[0]["lon"])
    return None


def _coords_for(mahalle: str | None, ilce: str | None) -> tuple[float, float] | None:
    if mahalle:
        key = _normalize(mahalle)
        if key in IZMIT_MAHALLE_MERKEZLERI:
            return IZMIT_MAHALLE_MERKEZLERI[key]

    district = (ilce or "Izmit").strip()
    query = f"{mahalle}, {district}, Kocaeli" if mahalle else f"{district}, Kocaeli"

    cache = _load_cache()
    if query in cache:
        return tuple(cache[query]) if cache[query] else None

    try:
        coords = _nominatim(query)
        # Mahalle bulunamadıysa ilçe merkezine düş (hassasiyet: ilçe).
        if coords is None and mahalle:
            coords = _nominatim(f"{district}, Kocaeli")
    except Exception:
        return None  # ağ hatasında cache'e yazma, sonraki turda yeniden dene

    cache[query] = list(coords) if coords else None
    _save_cache(cache)
    return coords


def resolve_hex(mahalle: str | None, ilce: str | None = None) -> dict | None:
    """Mahalle/ilçe adını hex bilgisine çevirir; çözülemezse None (raporlanır)."""
    coords = _coords_for(mahalle, ilce)
    if coords is None:
        return None
    lat, lng = coords
    h3_res9 = h3.latlng_to_cell(lat, lng, H3_RES_FINE)
    center_lat, center_lng = h3.cell_to_latlng(h3_res9)
    return {
        "h3_res9": h3_res9,
        "h3_res8": h3.cell_to_parent(h3_res9, H3_RES_POP),
        "h3_res7": h3.latlng_to_cell(lat, lng, H3_RES_COARSE),
        "lat": center_lat,   # hex MERKEZİ yazılır — olay adresi değil (KVKK)
        "lng": center_lng,
    }
