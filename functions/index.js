"use strict";

// Usta Cepte — Cloud Functions (Gen 2, Node 22).
//
// Amaç: istemci-tarafı "geçici çözümleri" sunucuya taşımak + push bildirimleri:
//  1) Puan (rating) toplamlarını `artisanProfiles` üzerine denormalize et →
//     müşteri araması artık her seferinde `reviews` koleksiyonunu TARAMAZ.
//  2) `jobs.offerCount` sayacını sunucuda tut → istemci `FieldValue.increment`
//     ve ona izin veren özel Firestore kuralı kaldırılabilir.
//  3) Yeni sohbet mesajında alıcının cihaz(lar)ına FCM push bildirimi gönder
//     (`onMessageCreated`) + geçersiz token'ları temizle.
//  4) Yeni iş ilanında AYNI İL + AYNI MESLEK ustalarına push (`onJobCreated`).
//  5) Hesap silme (`deleteAccount` callable) — Play zorunluluğu + KVKK;
//     yalnız sunucu, tüm koleksiyonları tutarlı temizleyebilir.
//
// Dağıtım: firebase deploy --only functions --project alljob1

const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {onCall, HttpsError} = require("firebase-functions/v2/https");
const {onSchedule} = require("firebase-functions/v2/scheduler");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Fonksiyonları Firestore veritabanına yakın bölgede çalıştır (gecikme/maliyet).
const REGION = "europe-west1";

// Tek taraf "işi tamamladım" dedikten sonra karşı tarafın yanıt süresi (gün).
// Mock paritesi: mock_job_repository.confirmDone aynı sayıyı kullanır.
const AUTO_COMPLETE_DAYS = 3;

// "Hızlı Destek" ilan kategorisi (ayak işleri): meslek filtresi olmadan
// İLÇEDEKİ TÜM ustalara gider. İstemci paritesi: job.dart
// kQuickSupportCategory / kOtherProfession.
const QUICK_SUPPORT_CATEGORY = "quick_support";

// Yönetici ön-yükleme (bootstrap) izin listesi. Yalnız bu (doğrulanmış)
// e-postalar `claimAdminAccess` ile kendilerine `admin:true` claim'i yazdırabilir.
// İstemci paritesi: lib/features/admin/data/admin_config.dart.
const ADMIN_BOOTSTRAP_EMAILS = new Set([
  "aboneai.plus@gmail.com",
]);

// Şikayet nedeni kodlarının Türkçe karşılıkları (istemci JobDisputeReason
// enum'u ile birebir — bildirim gövdesinde kullanılır).
const DISPUTE_REASON_TR = {
  notCompleted: "İş yapılmadı / yarım bırakıldı",
  qualityIssue: "İş kötü veya özensiz yapıldı",
  paymentIssue: "Ücret / ödeme anlaşmazlığı",
  communicationIssue: "Ulaşılamıyor / iletişim sorunu",
  other: "Diğer",
};

/**
 * Tek bir kullanıcıya (tüm kayıtlı cihazlarına) push gönderir; kayıtsız/geçersiz
 * token'ları kullanıcının dizisinden temizler (onMessageCreated ile aynı kalıp).
 */
async function sendPushToUid(uid, title, body, data) {
  const userSnap = await db.collection("users").doc(uid).get();
  const tokens = (userSnap.exists && Array.isArray(userSnap.data().fcmTokens)) ?
    userSnap.data().fcmTokens :
    [];
  if (tokens.length === 0) return;

  let resp;
  try {
    resp = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data,
      android: {priority: "high", notification: {sound: "default"}},
      apns: {payload: {aps: {sound: "default", badge: 1}}},
    });
  } catch (e) {
    logger.error(`Push failed for ${uid}: ${e}`);
    return;
  }

  const invalid = [];
  resp.responses.forEach((r, i) => {
    if (r.success) return;
    const code = r.error && r.error.code;
    if (code === "messaging/registration-token-not-registered" ||
        code === "messaging/invalid-argument" ||
        code === "messaging/invalid-registration-token") {
      invalid.push(tokens[i]);
    }
  });
  if (invalid.length > 0) {
    try {
      await db.collection("users").doc(uid).update({
        fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
      });
    } catch (e) {
      logger.warn(`Token cleanup skipped for ${uid}: ${e}`);
    }
  }
}

// Uygulama içi bildirim merkezi kayıtlarının saklama süresi (gün) — Firestore
// TTL politikası `expireAt` alanına bağlanır (Console → TTL: notifications).
const NOTIFICATION_TTL_DAYS = 30;

/**
 * Uygulama içi bildirim merkezine kayıt yazar (`users/{uid}/notifications`).
 * Push'tan BAĞIMSIZ çağrılır: cihaz token'ı olmayan kullanıcı da uygulama
 * içinde bildirimi görür. Kurallar bu alt-koleksiyonu istemci yazımına kapatır
 * (yalnızca `read` güncellenebilir) — sahte bildirim enjekte edilemez.
 *
 * [docId] deterministik verilir (ör. `chat_{chatId}`, `job_{jobId}`): aynı
 * kaynağın yeni olayı eski kaydın ÜZERİNE yazar → Instagram tarzı, sohbet/ilan
 * başına tek satır; `read` false'a döner ve satır listenin başına çıkar.
 */
async function saveNotification(uid, docId, notif) {
  try {
    await db.collection("users").doc(uid)
        .collection("notifications").doc(docId).set({
          ...notif,
          read: false,
          createdAt: new Date().toISOString(),
          expireAt: admin.firestore.Timestamp.fromMillis(
              Date.now() + NOTIFICATION_TTL_DAYS * 24 * 3600 * 1000),
        });
  } catch (e) {
    logger.warn(`Notification save failed for ${uid}/${docId}: ${e}`);
  }
}

/**
 * Bir değerlendirme yazıldığında (oluşturma VEYA güncelleme) ustanın puan
 * toplamlarını DELTA ile günceller. Müşteri başına usta başına tek döküman
 * (ID = chatId) olduğundan: create → sayaç+1, toplam+puan; update → sayaç
 * sabit, toplam += (yeni−eski). Silme kurallarda kapalı ama savunmacı olarak
 * ele alınır (sayaç−1, toplam−eski). Yalnız etiket değişimi toplamları
 * etkilemez → erken çıkış.
 */
