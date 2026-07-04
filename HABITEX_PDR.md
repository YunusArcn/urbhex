# HABITEX PDR (Project Design Requirements)
> Bu doküman projenin anayasasıdır. Tüm geliştirme süreçlerinde referans alınır.
> Son güncelleme: 2026-07-04

---

## 1. Proje Vizyonu

**Habitex**, küresel ölçekte çalışan, harita tabanlı bir **Canlı Yaşam Analitiği ve Asayiş Haber Platformu**dur. Kullanıcılara sadece suç verisi değil; ulaşım, sosyal yaşam ve emlak verilerini birleştirerek **"Mahalle Yaşanabilirlik Endeksi"** sunar.

**Amaç:** Taşınma veya gayrimenkul yatırımı kararı alan kişilere, hedefledikleri bölgenin güvenlik durumunu veri odaklı, şeffaf ve hukuka uygun şekilde sunan interaktif bir harita platformu yaratmak.

**MVP Stratejisi:**
- İlk sürüm **Flutter Web** olarak yayınlanır (mağaza onay bürokrasisini aşmak + Sahibinden ilan no ile aramayı kolaylaştırmak için).
- Kapsam yalnızca **İzmit (Kocaeli)** ile sınırlıdır; sistemin doğruluğu burada kanıtlanır.

---

## 2. Teknik Mimari (Stack)

| Katman | Teknoloji |
| :--- | :--- |
| Frontend | Flutter (Adaptive UI — Web, Mobil, Desktop tek kod tabanı) |
| Backend | Supabase (PostgreSQL + RLS + Edge Functions) |
| Harita Motoru | Uber H3 (altıgen grid) + Mapbox / Deck.gl (GPU render) |
| Arka Plan Botu | Python (asyncio — asenkron tarama), Hetzner sunucu |
| AI | Claude API (haber ayrıştırma, anonimleştirme, tekilleştirme) |
| Analitik | PostHog (ilk günden gömülü — heatmap, event takibi) |
| Ölçekleme | Supabase Edge Functions / Cloudflare Workers (serverless klonlama); büyüyünce Redis + Celery kuyruk |

### Mimari Prensipler
- **Serverless kullanıcı istekleri:** Anlık aramalar Edge Functions ile sınırsız klonlanır; tek sunucuya kuyruk oluşmaz.
- **Asenkron bot:** Python botu `asyncio` ile tüm kaynaklara paralel istek atar, sıralı beklemez.
- **Bounding Box sorgusu:** Harita kaydırıldığında yalnızca ekranda görünen çerçevedeki hex'ler veritabanından çekilir.
- **Lazy Loading:** Kimsenin takip etmediği bölgeler yalnızca arama yapıldığında güncellenir.

---

## 3. Harita ve H3 Sistemi

- **Mahalle sınırları kullanılmaz.** Olaylar GPS koordinatına göre doğrudan ilgili H3 altıgenine yazılır.
- **Dinamik çözünürlük:** Uzak zoom'da Res 7 (~5 km²), yakın zoom'da Res 9 (~0.1 km², 3-4 sokak).
- **Görselleştirme:** Hexagon Layer Fill — %40-50 şeffaf renkli altıgen dolgu. Olaysız hex şeffaf/hafif yeşil; yoğunluğa göre sarı → turuncu → kırmızı.
- **Kümeleme (Clustering):** Uzak bakışta olaylar "50 olay" rozetleriyle kümelenir, zoom ile sokağa kadar dağılır.

---

## 4. Kullanıcı Arayüzü (UI/UX)

- Açılışta karmaşık menü yok → doğrudan **tam ekran harita** (İzmit varsayılan).
- **Arama çubuğu:** "Mahalle Ara veya Sahibinden İlan No Gir" — ilan no girilirse mahalle çözülüp harita odaklanır.
- **Detay Paneli (Bottom Sheet / Side Panel):** Hex'e tıklanınca açılır:
  - Bölge adı + güncel nüfus (TÜİK / Kontur)
  - 0-100 arası algoritmik **Güvenlik Skoru**
  - Zaman çizelgesi (yeniden eskiye, sonsuz kaydırma/pagination)
  - Olay kartları: Tarih, Olay Türü, 2 cümlelik AI özeti, **"Habere Git (Kaynak)"** butonu
- **Adaptive Design:** `LayoutBuilder` ile ekran >800px → yan panel + üst butonlar; <600px → hamburger menü + Bottom Sheet.

---

## 5. Veri Boru Hattı (Pipeline)

1. **Veri Avı (Scraping):** Bot her 6 saatte bir (premium bölgelerde 10-15 dk) yerel asayiş sayfalarını / RSS'i tarar. Yeni haber yoksa AI'a gitmez (maliyet: 0). Yeni haber varsa yalnızca o metin AI'a gider.
2. **AI Ayrıştırma:** Claude, haberden temiz JSON çıkarır: `ilce`, `mahalle/koordinat`, `olay_turu`, `tarih`, `kisa_ozet`. **Anonimleştirme zorunlu** (bkz. Bölüm 8).
3. **Skorlama:** Nüfusa oranlama + zaman aşımı ile skor yeniden hesaplanır (bkz. Bölüm 6).
4. **DB + UI Güncelleme:** Veri Supabase'e yazılır; Flutter arayüzündeki hex renkleri anında güncellenir.

