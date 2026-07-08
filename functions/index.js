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
//
// Dağıtım: firebase deploy --only functions --project alljob1

const {
  onDocumentCreated,
  onDocumentWritten,
} = require("firebase-functions/v2/firestore");
const {logger} = require("firebase-functions");
const admin = require("firebase-admin");

admin.initializeApp();
const db = admin.firestore();

// Fonksiyonları Firestore veritabanına yakın bölgede çalıştır (gecikme/maliyet).
const REGION = "europe-west1";

/**
 * Yeni bir değerlendirme oluşunca ustanın puan toplamlarını günceller.
 *
 * `reviews` yalnızca create edilir (kurallar update/delete'i engeller), bu
 * yüzden artımlı (increment) güncelleme güvenlidir — tüm reviews'ı yeniden
 * okumaya gerek yok. Ortalama = toplam / adet.
 */
exports.onReviewCreated = onDocumentCreated(
    {document: "reviews/{reviewId}", region: REGION},
    async (event) => {
      const data = event.data && event.data.data();
      if (!data) return;

      const artisanUid = data.artisanUID;
      const rating = Number(data.rating) || 0;
      if (!artisanUid || rating <= 0) return;

      const ref = db.collection("artisanProfiles").doc(artisanUid);
      try {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (!snap.exists) return; // profil yoksa atla
          const cur = snap.data() || {};
          const totalReviews = (Number(cur.totalReviews) || 0) + 1;
          const totalRatingSum = (Number(cur.totalRatingSum) || 0) + rating;
          tx.update(ref, {
            totalReviews,
            totalRatingSum,
            averageRating: totalRatingSum / totalReviews,
          });
        });
        logger.info(`Rating updated for artisan ${artisanUid} (+${rating})`);
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

      // Alıcının token'ları.
      const userSnap = await db.collection("users").doc(recipientUid).get();
      const tokens = (userSnap.exists &&
        Array.isArray(userSnap.data().fcmTokens)) ?
        userSnap.data().fcmTokens :
        [];
      if (tokens.length === 0) return;

      // Bildirim başlığı = gönderenin adı; gövde = mesaj (foto ise etiket).
      const senderName = senderUid === chat.customerUid ?
        chat.customerName :
        chat.artisanName;
      const body = msg.imageHandle ? "📷 Fotoğraf" : (msg.text || "Yeni mesaj");

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
