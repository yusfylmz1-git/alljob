# 11 · Admin Paneli

**Kapsam:** Erişim kapısı, 12 sekme, moderasyon araçları, sayaçlar.
**Ortam:** Tarayıcı — `alljob1-admin` sitesi · **Süre:** ~25 dk

> [!important] Ayrı uygulama
> Admin paneli tüketici uygulamasından **tamamen bağımsız** çalışır
> (`lib/main_admin.dart`, kendi Hosting sitesi). Admin kodu kullanıcının
> indirdiği binary'e **hiç girmez**. Aynı Firebase projesini paylaşır.

> [!tip] Derleme
> ```bash
> flutter build web --target lib/main_admin.dart --release
> firebase deploy --only hosting:alljob1-admin
> ```

---

## 11.1 Erişim kapısı ⭐

- [ ] **11.1.1** Panel adresi açılıyor, giriş ekranı geliyor
- [ ] **11.1.2** ⭐ **Normal kullanıcı** hesabıyla girin → **"Yetkisiz"**
      ekranı çıkıyor, panele girilemiyor
- [ ] **11.1.3** Admin hesabıyla girince panel açılıyor
- [ ] **11.1.4** Sağ üstte e-posta ve rol (Superadmin / Moderatör) yazıyor
- [ ] **11.1.5** Çıkış yapınca giriş ekranına dönüyor
- [ ] **11.1.6** ⚠️ Sekme başlığı **"İlanda Hizmet · Yönetim"** yazıyor

## 11.2 Sekmeler ve gezinme ⭐

> **12 sekme:** Özet · Şikayetler · Kullanıcılar · Ustalar · İlanlar ·
> Yorumlar · Destek · Bildirim · Platform · *(superadmin)* Kadro · Denetim ·
> Sistem

- [ ] **11.2.1** Geniş ekranda **sol şerit** (rail), dar ekranda **çekmece**
- [ ] **11.2.2** Her sekme açılıyor, hata vermiyor
- [ ] **11.2.3** Şikayet sekmesinde **rozet** (açık şikayet sayısı) var
- [ ] **11.2.4** ⚠️ **"Anlaşmazlıklar"** sekmesi **OLMAMALI** *(kaldırıldı)*
- [ ] **11.2.5** ⭐ Özet'teki **hızlı erişim** çipleri **doğru sekmeyi**
      açıyor *(indeksler elle eşleniyor — kayma riski yüksek)*
- [ ] **11.2.6** ⭐ Özet'teki **KPI kartına** tıklayınca doğru sekme açılıyor
- [ ] **11.2.7** Moderatör hesabında Kadro/Denetim/Sistem **görünmüyor**

## 11.3 Özet (dashboard) ⭐

- [ ] **11.3.1** Kullanıcı / usta / ilan sayaçları geliyor
- [ ] **11.3.2** ⚠️ **"Açık anlaşmazlık"** kartı **OLMAMALI**
- [ ] **11.3.3** İlan kartı alt yazısı **"Açık N · Kapalı N"**
- [ ] **11.3.4** ⚠️ **"Süren"** / **"Biten"** ilan sayacı **OLMAMALI**
- [ ] **11.3.5** ⭐ **"Eski durumlu ilan"** kartı: *(varsa)* canlıda
      kaldırılmış durum taşıyan kayıt sayısı — **hata değil**, temizlik
      göstergesi. Yoksa kart hiç görünmez.
- [ ] **11.3.6** "Sayaçları yeniden kur" çalışıyor, sayılar tutarlı
- [ ] **11.3.7** Bayat uyarısı (24 saatten eski) mantıklı görünüyor

## 11.4 Şikayetler

- [ ] **11.4.1** Şikayet kuyruğu listeleniyor, sayfalama çalışıyor
- [ ] **11.4.2** Şikayet detayı açılıyor
- [ ] **11.4.3** "Üstlen" / "Bırak" çalışıyor
- [ ] **11.4.4** Karara bağlama çalışıyor, kuyruktan düşüyor
- [ ] **11.4.5** Mesaj şikayetinde sohbet dökümü görüntülenebiliyor
- [ ] **11.4.6** Mesaj gizleme / geri alma çalışıyor

## 11.5 Kullanıcı ve usta yönetimi