---

## 6. Skorlama Algoritması

1. **Nüfusa Oranlama:** Tüm skorlar "10.000 kişi başına düşen vaka" üzerinden hesaplanır. (30.000 nüfusta 10 olay ≠ 2.000 nüfusta 10 olay.)
2. **Yarı Ömür (Time Decay):** Son 1 aydaki olay %100 ağırlık; 3 yıl önceki olay görünür kalır ama skora etkisi ~%10'a düşer.
3. **Olay ağırlığı:** Olay türüne göre ağırlık katsayısı uygulanır (örn. gasp > hırsızlık).

---

## 7. Olay Tekilleştirme (Deduplication)

Aynı olayın farklı ajanslardan mükerrer kaydını engellemek için üç aşamalı filtre:

1. **Birincil Filtre:** Aynı gün + aynı bölge (hex) + aynı olay türü sorgusu. Eşleşme yoksa doğrudan yaz.
2. **Anlamsal Eşleştirme:** Eşleşme adayı varsa Claude iki özeti karşılaştırır ("%85 üzeri aynı olay mı?"). İleride maliyet için Vektör DB (Embeddings) ile çözülecek.
3. **Kaynak Dizisi:** Aynı olaysa yeni kayıt açılmaz; `kaynak_url` dizisine yeni link eklenir.

**UI yansıması:** "Bu olay X farklı kaynak tarafından doğrulandı" güven etiketi + tüm kaynak linkleri tek kartta.

---

## 8. Hukuki Koruma ve KVKK Kalkanı

- **Şahıs ismi (Ahmet Y., M.K.) ve açık kapı/apartman numarası ASLA saklanmaz.** AI ayrıştırma promptu anonimleştirme komutuyla çalışır.
- Açılış disclaimer'ı: *"Bu platform açık kaynaklı haberleri matematiksel olarak görselleştirir. Kesin emlak veya yatırım tavsiyesi değildir."*
- **Haber metninin tamamı barındırılmaz** (telif). Yalnızca özet + orijinal kaynağa link (traffic back) — haber siteleri trafik aldığı için engellemek yerine destekler.

---

## 9. Veri Kaynakları

- **Haberler:** Yerel haber ajansları (scraping) + Google News/Bing News API + GDELT (fallback)
- **Nüfus:** TÜİK (İzmit MVP) → Kontur Population Dataset (Global H3 Grid)
- **Mekanlar:** OpenStreetMap / Overture Maps Foundation

---

## 10. Geliştirme Fazları

| Faz | Kapsam |
| :--- | :--- |
| **Faz 1 (MVP/Alpha)** | İzmit — asayiş haberlerinin H3 altıgen bazlı kümelenmesi ve harita gösterimi. Tamamen ücretsiz (virallik + retention hedefi). |
| **Faz 2** | Native iOS/Android derleme; OSM ile ulaşım ve sosyal tesis katmanları ("Ulaşım Skoru", "Sosyal Yaşam Skoru"). |
| **Faz 3** | AI ile bölgesel "Yaşanabilirlik Skoru" + emlak entegrasyonu + monetizasyon. |

---

## 11. Gelir Modeli (Monetizasyon Yol Haritası)

1. **AdMob Native Ads (ilk 2 ay):** Haber akışında 3 kartta bir doğal reklam. Trafik kanıtlanır.
2. **Hiper-Yerel Emlakçı Sponsorlukları:** Hex bazlı sponsorlu alan kiralama ("Bu bölgenin uzman danışmanı: ...").
3. **Güvenlik Alarmı Aboneliği (Freemium):** Harita ücretsiz; favori hex'te anlık push bildirim ~29 TL/ay. Premium hex'ler 10-15 dk'da bir taranır.
4. **Bağlamsal Affiliate:** Hırsızlık/gasp haberlerinin altında güvenlik sistemi (alarm, akıllı kilit/kamera) satış ortaklığı linkleri.
5. **B2B (V3):** EmlakJet/Zingat/Sahibinden'e "Bölge Analizi API'si" satışı.

---

## 12. Test ve Kalite

- **Stres Testi:** k6 / Postman ile saniyede 1.000 sahte istek; serverless klonlamanın devreye girişi canlı doğrulanır.
- **Analitik ilk günden:** PostHog event'leri (`app_open`, `hex_tap`, `news_read`, `premium_buy`) MVP koduna gömülür.

---

## 13. Proje Yönetim Protokolü

- **HABITEX_PDR.md** (bu dosya): Projenin anayasası.
- **habitex_rules.md:** Geliştirme kuralları — AI ajanlar koda dokunmadan önce okur.
- **development_log.md:** Her işlemin tarihçesi. Ajanlar her görev sonunda buraya satır ekler; hatalar "Bug" etiketiyle kaydedilir.
- **Altın Komut:** Her göreve şu eklenir: *"Görevi tamamladıktan sonra development_log.md dosyasını güncelle. Hata yaparsan habitex_rules.md kurallarına tekrar bak ve düzelt."*
