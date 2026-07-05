"""unmatched_news'teki haberleri geliştirilmiş konum çözümüyle yeniden dener.

geo.py'ye yeni yetenek eklendiğinde (Nominatim, yeni mahalleler) çalıştırılır.
Başarılı olanlar incidents'a taşınır ve rapor tablosundan silinir.
Kullanım: python retry_unmatched.py
"""
import asyncio

import aiohttp

import db
from main import process_article
from scraper import Article, _extract_body, _fetch


async def run() -> None:
    rows = db.get_client().table("unmatched_news").select("url, source").execute().data
    print(f"[retry] {len(rows)} konumsuz haber yeniden denenecek.")
    ok = 0
    async with aiohttp.ClientSession() as session:
        for row in rows:
            try:
                html = await _fetch(session, row["url"])
                text = _extract_body(html)
                if not text:
                    continue
                result = process_article(
                    Article(source=row["source"] or "?", url=row["url"], text=text)
                )
                if result in ("eklendi", "birlestirildi"):
                    db.get_client().table("unmatched_news").delete().eq("url", row["url"]).execute()
                    ok += 1
            except Exception as exc:
                print(f"[retry] hata: {row['url']}: {exc}")
    print(f"[retry] Bitti: {ok}/{len(rows)} haber haritaya eklendi.")


if __name__ == "__main__":
    asyncio.run(run())
