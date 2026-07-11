# 🗺️ Usta Cepte — Proje Denetimi ve Yol Haritası

> Proje yöneticisi bakışıyla dürüst durum tespiti (2026-07-10).
> Amaç: "0 hata" hedefine giden, mağazaya çıkabilir, gerçek kullanıcıya
> dayanıklı bir ürün. Her madde koda bakılarak doğrulandı — varsayım değil.

---

## 🔴 P0 — Yayın Engelleyiciler (bunlar kapanmadan mağazaya çıkılamaz)

### 1. ✅ KAPANDI (Oturum 39, 2026-07-11) — Premium istemciden açılamıyor
- Kural: `artisanProfiles` guard listelerine `isPremium/premiumExpiresAt`
  eklendi (CANLIDA); `saveMyProfile` (Firebase+Mock) alanları yazımdan çıkarır;
  `setPremium` silindi.
- Ürün kararı (kullanıcı): **beta süresince premium özellikleri herkese
  ücretsiz, 1 yıl modeli yok** → `AppConstants.premiumFreeDuringBeta` +
  `ArtisanProfile.hasPremiumAccess` (gating buna bakar, rozet hâlâ gerçek
  premium'a). Premium ekranı satın almasız bilgi sayfası oldu.
- Kalan (madde 5 ile birlikte): Play Billing gelince `premiumFreeDuringBeta=false`
  + alanları yalnız sunucu (CF/billing doğrulaması) yazar.

### 2. Hesap silme yok (Google Play ZORUNLULUĞU)
- Hesap oluşturan her uygulama, uygulama İÇİNDEN hesap silme sunmak zorunda
  (Play politikası). Kodda `deleteAccount` yok.
- Kapsam: Auth kaydı + users + artisanProfiles + reviews/offers/jobs kararı
  (anonimleştir?) + Storage klasörleri + FCM token. Doğru yer: callable CF
  (istemci tek tek silemez, kurallar da izin vermemeli).

### 3. Yasal metinler yok (KVKK/Store zorunluluğu)
- Kodda gizlilik politikası, kullanım koşulları, KVKK aydınlatma metni,
  kayıt ekranında onay yok. Store girişinde gizlilik politikası URL'si zorunlu.
- Kapsam: 3 metin (web'de host + uygulamada sayfa), kayıtta onay kutusu,
  profil > Hesap altına linkler.

### 4. Kullanıcı engelleme + içerik şikayeti yok (UGC politikası)
- Sohbet/yorum/ilan = kullanıcı üretimi içerik. Play/App Store, UGC olan
  uygulamada **içerik şikayet etme + kullanıcı engelleme** ister. Bizde iş
  anlaşmazlığı (disputed) var ama kişi engelleme/mesaj şikayeti yok.
- Kapsam: `users/{uid}/blocked` alt-koleksiyonu; engellenen kişi mesaj
  yazamaz (kural: chat üyeliği kontrolüne ek), sohbet listesinde gizlenir;
  mesaj uzun basma menüsüne "Şikayet et" (admin kuyruğuna kayıt).

### 5. Premium ödeme akışı yok
- Gerçek gelir için Google Play Billing (`in_app_purchase`) + satın alma
  doğrulaması (CF ile server-side verify) + `isPremium`'u yalnız sunucu yazar
  (madde 1 ile birlikte tasarlanmalı). iOS tarafı App Store'a kalır.

### 6. App Check zorlaması + web reCAPTCHA (Oturum 37'de altyapı kuruldu)
- İstemci hazır, Play Integrity kayıtlı; **enforcement bilinçli KAPALI**.
- Kalan: cihazdan debug token ekle → metriklerde %100 verified görünce
  Firestore+Storage'da Enforce aç. Web için reCAPTCHA v3 anahtarı (manuel).

---

## 🟠 Güvenlik — yapılanlar / kalanlar

**Yapıldı (Oturum 23/24/26/31/34/37):** kural tabanlı alan/geçiş kısıtları
(jobs/offers/reviews/messages), deterministik ID'lerle spam kilidi, Storage
uid klasör sahipliği, telefon claim'li mavi tik, SMS bölge kilidi, tek yorum
→ güncellenebilir yorum (delta CF), dispute yaşam döngüsü kilidi, App Check
istemcisi, hassas veri `users/{uid}/private` ayrımı, Crashlytics.

**Kalanlar (öncelik sırasıyla):**
1. `isPremium` kural guard'ı (yukarıda, P0).
2. **Mesaj hız sınırı yok:** üye olduğu sohbete sınırsız mesaj yazılabilir
   (spam). Kural başına dakikalık limit Firestore'da zor; pratik çözüm:
   App Check enforce + istemci debounce + CF ile anomali tespiti (P2).
3. **Admin yetkisi:** custom claim `admin:true` + adminOnly kurallar —
   admin paneliyle birlikte (backlog'da).
4. **Firestore yedekleme:** PITR (point-in-time recovery) Console'dan
   açılmalı + haftalık export cron'u (gcloud scheduled export). Veri kaybı
   senaryosuna bugün cevabımız YOK.
5. **Functions izleme/alarm:** Cloud Monitoring'de hata oranı alarmı
   (onJobWritten patlarsa bugün kimsenin haberi olmaz).
6. Console'da bekleyen: notifications TTL politikası (Oturum 33'ten beri).
7. (P2) Görsel içerik denetimi: Vision SafeSearch CF ile yüklenen fotoğraf
   taraması (çıplaklık/şiddet) — UGC büyüyünce şart olur.

---

## 🟡 "0 Hata" hedefi — kalite altyapısı eksikleri

Mevcut: 85 birim/widget testi (mock katman), analyze 0, elle test.
Gerçek "0 hata" disiplini için eksikler:

1. **Firestore RULES testleri yok.** En kırılgan varlığımız kurallar
   (7 oturumda 6 kez değişti) ve tek doğrulaması "canlıda deneme".
   `@firebase/rules-unit-testing` + emulator ile kural regresyon paketi →
   en yüksek getirili kalite yatırımı.
2. **CI yok.** GitHub Actions: her push'ta `flutter analyze` + `flutter test`
   + `node --check` + (nightly) `flutter build`. Kırık kod main'e giremez olur.
3. **Staging ortamı yok.** Tek Firebase projesi (alljob1) hem geliştirme hem
   canlı. İkinci proje (`alljob-dev`) + flavor (`--dart-define=ENV=dev`) →
   canlı veriyle test etme riski biter.
4. **Entegrasyon testi yok.** `integration_test` + emulator suite ile 3 altın
   akış: kayıt→ilan ver→teklif→sohbet; usta seç→tamamla→değerlendir; silmeler.
5. **Zorunlu güncelleme mekanizması yok.** Eski/hatalı sürüm süresiz yaşar.
   Remote Config `minSupportedVersion` + `package_info_plus` + kibarca
   güncelleme ekranı. (Kural değişikliklerinde eski istemciler kırılabiliyor —
   bunu yönetmenin tek yolu bu.)
6. **Sürüm/rollout disiplini yok:** internal testing track → kapalı beta →
   %10 staged rollout → %100. Release öncesi 10 maddelik smoke checklist'i
   (bu dosyanın sonuna eklenecek).
7. Crashlytics velocity alarmı + sürüm bazlı crash-free oranı takibi.

---

## 🟢 Gerçek üründe olup bizde olmayanlar (ürün eksikleri)

| Eksik | Neden önemli | Öncelik |
|---|---|---|
| Analytics (firebase_analytics) | Kayıt→ilan→teklif→tamamlama hunisi ölçülmeden ürün kararı alınamaz | P1 |
| Bildirim tercihleri | Kullanıcı "yeni ilan bildirimi" kapatamıyor → uninstall sebebi | P1 |
| Yardım/SSS + destek kanalı | "Nasıl çalışır?", iletişim formu/mail | P1 |
| Onboarding | İlk açılışta değer önerisi + müşteri/usta yol ayrımı | P1 |
| Profil tamamlama yüzdesi | Ustayı foto+bölge+takvim eklemeye iten en etkili kalıp | P2 |
| App Links (https deep link) | Paylaşılan ilan linki uygulamada açılsın | P2 |
| Gelişmiş arama | Firestore prefix aramasıyla sınırlıyız; büyüyünce Algolia/Typesense | P3 |
| Web push (VAPID) + iOS APNs | Bilinen bekleyenler (Oturum 30) | P2/P3 |
| Koyu tema | `AppTheme.dark` var ama kapalı; cilalanıp açılmalı | P2 |

---

## 🎨 Tasarım — "yapay zeka tasarımı" hissini kırmak

Dürüst tespit: mevcut tasarım TEMİZ ama GÜVENLİ — Material kartlar + gradyan
app bar her yerde görülen dil. Ayırt edici kimlik için (etki sırasına göre):

1. **Özel ikon/illüstrasyon seti (en güçlü hamle).** 24 meslek için tek
   çizgide özel meslek ikonları + boş durum/hata/onboarding için tek stilde
   3-5 illüstrasyon. İnsanlar "gerçek tasarımcı" hissini en çok buradan alır.
   (Bir illüstratöre tek seferlik iş olarak verilebilir; stil rehberi bizden.)
2. **UX writing / ses tonu.** Kuru sistem dili yerine tutarlı zanaat dili:
   "İlanın yayında 🎉 Ustalar haberdar edildi", "Usta yolda!". Tek sayfalık
   mikro-metin rehberi yazılmalı; tüm toast/boş durum metinleri oradan geçmeli.
3. **Mikro-etkileşimler.** Basınca hafif yaylanan butonlar (scale 0.97),
   listeye giriş stagger'ı, ilan yayınlanınca konfeti anı, haptic feedback
   (başarı/hata). Az ama tutarlı — her yere değil, 5-6 kilit ana.
4. **Tipografi kontrastı.** Her şey Inter — başlıklara karakterli bir
   display font (lisansına dikkat) veya en azından ExtraBold + sıkı
   letter-spacing ile belirgin hiyerarşi.
5. **Markalı yükleme/boş durumlar.** Genel skeleton yerine marka renkli
   shimmer; boş durumlarda illüstrasyon + tek CTA (İlanlarım'da başladık).
6. **Erişilebilirlik = profesyonellik.** 48px dokunma hedefleri, kontrast
   denetimi (inkFaint bazı yerlerde sınırda), TalkBack etiketleri, büyük
   font ölçeğinde taşma testi. "AI tasarımı" en çok erişilebilirlik
   ihmalinden belli olur.

---

## 📣 Kullanıcı bilgilendirme — durum

**İyi olanlar (korunmalı):** Hızlı Destek bilgi kutusu, otomatik tamamlama
uyarısı, tek taraflı sohbet silme onayı, iletişim maskeleme açıklaması,
değerlendirme güncelleme şeridi.

**Eksikler:** onboarding yok; "İlgilenen ustalar"a teklif gelmeyince ne
olacağı anlatılmıyor (ilan süresi dolunca ne olur?); usta tarafında "neden
ilan görmüyorum" (bölge/meslek uyumsuzluğu) açıklaması yok; premium'un ne
kazandırdığı tek yerde net listelenmiyor; ilk kez sohbete girene maskeleme
kuralı önceden söylenmiyor (mesajı kırpılınca öğreniyor).

---

## 📋 Önerilen sprint planı

- **Sprint 1 — Mağaza/Güvenlik engelleri (P0):** isPremium kural kilidi →
  hesap silme (callable CF) → engelle/şikayet → yasal metinler + kayıt onayı.
- **Sprint 2 — Kalite altyapısı:** GitHub Actions CI → rules emulator
  testleri → staging projesi + flavor → Remote Config zorunlu güncelleme →
  Firestore PITR/export → Functions alarmı → analytics.
- **Sprint 3 — Gelir:** Play Billing premium (sunucu doğrulamalı) + premium
  değer sayfası.
- **Sprint 4 — Tasarım kimliği:** ikon/illüstrasyon seti + mikro-etkileşim
  paketi + UX writing rehberi + koyu tema + onboarding.
- **Sprint 5 — Operasyon:** admin paneli (disputed hakemliği, şikayet
  kuyruğu, kullanıcı yönetimi) + App Check enforce + TTL.

> Not: Her sprint sonunda release checklist + staged rollout. "0 hata"
> bir hedef değil süreçtir: kural testi + CI + staging + zorunlu güncelleme
> dörtlüsü kurulunca hata SIZMA yolları kapanmış olur.
