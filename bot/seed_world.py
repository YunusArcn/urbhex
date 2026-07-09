"""DÜNYA TOHUMLAMA: tüm TR illeri + küresel metropollerin haberlerini tek seferde çeker.

Amaç: reklam/lansman öncesi hiçbir kullanıcı boş harita görmesin.
Şişme kontrolü: şehir başına TEK sorgu (yerel dilde) ve en fazla --per-city haber.
Tekilleştirme + hassasiyet normal boru hattından aynen geçer; tekrar
çalıştırmak güvenlidir (işlenmiş linkler atlanır → sadece yeni haber ekler).

Kullanım:
  python seed_world.py                    # her şey (TR + dünya)
  python seed_world.py --only tr          # sadece 81 il
  python seed_world.py --only world       # sadece küresel metropoller
  python seed_world.py --per-city 5       # şehir başına kota
"""
import argparse
import asyncio
from collections import Counter

import db
from scan_worker import fetch_google_news, process_item

TR_ILLER = [
    "Adana", "Adıyaman", "Afyonkarahisar", "Ağrı", "Amasya", "Ankara",
    "Antalya", "Artvin", "Aydın", "Balıkesir", "Bilecik", "Bingöl", "Bitlis",
    "Bolu", "Burdur", "Bursa", "Çanakkale", "Çankırı", "Çorum", "Denizli",
    "Diyarbakır", "Edirne", "Elazığ", "Erzincan", "Erzurum", "Eskişehir",
    "Gaziantep", "Giresun", "Gümüşhane", "Hakkari", "Hatay", "Isparta",
    "Mersin", "İstanbul", "İzmir", "Kars", "Kastamonu", "Kayseri",
    "Kırklareli", "Kırşehir", "Kocaeli", "Konya", "Kütahya", "Malatya",
    "Manisa", "Kahramanmaraş", "Mardin", "Muğla", "Muş", "Nevşehir", "Niğde",
    "Ordu", "Rize", "Sakarya", "Samsun", "Siirt", "Sinop", "Sivas",
    "Tekirdağ", "Tokat", "Trabzon", "Tunceli", "Şanlıurfa", "Uşak", "Van",
    "Yozgat", "Zonguldak", "Aksaray", "Bayburt", "Karaman", "Kırıkkale",
    "Batman", "Şırnak", "Bartın", "Ardahan", "Iğdır", "Yalova", "Karabük",
    "Kilis", "Osmaniye", "Düzce",
]

# (şehir, ülke adı, ülke kodu) — yerel dil scan_worker._LOCALES'ten gelir.
WORLD_CITIES = [
    ("New York", "United States", "us"), ("Los Angeles", "United States", "us"),
    ("Chicago", "United States", "us"), ("Houston", "United States", "us"),
    ("Miami", "United States", "us"), ("Toronto", "Canada", "ca"),
    ("Vancouver", "Canada", "ca"), ("Mexico City", "Mexico", "mx"),
    ("São Paulo", "Brazil", "br"), ("Rio de Janeiro", "Brazil", "br"),
    ("Buenos Aires", "Argentina", "ar"), ("London", "United Kingdom", "gb"),
    ("Manchester", "United Kingdom", "gb"), ("Berlin", "Germany", "de"),
    ("München", "Germany", "de"), ("Hamburg", "Germany", "de"),
    ("Frankfurt", "Germany", "de"), ("Köln", "Germany", "de"),
    ("Paris", "France", "fr"), ("Lyon", "France", "fr"),
    ("Marseille", "France", "fr"), ("Madrid", "Spain", "es"),
    ("Barcelona", "Spain", "es"), ("Roma", "Italy", "it"),
    ("Milano", "Italy", "it"), ("Napoli", "Italy", "it"),
    ("Amsterdam", "Netherlands", "nl"), ("Rotterdam", "Netherlands", "nl"),
    ("Brussels", "Belgium", "be"), ("Wien", "Austria", "at"),
    ("Zürich", "Switzerland", "ch"), ("Lisboa", "Portugal", "pt"),
    ("Athens", "Greece", "gr"), ("Stockholm", "Sweden", "se"),
    ("Oslo", "Norway", "no"), ("Copenhagen", "Denmark", "dk"),
    ("Warsaw", "Poland", "pl"), ("Prague", "Czechia", "cz"),
    ("Budapest", "Hungary", "hu"), ("Bucharest", "Romania", "ro"),
    ("Kyiv", "Ukraine", "ua"), ("Dubai", "United Arab Emirates", "ae"),
    ("Cairo", "Egypt", "eg"), ("Johannesburg", "South Africa", "za"),
    ("Cape Town", "South Africa", "za"), ("Mumbai", "India", "in"),
    ("Delhi", "India", "in"), ("Singapore", "Singapore", "sg"),
    ("Tokyo", "Japan", "jp"), ("Osaka", "Japan", "jp"),
    ("Seoul", "South Korea", "kr"), ("Sydney", "Australia", "au"),
    ("Melbourne", "Australia", "au"), ("Auckland", "New Zealand", "nz"),
    ("Baku", "Azerbaijan", "az"), ("Tbilisi", "Georgia", "ge"),
]


