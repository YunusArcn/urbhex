# HABITEX PROJECT RULES (Anayasa)

> AI ajanlar (Claude / OpenCode) bu dosyayı okumadan hiçbir koda dokunamaz.

## Teknoloji
- **Framework:** Flutter (Adaptive UI), Supabase, H3 Indexing.
- **Data Source:** Yerel haber siteleri + Google News/Bing API (Scraping), Kontur (Global Population), TÜİK (İzmit MVP).
- **Harita:** Mapbox / Deck.gl (GPU hexagon render). Mahalle sınırı yok, sadece H3 hex.

## Kod Kuralları
- **Modülerlik:** Her fonksiyon kendi dosyasında (Single Responsibility).
- **Token Optimizasyonu:**
  - AI'a asla tüm projeyi okutma.
  - Sadece ilgili dosyayı + PDR/LOG dosyalarını okut.
  - Değişiklikleri kodun tamamını vererek değil, fonksiyonel olarak bildir.

## Güvenlik ve Hukuk (KVKK)
- Şahıs ismi (Ahmet Y., M.K.) ve açık adres/kapı numarası veritabanına ASLA yazılmaz.
- Haber metninin tamamı saklanmaz; sadece özet + kaynak URL.

## Git Protokolü
- Kod değişikliği öncesi `git commit` (save point).
- Hata durumunda `discard changes` (rollback).
- Her günün sonunda çalışır durumda commit at.

## Otonomi
- Her görev sonrası `development_log.md` güncellenir.
- Hatalar log dosyasına **Bug** etiketiyle kaydedilir.
