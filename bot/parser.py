"""AI Ayrıştırma: haber metninden anonim, yapılandırılmış olay verisi çıkarır.

KVKK kalkanı prompt seviyesinde uygulanır — şahıs ismi/açık adres asla çıktıya girmez.
"""
from datetime import date

import anthropic
from pydantic import BaseModel

from config import EVENT_TYPES

client = anthropic.Anthropic()  # ANTHROPIC_API_KEY ortam değişkeninden okunur

# Maliyet: Haiku 4.5 ($1/$5 per MTok) — ayrıştırma için yeterli zekada, en ucuz katman.
# NOT: claude-3-5-haiku-20241022 Şubat 2026'da emekli edildi, o ID artık 404 döner.
MODEL = "claude-haiku-4-5"

SYSTEM_PROMPT = f"""Sen KÜRESEL bir asayiş haberi ayrıştırma asistanısın. Haber Türkçe, İngilizce \
veya başka bir dilde olabilir; DÜNYANIN HERHANGİ BİR YERİNDEKİ olaylar geçerlidir.

KURALLAR (gizlilik — ihlal edilemez):
- Özette ASLA şahıs ismi/kısaltması, plaka, kapı/apartman numarası yazma.
- Özet en fazla 2 cümle, TÜRKÇE, tarafsız ve anonim olsun ("bir kişi", "iki şüpheli").
- olay_turu şunlardan biri olmalı: {", ".join(EVENT_TYPES)}.
  İngilizce eşleme: murder/homicide→cinayet, shooting→silahli_saldiri,
  robbery→gasp, theft/burglary→hirsizlik, assault/stabbing→yaralama,
  brawl/fight→kavga, drug→uyusturucu, car crash/accident→trafik_kazasi.
  Emin değilsen "diger".
- Haber bir asayiş/kaza olayı anlatmıyorsa (magazin, spor, duyuru, siyaset) ilgili=false döndür.
- Konum alanları: ulke = ülke adı; il = şehir/eyalet (örn: Bursa, New York);
  ilce = ilçe/district/borough/county; mahalle = mahalle/neighborhood.
  Metinde geçenleri aynen yaz; geçmeyeni null bırak.
- Tarih metinden çıkarılamıyorsa yayın bağlamından tahmin et, o da yoksa null bırak."""


class ParsedIncident(BaseModel):
    ilgili: bool            # bir asayiş/kaza olayı mı?
    ulke: str | None        # örn: Türkiye, United States
    il: str | None          # örn: Bursa, New York
    ilce: str | None        # örn: Osmangazi, Brooklyn
    mahalle: str | None
    olay_turu: str | None
    tarih: date | None      # YYYY-MM-DD
    kisa_ozet: str | None   # 2 cümle, anonim


def parse_article(article_text: str) -> ParsedIncident | None:
    """Tek haber metnini Claude'a gönderir; İzmit asayiş olayı değilse None döner."""
    response = client.messages.parse(
        model=MODEL,
        max_tokens=1024,  # çıktı küçük bir JSON — daha fazlasına gerek yok
        system=SYSTEM_PROMPT,
        messages=[{"role": "user", "content": f"Haber metni:\n\n{article_text[:3500]}"}],
        output_format=ParsedIncident,
    )
    parsed = response.parsed_output
    if parsed is None or not parsed.ilgili:
        return None
    if not (parsed.olay_turu and parsed.kisa_ozet and parsed.tarih):
        return None
    return parsed


def is_same_incident(summary_a: str, summary_b: str) -> bool:
    """Anlamsal eşleştirme: iki özet %85+ olasılıkla aynı olayı mı anlatıyor?

    (İleride maliyet için vektör/embedding karşılaştırmasına taşınacak.)
    """

    class SameIncident(BaseModel):
        ayni_olay: bool

    response = client.messages.parse(
        model=MODEL,
        max_tokens=256,  # tek boolean cevap
        messages=[{
            "role": "user",
            "content": (
                "Aşağıdaki iki asayiş haberi özeti %85'in üzerinde bir olasılıkla AYNI olayı mı anlatıyor?\n\n"
                f"Özet 1: {summary_a}\n\nÖzet 2: {summary_b}"
            ),
        }],
        output_format=SameIncident,
    )
    return bool(response.parsed_output and response.parsed_output.ayni_olay)
