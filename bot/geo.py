"""Mahalle adı → koordinat → H3 hex çözümü.

PDR gereği mahalle sınırı kullanılmaz; mahalle merkezinden H3 hex hesaplanır.
Kaynak: mahalle merkez koordinatları (OSM'den elle derlendi, genişletilecek).
"""
import h3

from config import H3_RES_COARSE, H3_RES_FINE

# İzmit mahalle merkezleri (lat, lng) — MVP başlangıç seti, OSM'den genişletilecek.
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
    "izmit merkez": (40.7654, 29.9408),
}

_TR_MAP = str.maketrans("çğıöşüÇĞİÖŞÜ", "cgiosuCGIOSU")


def _normalize(name: str) -> str:
    return name.translate(_TR_MAP).lower().strip()


def resolve_hex(mahalle: str | None) -> dict | None:
    """Mahalle adını hex bilgisine çevirir. Bilinmeyen mahalle → İzmit merkez."""
    key = _normalize(mahalle) if mahalle else "izmit merkez"
    lat, lng = IZMIT_MAHALLE_MERKEZLERI.get(key, IZMIT_MAHALLE_MERKEZLERI["izmit merkez"])
    h3_res9 = h3.latlng_to_cell(lat, lng, H3_RES_FINE)
    center_lat, center_lng = h3.cell_to_latlng(h3_res9)
    return {
        "h3_res9": h3_res9,
        "h3_res7": h3.latlng_to_cell(lat, lng, H3_RES_COARSE),
        "lat": center_lat,   # hex MERKEZİ yazılır — olay adresi değil (KVKK)
        "lng": center_lng,
    }
