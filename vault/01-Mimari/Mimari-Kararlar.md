# Mimari Kararlar (ADR)

Verilmiş kararlar ve **gerekçeleri**. Bir kararı değiştirmeden önce gerekçesini
oku — çoğu bir sorunun çözümü olarak doğdu.

---

## ADR-01 · Repository arayüzü + Mock ikizi

**Karar:** Her veri kaynağı arayüz ardında; Firebase ve Mock uygulaması ikiz.
Seçim `useFirebaseBackend` sabiti ile.

**Gerekçe:** Proje Firebase'siz başladı. Bugünkü kazanç: 319 test emulator ve
ağ olmadan koşar; UI geliştirmesi backend'i beklemez; arayüz doc-comment'leri
sözleşmenin tek kaynağıdır.

**Bedel:** Her yeni metot iki kez yazılır. Parite bozulursa test yanlış güven
verir. → [[Repository-Deseni]]

---

## ADR-02 · İlan bazlı sohbet kimliği

**Karar:** `chat_{müşteri}__{usta}__{jobId}` — aynı çift her iş için ayrı oda.

**Gerekçe:** Tek sohbet paylaşılsaydı hangi işin konuşulduğu belirsiz kalırdı;
"Ustayı Seç" hangi ilanı kapatacağını bilemezdi; değerlendirme iş başına
ayrışamazdı.

**Bedel:** Sohbet sayısı artar. Genel sohbetler (`jobId` null) hâlâ desteklenir
— ürün/eleman akışları ve eski kayıtlar için.

→ [[Sohbet-Mimarisi]]

---

## ADR-03 · Deterministik doküman kimlikleri

**Karar:** `chats`, `offers`, `reviews`, `favorites` hesaplanabilir kimlik
kullanır.

**Gerekçe:** Tekillik bedava gelir (aynı usta ikinci teklif yazamaz, günceller);
kural kimliği doğrulayarak spam engeller (rastgele kimlikle üçüncü kişiye
sohbet açılamaz); "var mı?" sorusu sorgu gerektirmez.

→ [[Firestore-Semasi]]

---

## ADR-04 · İletişimi müşteri başlatır

**Karar:** Usta ilana yalnız ilgi bildirir; ilk mesajı müşteri yazar
(`customerStarted` bayrağı).

**Gerekçe:** Ustaların müşteriyi mesaj yağmuruna tutmasını engeller. Kural
motoru mesaj sayamadığı için bayrak denormalize tutulur.

**Sonradan eklenen istisna:** Müşteri işi verirse bayrak otomatik açılır — işi
vermek iletişimi başlatmaktan güçlü bir niyettir. Bu istisna olmadan seçilen
usta kendi işinin sohbetinde kilitli kalıyordu. → [[Bilinen-Tuzaklar]]

---

## ADR-05 · Kilidi yalnız Cloud Function koyar

**Karar:** `lockedAt` / `lockReason` istemci yazımına tamamen kapalı.

**Gerekçe:** Açık olsaydı seçilmeyen usta kendi kilidini kaldırıp işi alan
ustanın müşterisine yazmaya devam ederdi. Kural allowlist'i bu alanları hiç
içermez.

---

## ADR-06 · İş tamamlanınca sohbet kilitlenmez

**Karar:** `completed` durumu sohbeti kapatmaz; kapanma 7 gün sonra arşivle
olur.

**Gerekçe:** Taraflar teslim sonrası konuşabilmeli (eksik iş, garanti, ek
soru). `ChatLockReason.completed` bu yüzden tanımlı ama kullanılmıyor.

---

## ADR-07 · Sohbet arşivlenir, silinmez

**Karar:** `archiveCompletedChats` salt okunur yapar, veri kalır.

