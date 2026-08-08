# 🎯 PLAN · Sade ilan + usta uygulaması

> **Karar:** 2026-08-08. *"Sade bir ilan ve usta uygulaması gibi olması
> lazım. Anlaşılabilir bir sisteme çeviriyoruz."*

---

## Hedef

İş akışı (usta seçimi → tamamlama onayı → değerlendirme kapısı) **tamamen
kalkıyor**. İlan sahibiyle **doğrudan** iletişim kuruluyor.

| | Önce | Sonra |
|---|---|---|
| İlana ilgi | Usta "bildirim gönderir", müşteri "Ustayı Seç" der | Usta **doğrudan mesaj atar** |
| Sohbet türü | İlan sohbeti / genel sohbet ayrı | **Tek tür** |
| İş durumu | 8 durum (open → workerSelected → … → rated) | **3 durum** (open · cancelled · expired) |
| Değerlendirme | "İş tamamlandı" şartı | **Sohbet varsa** yeter |
| İlan listesi | Alt barda ayrı sekme | **Keşfet'te 2. sekme** |

---

## Fazlar

### Faz 1 · Vitrin uyarısı (küçük)
"Vitrini tamamla" bandı usta moduna geçince **çıkmasın**; yalnız
**Profili Düzenle** ekranında görünsün.

### Faz 2 · Keşfet sekmeleri (küçük)
Alt bardaki "İlanlar" sekmesi kalkar → Keşfet **iki sekme**: `Ustalar |
İlanlar`. İlanlar sekmesi **usta modu + müsaitlik** ister.

### Faz 3 · İlan sohbeti ayrımı kalkar (orta)
`chatIdFor(...jobId)` ilan başına ayrı oda açıyordu. Tek oda:
`chat_{a}__{b}`. Sohbet başlığındaki ilan satırı kalkar.

> ⚠️ **Veri notu:** eski ilan sohbetleri (`chat_a__b__jobId`) durmaya devam
> eder; yalnız YENİ sohbetler tek kimlikle açılır. Göç yok.

### Faz 4 · İş akışı silinir (büyük)
- `JobStatus`: 8 → 3 (`open`, `cancelled`, `expired`)
- Silinecek: usta seçimi (`select_artisan.dart`), tamamlama onayı
  (`job_completion.dart`), sohbet kilidi, `offers` akışı
- CF: 56 referans temizlenecek
- Kural: `jobs` update kuralı sadeleşir

### Faz 5 · Değerlendirme yeniden bağlanır
Şart: **"iş tamamlandı"** → **"sohbet var"**.
Kural zaten sohbet dokümanının varlığını kontrol ediyordu; istemci
tarafındaki `completed/rated` kontrolü kalkar.

---

## Risk sırası

| Faz | Risk | Deploy |
|---|---|---|
| 1 | Yok | — |
| 2 | Düşük | — |
| 3 | Orta (yeni sohbet kimliği) | — |
| 4 | **Yüksek** (enum + CF + kural) | **CF + rules** |
| 5 | Orta | **rules** |

**1-2-3 önce**, sonra 4-5 birlikte (ikisi birbirine bağlı).

---
İlgili: [[PLAN-Sadelestirme]] · [[00-TEST-PLANI]]
