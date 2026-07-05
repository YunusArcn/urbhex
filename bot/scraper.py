"""Veri Avı: kaynakları asenkron tarar, yalnızca YENİ haber linklerini döndürür.

"Ahtapot mantığı": tüm kaynaklara aynı anda istek atılır, sıralı beklenmez.
"""
import asyncio
from dataclasses import dataclass

import aiohttp
from bs4 import BeautifulSoup

from config import NEWS_SOURCES

HEADERS = {"User-Agent": "UrbhexBot/0.1 (+https://urbhex.com)"}


@dataclass
class Article:
    source: str
    url: str
    text: str


async def _fetch(session: aiohttp.ClientSession, url: str) -> str:
    async with session.get(url, headers=HEADERS, timeout=aiohttp.ClientTimeout(total=30)) as resp:
        resp.raise_for_status()
        return await resp.text()


def _extract_links(list_html: str, base_url: str) -> list[str]:
    """Asayiş liste sayfasından haber linklerini çıkarır."""
    soup = BeautifulSoup(list_html, "html.parser")
    links = set()
    for a in soup.select("a[href]"):
        href = a["href"]
        if href.startswith("/"):
            root = base_url.split("/", 3)
            href = f"{root[0]}//{root[2]}{href}"
        low = href.lower().rstrip("/")
        if low.endswith("-haberleri") or low.endswith("/haberleri"):
            continue  # kategori sayfaları haber değil (410/404 gürültüsü yapıyordu)
        if href.startswith("http") and any(k in low for k in ("haber", "asayis", "3-sayfa")):
            links.add(href.split("?")[0])
    return sorted(links)


def _extract_body(article_html: str) -> str:
    soup = BeautifulSoup(article_html, "html.parser")
    for tag in soup(["script", "style", "nav", "footer", "header", "aside"]):
        tag.decompose()
    paragraphs = [p.get_text(" ", strip=True) for p in soup.select("article p, .haber-detay p, p")]
    return "\n".join(t for t in paragraphs if len(t) > 40)[:3500]  # token tasarrufu


async def scrape_new_articles(known_urls: set[str]) -> list[Article]:
    """Tüm kaynakları paralel tarar; daha önce işlenmemiş haberlerin metnini döndürür."""
    articles: list[Article] = []
    async with aiohttp.ClientSession() as session:
        list_pages = await asyncio.gather(
            *(_fetch(session, s["url"]) for s in NEWS_SOURCES),
            return_exceptions=True,
        )
        new_links: list[tuple[str, str]] = []
        for source, html in zip(NEWS_SOURCES, list_pages):
            if isinstance(html, Exception):
                print(f"[scraper] {source['name']} liste sayfası alınamadı: {html}")
                continue
            for link in _extract_links(html, source["url"]):
                if link not in known_urls:
                    new_links.append((source["name"], link))

        bodies = await asyncio.gather(
            *(_fetch(session, url) for _, url in new_links),
            return_exceptions=True,
        )
        for (source_name, url), body in zip(new_links, bodies):
            if isinstance(body, Exception):
                print(f"[scraper] {url} alınamadı: {body}")
                continue
            text = _extract_body(body)
            if text:
                articles.append(Article(source=source_name, url=url, text=text))
    return articles
