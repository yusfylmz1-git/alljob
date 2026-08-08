# 🐛 Bulgular · v2

> Test sırasında bulunan her şey buraya. Ben düzelttikçe **Durum** sütununu
> güncellerim.

---

## Nasıl bildirilir?

Bana şunu söylemeniz yeterli:

> **"7.2.2 çalışmadı — usta yazamıyor"**

Faydalı olursa ekleyin: hangi hesap, ekran görüntüsü, hata mesajının aynısı.

---

## Öncelik ölçeği

| | Anlamı | Örnek |
|---|---|---|
| 🔴 **P0** | Kullanıcıyı engelliyor, veri kaybı, gizlilik ihlali | Mesaj gönderilemiyor · çökme · e-posta herkese açık |
| 🟠 **P1** | Bozuk ama etrafından dolaşılabilir | Sayaç yanlış · liste tazelenmiyor |
| 🟡 **P2** | Cila, rahatsız edici ama işlevsel | Metin taşması · koyu temada soluk renk |

---

## Açık bulgular

| # | Adım | Ne oldu | Öncelik | Durum |
|---|---|---|---|---|
| — | — | *(henüz bulgu yok)* | — | — |

---

## Bilinen kısıtlar (bulgu DEĞİL)

Bunlar zaten biliniyor; tekrar bildirmenize gerek yok.

| # | Konu | Durum |
|---|---|---|
| K-1 | İlan düzenlemede yalnız başlık + açıklama var (fotoğraf/konum değişmiyor) | 📋 planlandı |
| K-2 | İlan fotoğrafı **çoklu seçilemiyor**, tek tek eklenir | 📋 planlandı |
| K-3 | Müşteri sayaçları **geçmişe dönük dolmaz** — CF bundan sonrasını sayar | ✅ bilinçli |
| K-4 | `jobs` koleksiyonu kuralda **herkese açık okunur**; kapı yalnız istemcide | ⚠️ değerlendirilecek |
| K-5 | Push bildirimi tek cihazda test edilemez | ⏸️ 2. cihaz |

---

## ⏸️ İkinci cihaz bekleyen adımlar

Tek cihazla doğrulanamaz — hesap değiştirmek ekranı yeniden kurar.

| Adım | Ne test edilecek |
|---|---|
| 4.5.4 | Takip push'u geliyor mu |
| 6.3.6 | İlgi bildirimi push'u |
| 7.x | Canlı mesaj güncellemesi (ekran açıkken) |
| 10.3.4 | Push tanılama satırı |

---

## 📋 Test oturumu kaydı

Her oturumun sonunda nerede kaldığınızı buraya yazın.

### Oturum 1 — ____________
- **Tamamlanan:**
- **🔜 KALINAN YER:**
- **Bulgular:**
- **Not:**

---

## Bulgu şablonu

```
### B-01 · [adım no] — kısa başlık
**Ne bekledim:**
**Ne oldu:**
**Hangi hesap:** A / B
**Tekrarlanıyor mu:** evet / hayır / bazen
**Öncelik:** P0 / P1 / P2
**Durum:** açık / inceleniyor / düzeltildi
```

---
İlgili: [[00-TEST-PLANI]] · [[Bilinen-Tuzaklar]]
