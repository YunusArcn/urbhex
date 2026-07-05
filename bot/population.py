"""Kontur global nüfus verisini H3 res-8 bazında Supabase'e yükler (TEK SEFERLİK).

Kaynak: Kontur Population (400m H3 hex grid, tüm dünya, ücretsiz):
  https://data.humdata.org/dataset/kontur-population-dataset
  → "kontur_population_YYYYMMDD.gpkg.gz" dosyasını indirip aç (gunzip).
  Ülke bazlı küçük dosyalar da var: "Kontur Population <Ülke>" araması.

Kullanım:
  pip install geopandas h3 supabase python-dotenv     # geopandas sadece bu betik için
  python population.py kontur_population_TR.gpkg                 # tek ülke (önerilen başlangıç)
  python population.py kontur_population.gpkg --bbox 28.5 40.2 31.5 41.5   # sadece bir bölge

Not: TÜM dünya ~10 GB veri / on milyonlarca hex üretir — Supabase ücretsiz
planına (500 MB) sığmaz. Strateji: yayında olduğun ülkeleri yükle, yenisi
açıldıkça ekle. Betik zaten "1 kere çek, sonsuza dek kullan" mantığıyla çalışır.
"""
import argparse
import sys

import geopandas as gpd
import h3

import db

BATCH = 1000


def load(gpkg_path: str, bbox: tuple[float, float, float, float] | None) -> None:
    print(f"[population] {gpkg_path} okunuyor (büyük dosyada birkaç dakika sürebilir)...")
    gdf = gpd.read_file(gpkg_path, bbox=bbox)  # bbox verilirse sadece o pencere okunur
    print(f"[population] {len(gdf):,} hex satırı bulundu.")

    rows, total = [], 0
    for _, row in gdf.iterrows():
        pop = int(row.get("population") or 0)
        if pop <= 0:
            continue
        # Kontur h3 sütunu varsa doğrudan kullan; yoksa merkezden hesapla.
        cell = row.get("h3") or h3.latlng_to_cell(
            row.geometry.centroid.y, row.geometry.centroid.x, 8
        )
        rows.append({"h3_res8": str(cell), "population": pop})
        if len(rows) >= BATCH:
            db.get_client().table("hex_population").upsert(rows).execute()
            total += len(rows)
            rows = []
            print(f"[population] {total:,} hex yüklendi...", end="\r")
    if rows:
        db.get_client().table("hex_population").upsert(rows).execute()
        total += len(rows)
    print(f"\n[population] Bitti: {total:,} hex nüfusu veritabanında.")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("gpkg", help="Kontur .gpkg dosya yolu")
    ap.add_argument("--bbox", nargs=4, type=float, metavar=("MIN_LNG", "MIN_LAT", "MAX_LNG", "MAX_LAT"))
    args = ap.parse_args()
    try:
        load(args.gpkg, tuple(args.bbox) if args.bbox else None)
    except Exception as exc:
        print(f"[population] HATA: {exc}")
        sys.exit(1)
