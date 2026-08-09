# 6 · İlan Alma (Usta Tarafı)

**Kapsam:** İlan listesi erişimi, dört kapı, ilan sahibine doğrudan mesaj.
**Hesap:** B (usta modu açık) · **Süre:** ~15 dk

> [!important] Akış değişti (2026-08-08/09)
> Usta **teklif vermez, ilgi de bildirmez** — ilan sahibine **doğrudan mesaj
> atar**. "İlgilenen Ustalar" listesi, "Ustayı Seç" ve "İlgilendiğim" sekmesi
> **kaldırıldı**. Bu bölüm eskiden onları test ediyordu.

---

## 6.1 Erişim kapısı ⭐

- [ ] **6.1.1** Usta modu **KAPALIYKEN** "İşler" sekmesi ilan listesi değil,
      **kendi ilanlarını** açıyor
- [ ] **6.1.2** Usta modunu açın → "İşler" artık **yakındaki ilanları** açıyor
- [ ] **6.1.3** Profil eksikse (meslek/bölge yok) → **uyarı ekranı** çıkıyor
- [ ] **6.1.4** ⭐ Profilde **"Müsait değilim"** yapın → ilan listesi
      **boş geliyor** / bilgilendirme çıkıyor
- [ ] **6.1.5** ⚠️ Ekranda **tek liste** var — "İlgilendiğim" diye ikinci
      sekme **OLMAMALI** *(kaldırıldı)*

## 6.2 İlan listesi

- [ ] **6.2.1** Yakındaki ilanlar listeleniyor
- [ ] **6.2.2** A hesabının açtığı ilan listede çıkıyor
      *(çıkmıyorsa: meslek + bölge eşleşiyor mu?)*
- [ ] **6.2.3** İlan detayı açılıyor, ilan sahibinin bilgileri görünüyor
- [ ] **6.2.4** Fotoğraflar açılıyor
- [ ] **6.2.5** ⚠️ Kartta **"N ilgilendi"** yazısı **OLMAMALI** *(sayaç kalktı)*
- [ ] **6.2.6** Kartta ilçe + "ne kadar önce" bilgisi var

## 6.3 Doğrudan mesaj ⭐

> Yeni akış: usta ilan sahibine mesaj atar, anlaşma sohbette olur.

- [ ] **6.3.1** İlan detayında **"Mesaj Gönder"** düğmesi var
- [ ] **6.3.2** ⚠️ **"Bildirim Gönder"** / **"İlgilendim"** düğmesi
      **OLMAMALI**
- [ ] **6.3.3** Basınca sohbet açılıyor
- [ ] **6.3.4** ⭐ İkinci kez basınca **aynı sohbete** giriyor
      *(kişi başına tek kutu — yeni sohbet açılmamalı)*
- [ ] **6.3.5** A'ya mesaj bildirimi gidiyor *(uygulama içi)*
- [ ] **6.3.6** A'nın telefonuna push geliyor *(2. cihaz)*
- [ ] **6.3.7** ⭐ A ile B'nin **başka bir ilan** üzerinden de konuşması →
      **yine aynı sohbet** açılıyor

## 6.4 Dört kapı ⭐

> `_messageOwner()` sırayla dört şey kontrol eder. Her birini ayrı deneyin.

**Kapı 1 — askıya alınmış hesap**
- [ ] **6.4.1** *(admin panelinden B'yi askıya alın)* → mesaj atamıyor,
      uyarı çıkıyor. **Sonra askıyı kaldırın.**

**Kapı 2 — müsaitlik**
- [ ] **6.4.2** ⭐ B'yi **müsait değil** yapın → ilana mesaj atamıyor,
      *"müsait değil görünüyorsunuz"* uyarısı
- [ ] **6.4.3** ⭐ A, Keşfet'te arama yapsın → **B listede ÇIKMIYOR**
- [ ] **6.4.4** A, B'nin profiline **doğrudan** girsin (takip listesinden) →
      profil **açılıyor**
- [ ] **6.4.5** ⭐ Profilde **"Şu an yeni iş almıyor"** yazıyor, mesaj düğmesi
      pasif
- [ ] **6.4.6** Müsaitliği açın → hepsi normale dönüyor

**Kapı 3 — eşleşme**
- [ ] **6.4.7** ⭐ B'nin **mesleğiyle alakasız** bir ilana girin *(varsa)* →
      mesaj atamıyor / ilan listede zaten yok
- [ ] **6.4.8** Farklı **ilçedeki** normal ilan listede çıkmıyor

**Kapı 4 — e-posta doğrulama**
- [ ] **6.4.9** ⭐ E-postası **doğrulanmamış** hesapla mesaj atmayı deneyin →
      doğrulama istemi çıkıyor

## 6.5 Kolay İş farkı ⭐

> Kolay İş ilanları **il geneline** gider ve meslek şartı gevşektir.

- [ ] **6.5.1** A, **Kolay İş** ilanı versin *(süre otomatik 1 gün)*
- [ ] **6.5.2** ⭐ B **farklı ilçede** olsun → ilan yine de listede **ÇIKIYOR**
- [ ] **6.5.3** ⭐ B **başka ilde** olsun → ilan **ÇIKMIYOR** (il sınırı)
- [ ] **6.5.4** Normal ilan aynı testte **ilçe şartını koruyor**

---

## 🔍 Bu alanda nelere dikkat

| Belirti | Not düşün |
|---|---|
| "İlgilendiğim" sekmesi duruyor | ⚠️ Eski kod geri gelmiş — bildir |
| "Bildirim Gönder" düğmesi var | ⚠️ Eski akış — bildir |
| Kartta "N ilgilendi" yazıyor | ⚠️ Ölü sayaç — bildir |
| Müsait değilken mesaj atılıyor | ⚠️ Kapı bozuk |
| Müsait olmayan usta aramada çıkıyor | ⚠️ Filtre bozuk |
| Aynı kişiyle ikinci sohbet açılıyor | ⚠️ `chatIdFor` bozuk — ciddi |
| İlan listede çıkmıyor | Meslek/bölge eşleşmesini kontrol et |

---

**Bulgu yaz:** [[99-BULGULAR]] · **Sonraki:** [[07-Mesajlasma]]