exports.onReviewWritten = onDocumentWritten(
    {document: "reviews/{reviewId}", region: REGION},
    async (event) => {
      const beforeSnap = event.data && event.data.before;
      const afterSnap = event.data && event.data.after;
      const before =
        beforeSnap && beforeSnap.exists ? beforeSnap.data() : null;
      const after = afterSnap && afterSnap.exists ? afterSnap.data() : null;

      const artisanUid = (after && after.artisanUID) ||
        (before && before.artisanUID);
      if (!artisanUid) return;

      const oldRating = before ? (Number(before.rating) || 0) : 0;
      const newRating = after ? (Number(after.rating) || 0) : 0;
      const countDelta = (after ? 1 : 0) - (before ? 1 : 0);
      const sumDelta = newRating - oldRating;
      if (countDelta === 0 && sumDelta === 0) return;

      const ref = db.collection("artisanProfiles").doc(artisanUid);
      try {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (!snap.exists) return; // profil yoksa atla
          const cur = snap.data() || {};
          const totalReviews =
            Math.max(0, (Number(cur.totalReviews) || 0) + countDelta);
          const totalRatingSum =
            Math.max(0, (Number(cur.totalRatingSum) || 0) + sumDelta);
          tx.update(ref, {
            totalReviews,
            totalRatingSum,
            averageRating:
              totalReviews > 0 ? totalRatingSum / totalReviews : 0,
          });
        });
        logger.info(
            `Rating updated for artisan ${artisanUid} ` +
            `(count ${countDelta}, sum ${sumDelta})`);
      } catch (e) {
        logger.error(`Rating update failed for ${artisanUid}: ${e}`);
      }
    },
);

/**
 * Bir teklif (ilgi kaydı) her yazıldığında (oluşturma/güncelleme/geri çekme)
 * ilgili ilanın `offerCount` alanını, çekilmemiş (withdrawn olmayan) teklif
 * sayısına göre YENİDEN HESAPLAR. Böylece sayaç her zaman tutarlıdır ve
 * istemcinin yazmasına gerek kalmaz.
 */
exports.onOfferWritten = onDocumentWritten(
    {document: "offers/{offerId}", region: REGION},
    async (event) => {
      const after = event.data && event.data.after && event.data.after.data();
      const before =
        event.data && event.data.before && event.data.before.data();
      const jobId = (after && after.jobId) || (before && before.jobId);
      if (!jobId) return;

      const snap = await db
          .collection("offers")
          .where("jobId", "==", jobId)
          .get();

      let count = 0;
      snap.forEach((d) => {
        if ((d.data().status || "") !== "withdrawn") count += 1;
      });

      try {
        await db.collection("jobs").doc(jobId).update({offerCount: count});
        logger.info(`offerCount=${count} for job ${jobId}`);
      } catch (e) {
        // İlan silinmiş/yoksa güncelleme atlanır (zararsız).
        logger.warn(`offerCount update skipped for ${jobId}: ${e}`);
      }
    },
);

/**
 * Bir sohbete yeni mesaj yazılınca, mesajı GÖNDEREN dışındaki katılımcıya
 * (alıcı) kayıtlı FCM token'ları üzerinden push bildirimi gönderir.
 *
 * Token'lar `users/{uid}.fcmTokens` (string dizisi) alanında tutulur; istemci
 * giriş yapınca ekler, çıkışta çıkarır (bkz. `push_service.dart`). Gönderim
 * sonrası "kayıtlı değil/geçersiz" dönen token'lar diziden temizlenir
 * (uygulaması silinmiş/oturumu kapanmış cihazlar birikmesin).
 *
 * `data.chatId` yükü sayesinde istemci bildirime dokununca ilgili sohbeti açar.
 */
exports.onMessageCreated = onDocumentCreated(
    {document: "chats/{chatId}/messages/{msgId}", region: REGION},
    async (event) => {
      const msg = event.data && event.data.data();
      if (!msg) return;
      const chatId = event.params.chatId;
      const senderUid = msg.senderUid;
      if (!senderUid) return;

      // Sohbet dökümanından katılımcıları + adları oku.
      const chatSnap = await db.collection("chats").doc(chatId).get();
      if (!chatSnap.exists) return;
      const chat = chatSnap.data() || {};
      const participants = Array.isArray(chat.participants) ?
        chat.participants :
        [chat.customerUid, chat.artisanUid];
      const recipientUid = participants.find((p) => p && p !== senderUid);
      if (!recipientUid) return;

      // Bildirim başlığı = gönderenin adı; gövde = mesaj (foto ise etiket).
      const senderName = senderUid === chat.customerUid ?
        chat.customerName :
        chat.artisanName;
      const body = msg.imageHandle ? "📷 Fotoğraf" : (msg.text || "Yeni mesaj");

      // Uygulama içi bildirim merkezi (sohbet başına tek kayıt, push'tan
      // bağımsız — token'sız kullanıcı da görsün).
      await saveNotification(recipientUid, `chat_${chatId}`, {
        type: "chat",
        title: senderName || "Yeni mesaj",
        body,
        chatId,
      });

      // Alıcının token'ları.
      const userSnap = await db.collection("users").doc(recipientUid).get();
      const tokens = (userSnap.exists &&
        Array.isArray(userSnap.data().fcmTokens)) ?
        userSnap.data().fcmTokens :
        [];
      if (tokens.length === 0) return;

      const payload = {
        tokens,
        notification: {
          title: senderName || "Yeni mesaj",
          body,
        },
        data: {type: "chat", chatId},
        // channelId belirtilmez: cihazda olmayan bir kanal Android 8+'da
        // bildirimi gizler. FCM SDK'sı otomatik varsayılan kanalı kullanır.
        android: {
          priority: "high",
          notification: {sound: "default"},
        },
        apns: {
          payload: {aps: {sound: "default", badge: 1}},
        },
      };

      let resp;
      try {
        resp = await admin.messaging().sendEachForMulticast(payload);
      } catch (e) {
        logger.error(`FCM send failed for ${recipientUid}: ${e}`);
        return;
      }

      // Geçersiz/kayıtsız token'ları diziden temizle.
      const invalid = [];
      resp.responses.forEach((r, i) => {
        if (r.success) return;
        const code = r.error && r.error.code;
        if (code === "messaging/registration-token-not-registered" ||
            code === "messaging/invalid-argument" ||
            code === "messaging/invalid-registration-token") {
          invalid.push(tokens[i]);
        }
      });
      if (invalid.length > 0) {
        try {
          await db.collection("users").doc(recipientUid).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...invalid),
          });
        } catch (e) {
          logger.warn(`Token cleanup skipped for ${recipientUid}: ${e}`);
        }
      }
      logger.info(
          `Push→${recipientUid}: ${resp.successCount}/${tokens.length} ok, ` +
          `${invalid.length} pruned`,
      );
    },
);

