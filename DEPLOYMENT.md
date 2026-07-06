# URBHEX — Ücretsiz Yayınlama Rehberi (urbhex.com)

Tüm sistem **0 TL/ay** ile yayında tutulabilir:

| Parça | Nerede çalışır | Ücret |
|---|---|---|
| Flutter Web (site) | Cloudflare Pages | Ücretsiz (sınırsız trafik) |
| Python botlar (main.py + gdelt.py) | GitHub Actions (zamanlı) | Ücretsiz (public repo'da sınırsız) |
| Veritabanı + Üyelik | Supabase (mevcut) | Ücretsiz plan (500 MB) |
| Domain DNS + SSL | Cloudflare (Natro'daki domain'e NS değişikliği) | Ücretsiz |

---

## 1. Kodu GitHub'a koy (botların çalışacağı yer)

```powershell
cd C:\Users\yunus\Desktop\HaritaHaber
# github.com'da "urbhex" adında yeni repo aç (Public önerilir: Actions dakikası sınırsız olur)
git remote add origin https://github.com/KULLANICI_ADIN/urbhex.git
git push -u origin master
```

> Güvenlik: `bot/.env` .gitignore'da — anahtarlar GitHub'a GİTMEZ. Anahtarlar
> bir sonraki adımda "Secrets" olarak ayrı girilir.

## 2. Botları buluta al (GitHub Actions — bilgisayarın kapalıyken de çalışır)

1. GitHub repo → **Settings → Secrets and variables → Actions → New repository secret**
2. Üç secret ekle: `SUPABASE_URL`, `SUPABASE_SERVICE_KEY`, `ANTHROPIC_API_KEY`
   (değerler `bot\.env` dosyandakiler)
3. Hepsi bu — `.github/workflows/bot.yml` zaten repoda: yerel kaynaklar 6 saatte
   bir, GDELT saatte bir otomatik çalışır. **Actions** sekmesi → `urbhex-bot` →
   "Run workflow" ile elle test edebilirsin.

## 3. Siteyi yayınla (Cloudflare Pages)

1. Derle:
   ```powershell
   cd app
   flutter build web --release --dart-define=SUPABASE_URL=https://exsjwrmoxheuhzthvflz.supabase.co --dart-define=SUPABASE_ANON_KEY=<anon key>
   ```
   Çıktı: `app\build\web` klasörü.
2. [dash.cloudflare.com](https://dash.cloudflare.com) → ücretsiz hesap →
   **Workers & Pages → Create → Pages → Upload assets** → proje adı `urbhex` →
   `app\build\web` klasörünü sürükle-bırak → Deploy.
3. Önce `urbhex.pages.dev` adresinde test et.

## 4. Natro'daki urbhex.com'u bağla (NS değişikliği — transfer GEREKMEZ)

Önemli: Domain'i Natro'dan taşımana gerek yok; sadece **yönetimini** Cloudflare'e
veriyoruz. (Zaten ICANN kuralı gereği yeni alınan domain 60 gün transfer edilemez.)

1. Cloudflare → **Add a site** → `urbhex.com` yaz → **Free** planı seç.
2. Cloudflare sana 2 nameserver verir (örn. `ada.ns.cloudflare.com` ve `bob.ns.cloudflare.com`).
3. **Natro paneli** → Alan Adlarım → urbhex.com → **DNS / Nameserver (NS) Yönetimi**
   → mevcut `ns1.natrodns.com` tarzı kayıtları sil, Cloudflare'in verdiği ikisini yaz → kaydet.
4. Yayılması 5 dk - 24 saat sürer. Cloudflare "Active" gösterince:
5. Cloudflare → Workers & Pages → urbhex projesi → **Custom domains → Set up a domain**
   → `urbhex.com` (ve istersen `www.urbhex.com`) → DNS kaydını otomatik ekler.

### SSL (https) — hiçbir şey satın alma
Cloudflare'e geçtiğin an SSL otomatik ve ücretsizdir. Tek ayar:
Cloudflare → urbhex.com → **SSL/TLS → Overview → "Full"** seç (varsayılan
"Flexible" kalmasın). Sertifika yenileme, kurulum, ücret — hepsi otomatik.
Natro'nun SSL paketlerini SATIN ALMANA GEREK YOK.

### WHOIS gizliliği
- .com domain'lerde kişisel veriler 2018'den beri (GDPR) büyük ölçüde zaten maskeli.
- Kontrol: [lookup.icann.org](https://lookup.icann.org) → urbhex.com yaz → ad/mail
  görünüyor mu bak.
- Görünüyorsa: Natro paneli → alan adı → **Whois Gizliliği / Kişisel Veri Koruma**
  seçeneğini aç (Natro'da genelde ücretsiz veya cüzi ücretli).
- 60 gün dolunca istersen domain'i tamamen Cloudflare Registrar'a taşırsın:
  yenileme maliyetine (~$10/yıl) + WHOIS gizliliği kalıcı ücretsiz olur.

## 5. Güncelleme akışı (yayından sonra)

- **Kod değişince site:** `flutter build web --release ...` → Cloudflare Pages →
  "Create new deployment" → klasörü tekrar sürükle. (İleride GitHub bağlantılı
  otomatik dağıtıma geçilebilir.)
- **Bot değişince:** `git push` yeterli — Actions yeni kodu kullanır.
- **Google girişi:** Yayına çıkınca Google Cloud Console'daki OAuth istemcisine
  `https://urbhex.com` origin'inin ekli olduğundan emin ol (eklemiştik) ve
  Supabase → Authentication → URL Configuration → Site URL `https://urbhex.com` olsun.
