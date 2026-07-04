"""Habitex bot yapılandırması. Her ayar tek yerden yönetilir."""
import os

from dotenv import load_dotenv

load_dotenv()

SUPABASE_URL = os.environ["SUPABASE_URL"]
SUPABASE_SERVICE_KEY = os.environ["SUPABASE_SERVICE_KEY"]  # service_role — RLS bypass, sadece botta!

# İzmit yerel haber kaynakları — asayiş/RSS sayfaları.
# Yeni kaynak eklemek = bu listeye satır eklemek.
NEWS_SOURCES = [
    {"name": "kocaeligazetesi", "url": "https://www.kocaeligazetesi.com.tr/asayis", "type": "html"},
    {"name": "kocaelikoz", "url": "https://www.kocaelikoz.com/3-sayfa", "type": "html"},
    # {"name": "ornek_rss", "url": "https://ornek.com/asayis/rss", "type": "rss"},
]

SCRAPE_INTERVAL_HOURS = 6
H3_RES_FINE = 9    # ~0.1 km2, sokak seviyesi
H3_RES_COARSE = 7  # ~5 km2, genel bakış

EVENT_TYPES = [
    "cinayet", "gasp", "yaralama", "haneye_tecavuz",
    "hirsizlik", "uyusturucu", "diger",
]