/**
 * Yeni bir iş ilanı verildiğinde, ilanın MESLEĞİNE sahip ve hizmet bölgeleri
 * arasında ilanın İLİ bulunan ustalara push bildirimi gönderir.
 *
 * Eşleşme sunucuda bellek içi yapılır: `artisanProfiles` üzerinde tek eşitlik
 * sorgusu (`profession == category`, composite index gerekmez), ardından
 * `serviceAreas[].province` kontrolü kodda. Bu ölçekte (meslek başına yüzlerce
 * usta) hem ucuz hem de istemci şemasında değişiklik/backfill gerektirmez.
 *
 * İlan sahibinin kendisi (çift rollü kullanıcı) atlanır. Token temizliği
 * `onMessageCreated` ile aynı: kayıtsız/geçersiz token'lar sahibinin
 * dizisinden düşülür.
 */
exports.onJobCreated = onDocumentCreated(
    {document: "jobs/{jobId}", region: REGION},
    async (event) => {
      const job = event.data && event.data.data();
      if (!job) return;
      const jobId = event.params.jobId;

      // Yalnızca açık (yeni) ilanlar; kategori/il yoksa eşleşme yapılamaz.
      if ((job.status || "open") !== "open") return;
      const category = job.category || "";
      const province = job.province || "";
      if (!category || !province) return;

      const isQuickSupport = category === QUICK_SUPPORT_CATEGORY;

      // Alıcı profilleri:
      //  - Hızlı Destek: MESLEK FİLTRESİ YOK → ilçedeki tüm ustalar (tavan
      //    1000; koleksiyon taraması bu ölçekte kabul edilebilir, ilçe
      //    eşleşmesi bellek içi).
      //  - Klasik ilan: aynı meslek (tavan 500) + il eşleşmesi (mevcut kalıp).
      const profilesSnap = isQuickSupport ?
        await db.collection("artisanProfiles").limit(1000).get() :
        await db
            .collection("artisanProfiles")
            .where("profession", "==", category)
            .limit(500)
            .get();
      if (profilesSnap.empty) return;

      // Bölgede hizmet verenler (ilan sahibi hariç). Hızlı Destek'te il+İLÇE
      // düzeyinde eşleşme aranır (kullanıcı kararı: "ilçedeki tüm ustalar").
      const jobDistrict = job.district || "";
      const recipientUids = [];
      profilesSnap.forEach((d) => {
        if (d.id === job.customerId) return; // kendi ilanına bildirim gitmesin
        const areas = Array.isArray(d.data().serviceAreas) ?
          d.data().serviceAreas :
          [];
        const match = isQuickSupport ?
          areas.some((a) => a && a.province === province &&
            a.district === jobDistrict) :
          areas.some((a) => a && a.province === province);
        if (match) recipientUids.push(d.id);
      });
      if (recipientUids.length === 0) {
        logger.info(`Job ${jobId}: no matching artisans in ${province}`);
        return;
      }

      // Not: il adına ek ("'de/'da") ünlü uyumu gerektirdiğinden ekli kalıp
      // kullanılmaz ("İstanbul'de" gibi hatalar oluşuyordu).
      const urgent = job.isUrgent === true;
      const place = isQuickSupport && jobDistrict ? jobDistrict : province;
      const kind = isQuickSupport ? "Hızlı Destek ilanı" : "iş ilanı";
      const title = urgent ?
        `🚨 ${place} bölgesinde acil ${kind}` :
        `${isQuickSupport ? "⚡ " : ""}${place} bölgesinde yeni ${kind}`;
      const district = job.district ? ` · ${job.district}` : "";
      const body = `${job.title || "Yeni ilan"}${district}`;

      // Uygulama içi bildirim merkezi: eşleşen HER ustaya kayıt (push'tan
      // bağımsız). 500 işlem/batch sınırına karşı parçalı yazım.
      const expireAt = admin.firestore.Timestamp.fromMillis(
          Date.now() + NOTIFICATION_TTL_DAYS * 24 * 3600 * 1000);
      const nowIso = new Date().toISOString();
      for (let i = 0; i < recipientUids.length; i += 450) {
        const batch = db.batch();
        for (const uid of recipientUids.slice(i, i + 450)) {
          batch.set(
              db.collection("users").doc(uid)
                  .collection("notifications").doc(`job_${jobId}`),
              {
                type: "job",
                title,
                body,
                jobId,
                read: false,
                createdAt: nowIso,
                expireAt,
              });
        }
        try {
          await batch.commit();
        } catch (e) {
          logger.warn(`Job ${jobId}: notification batch failed: ${e}`);
        }
      }

      // Alıcıların token'larını topla (token → sahip eşlemesiyle; temizlik
      // için hangi token kimin dizisinde biliniyor olmalı).
      const tokens = [];
      const tokenOwner = new Map();
      for (let i = 0; i < recipientUids.length; i += 100) {
        const refs = recipientUids
            .slice(i, i + 100)
            .map((uid) => db.collection("users").doc(uid));
        const snaps = await db.getAll(...refs);
        snaps.forEach((s) => {
          const list = (s.exists && Array.isArray(s.data().fcmTokens)) ?
            s.data().fcmTokens :
            [];
          list.forEach((t) => {
            if (!tokenOwner.has(t)) {
              tokenOwner.set(t, s.id);
              tokens.push(t);
            }
          });
        });
      }
      if (tokens.length === 0) {
        logger.info(`Job ${jobId}: matching artisans have no tokens`);
        return;
      }

      // FCM multicast en fazla 500 token kabul eder → parça parça gönder.
      const invalidByOwner = new Map(); // uid → [token]
      let success = 0;
      for (let i = 0; i < tokens.length; i += 500) {
        const chunk = tokens.slice(i, i + 500);
        let resp;
        try {
          resp = await admin.messaging().sendEachForMulticast({
            tokens: chunk,
            notification: {title, body},
            data: {type: "job", jobId},
            android: {priority: "high", notification: {sound: "default"}},
            apns: {payload: {aps: {sound: "default", badge: 1}}},
          });
        } catch (e) {
          logger.error(`Job ${jobId}: FCM send failed: ${e}`);
          continue;
        }
        success += resp.successCount;
        resp.responses.forEach((r, j) => {
          if (r.success) return;
          const code = r.error && r.error.code;
          if (code === "messaging/registration-token-not-registered" ||
              code === "messaging/invalid-argument" ||
              code === "messaging/invalid-registration-token") {
            const token = chunk[j];
            const owner = tokenOwner.get(token);
            if (!owner) return;
            if (!invalidByOwner.has(owner)) invalidByOwner.set(owner, []);
            invalidByOwner.get(owner).push(token);
          }
        });
      }

      // Geçersiz token'ları sahiplerinin dizilerinden düş.
      for (const [uid, bad] of invalidByOwner) {
        try {
          await db.collection("users").doc(uid).update({
            fcmTokens: admin.firestore.FieldValue.arrayRemove(...bad),
          });
        } catch (e) {
          logger.warn(`Job ${jobId}: token cleanup skipped for ${uid}: ${e}`);
        }
      }

      logger.info(
          `Job ${jobId} (${category}/${province}): ` +
          `${recipientUids.length} artisan, ${success}/${tokens.length} push ok`,
      );
    },
);

