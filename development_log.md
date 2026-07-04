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
