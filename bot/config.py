"""Urbhex bot yapılandırması. Her ayar tek yerden yönetilir."""
import os

from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]  # service_role — RLS bypass, sadece botta!

# İzmit/Kocaeli yerel haber kaynakları — asayiş sayfaları.
# Tümü 2026-07-04 tarihinde HTTP 200 ile doğrulandı. Yeni kaynak = yeni satır.
NEWS_SOURCES = [
    {"name": "kocaeligazetesi", "url": "https://www.kocaeligazetesi.com.tr/asayis", "type": "html"},
    {"name": "kocaelibaris", "url": "https://www.kocaelibarisgazetesi.com/asayis", "type": "html"},
    {"name": "bizimyaka", "url": "https://www.bizimyaka.com/haberleri/asayis", "type": "html"},
    {"name": "gazetegebze", "url": "https://www.gazetegebze.com.tr/asayis", "type": "html"},
    {"name": "kocaelikoz", "url": "https://www.kocaelikoz.com/asayis", "type": "html"},
    # RSS alternatifi (daha stabil, V1.1'de scraper'a rss desteği eklenince açılacak):
    # {"name": "kocaeligazetesi_rss", "url": "https://www.kocaeligazetesi.com.tr/rss", "type": "rss"},
]

SCRAPE_INTERVAL_HOURS = 6
H3_RES_FINE = 9    # ~0.1 km2, sokak seviyesi
H3_RES_COARSE = 7  # ~5 km2, genel bakış

EVENT_TYPES = [
    "cinayet", "silahli_saldiri", "gasp", "yaralama", "haneye_tecavuz",
    "kavga", "hirsizlik", "uyusturucu", "trafik_kazasi", "diger",
]

H3_RES_POP = 8  # nüfus eşleme çözünürlüğü (hex_population tablosu)

# Token tasarrufu: metinde bu kelimelerden biri yoksa haber AI'a HİÇ gönderilmez.
# (Asayiş sayfalarında magazin/duyuru da çıkabiliyor — onlara token harcanmaz.)
ASAYIS_KEYWORDS = [
    "hırsız", "gasp", "cinayet", "öldür", "yaralan", "yaralı", "bıçak", "silah",
    "kaza", "çarptı", "uyuşturucu", "kavga", "darp", "polis", "jandarma",
    "gözaltı", "tutukla", "operasyon", "soygun", "kaçakçı", "dolandır", "cinsel",
]