/**
 * İş yaşam döngüsü tetikleyicisi (#tamamlama-mühendisliği):
 *
 * 1) İş `completed`/`rated` durumuna İLK geçtiğinde ustanın profilindeki
 *    `completedJobs` sayacını +1 artırır. Kurallar bu alanı istemciye kapatır;
 *    ayrıca kural gereği `completed` ancak İKİ tarafın onayı da true iken
 *    yazılabildiğinden sayaç şişirilemez.
 *
 * 2) Tek taraf "işi tamamladım" dediğinde (onay bayrakları XOR) ilana
 *    `autoCompleteAt` son tarihini yazar ve KARŞI tarafa push gönderir.
 *    Süre dolunca `autoCompleteJobs` zamanlanmış fonksiyonu işi tamamlar —
 *    "unutulan iş sonsuza dek inProgress kalır" sorunu böyle çözülür.
 *
 * Döngü güvenliği: bu fonksiyonun kendi `autoCompleteAt` yazımı tetiklenmeyi
 * yeniler ama onay bayrakları değişmediği için her iki dal da atlanır.
 */
exports.onJobWritten = onDocumentWritten(
    {document: "jobs/{jobId}", region: REGION},
    async (event) => {
      const before =
        event.data && event.data.before && event.data.before.data();
      const after = event.data && event.data.after && event.data.after.data();
      if (!after) {
        // İlan silindi (kural: sahibi, ustaya bağlanmamış ilanı silebilir).
        // Bağlı teklifleri temizle — ustanın listesinde hayalet kayıt kalmasın.
        // (Teklif silinmesi onOfferWritten'ı tetikler; o da ilan yoksa
        // offerCount güncellemesini zaten atlar.)
        const orphans = await db.collection("offers")
            .where("jobId", "==", event.params.jobId)
            .get();
        if (orphans.empty) return;
        const batch = db.batch();
        orphans.forEach((d) => batch.delete(d.ref));
        await batch.commit();
        logger.info(
            `job ${event.params.jobId} silindi; ${orphans.size} teklif temizlendi`);
        return;
      }
      const jobId = event.params.jobId;

      // 1) completed'a ilk geçiş → completedJobs +1.
      //    `disputed`dan dönüş sayılmaz: disputed→completed yalnızca şikayet
      //    geri çekişiyle olur ve iş completed'dan disputed'a giderken sayaç
      //    zaten artmıştı (çift artış olmasın).
      const doneStates = ["completed", "rated"];
      const wasDone = !!before && doneStates.includes(before.status);
      const isDone = doneStates.includes(after.status);
      const fromDispute = !!before && before.status === "disputed";
      if (!wasDone && !fromDispute && isDone && after.selectedArtisanId) {
        try {
          await db.collection("artisanProfiles")
              .doc(after.selectedArtisanId)
              .update({
                completedJobs: admin.firestore.FieldValue.increment(1),
              });
          logger.info(`completedJobs +1 for ${after.selectedArtisanId}`);
        } catch (e) {
          // Profil yoksa atla (zararsız).
          logger.warn(
              `completedJobs skipped for ${after.selectedArtisanId}: ${e}`);
        }
      }

      // 2) Usta seçildi (open → workerSelected) → seçilen ustaya haber ver.
      //    (Bu ana kadar seçilen usta push almıyordu — eksik bildirimdi.)
      if (before && before.status === "open" &&
          after.status === "workerSelected" && after.selectedArtisanId) {
        const selTitle = "🎉 Bir iş için seçildiniz";
        const selBody = `"${after.title || "İş"}" için müşteri sizi seçti. ` +
          "Detayları sohbetten konuşabilirsiniz.";
        await saveNotification(after.selectedArtisanId, `job_${jobId}`, {
          type: "job",
          title: selTitle,
          body: selBody,
          jobId,
        });
        await sendPushToUid(after.selectedArtisanId, selTitle, selBody,
            {type: "job", jobId});
      }

      // 2b) Şikayet açıldı/geri çekildi → KARŞI tarafa bildirim + push.
      //     (disputed'a geçişte autoCompleteAt varsa zamanlanmış CF onu
      //     "aktif değil" diye kendisi temizler; iş otomatik TAMAMLANMAZ.)
      const wasDisputed = !!before && before.status === "disputed";
      const isDisputed = after.status === "disputed";
      if (!wasDisputed && isDisputed) {
        const raiser = after.disputedBy === "customer" ? "Müşteri" : "Usta";
        const recipient = after.disputedBy === "customer" ?
          after.selectedArtisanId :
          after.customerId;
        if (recipient) {
          const reasonTr = DISPUTE_REASON_TR[after.disputeReason] || "Diğer";
          const dTitle = "⚠️ İşle ilgili sorun bildirildi";
          const dBody = `"${after.title || "İş"}" için ${raiser.toLowerCase()} ` +
            `sorun bildirdi: ${reasonTr}. İş, sorun çözülene dek beklemede.`;
          await saveNotification(recipient, `job_${jobId}`, {
            type: "job",
            title: dTitle,
            body: dBody,
            jobId,
          });
          await sendPushToUid(recipient, dTitle, dBody, {type: "job", jobId});
        }
      }
      // Yönetici hakemliğiyle kapanan anlaşmazlıkta bu genel "geri çekildi"
      // bildirimi atlanır: `adminResolveDispute` her iki tarafa kendi KESİN
      // kararını (iptal / devam) ayrıca bildirir; ayrıca iptalde "kaldığı
      // yerden devam ediyor" mesajı YANLIŞ olurdu.
      if (wasDisputed && !isDisputed && after.adminResolved !== true) {
        const recipient = before.disputedBy === "customer" ?
          after.selectedArtisanId :
          after.customerId;
        if (recipient) {
          const wTitle = "Sorun bildirimi geri çekildi";
          const wBody = `"${after.title || "İş"}" için bildirilen sorun geri ` +
            "çekildi; iş kaldığı yerden devam ediyor.";
          await saveNotification(recipient, `job_${jobId}`, {
            type: "job",
            title: wTitle,
            body: wBody,
            jobId,
          });
          await sendPushToUid(recipient, wTitle, wBody, {type: "job", jobId});
        }
      }

      // 3) Tek taraflı tamamlama onayı YENİ geldi → son tarih + push.
      const custNew = after.customerConfirmedDone === true &&
        !(before && before.customerConfirmedDone === true);
      const artNew = after.artisanConfirmedDone === true &&
        !(before && before.artisanConfirmedDone === true);
      const oneSided = (after.customerConfirmedDone === true) !==
        (after.artisanConfirmedDone === true);
      const active = after.status === "workerSelected" ||
        after.status === "inProgress";
      if ((custNew || artNew) && oneSided && active && !after.autoCompleteAt) {
        const deadline = new Date(
            Date.now() + AUTO_COMPLETE_DAYS * 24 * 3600 * 1000).toISOString();
        await db.collection("jobs").doc(jobId).update({
          autoCompleteAt: deadline,
        });

        const recipient = custNew ? after.selectedArtisanId : after.customerId;
        if (recipient) {
          const cTitle = "İş tamamlama onayınız bekleniyor";
          const cBody = `"${after.title || "İş"}" karşı tarafça tamamlandı ` +
            `olarak işaretlendi. ${AUTO_COMPLETE_DAYS} gün içinde yanıt ` +
            "vermezseniz iş otomatik tamamlanacak.";
          await saveNotification(recipient, `job_${jobId}`, {
            type: "job",
            title: cTitle,
            body: cBody,
            jobId,
          });
          await sendPushToUid(recipient, cTitle, cBody, {type: "job", jobId});
        }
      }
    },
);

