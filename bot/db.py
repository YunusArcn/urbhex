"""Supabase erişim katmanı — tüm veritabanı işlemleri tek dosyada."""
from supabase import Client, create_client

from config import SUPABASE_SERVICE_KEY, SUPABASE_URL

_client: Client | None = None


def get_client() -> Client:
    global _client
    if _client is None:
        _client = create_client(SUPABASE_URL, SUPABASE_SERVICE_KEY)
    return _client


def known_source_urls() -> set[str]:
    """Daha önce işlenmiş tüm kaynak URL'leri (tekrar AI'a gitmesin — maliyet 0 kuralı).

    Konumu çözülemeyip raporlanan haberler de dahildir (tekrar denenmez).
    """
    urls = set()
    rows = get_client().table("incidents").select("source_urls").execute().data
    urls.update(url for row in rows for url in row["source_urls"])
    unmatched = get_client().table("unmatched_news").select("url").execute().data
    urls.update(row["url"] for row in unmatched)
    return urls


def report_unmatched(url: str, source: str, reason: str) -> None:
    """Bölgeyle eşlenemeyen haberi raporla — sessizce atılmaz, incelenmek üzere saklanır."""
    get_client().table("unmatched_news").upsert(
        {"url": url, "source": source, "reason": reason}, on_conflict="url"
    ).execute()


def find_dedup_candidates(occurred_on: str, h3_res7: str, event_type: str) -> list[dict]:
    """Birincil filtre: ±1 gün + aynı res-7 bölge (~5 km2) + aynı tür.

    (İki site aynı olayı bir gün arayla ve farklı mahalleyle verebiliyor;
    dar res-9 + tek-gün eşitliği mükerrer kayıtlara yol açıyordu. Geniş filtre
    adayları bulur, benzerlik/anlamsal karşılaştırma son kararı verir.)
    """
    from datetime import date, timedelta

    d = date.fromisoformat(occurred_on)
    return (
        get_client()
        .table("incidents")
        .select("id, summary, source_urls")
        .gte("occurred_on", (d - timedelta(days=1)).isoformat())
        .lte("occurred_on", (d + timedelta(days=1)).isoformat())
        .eq("h3_res7", h3_res7)
        .eq("event_type", event_type)
        .execute()
        .data
    )


def append_source(incident_id: str, existing_urls: list[str], new_url: str) -> None:
    """Kaynak dizisi mantığı: mükerrer olayda yeni kayıt açılmaz, link eklenir."""
    if new_url not in existing_urls:
        get_client().table("incidents").update(
            {"source_urls": existing_urls + [new_url]}
        ).eq("id", incident_id).execute()


def insert_incident(record: dict) -> None:
    get_client().table("incidents").insert(record).execute()