async def run(only: str, per_city: int, days: int, rotate: int = 0) -> None:
    targets: list[tuple[str, str, str]] = []
    if only in ("tr", "all"):
        targets += [(il, "Türkiye", "tr") for il in TR_ILLER]
    if only in ("world", "all"):
        targets += WORLD_CITIES

    # DÖNEN DİLİM modu (GitHub Actions saatlik): her saat listenin farklı bir
    # parçası taranır → tüm dünya birkaç saatte bir tamamen tazelenir, tek
    # koşu Actions'ın süre sınırına sığar.
    if rotate > 0:
        import time

        slices = max(1, -(-len(targets) // rotate))  # tavan bölme
        idx = int(time.time() // 3600) % slices
        targets = targets[idx * rotate:(idx + 1) * rotate]
        print(f"[seed] Dönen dilim {idx + 1}/{slices}: {[t[0] for t in targets]}")

    known = db.known_source_urls()
    total: Counter = Counter()
    print(f"[seed] {len(targets)} şehir, şehir başına en çok {per_city} haber, son {days} gün.\n")

    for n, (city, country, cc) in enumerate(targets, 1):
        stats: Counter = Counter()
        try:
            items = fetch_google_news(city, days=days, country_code=cc)
        except Exception as exc:
            print(f"[seed] {n}/{len(targets)} {city}: sorgu hatası ({exc})")
            continue
        for item in items[:per_city]:
            try:
                r = process_item(item, city, known, country=country, country_code=cc)
                stats[r] += 1
                known.add(item["link"])
                # Ücretsiz AI katmanlarının dakika limitine takılmamak için tempo.
                await asyncio.sleep(2)
            except Exception as exc:
                # Kredi bittiyse ve ÜCRETSİZ sağlayıcı da yoksa DUR.
                # (Gemini/Groq tanımlıysa 429'ları parser bekleyerek aşar;
                #  Anthropic'in kredi hatası tek başına koşuyu öldürmemeli.)
                import os as _os

                if "credit balance" in str(exc).lower() and not (
                        _os.environ.get("GEMINI_API_KEY")
                        or _os.environ.get("GROQ_API_KEY")):
                    print("\n[seed] DURDU: Anthropic API kredisi bitti ve "
                          "ücretsiz sağlayıcı tanımlı değil! GEMINI/GROQ "
                          "anahtarı ekleyin veya kredi yükleyin.")
                    raise SystemExit(2) from exc
                stats["hata"] += 1
                if stats["hata"] <= 3:  # ilk hataları göster (sessiz yutma yok)
                    print(f"[seed]   hata örneği: {exc}")
        total.update(stats)
        print(f"[seed] {n}/{len(targets)} {city} ({cc}): {dict(stats)}")

    print(f"\n[seed] DÜNYA TOHUMLAMASI BİTTİ: {dict(total)}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", choices=["tr", "world", "all"], default="all")
    ap.add_argument("--per-city", type=int, default=8)
    ap.add_argument("--days", type=int, default=7)
    ap.add_argument("--rotate", type=int, default=0,
                    help="Saatlik dönen dilim boyutu (0 = tüm liste tek seferde)")
    args = ap.parse_args()
    asyncio.run(run(args.only, args.per_city, args.days, args.rotate))