/**
 * Süresi dolan tek taraflı onayları kapatır: `autoCompleteAt <= şimdi` olan
 * ilanlardan hâlâ aktif (workerSelected/inProgress) ve tek taraflı onaylı
 * olanları `completed` yapar (onay bayrakları true'ya çekilir; `completedJobs`
 * artışını onJobWritten üstlenir), onay vermemiş tarafa bilgi push'u gönderir.
 * Uygun olmayanların (iptal/zaten tamam) süresi temizlenir.
 *
 * `autoCompleteAt` yalnızca bu dosyadaki CF'lerce UTC ISO string yazılır →
 * tek alanlı aralık sorgusu, composite index gerekmez.
 */
exports.autoCompleteJobs = onSchedule(
    {schedule: "every 6 hours", region: REGION, timeZone: "Europe/Istanbul"},
    async () => {
      const nowIso = new Date().toISOString();
      const snap = await db.collection("jobs")
          .where("autoCompleteAt", "<=", nowIso)
          .limit(300)
          .get();
      if (snap.empty) return;

      let completed = 0;
      for (const d of snap.docs) {
        const j = d.data();
        const oneSided = (j.customerConfirmedDone === true) !==
          (j.artisanConfirmedDone === true);
        const active = j.status === "workerSelected" ||
          j.status === "inProgress";

        if (!(active && oneSided)) {
          // İptal edilmiş/tamamlanmış vb. — bayat son tarihi temizle.
          await d.ref.update({
            autoCompleteAt: admin.firestore.FieldValue.delete(),
          });
          continue;
        }

        await d.ref.update({
          status: "completed",
          customerConfirmedDone: true,
          artisanConfirmedDone: true,
          autoCompletedBySystem: true, // denetim izi
          autoCompleteAt: admin.firestore.FieldValue.delete(),
        });
        completed += 1;

        // Onay vermeyen tarafa bilgi ver (müşteriyse değerlendirme yapabilir).
        const silentParty = j.customerConfirmedDone === true ?
          j.selectedArtisanId :
          j.customerId;
        if (silentParty) {
          const aTitle = "İş otomatik tamamlandı";
          const aBody = `"${j.title || "İş"}", karşı tarafın onayı ve yanıt ` +
            "süresinin dolması nedeniyle tamamlandı olarak işaretlendi.";
          await saveNotification(silentParty, `job_${d.id}`, {
            type: "job",
            title: aTitle,
            body: aBody,
            jobId: d.id,
          });
          await sendPushToUid(silentParty, aTitle, aBody,
              {type: "job", jobId: d.id});
        }
      }
      logger.info(
          `autoCompleteJobs: ${snap.size} aday, ${completed} tamamlandı`);
    },
);

// ---------------------------------------------------------------------------
// Hesap silme (Google Play zorunluluğu + KVKK) — YOL_HARITASI P0-2.
// ---------------------------------------------------------------------------

// Silinen kullanıcının kalan kayıtlarda görünen adı.
const DELETED_USER_NAME = "Silinmiş Kullanıcı";

// Storage'da kullanıcıya ait klasör kökleri (storage.rules allowlist'i ile
// birebir): {klasör}/{uid}/... yolundaki her şey silinir.
const STORAGE_FOLDERS = ["profile", "work", "job", "certificate", "chat"];

/**
 * Kullanıcının hesabını ve kişisel verilerini KALICI olarak siler.
 * Yalnızca oturum sahibi KENDİ hesabını silebilir (uid = auth.uid).
 *
 * Politika (sil / anonimleştir ayrımı):
 *  - users/{uid} (+ private, notifications alt koleksiyonları): SİL.
 *  - artisanProfiles/{uid}: SİL.
 *  - favorites (iki yönde): SİL.
 *  - Verdiği teklifler: SİL (onOfferWritten açık ilanların sayacını yeniden
 *    hesaplar; ilan yoksa zaten atlar).
 *  - Sahibi olduğu ilanlar: bağlanmamış (open/cancelled) → SİL (onJobWritten
 *    tekliflerini temizler); aktif → İPTAL + anonimleştir (karşı tarafa
 *    bildirim); tamamlanmış → adı anonimleştir (kayıt karşı tarafın geçmişi).
 *  - Usta olarak seçildiği AKTİF işler: İPTAL (müşteriye bildirim).
 *  - Yazdığı değerlendirmeler: KALIR, adı anonimleşir (ustanın puanı kazanılmış
 *    veridir, sayaçlar bozulmaz); HAKKINDAKİ değerlendirmeler: SİL (profil yok).
 *  - Sohbetler: karşı tarafta KALIR (WhatsApp modeli); ad/foto anonimleşir.
 *  - Storage {klasör}/{uid}/*: SİL. En son Auth kaydı silinir — böylece bir
 *    adım yarıda kalırsa kullanıcı tekrar deneyebilir.
 */
