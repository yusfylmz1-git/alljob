# Web sitesi (tanıtım + yasal)

**Canlı (Firebase Hosting):** https://alljob1.web.app  
**Kaynak klasör:** `hosting/`  
**Deploy:** `firebase deploy --only hosting:alljob1 --project alljob1`

Bu site **telefon uygulamasının kendisi değildir**. Tanıtım, iletişim ve Play Store için gerekli yasal sayfalardır.

| Sayfa | URL |
|--------|-----|
| Ana sayfa | https://alljob1.web.app/ |
| Gizlilik | …/gizlilik-politikasi.html |
| Koşullar | …/kullanim-kosullari.html |
| KVKK | …/kvkk-aydinlatma.html |
| Hesap silme | …/hesap-silme.html |

Admin paneli ayrı sitedir: https://alljob1-admin.web.app

---

## Alan adı (ör. ustasindan.com) — senin adımların

1. **Alan adını satın al** (Natro, Turhost, GoDaddy, Google Domains vb.).
2. Firebase Console → proje **alljob1** → **Hosting** → site **alljob1** → **Add custom domain**.
3. `ustasindan.com` (ve istersen `www.ustasindan.com`) yaz.
4. Google’ın verdiği **DNS kayıtlarını** (A / TXT / bazen CNAME) alan adı panelinden ekle.
5. Doğrulama 10 dk – 48 saat sürebilir; SSL (https) otomatik gelir.
6. Site hazır olunca `index.html` içindeki `canonical` / `og:url` adreslerini yeni domaine güncelle (istersen bana söyle, ben yaparım).

**Not:** Hosting paketi almana gerek yok; dosyalar Firebase’de kalır. Sadece alan adı + DNS yeter.

---

## Play Store için URL’ler

Yayın formunda genelde:

- Gizlilik politikası: `https://alljob1.web.app/gizlilik-politikasi.html`  
  (domain bağlanınca: `https://ustasindan.com/gizlilik-politikasi.html`)
- Web sitesi: `https://alljob1.web.app/`

---

## Sonra (isteğe bağlı)

- Play linkini ana sayfadaki **Uygulama** / **Bilgi al** butonuna eklemek  
- Flutter uygulamasını `app.ustasindan.com` altında açmak (ayrı iş)  
- Logo / ekran görüntüleri  
