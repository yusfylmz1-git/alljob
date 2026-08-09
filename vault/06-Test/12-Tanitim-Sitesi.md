# 12 · Tanıtım Sitesi ve Yasal Metinler

**Kapsam:** `alljob1` sitesi — marka, logo, içerik doğruluğu, yasal uyum.
**Ortam:** Tarayıcı (masaüstü + telefon) · **Süre:** ~15 dk

> [!important] Neden test ediliyor?
> Bu site **Play Store başvurusunun parçası**: gizlilik politikası ve hesap
> silme sayfası zorunlu. Metinler koddaki **gerçek davranışı** anlatmak
> zorunda — yanlış bilgi yasal risktir, kozmetik sorun değil.

> [!tip] Deploy
> ```bash
> firebase deploy --only hosting:alljob1
> ```

---

## 12.1 Marka ve logo ⭐

> Marka **üç kez** değişti: Ustasından → Sepette Hizmet → **İlanda Hizmet**.

- [ ] **12.1.1** ⭐ Tüm sayfalarda marka **"İlanda Hizmet"**
- [ ] **12.1.2** ⚠️ **"Sepette Hizmet"** hiçbir yerde geçmiyor
- [ ] **12.1.3** ⚠️ **"Ustasından"** / **"USTASINDAN"** hiçbir yerde geçmiyor
      *(eski logoda yazıyordu)*
- [ ] **12.1.4** ⭐ Başlıktaki logo **"İH" monogramı** (renkli), eski turuncu
      çekiçli logo **değil**
- [ ] **12.1.5** Logo 40px'te net görünüyor, bulanık değil
- [ ] **12.1.6** Tarayıcı sekmesinde favicon yeni logo
- [ ] **12.1.7** Footer'daki logo ve marka adı doğru

## 12.2 Sosyal paylaşım kartı ⭐

> Sitenin linkini WhatsApp / X / Slack'e yapıştırınca çıkan önizleme.

- [ ] **12.2.1** ⭐ Linki WhatsApp'ta paylaşın → **geniş kart** çıkıyor
      *(kare küçük ikon değil)*
- [ ] **12.2.2** Kartta **"İlanda Hizmet"** yazıyor
- [ ] **12.2.3** Kartta logo görünüyor, Türkçe karakterler bozuk değil
- [ ] **12.2.4** *(alternatif)* [opengraph.xyz](https://www.opengraph.xyz)
      ile URL'yi kontrol edin

## 12.3 İçerik doğruluğu ⭐

> Site, ürünün **bugün yaptığını** anlatmalı.

- [ ] **12.3.1** ⚠️ **"teklif"** kelimesi hiçbir yerde geçmiyor
      *(teklif akışı kaldırıldı)*
- [ ] **12.3.2** ⚠️ **"teklifleri karşılaştır"**, **"ustayı seç"** gibi
      ifadeler yok
- [ ] **12.3.3** ⭐ "Nasıl çalışır" bölümü **doğrudan mesajlaşmayı** anlatıyor
- [ ] **12.3.4** Özellik kartları mevcut özellikleri anlatıyor
- [ ] **12.3.5** Cihaz önizlemesindeki metinler gerçekle uyumlu

## 12.4 Yasal metinler ⭐⭐

> **En kritik bölüm.** Bu metinler `deleteAccount` CF'i ile birebir tutmalı.

- [ ] **12.4.1** Dört sayfa da açılıyor: Kullanım Koşulları · Gizlilik ·
      KVKK · Hesap Silme
- [ ] **12.4.2** ⭐⭐ **Hesap silme** sayfası: **"tüm ilanlarınız SİLİNİR"**
      diyor
- [ ] **12.4.3** ⚠️ **"ustaya bağlanmamış açık ilanlarınız"** ifadesi
      **OLMAMALI** *(eski davranış)*
- [ ] **12.4.4** ⚠️ **"aktif işleriniz iptal edilir"** ifadesi **OLMAMALI**
- [ ] **12.4.5** ⚠️ **"tamamlanmış işler anonimleştirilir"** ifadesi
      **OLMAMALI**
- [ ] **12.4.6** ⭐ Gizlilik politikasındaki silme maddesi hesap-silme
      sayfasıyla **çelişmiyor**
- [ ] **12.4.7** İletişim e-postası doğru: `aboneai.plus@gmail.com`
- [ ] **12.4.8** Ana sayfadaki yasal kartlar doğru sayfalara gidiyor

> [!warning] Kod değişirse bu metinler de değişir
> `deleteAccount` CF'ine dokunan her değişiklikten sonra
> `hesap-silme.html` + `gizlilik-politikasi.html` gözden geçirilmeli.
> → [[Cloud-Functions-Haritasi]]

## 12.5 Gezinme ve görünüm

- [ ] **12.5.1** Telefonda hamburger menü açılıyor/kapanıyor
- [ ] **12.5.2** Menüden bir bağlantıya tıklayınca menü kapanıyor
- [ ] **12.5.3** ESC tuşu menüyü kapatıyor
- [ ] **12.5.4** Sayfa kaydırınca üst şerit görünümü değişiyor
- [ ] **12.5.5** "İçeriğe geç" bağlantısı Tab'a basınca beliriyor
- [ ] **12.5.6** Telefonda yatay kaydırma / taşma yok
- [ ] **12.5.7** Yasal sayfalar telefonda okunabilir

## 12.6 Admin sitesi ayrımı

- [ ] **12.6.1** ⭐ Admin paneli **ayrı adreste** (`alljob1-admin`)
- [ ] **12.6.2** Tanıtım sitesinden admin paneline **bağlantı yok**
- [ ] **12.6.3** ⭐ Admin sekmesi başlığı **"İlanda Hizmet · Yönetim"**
- [ ] **12.6.4** Admin sayfası kaynağında `noindex` var
      *(aramaya çıkmamalı)*

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Hesap silme metni koddan farklı | 🔴🔴 **Yasal risk** — hemen bildir |
| "Sepette Hizmet" / "Ustasından" | ⚠️ Eski marka — deploy edilmemiş olabilir |
| Eski turuncu çekiçli logo | ⚠️ Tarayıcı önbelleği? Ctrl+F5 deneyin |
| Paylaşım kartı kare/bozuk | ⚠️ og-image güncellenmemiş |
| "teklif" geçen cümle | ⚠️ Kaldırılmış akış |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Defterin sonu** — [[00-TEST-PLANI]]'na dön
