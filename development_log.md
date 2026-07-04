# DEVELOPMENT LOG

| Tarih | Saat | Başlık | İşlem (Versiyon) | Dosya/Satır | Durum |
| :--- | :--- | :--- | :--- | :--- | :--- |
| 2026-07-04 | 19:00 | Proje Başlangıcı | PDR, kurallar ve log dosyaları oluşturuldu; git deposu başlatıldı (v0.1) | /HABITEX_PDR.md, /habitex_rules.md, /development_log.md | OK |
| 2026-07-04 | 20:00 | DB Schema | incidents + event_weights + hex_population + hex_scores view + bbox RPC + RLS (v1.0) | /supabase/schema.sql | OK |
| 2026-07-04 | 20:00 | Python Bot | Asenkron scraper, Claude ayrıştırma (KVKK anonimleştirme), 3 aşamalı tekilleştirme, H3 geo çözümleme (v1.0) | /bot/*.py | OK |
| 2026-07-04 | 20:00 | Flutter UI | Adaptive harita ekranı, hex katmanı (bbox yükleme), olay paneli (sonsuz kaydırma), disclaimer (v1.0) | /app/lib/** | OK |
| 2026-07-04 | 20:00 | Dokümantasyon | README (kurulum + çalıştırma) ve .gitignore eklendi | /README.md, /.gitignore | OK |
| 2026-07-04 | 20:00 | Bug | Ortamda Flutter/Python/Node kurulu değil — kod derlenmedi, kurulum adımları README'de. Kurulum sonrası "flutter create . --platforms web" gerekli | - | AÇIK |