- [ ] **11.5.1** Kullanıcı arama (e-posta / uid) çalışıyor
- [ ] **11.5.2** Kullanıcı özeti açılıyor; sayaçlar geliyor
- [ ] **11.5.3** ⚠️ Özette **"Teklif"** sayacı **OLMAMALI** *(kaldırıldı)*
- [ ] **11.5.4** ⭐ Askıya alma çalışıyor → **kullanıcı uygulamada**
      `/suspended` ekranına düşüyor *(cihazda doğrulayın)*
- [ ] **11.5.5** Askı kaldırma çalışıyor
- [ ] **11.5.6** Kullanıcı notu eklenebiliyor / listeleniyor
- [ ] **11.5.7** Usta doğrulama / öne çıkarma bayrakları çalışıyor
- [ ] **11.5.8** Premium verme çalışıyor
- [ ] **11.5.9** Sertifika inceleme açılıyor

## 11.6 İlan moderasyonu ⭐

- [ ] **11.6.1** İlan listesi geliyor, sayfalama çalışıyor
- [ ] **11.6.2** ⭐ Durum filtresinde **yalnız üç seçenek**:
      Açık · İptal Edildi · Süresi Doldu
- [ ] **11.6.3** ⚠️ **"Usta Seçildi"/"Tamamlandı"/"Sorun"** filtresi
      **OLMAMALI**
- [ ] **11.6.4** İl filtresi çalışıyor
- [ ] **11.6.5** İlan gizleme çalışıyor → uygulamada görünmüyor
- [ ] **11.6.6** ⭐ Zorla iptal (`force_cancel`) çalışıyor →
      **ilan sahibine** bildirim gidiyor
- [ ] **11.6.7** ⚠️ Zorla iptalde ikinci bir kişiye (usta) bildirim
      **gitmemeli** *(usta ataması yok)*

## 11.7 Yorum, destek, duyuru

- [ ] **11.7.1** Yorum listesi geliyor; gizleme çalışıyor
- [ ] **11.7.2** Gizlenen yorum uygulamada görünmüyor, ortalama puan güncelleniyor
- [ ] **11.7.3** Destek talepleri listeleniyor, durum değiştirilebiliyor
- [ ] **11.7.4** Toplu bildirim gönderiliyor *(dikkat: gerçek push gider)*
- [ ] **11.7.5** Zamanlanmış kampanya kurulabiliyor / iptal edilebiliyor

## 11.8 Superadmin alanları

- [ ] **11.8.1** Kadro: rol atama, davet oluşturma/iptal çalışıyor
- [ ] **11.8.2** ⚠️ Yetki listesinde **"Anlaşmazlık hakemliği"**
      **OLMAMALI** *(kaldırıldı)*
- [ ] **11.8.3** Denetim: kayıtlar listeleniyor, kategori filtresi çalışıyor
- [ ] **11.8.4** ⚠️ Kategori filtresinde **"Anlaşmazlık"** **OLMAMALI**
- [ ] **11.8.5** *(varsa eski kayıt)* "Anlaşmazlık çözüldü" etiketi **okunabilir
      Türkçe** görünüyor — ham `resolve_dispute` yazmıyor
- [ ] **11.8.6** Sistem: uzaktan yapılandırma okunuyor/yazılıyor
- [ ] **11.8.7** Dışa aktarma (CSV) çalışıyor, **telefon içermiyor**

## 11.9 Görünüm

- [ ] **11.9.1** Dar ekranda (telefon) panel kullanılabilir durumda
- [ ] **11.9.2** Koyu/açık tema geçişi bozulma yapmıyor
- [ ] **11.9.3** Uzun tablolar yatay kayabiliyor, taşma yok

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| Normal kullanıcı panele girebiliyor | 🔴🔴 **En ciddi** — hemen bildir |
| Hızlı erişim yanlış sekme açıyor | ⚠️ İndeks kayması (sekme eklenmiş/çıkmış) |
| "Anlaşmazlık" herhangi bir yerde | ⚠️ Kaldırılmış modül izi |
| KPI sayıları toplamı tutmuyor | `jobsOther` kartına bakın |
| "Eski durumlu ilan" > 0 | Bilgi — canlıda temizlenmemiş kayıt var |
| Sayaç sıfır kalıyor | CF deploy edilmemiş olabilir |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[12-Tanitim-Sitesi]]
