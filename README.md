# Habitex — Mahalle Güvenlik ve Yaşanabilirlik Endeksi

Faz 1 (MVP): İzmit'teki asayiş haberlerinin H3 altıgen bazlı harita gösterimi.
Anayasa: [HABITEX_PDR.md](HABITEX_PDR.md) · Kurallar: [habitex_rules.md](habitex_rules.md) · Günlük: [development_log.md](development_log.md)

## Proje Yapısı

```
supabase/schema.sql   → Veritabanı şeması (incidents, event_weights, hex_population, hex_scores view, RLS)
bot/                  → Python asenkron veri boru hattı (scrape → Claude ayrıştırma → tekilleştirme → DB)
app/                  → Flutter Adaptive UI (harita, hex katmanı, olay paneli)
```

## Kurulum (bu makinede henüz kurulu OLMAYAN araçlar)

1. **Python 3.11+** → https://www.python.org/downloads/ (veya `winget install Python.Python.3.12`)
2. **Flutter SDK** → https://docs.flutter.dev/get-started/install/windows (`flutter doctor` ile doğrulayın)
3. **Supabase projesi** → https://supabase.com adresinde ücretsiz proje açın

## Çalıştırma

### 1. Veritabanı
Supabase Dashboard → SQL Editor → `supabase/schema.sql` içeriğini yapıştırıp çalıştırın.

### 2. Bot
```powershell
cd bot
copy .env.example .env    # değerleri doldurun (Supabase URL, service_role key, Anthropic key)
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
python main.py            # tek çalıştırma; sunucuda cron ile 6 saatte bir
```

### 3. Flutter Web
```powershell
cd app
flutter create . --platforms web    # eksik platform dosyalarını üretir (ilk seferde)
flutter pub get
flutter run -d chrome --dart-define=SUPABASE_URL=https://XXXX.supabase.co --dart-define=SUPABASE_ANON_KEY=eyJ...
```

> Frontend'de **anon key** kullanılır (RLS sadece okumaya izin verir). `service_role` key yalnızca botta kalır.

## Sıradaki Adımlar (Faz 1 kalanlar)
- [ ] Gerçek İzmit haber kaynaklarının URL'lerini `bot/config.py` içinde doğrula
- [ ] `bot/geo.py` mahalle listesini OSM'den genişlet
- [ ] `hex_population` tablosunu TÜİK verisiyle doldur
- [ ] PostHog entegrasyonu (app_open, hex_tap, news_read event'leri)
- [ ] `url_launcher` ile kaynak linklerini açma
- [ ] k6 stres testi
