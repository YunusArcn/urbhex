# URBHEX — Özellik Yol Haritası

Piyasadaki emlak/harita uygulamalarında olmayan, en çok ihtiyaç duyulan 20 özellik.
Durum: ✅ uygulandı · 🔨 kısmen · 📋 sırada

| # | Özellik | Neden piyasada yok / neden değerli | Durum |
|---|---------|-------------------------------------|-------|
| 1 | **Konum-bazlı açılış** — harita bulunduğun yerden açılır | Emlak siteleri şehir seçtirir; biz anında "senin bölgen"i gösteririz | ✅ |
| 2 | **Bölge favorileme** — hex bazlı kişisel takip listesi | Kimse sokak hassasiyetinde bölge takibi sunmuyor | ✅ |
| 3 | **Üyelik**: Google + e-posta doğrulamalı kayıt, profil (isim/pp) | Kişiselleştirmenin temeli | ✅ |
| 4 | **Tür-bazlı olay akışı** — tıklanan bölgede türler alt alta, açılır; özet + orijinal kaynak linki | Haber siteleri konuma göre gruplamaz; biz suç türüne göre katmanlarız | ✅ |
| 5 | **Cihaza uyarlanan görünüm** — telefon/tablet/PC ayrı oran ve panel düzeni, ikonlar ölçeklenir | Çoğu harita sitesi masaüstünde mobil gibi durur | ✅ |
| 6 | **Habere gömülü doğal reklam** + self-servis "Burada reklam verin" → fiyat sayfası | Hiper-yerel reklam envanteri (Zillow modeli) Türkiye'de yok | ✅ |
| 7 | **Güvenlik Alarmı** — favori bölgede yeni olay olunca push bildirimi (premium, 29 TL/ay) | DB'de `alert_enabled` hazır; FCM entegrasyonu kaldı | 🔨 |
| 8 | **Skor trendi grafiği** — hex'in 3/6/12 aylık güvenlik eğrisi ("iyileşiyor mu kötüleşiyor mu?") | Kimse zaman boyutu göstermiyor; taşınma kararının kalbi | 📋 |
| 9 | **İki bölge karşılaştırma** — A/B ekranı: iki mahalleyi skor, tür dağılımı, trendle yan yana | Ev arayanların gerçek sorusu: "Burası mı orası mı?" | 📋 |
| 10 | **Güvenli rota** — iki nokta arası düşük riskli yürüyüş rotası (gece modu) | Navigasyonlar en hızlıyı verir, en güvenliyi değil | 📋 |
| 11 | **Saat dilimi ısı haritası** — aynı bölgenin gündüz/gece risk farkı | Olay saati verisiyle mümkün; benzersiz içgörü | 📋 |
| 12 | **İlan linki analizi** — Sahibinden/EmlakJet linki yapıştır → o adresin bölge raporu | İlan platformlarıyla köprü; viral büyüme kanalı | 📋 |
| 13 | **PDF Bölge Güvenlik Raporu** — indirilebilir, markalı rapor (emlakçıya satılır) | B2B gelir + paylaşılabilirlik | 📋 |
| 14 | **Topluluk doğrulaması** — "bu bölgede yaşıyorum" rozeti ile skoru oyla (katılıyorum/katılmıyorum) | Veriye insan katmanı; güven artırır | 📋 |
| 15 | **Kira/sigorta endeks API'si** — bölge riski → sigorta primi/kira çarpanı (B2B) | V3 monetizasyon; sigorta şirketleri bu veriyi satın alır | 📋 |
| 16 | **Global şehir kartları** — GDELT verisiyle dünya şehirlerinin özet güvenlik profili | Altyapı hazır (gdelt.py); UI kaldı | 🔨 |
| 17 | **Yaşanabilirlik bileşik skoru** — güvenlik + ulaşım + sosyal yaşam tek skorda | Faz 2 (OSM katmanları) | 📋 |
| 18 | **Anonim gözlem pini** — kullanıcı moderasyonlu "dikkat" işareti (aydınlatma bozuk, tenha sokak vb.) | Haberlere yansımayan mikro-güvenlik verisi | 📋 |
| 19 | **Haftalık bölge özeti e-postası** — favori bölgelerin haftalık raporu | Geri getirme (retention) motoru | 📋 |
| 20 | **Kurum paneli** — belediye/muhtarlık için bölge istatistik ekranı | Kamu işbirliği + meşruiyet + veri ortaklığı | 📋 |

## Bu turda uygulananların teknik özeti
- **1**: `geolocator` ile tarayıcı konum izni; alınamazsa İzmit varsayılanı. Sağ altta "konumuma git" düğmesi.
- **2**: `favorites` tablosu (RLS: herkes yalnız kendi kaydını görür), panelde kalp butonu, ayarlarda liste + silme + haritaya odaklanma.
- **3**: Supabase Auth — Google OAuth + e-posta/şifre (doğrulama maili zorunlu), `profiles` tablosu ve otomatik profil tetikleyicisi, ayarlar ekranında isim/pp.
- **4**: Panel türe göre `ExpansionTile` grupları; sayı rozeti, tıkla-aç, özet oku, `url_launcher` ile orijinal kaynağa git.
- **5**: `responsive.dart` — mobile/tablet/desktop kırılımları; ikon-rozet-yazı ölçekleri, masaüstünde yan panel, telefonda bottom sheet.
- **6**: `AdCard` doğal reklam bileşeni ("Sponsorlu" etiketli), 2 tür grubunda bir akışa girer; tıklayınca `AdPricingScreen` (3 paket + iletişim).
