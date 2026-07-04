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
    """Daha önce işlenmiş tüm kaynak URL'leri (tekrar AI'a gitmesin — maliyet 0 kuralı)."""
    rows = get_client().table("incidents").select("source_urls").execute().data
    return {url for row in rows for url in row["source_urls"]}


def find_dedup_candidates(occurred_on: str, h3_res9: str, event_type: str) -> list[dict]:
    """Birincil filtre: aynı gün + aynı hex + aynı tür."""
    return (
        get_client()
        .table("incidents")
        .select("id, summary, source_urls")
        .eq("occurred_on", occurred_on)
        .eq("h3_res9", h3_res9)
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
