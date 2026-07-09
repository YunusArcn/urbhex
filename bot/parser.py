"""Çok sağlayıcılı AI ayrıştırma — maliyet stratejisi:

  1) Google Gemini Flash (ÜCRETSİZ katman)   ┐ istekler bu ikisi arasında
  2) Groq / Llama 3.3 (ÜCRETSİZ katman)      ┘ sırayla döner (kota yayılır)
  3) Claude Haiku (ücretli) — yalnızca ikisi de yanıt veremezse SON ÇARE

Kota/hız hatası veren sağlayıcı 10 dk "dinlenmeye" alınır ve zincir diğerine
geçer. Hiçbiri çalışmazsa istisna yükselir; haber unmatched/sonraki tura kalır.

Anahtarlar (.env / GitHub Secrets):
  GEMINI_API_KEY  → aistudio.google.com/apikey  (ücretsiz, kart istemez)
  GROQ_API_KEY    → console.groq.com/keys       (ücretsiz)
  ANTHROPIC_API_KEY → mevcut (yedek)
"""
import json
import os
import time
import urllib.error
import urllib.request
from datetime import date

from pydantic import BaseModel

from config import EVENT_TYPES

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

_SCHEMA_HINT = ('Yanıtı SADECE geçerli JSON olarak ver, başka hiçbir şey yazma: '
                '{"ilgili": true/false, "ulke": "..."|null, "il": "..."|null, '
                '"ilce": "..."|null, "mahalle": "..."|null, "olay_turu": "..."|null, '
                '"tarih": "YYYY-MM-DD"|null, "kisa_ozet": "..."|null}')


class ParsedIncident(BaseModel):
    ilgili: bool            # bir asayiş/kaza olayı mı?
    ulke: str | None        # örn: Türkiye, United States
    il: str | None          # örn: Bursa, New York
    ilce: str | None        # örn: Osmangazi, Brooklyn
    mahalle: str | None
    olay_turu: str | None
    tarih: date | None      # YYYY-MM-DD
    kisa_ozet: str | None   # 2 cümle, anonim, Türkçe


# ---------------- Sağlayıcılar ----------------

def _post_json(url: str, payload: dict, headers: dict) -> dict:
    req = urllib.request.Request(
        url, data=json.dumps(payload).encode("utf-8"),
        headers={"Content-Type": "application/json", **headers})
    try:
        with urllib.request.urlopen(req, timeout=60) as resp:
            return json.loads(resp.read())
    except urllib.error.HTTPError as e:
        body = e.read()[:300].decode("utf-8", errors="replace")
        raise RuntimeError(f"HTTP {e.code}: {body}") from e


def _ask_gemini(system: str, user: str) -> dict:
    model = os.environ.get("GEMINI_MODEL", "gemini-2.0-flash")
    url = ("https://generativelanguage.googleapis.com/v1beta/models/"
           f"{model}:generateContent?key={os.environ['GEMINI_API_KEY']}")
    data = _post_json(url, {
        "system_instruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": user}]}],
        "generationConfig": {"response_mime_type": "application/json",
                             "temperature": 0.2},
    }, {})
    return json.loads(data["candidates"][0]["content"]["parts"][0]["text"])


def _ask_groq(system: str, user: str) -> dict:
    model = os.environ.get("GROQ_MODEL", "llama-3.3-70b-versatile")
    data = _post_json("https://api.groq.com/openai/v1/chat/completions", {
        "model": model,
        "messages": [{"role": "system", "content": system},
                     {"role": "user", "content": user}],
        "response_format": {"type": "json_object"},
        "temperature": 0.2,
    }, {"Authorization": f"Bearer {os.environ['GROQ_API_KEY']}"})
    return json.loads(data["choices"][0]["message"]["content"])


def _ask_anthropic(system: str, user: str) -> dict:
    import anthropic  # tembel import: yedek hiç gerekmezse SDK yüklenmez

    client = anthropic.Anthropic()
    resp = client.messages.create(
        model="claude-haiku-4-5", max_tokens=1024,
        system=system,
        messages=[{"role": "user", "content": user}],
    )
    text = next(b.text for b in resp.content if b.type == "text")
    return json.loads(text[text.index("{"):text.rindex("}") + 1])


_FREE = [("gemini", _ask_gemini, "GEMINI_API_KEY"),
         ("groq", _ask_groq, "GROQ_API_KEY")]
_PAID = [("anthropic", _ask_anthropic, "ANTHROPIC_API_KEY")]
_cooldown: dict[str, float] = {}
_rr = 0  # round-robin: ücretsizler sırayla öne geçer


def _ask(system: str, user: str) -> dict:
    global _rr
    now = time.time()
    free = [p for p in _FREE if os.environ.get(p[2])]
    if free:
        shift = _rr % len(free)
        free = free[shift:] + free[:shift]
        _rr += 1
    chain = free + [p for p in _PAID if os.environ.get(p[2])]
    if not chain:
        raise RuntimeError("Hiçbir AI anahtarı tanımlı değil (GEMINI/GROQ/ANTHROPIC)")

    last: Exception | None = None
    for name, fn, _ in chain:
        if _cooldown.get(name, 0) > now:
            continue
        try:
            return fn(system, user)
        except Exception as exc:
            last = exc
            msg = str(exc).lower()
            if any(k in msg for k in ("429", "quota", "rate", "exhaust", "credit", "overload")):
                _cooldown[name] = now + 600  # kota/hız: 10 dk dinlendir
            print(f"[parser] {name} hata: {str(exc)[:140]}")
    raise RuntimeError(f"Tüm AI sağlayıcılar başarısız: {last}")


def _clean(raw: dict) -> dict:
    # Bazı modeller null yerine "" döndürür — pydantic'e girmeden temizle.
    return {k: (None if v == "" else v) for k, v in raw.items()}


# ---------------- Genel API (boru hattının kullandığı yüzey) ----------------

def parse_article(article_text: str) -> ParsedIncident | None:
    """Tek haber metnini ayrıştırır; asayiş olayı değilse/eksikse None döner."""
    raw = _ask(f"{SYSTEM_PROMPT}\n\n{_SCHEMA_HINT}",
               f"Haber metni:\n\n{article_text[:3500]}")
    try:
        parsed = ParsedIncident(**_clean(raw))
    except Exception:
        return None
    if not parsed.ilgili:
        return None
    if not (parsed.olay_turu and parsed.kisa_ozet and parsed.tarih):
        return None
    return parsed


def is_same_incident(summary_a: str, summary_b: str) -> bool:
    """Anlamsal eşleştirme: iki özet %85+ olasılıkla aynı olayı mı anlatıyor?"""
    raw = _ask(
        'Yanıtı SADECE şu JSON ile ver: {"ayni_olay": true/false}',
        "Aşağıdaki iki asayiş haberi özeti %85'in üzerinde bir olasılıkla "
        f"AYNI olayı mı anlatıyor?\n\nÖzet 1: {summary_a}\n\nÖzet 2: {summary_b}",
    )
    return bool(raw.get("ayni_olay"))
