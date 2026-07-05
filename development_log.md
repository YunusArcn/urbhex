# DEVELOPMENT LOG

| Tarih | Saat | Başlık | İşlem (Versiyon) | Dosya/Satır | Durum |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-07-04 | 19:00 | Proje Başlangıcı | PDR, kurallar ve log dosyaları oluşturuldu; git deposu başlatıldı (v0.1) | /HABITEX_PDR.md, /habitex_rules.md, /development_log.md | OK |
| 2026-07-04 | 20:00 | DB Schema | incidents + event_weights + hex_population + hex_scores view + bbox RPC + RLS (v1.0) | /supabase/schema.sql | OK |
| 2026-07-04 | 20:00 | Python Bot | Asenkron scraper, Claude ayrıştırma (KVKK anonimleştirme), 3 aşamalı tekilleştirme, H3 geo çözümleme (v1.0) | /bot/*.py | OK |
| 2026-07-04 | 20:00 | Flutter UI | Adaptive harita ekranı, hex katmanı (bbox yükleme), olay paneli (sonsuz kaydırma), disclaimer (v1.0) | /app/lib/** | OK |
| 2026-07-04 | 20:00 | Dokümantasyon | README (kurulum + çalıştırma) ve .gitignore eklendi | /README.md, /.gitignore | OK |
| 2026-07-04 | 20:00 | Bug | Ortamda Flutter/Python/Node kurulu değil — kod derlenmedi, kurulum adımları README'de. Kurulum sonrası "flutter create . --platforms web" gerekli | - | AÇIK |
| 2026-07-04 | 20:30 | İsim/Domain | RDAP ile 30 aday tarandı. BOŞ .com'lar: urbhex, mahalio, livhex, kenthex, hexrisk, guvenmap, mapizmit, hexmahal (2026-07-04 itibarıyla). Öneri: Urbhex | - | OK |
| 2026-07-04 | 21:00 | Rebrand | urbhex.com satın alındı. Habitex → Urbhex geçişi: PDR/kurallar dosyaları yeniden adlandırıldı, tüm kod ve dokümanlar güncellendi (v1.1) | URBHEX_PDR.md, urbhex_rules.md, app/**, bot/** | OK |
| 2026-07-04 | 21:00 | Logo | Animasyonlu SVG logo (petek kümesi + wordmark) ve Flutter splash animasyonu eklendi (v1.0) | /assets/logo/urbhex_logo_animated.svg, /app/lib/screens/splash_screen.dart | OK |
| 2026-07-04 | 21:30 | Haber Kaynakları | 11 URL canlı test edildi; 5 doğrulanmış asayiş kaynağı config'e yazıldı (kocaeligazetesi, kocaelibaris, bizimyaka, gazetegebze, kocaelikoz). Eski 404 URL düzeltildi (v1.1) | /bot/config.py | OK |
| 2026-07-04 | 22:00 | Global Hat (GDELT) | GDELT 2.0 boru hattı: 15dk'lık export CSV → CAMEO filtre (17-20) → koordinat → H3 → tekilleştirmeli kayıt. Bing News API kullanılmadı (Microsoft Ağu 2025'te emekliye ayırdı) (v1.0) | /bot/gdelt.py | OK |
| 2026-07-05 | -- | Şema v2 | Yeni türler (trafik_kazasi, kavga, silahli_saldiri) + ikon eşleme, unmatched_news raporlama, Kontur nüfus betiği, 1-100 kırmızı→yeşil skor, zoom bazlı kümeleme (v2.0) | schema.sql, bot/**, app/** | OK |
| 2026-07-05 | -- | Bug Fix | h3 uzantısı Supabase'de yok → şema eklentisiz yapıya çevrildi (h3_res8 sütunu). Bot h3_res8 göndermiyordu, insert'ler NOT NULL hatasıyla düşüyordu (haritanın boş görünme nedeni) → geo.py/gdelt.py düzeltildi, backfill betiği eklendi | bot/geo.py, bot/gdelt.py, bot/backfill_res8.py, supabase/migration_v2_1.sql | OK |
| 2026-07-05 | -- | Token Tasarrufu | Parser Haiku 4.5'e alındı (eski 3.5 ID'si emekli — 404 veriyordu), anahtar kelime ön filtresi eklendi (alakasız haber AI'a gitmez), metin 3500 karaktere kısıldı, max_tokens düşürüldü | bot/parser.py, bot/config.py, bot/main.py | OK |
| 2026-07-05 | -- | Güvenlik | Gerçek API anahtarları .env.example'dan çıkarıldı (git'e girmesin), .env'de tutuluyor | bot/.env.example | OK |
| 2026-07-06 | -- | İlk Canlı Tur | Bağımlılıklar kuruldu, bot ilk kez uçtan uca çalıştı: 158 haber tarandı, 113 elendi, 45 konumsuz kaldı (mahalle sözlüğü yetersizdi) | bot/ | OK |
| 2026-07-06 | -- | Geocoding | Nominatim/OSM coğrafi kodlama eklendi (önbellekli, 1 istek/sn, Kocaeli kutusuna sınırlı); mahalle yoksa ilçe merkezine düşülür. retry_unmatched.py ile 59 konumsuz haberin 55'i haritaya taşındı → hex_scores 26 renkli hex döndürüyor (v2.1) | bot/geo.py, bot/retry_unmatched.py | OK |