exports.deleteAccount = onCall(
    {region: REGION, timeoutSeconds: 300},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      logger.info(`deleteAccount başladı: ${uid}`);
      const activeStates = ["workerSelected", "inProgress", "disputed"];

      // 1) Sahibi olduğu ilanlar.
      const myJobs = await db.collection("jobs")
          .where("customerId", "==", uid).get();
      for (const d of myJobs.docs) {
        const j = d.data() || {};
        if (j.status === "open" || j.status === "cancelled") {
          await d.ref.delete(); // onJobWritten teklifleri temizler
        } else if (activeStates.includes(j.status)) {
          await d.ref.update({
            status: "cancelled",
            cancelReason: "Hesap silindi",
            customerName: DELETED_USER_NAME,
          });
          if (j.selectedArtisanId) {
            const t = "İş iptal edildi";
            const b = `"${j.title || "İş"}" ilanının sahibi hesabını ` +
              "sildiği için iş iptal edildi.";
            await saveNotification(j.selectedArtisanId, `job_${d.id}`,
                {type: "job", title: t, body: b, jobId: d.id});
            await sendPushToUid(j.selectedArtisanId, t, b,
                {type: "job", jobId: d.id});
          }
        } else {
          // completed/rated — karşı tarafın iş geçmişi, yalnız ad anonimleşir.
          await d.ref.update({customerName: DELETED_USER_NAME});
        }
      }

      // 2) Usta olarak seçildiği AKTİF işler → iptal + müşteriye bildirim.
      const assigned = await db.collection("jobs")
          .where("selectedArtisanId", "==", uid).get();
      for (const d of assigned.docs) {
        const j = d.data() || {};
        if (!activeStates.includes(j.status)) continue;
        await d.ref.update({
          status: "cancelled",
          cancelReason: "Usta hesabını sildi",
        });
        if (j.customerId) {
          const t = "İş iptal edildi";
          const b = `"${j.title || "İş"}" işindeki usta hesabını sildiği ` +
            "için iş iptal edildi. Dilerseniz ilanı yeniden yayınlayın.";
          await saveNotification(j.customerId, `job_${d.id}`,
              {type: "job", title: t, body: b, jobId: d.id});
          await sendPushToUid(j.customerId, t, b, {type: "job", jobId: d.id});
        }
      }

      // 3) Verdiği teklifler + iki yönlü takip kayıtları → sil.
      const writer = db.bulkWriter();
      const [myOffers, favsOut, favsIn] = await Promise.all([
        db.collection("offers").where("artisanId", "==", uid).get(),
        db.collection("favorites").where("customerUid", "==", uid).get(),
        db.collection("favorites").where("artisanUid", "==", uid).get(),
      ]);
      myOffers.forEach((d) => writer.delete(d.ref));
      favsOut.forEach((d) => writer.delete(d.ref));
      favsIn.forEach((d) => writer.delete(d.ref));

      // 4) Değerlendirmeler: yazdıkları anonim kalır, hakkındakiler silinir
      //    (onReviewWritten profil yoksa toplam güncellemesini zaten atlar).
      const [reviewsBy, reviewsAbout] = await Promise.all([
        db.collection("reviews").where("customerUID", "==", uid).get(),
        db.collection("reviews").where("artisanUID", "==", uid).get(),
      ]);
      reviewsBy.forEach((d) =>
        writer.update(d.ref, {customerDisplayName: DELETED_USER_NAME}));
      reviewsAbout.forEach((d) => writer.delete(d.ref));

      // 5) Sohbetlerde ad/foto anonimleştir (mesajlar karşı tarafta kalır).
      const chats = await db.collection("chats")
          .where(`members.${uid}`, "==", true).get();
      chats.forEach((d) => {
        const c = d.data() || {};
        const asCustomer = c.customerUid === uid;
        writer.update(d.ref, asCustomer ?
          {
            customerName: DELETED_USER_NAME,
            customerPhotoURL: admin.firestore.FieldValue.delete(),
          } :
          {
            artisanName: DELETED_USER_NAME,
            artisanPhotoURL: admin.firestore.FieldValue.delete(),
          });
      });
      await writer.close();

      // 6) Profil dökümanları (users alt koleksiyonlarıyla birlikte).
      await db.recursiveDelete(db.collection("users").doc(uid));
      await db.collection("artisanProfiles").doc(uid).delete();

      // 7) Storage: kullanıcının tüm klasörleri.
      const bucket = admin.storage().bucket();
      for (const folder of STORAGE_FOLDERS) {
        try {
          await bucket.deleteFiles({prefix: `${folder}/${uid}/`});
        } catch (e) {
          logger.warn(`Storage temizliği atlandı (${folder}/${uid}): ${e}`);
        }
      }

      // 8) En son Auth kaydı — buraya kadar geldiyse veri temizlendi.
      await admin.auth().deleteUser(uid);
      logger.info(`deleteAccount tamamlandı: ${uid}`);
      return {ok: true};
    },
);

// ── Yönetici erişimi (bootstrap) ──────────────────────────────────────────
// Çağıran, doğrulanmış e-postası ADMIN_BOOTSTRAP_EMAILS'te ise KENDİSİNE
// `admin:true` custom claim'i yazar. İstemci kendine keyfî yönetici olamaz;
// karar yalnız burada verilir. (Başka kullanıcıları yönetici yapma yeteneği
// ileride admin-only ayrı bir callable ile eklenebilir.)
exports.claimAdminAccess = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      const email = String(auth.token.email || "").toLowerCase();
      const emailVerified = auth.token.email_verified === true;
      if (!emailVerified || !ADMIN_BOOTSTRAP_EMAILS.has(email)) {
        throw new HttpsError(
            "permission-denied", "Bu hesap yönetici olamaz.");
      }
      // RBAC: `admin` (kaba kapı) + `role` (ayrıntılı yetki). Bootstrap
      // her zaman en yüksek rolü (superadmin) verir.
      await admin.auth().setCustomUserClaims(
          auth.uid, {admin: true, role: "superadmin"});
      // Yönetici kadrosu (roster) dokümanı — yalnız yöneticiler okur (kural),
      // yalnız CF yazar. Rol atama ekranı bir kullanıcının mevcut rolünü buradan
      // okur (başka kullanıcının Auth claim'i istemciden görülemez).
      await db.collection("adminRoles").doc(auth.uid).set({
        role: "superadmin",
        updatedBy: auth.uid,
        updatedAt: new Date().toISOString(),
      });
      await writeAuditLog({
        actorUid: auth.uid,
        action: "grant_admin",
        targetType: "user",
        targetId: auth.uid,
        after: {role: "superadmin"},
      });
      logger.info(`admin claim verildi: ${auth.uid} (${email})`);
      return {granted: true, role: "superadmin"};
    },
);

