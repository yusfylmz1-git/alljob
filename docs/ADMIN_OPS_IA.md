# Admin Ops Console — bilgi mimarisi (PM + mühendislik)

Amaç: moderasyon kuyruğu değil, **platform operasyon merkezi**.

## Modüller (fazlı)

| Bölüm | Ekranlar | Durum |
|--------|----------|--------|
| **Operasyon** | Özet KPI, Şikayetler, Anlaşmazlıklar | Var |
| **Kişiler & içerik** | Kullanıcılar, Ustalar, İlanlar, Yorumlar | Var |
| **İletişim** | Toplu bildirim (in-app + FCM) | **Bu PR** |
| **Platform** | Marka, destek, duyuru, mağaza linkleri | **Bu PR** |
| **Sistem** | Bayraklar (beta/bakım/min sürüm), Kadro, Denetim | Var + genişledi |

## Veri

- `adminConfig/runtime` — public read, CF `adminUpdateConfig` write  
- Bildirim: `users/{uid}/notifications` (CF only) + FCM  
- Denetim: her config/broadcast audit log  

## Bilinçli sınırlar (v1)

- Toplu bildirim: son **300** kullanıcı / çağrı (fan-out güvenliği)  
- Broadcast rate: **5 dk / admin**  
- Logo: **URL** (Storage yükleme paneli sonraki faz)  
- Tam “CMS + medya kütüphanesi” yok — bilinçli MVP  

## Sonraki fazlar

1. Storage’dan logo yükleme  
2. Segment: il / meslek / premium  
3. Zamanlanmış duyuru  
4. Yardım makaleleri CMS  
5. reCAPTCHA + App Check ENFORCE admin web  
