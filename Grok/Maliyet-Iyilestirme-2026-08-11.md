# Maliyet iyileştirmesi — 2026-08-11

**Hedef:** Giderleri düşür, kullanıcıyı sistemden uzaklaştırma.

## Yapılanlar

### 1. `onJobCreated` fan-out (en büyük kalem)

| | Eskiden | Şimdi |
|--|---------|--------|
| Meslek sorgu limiti | 500 / sorgu | **200** |
| Bildirim alıcı tavanı | Limitsiz (eşleşen hepsi) | **120** (skorlu seçim) |
| Token okuma | Seri N+1 | **Paralel** (25) |
| Tercih kapalı (`nearbyJobs`) | Yine in-app yazı + FCM yok | **İkisi de yok** (tercihe saygı) |

**Skor (kim bildirim alır):** pause değil > alwaysAvailable > premium > completedJobs + rastgele jitter  
→ Kalabalık ilde hep aynı 120 kişi olmaz; aktif ustalar önce.

**UX:**  
- Kullanıcı hâlâ bildirim alır (çoğu ilde eşleşen &lt; 120).  
- 200+ elektrikçi/İstanbul gibi uçta en fazla 120 bildirim — fazlası **Keşfet → İlanlar** listesinde durur.  
- Müsait olmayan da skorda kalır (ürün kararı: görür + bildirim).

### 2. Ürün talebi digesti
Aktif ürün tarama **2000 → 1200**.

### 3. İstemci fetch tavanları (`app_constants.dart`)

| Cap | Eski | Yeni |
|-----|------|------|
| openJobsFetchCap | 60 | **50** |
| nearbyJobsFetchCap | 100 | **80** |
| productDiscoverFetchCap | 60 | **48** |
| artisanFetchCap | 300 | **180** |

Liste boşalmadan, her açılışta daha az doc okunur.

## Deploy

- `onJobCreated` → **canlıda** (`europe-west1`, 2026-08-11)  
- İstemci cap'leri → uygulama hot restart / store build ile

## Güncellenmiş risk tablosu (iyileştirme sonrası)

Aynı varsayımlar: %80 klasik ilan fan-out, %20 talep digeste; ürün = ilan adedi.

| Günlük ilan (+eşdeğer ürün) | Önce tipik $/ay | **Sonra tipik $/ay** | Önce kötümser | **Sonra kötümser** |
|-----------------------------|-----------------|----------------------|---------------|---------------------|
| **100** | $15–60 | **$10–40** | ~$150 | **~$80** |
| **1.000** | $150–500 | **$80–280** | ~$1.200 | **~$500–700** |
| **10.000** | $1.500–4.000 | **$600–1.800** | $5k–12k+ | **~$2.500–5.000** |

### Neden düştü?

1. **Alıcı tavanı 120** → kalabalık ilde yazma/okuma ~3–10× kesilir (500→120).  
2. **Sorgu 200** → profil okuma tavanı düştü.  
3. **Paralel token** → CF süresi (GB-s) ve timeout riski azalır.  
4. **Tercih kapalı = yazma yok** → boşa notification write azalır.  
5. **Client cap** → Keşfet/usta arama okuması ~%30–40.  

Küçük şehir/meslekte (zaten &lt;120 eşleşme) kazanç az; **İstanbul + popüler meslek**’te kazanç büyük.

### Hâlâ en pahalı kalemler

1. Fan-out (ama tavanlı)  
2. Canlı snapshot / MAU  
3. Sohbet  

### UX etkisi

| Kullanıcı | Etki |
|-----------|------|
| Çoğu usta | Fark etmez (eşleşme &lt; 120) |
| Megakent + popüler meslek | En fazla 120 bildirim; liste hâlâ dolu |
| Bildirim kapalı tercihi | Artık in-app de yazılmaz (daha tutarlı) |
| Müşteri / ilan veren | Değişmez |

## Bilinçli yapılmayanlar (UX riski)

- Müsait olmayana bildirim kesmek (ürün: almalı)  
- Fan-out’u tamamen kapatmak  
- Sohbet push’unu kısmak  
- Foto kalitesini bozacak agresif sıkıştırma  