// Süper yönetici, başka bir kullanıcının yönetici rolünü atar/kaldırır (RBAC
// delegasyonu). YALNIZ superadmin çağırabilir. Roller: 'moderator' (şikayet/
// anlaşmazlık/askı) | 'superadmin' (ayrıca rol atama) | 'none' (yetkiyi kaldır).
//
// setCustomUserClaims TÜM claim'leri değiştirdiğinden mevcut `suspended`
// KORUNUR; yalnız admin/role eklenir/çıkarılır. Kendi rolünü değiştiremez
// (kendini kilitleme/yanlışlıkla düşürme). `adminRoles/{uid}` roster dokümanı
// güncellenir/silinir, refresh token'lar iptal edilir (yeni yetki/kayıp kesin
// yansısın), denetim kaydı yazılır.
exports.adminSetRole = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth || auth.token.admin !== true ||
          auth.token.role !== "superadmin") {
        throw new HttpsError(
            "permission-denied", "Süper yönetici yetkisi gerekli.");
      }
      const {uid, role} = request.data || {};
      const valid = ["moderator", "superadmin", "none"];
      if (typeof uid !== "string" || !valid.includes(role)) {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      if (uid === auth.uid) {
        throw new HttpsError(
            "failed-precondition", "Kendi rolünüzü değiştiremezsiniz.");
      }

      let target;
      try {
        target = await admin.auth().getUser(uid);
      } catch (e) {
        throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
      }
      const claims = target.customClaims || {};
      const prevRole = claims.admin === true ? (claims.role || null) : null;

      const newClaims = {...claims};
      if (role === "none") {
        delete newClaims.admin;
        delete newClaims.role;
      } else {
        newClaims.admin = true;
        newClaims.role = role;
      }
      await admin.auth().setCustomUserClaims(uid, newClaims);

      const rosterRef = db.collection("adminRoles").doc(uid);
      if (role === "none") {
        await rosterRef.delete();
      } else {
        await rosterRef.set({
          role,
          updatedBy: auth.uid,
          updatedAt: new Date().toISOString(),
        });
      }

      // Yetki değişimi kesin yansısın (yeni token'da güncel claim).
      try {
        await admin.auth().revokeRefreshTokens(uid);
      } catch (e) {
        logger.warn(`revokeRefreshTokens skipped for ${uid}: ${e}`);
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: role === "none" ? "revoke_admin" : "set_role",
        targetType: "user",
        targetId: uid,
        before: {role: prevRole},
        after: {role: role === "none" ? null : role},
      });
      logger.info(`role ${uid} → ${role} by superadmin ${auth.uid}`);
      return {ok: true, role: role === "none" ? null : role};
    },
);

// Değiştirilemez yönetici denetim kaydı. Her yetkili eylem (rol verme,
// şikayet çözme, ileride askıya alma/iade) buraya atomik yazılır: kim, ne,
// hedef, öncesi/sonrası, ne zaman. Yalnız CF yazar (kural: client write=false),
// yalnız yönetici okur. Hesap verebilirlik + KVKK/GDPR + anlaşmazlık savunması.
async function writeAuditLog(entry, batch) {
  const ref = db.collection("adminAuditLogs").doc();
  const data = {
    actorUid: entry.actorUid,
    action: entry.action,
    targetType: entry.targetType || null,
    targetId: entry.targetId || null,
    before: entry.before || null,
    after: entry.after || null,
    createdAt: new Date().toISOString(),
  };
  if (batch) {
    batch.set(ref, data);
  } else {
    await ref.set(data);
  }
}

// Yönetici bir şikayeti karara bağlar (durum + opsiyonel not). İstemci ARTIK
// reports'a doğrudan YAZAMAZ (kural CF-only'e çevrildi): tüm mutasyon buradan
// geçer → yetki doğrulanır, güncelleme ve denetim kaydı ATOMİK yazılır.
exports.adminResolveReport = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth || auth.token.admin !== true) {
        throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
      }
      const {reportId, status, note} = request.data || {};
      const allowed = ["open", "reviewing", "resolved", "dismissed"];
      if (typeof reportId !== "string" || !allowed.includes(status)) {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      const ref = db.collection("reports").doc(reportId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Şikayet bulunamadı.");
      }
      const before = snap.data() || {};
      const now = new Date().toISOString();
      const update = {
        status,
        resolvedBy: auth.uid,
        resolvedAt: now,
      };
      if (typeof note === "string" && note.trim()) {
        update.adminNote = note.trim();
      }
      // Karara bağlanınca atama düşer (iş bitti; kimin çözdüğü resolvedBy'da).
      if (before.assignedTo) {
        update.assignedTo = admin.firestore.FieldValue.delete();
        update.assignedAt = admin.firestore.FieldValue.delete();
      }
      const batch = db.batch();
      batch.update(ref, update);
      await writeAuditLog({
        actorUid: auth.uid,
        action: "resolve_report",
        targetType: "report",
        targetId: reportId,
        before: {status: before.status || "open"},
        after: {status},
      }, batch);
      await batch.commit();
      logger.info(`report ${reportId} → ${status} (admin ${auth.uid})`);
      return {ok: true};
    },
);

// Yönetici bir şikayeti ÜSTLENİR / bırakır (çoklu-moderatör koordinasyonu:
// iki kişi aynı kaydı işlemesin). `assign:true` → assignedTo = çağıranın uid'i;
// `assign:false` → yalnız ATAYAN kişi (veya herhangi bir yönetici) bırakabilir.
// İstemci reports'a doğrudan yazamaz (kural CF-only) → buradan geçer + audit.
exports.adminAssignReport = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth || auth.token.admin !== true) {
        throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
      }
      const {reportId, assign} = request.data || {};
      if (typeof reportId !== "string" || typeof assign !== "boolean") {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      const ref = db.collection("reports").doc(reportId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Şikayet bulunamadı.");
      }
      const before = snap.data() || {};
      const update = assign ?
        {assignedTo: auth.uid, assignedAt: new Date().toISOString()} :
        {
          assignedTo: admin.firestore.FieldValue.delete(),
          assignedAt: admin.firestore.FieldValue.delete(),
        };

      const batch = db.batch();
      batch.update(ref, update);
      await writeAuditLog({
        actorUid: auth.uid,
        action: assign ? "claim_report" : "release_report",
        targetType: "report",
        targetId: reportId,
        before: {assignedTo: before.assignedTo || null},
        after: {assignedTo: assign ? auth.uid : null},
      }, batch);
      await batch.commit();
      logger.info(
          `report ${reportId} ${assign ? "claimed" : "released"} ` +
          `by ${auth.uid}`);
      return {ok: true};
    },
);