**Gerekçe:** Üç şey korunur — anlaşmazlık kanıtı (8. günde gelen şikayet),
değerlendirme bağı (`reviews` kimliği `chatId`'ye dayanır), admin transcript'i.

**Bedel:** Depolama maliyeti. Kabul edildi.

---

## ADR-08 · Değerlendirme yönü asimetrik görünür

**Karar:** c2a (müşteri→usta) herkese açık; a2c (usta→müşteri) yalnız ustalara.

**Gerekçe:** Müşteri profili vitrin değildir. Düşük puanlı müşterinin hizmet
alamaz hale gelmesi istenmiyor — puan ustalara sinyal, müşteriye damga değil.

→ [[Degerlendirme-Sistemi]]

---

## ADR-09 · Serbest metin yorum yok

**Karar:** Değerlendirme = yıldız + hazır etiket. Yazılı yorum yok (PRD §3).

**Gerekçe:** Moderasyon yükü ve hakaret riski. Etiketler yapılandırılmış veri
verir, filtrelenebilir.

---

## ADR-10 · İletişim bilgisi maskelenir

**Karar:** Sohbette telefon, e-posta, sosyal medya otomatik gizlenir
(`core/utils/contact_masker.dart`, PRD §5).

**Gerekçe:** Ticari — iş platform içinde kalmalı. Platform dışına çıkan iş
komisyon ve güvence dışında kalır.

**Not:** Maskeleme uygulandıysa `sendMessage` `true` döner, UI kullanıcıyı
uyarır — sessizce değiştirmez.

---

## ADR-11 · Hassas veri `private/` alt koleksiyonunda

**Karar:** `users/{uid}` herkese açık okunur; telefon vb. `users/{uid}/private/*`
altında.

**Gerekçe:** **Firestore alan bazlı okuma kısıtlaması yapamaz** — okuma izni
varsa tüm doküman döner. Kural `owner` dahil kimsenin ana dokümana
`phoneNumber` yazmasına izin vermez.

→ [[Guvenlik-Kurallari]]

---

## ADR-12 · Zaman damgaları ISO string

**Karar:** Firestore `Timestamp` yerine UTC ISO 8601 string.

**Gerekçe:** Tek alanlı aralık sorgusu composite index gerektirmez. ISO
string sözlük sırası = kronolojik sıra.

**Bedel:** UTC yazmak zorunlu; yerel saatle karışırsa sıralama bozulur.

---

## ADR-13 · Sayaçları yalnız CF yazar

**Karar:** `offerCount`, ortalama puan, `completedJobs`, okunmamış sayacı —
hepsi CF'ye ait, kural istemciye kapatır.

**Gerekçe:** İstemci yazabilseydi kendi puanını şişirirdi. Ayrıca CF
"yeniden hesapla" yaklaşımı kullanır (artır/azalt değil) → sayaç her zaman
tutarlı, kaçan olay veriyi bozmaz.

---

## ADR-14 · Admin ayrı derleme hedefi

**Karar:** `main_admin.dart`, aynı kod tabanı, aynı Firebase projesi.

**Gerekçe:** Kullanıcı uygulamasının paket boyutuna 36 dosyalık panel
girmemeli. Aynı modeller ve repository'ler paylaşılır.

→ [[Admin-Paneli]]

---

## ADR-15 · Türkçe metin enum'da

**Karar:** `labelTR` / `simpleLabelTR` model enum'unda durur, UI'da değil.

**Gerekçe:** Tek yer, tutarlı dil. Ayrıca iki dil ayrımı: `labelTR` teknik
(8 durum), `simpleLabelTR` kullanıcı (3 evre). Backend enum'u sadeleşmez,
yalnız UI metni birleşir.

---

## ADR-16 · Kullanıcıya görünen sadeleştirme

**Karar:** 8 iş durumu kullanıcıya 3 evre olarak gösterilir
(teklif toplanıyor → iş yürüyor → tamamlandı).

**Gerekçe:** `workerSelected` ile `inProgress` ayrımı kullanıcı için
anlamsızdı. Backend ayrımı korur çünkü CF davranışı farklı.

---
İlgili: [[Bilinen-Tuzaklar]] · [[Katman-Mimarisi]] · [[Repository-Deseni]]