// Yönetici bir anlaşmazlığı (disputed iş) hakemlikle karara bağlar. İki güvenli
// karar (puan/completedJobs muhasebesini bozmadan):
//  - cancel  → iş 'cancelled' (anlaşmazlık haklı; kimse puanlanmaz).
//  - restore → iş `statusBeforeDispute` durumuna döner (yersiz/çözüldü; kaldığı
//    yerden devam). statusBeforeDispute 'completed' ise completedJobs zaten
//    sayılmıştı (onJobWritten `fromDispute` guard'ı çift artışı engeller).
// Her iki durumda anlaşmazlık alanları temizlenir, `adminResolved:true` yazılır
// (onJobWritten'in genel "geri çekildi" bildirimini bastırır), her iki tarafa
// KESİN karar bildirilir ve denetim kaydı ATOMİK yazılır. İstemci `jobs`'a
// doğrudan yazamaz — tüm mutasyon buradan geçer.
exports.adminResolveDispute = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth || auth.token.admin !== true) {
        throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
      }
      const {jobId, decision, note} = request.data || {};
      if (typeof jobId !== "string" ||
          !["cancel", "restore"].includes(decision)) {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      const ref = db.collection("jobs").doc(jobId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "İlan bulunamadı.");
      }
      const job = snap.data() || {};
      if (job.status !== "disputed") {
        throw new HttpsError(
            "failed-precondition", "İlan anlaşmazlık durumunda değil.");
      }

      const del = admin.firestore.FieldValue.delete();
      const restored = job.statusBeforeDispute || "inProgress";
      const newStatus = decision === "cancel" ? "cancelled" : restored;
      const update = {
        status: newStatus,
        adminResolved: true,
        // Anlaşmazlık alanlarını temizle (kayıt hakemlikle kapandı).
        disputedBy: del,
        disputeReason: del,
        disputeNote: del,
        disputedAt: del,
        statusBeforeDispute: del,
      };
      if (decision === "cancel") {
        // Serbest metin: istemci Job.cancelReason enum'u bunu null çözer
        // (zararsız); asıl bağlam bildirimde + denetim kaydında.
        update.cancelReason = "Yönetici kararı";
      }

      const batch = db.batch();
      batch.update(ref, update);
      await writeAuditLog({
        actorUid: auth.uid,
        action: "resolve_dispute",
        targetType: "job",
        targetId: jobId,
        before: {status: "disputed", statusBeforeDispute: restored},
        after: {decision, status: newStatus},
      }, batch);
      await batch.commit();

      // Her iki tarafa KESİN kararı bildir (push + uygulama içi merkez). docId
      // `dispute_{jobId}`: onJobWritten'in `job_{jobId}` kaydıyla çakışmaz.
      const noteSuffix = (typeof note === "string" && note.trim()) ?
        ` Yönetici notu: ${note.trim()}` : "";
      const title = decision === "cancel" ?
        "İş, yönetici kararıyla iptal edildi" :
        "Anlaşmazlık kapatıldı — iş devam ediyor";
      const body = (decision === "cancel" ?
        `"${job.title || "İş"}" için bildirilen sorun sonucunda iş iptal ` +
          "edildi." :
        `"${job.title || "İş"}" için bildirilen sorun kapatıldı; iş kaldığı ` +
          "yerden devam ediyor.") + noteSuffix;

      for (const uid of [job.customerId, job.selectedArtisanId]) {
        if (!uid) continue;
        await saveNotification(uid, `dispute_${jobId}`, {
          type: "job",
          title,
          body,
          jobId,
        });
        await sendPushToUid(uid, title, body, {type: "job", jobId});
      }

      logger.info(
          `dispute ${jobId} → ${decision} (${newStatus}) admin ${auth.uid}`);
      return {ok: true};
    },
);

// Yönetici bir kullanıcıyı askıya alır / geri açar (kötüye kullanım yönetimi).
//
// Zorlama modeli SUNUCUDADIR: `suspended:true` custom claim → Firestore
// kuralları yeni iş/teklif/mesaj/değerlendirme oluşturmayı reddeder (bkz.
// firestore.rules isSuspended()). Ek olarak `users/{uid}.suspended` (bool)
// aynalanır → istemci "hesabınız askıya alındı" kapısını gösterir (herkese
// açık dökümanda YALNIZ bool; askıya alma NEDENİ gizlilik için buraya
// YAZILMAZ, yalnız denetim kaydında tutulur). Askıya alırken refresh token'lar
// iptal edilir (claim yeni oturumda kesin yansır). Kendini veya başka bir
// yöneticiyi askıya alamazsın. setCustomUserClaims TÜM claim'leri değiştirir →
// mevcut admin/role claim'leri KORUNARAK yalnız `suspended` eklenir/çıkarılır.
exports.adminSetUserSuspended = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth || auth.token.admin !== true) {
        throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
      }
      const {uid, suspended, reason} = request.data || {};
      if (typeof uid !== "string" || typeof suspended !== "boolean") {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      if (uid === auth.uid) {
        throw new HttpsError(
            "failed-precondition", "Kendinizi askıya alamazsınız.");
      }

      let target;
      try {
        target = await admin.auth().getUser(uid);
      } catch (e) {
        throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
      }
      const claims = target.customClaims || {};
      if (claims.admin === true) {
        throw new HttpsError(
            "failed-precondition", "Yöneticiler askıya alınamaz.");
      }

      // Mevcut claim'leri koru; yalnız `suspended`'ı ayarla/kaldır.
      const newClaims = {...claims};
      if (suspended) {
        newClaims.suspended = true;
      } else {
        delete newClaims.suspended;
      }
      await admin.auth().setCustomUserClaims(uid, newClaims);

      // Herkese açık `users` dökümanına YALNIZ bool ayna (+ zaman); neden yok.
      const del = admin.firestore.FieldValue.delete();
      await db.collection("users").doc(uid).set(
          suspended ?
            {suspended: true, suspendedAt: new Date().toISOString()} :
            {suspended: del, suspendedAt: del},
          {merge: true});

      // Askıya alırken oturumları geçersiz kıl (claim kesin yansısın).
      if (suspended) {
        try {
          await admin.auth().revokeRefreshTokens(uid);
        } catch (e) {
          logger.warn(`revokeRefreshTokens skipped for ${uid}: ${e}`);
        }
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: suspended ? "suspend_user" : "unsuspend_user",
        targetType: "user",
        targetId: uid,
        before: {suspended: claims.suspended === true},
        // Neden yalnız burada (denetim/hesap verebilirlik) tutulur.
        after: {
          suspended,
          reason: (typeof reason === "string" && reason.trim()) ?
            reason.trim() : null,
        },
      });
      logger.info(
          `user ${uid} suspended=${suspended} by admin ${auth.uid}`);
      return {ok: true, suspended};
    },
);
