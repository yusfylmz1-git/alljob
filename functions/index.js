"use strict";

// Ustasından — Cloud Functions (Gen 2, Node 22).
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

// "Hızlı Destek" ilan kategorisi (ayak işleri): yalnız meslek "other"
// (Hızlı Destek) seçen ustalara gider. İstemci: job.dart.
const QUICK_SUPPORT_CATEGORY = "quick_support";

// Yönetici ön-yükleme (bootstrap) izin listesi. Yalnız bu (doğrulanmış)
// e-postalar `claimAdminAccess` ile kendilerine `admin:true` claim'i yazdırabilir.
// İstemci paritesi: lib/features/admin/data/admin_config.dart.
const ADMIN_BOOTSTRAP_EMAILS = new Set([
  "nflx.tr.avs1@gmail.com",
]);

// Varsayılan moderatör yetkileri (istemci AdminCapabilities.defaultModerator
// ile parite — chats/export/staff/audit/config YOK).
const DEFAULT_MODERATOR_CAPABILITIES = Object.freeze([
  "reports.manage",
  "disputes.manage",
  "users.read",
  "users.suspend",
  "jobs.read",
  "jobs.moderate",
  "artisans.read",
  "artisans.moderate",
  "reviews.moderate",
  "stats.read",
]);

const ALL_CAPABILITIES = new Set([
  ...DEFAULT_MODERATOR_CAPABILITIES,
  "chats.read",
  "audit.read",
  "staff.manage",
  "config.manage",
  "export.run",
]);

// "log-only" | "enforce" — Wave 2: enforce (missing field → DEFAULT set).
const CAP_ASSERT_MODE = "enforce";

const INVITE_PENDING_CAP = 20;
const INVITE_DEFAULT_DAYS = 7;

/**
 * Superadmin her zaman geçer. Moderator: roster.capabilities.
 * Alan yok → DEFAULT (enforce) veya full (log-only). Explicit [] → hiç yetki.
 */
async function assertCap(auth, cap) {
  if (!auth || auth.token.admin !== true) {
    throw new HttpsError("permission-denied", "Yönetici yetkisi gerekli.");
  }
  if (auth.token.role === "superadmin") return;
  const snap = await db.collection("adminRoles").doc(auth.uid).get();
  const raw = snap.exists ? snap.data().capabilities : undefined;
  let allowed;
  if (raw === undefined || raw === null) {
    allowed = CAP_ASSERT_MODE === "log-only" ?
      null :
      DEFAULT_MODERATOR_CAPABILITIES;
  } else if (Array.isArray(raw)) {
    allowed = raw;
  } else {
    allowed = [];
  }
  if (allowed === null) return;
  if (!allowed.includes(cap)) {
    if (CAP_ASSERT_MODE === "log-only") {
      logger.warn(`cap miss uid=${auth.uid} need=${cap}`);
      return;
    }
    throw new HttpsError("permission-denied", `Yetki yok: ${cap}`);
  }
}

function assertSuperadmin(auth) {
  if (!auth || auth.token.admin !== true || auth.token.role !== "superadmin") {
    throw new HttpsError(
        "permission-denied", "Süper yönetici yetkisi gerekli.");
  }
}

function validateCapabilities(caps) {
  if (!Array.isArray(caps)) {
    throw new HttpsError("invalid-argument", "capabilities dizi olmalı.");
  }
  const out = [];
  for (const c of caps) {
    if (typeof c !== "string" || !ALL_CAPABILITIES.has(c)) {
      throw new HttpsError("invalid-argument", `Geçersiz yetki: ${c}`);
    }
    if (!out.includes(c)) out.push(c);
  }
  return out;
}

function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase();
}

// ── adminStats (Wave 3 / PR6) ─────────────────────────────────────────────
// Tek döküman KPI: adminStats/global. Yazma yalnız CF; istemci okur.
// Job bucket + report open transition pure helpers (test edilebilir).

/** @param {string|undefined|null} status */
function jobStatsBucket(status) {
  switch (status) {
    case "open":
      return "jobsOpen";
    case "workerSelected":
    case "inProgress":
      return "jobsInProgress";
    case "completed":
    case "rated":
      return "jobsCompleted";
    case "disputed":
      return "jobsDisputed";
    case "cancelled":
    case "expired":
      return "jobsCancelled";
    default:
      return status ? "jobsOther" : null;
  }
}

function isOpenReportStatus(status) {
  return status === "open" || status === "reviewing";
}

/** Pure: before/after job data → increment map (no FieldValue). */
function jobStatsDelta(before, after) {
  const d = {};
  const bump = (k, n) => {
    if (!k || !n) return;
    d[k] = (d[k] || 0) + n;
  };
  if (!before && after) {
    bump(jobStatsBucket(after.status), 1);
    if (after.status === "disputed") bump("openDisputes", 1);
  } else if (before && !after) {
    bump(jobStatsBucket(before.status), -1);
    if (before.status === "disputed") bump("openDisputes", -1);
  } else if (before && after) {
    const b = jobStatsBucket(before.status);
    const a = jobStatsBucket(after.status);
    if (b !== a) {
      bump(b, -1);
      bump(a, 1);
    }
    const wasD = before.status === "disputed";
    const isD = after.status === "disputed";
    if (!wasD && isD) bump("openDisputes", 1);
    if (wasD && !isD) bump("openDisputes", -1);
  }
  return d;
}

/** Pure: report before/after → openReports delta. */
function reportStatsDelta(before, after) {
  const d = {};
  const openB = before ? isOpenReportStatus(before.status) : false;
  const openA = after ? isOpenReportStatus(after.status) : false;
  if (!openB && openA) d.openReports = 1;
  if (openB && !openA) d.openReports = -1;
  return d;
}

async function applyStatsDelta(delta) {
  if (!delta || typeof delta !== "object") return;
  const patch = {};
  for (const [k, v] of Object.entries(delta)) {
    if (typeof v === "number" && v !== 0) {
      patch[k] = admin.firestore.FieldValue.increment(v);
    }
  }
  if (Object.keys(patch).length === 0) return;
  patch.updatedAt = new Date().toISOString();
  await db.collection("adminStats").doc("global").set(patch, {merge: true});
}

function istanbulDayKey(date = new Date()) {
  // en-CA → YYYY-MM-DD
  return date.toLocaleDateString("en-CA", {timeZone: "Europe/Istanbul"});
}

async function bumpDaily(field, n = 1) {
  if (!n) return;
  const day = istanbulDayKey();
  await db.collection("adminStats").doc("daily").collection("days").doc(day)
      .set({
        [field]: admin.firestore.FieldValue.increment(n),
        day,
        updatedAt: new Date().toISOString(),
      }, {merge: true});
}

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
 * FCM token'ları: H2 sonrası `users/{uid}/private/push.fcmTokens`.
 * Legacy: public `users/{uid}.fcmTokens` (okuma + temizlikte her ikisi).
 * Aynı dökümandan prefs okunur (ikinci get yok — getPushDoc).
 */
async function getPushDoc(uid) {
  return db.collection("users").doc(uid)
      .collection("private").doc("push").get();
}

async function getFcmTokens(uid) {
  const pushSnap = await getPushDoc(uid);
  if (pushSnap.exists && Array.isArray(pushSnap.data().fcmTokens) &&
      pushSnap.data().fcmTokens.length > 0) {
    return {tokens: pushSnap.data().fcmTokens, source: "private", snap: pushSnap};
  }
  const userSnap = await db.collection("users").doc(uid).get();
  const legacy = (userSnap.exists && Array.isArray(userSnap.data().fcmTokens)) ?
    userSnap.data().fcmTokens :
    [];
  return {tokens: legacy, source: "public", snap: pushSnap};
}

/**
 * Push tercihleri (`users/{uid}/private/push.prefs`).
 * Eksik alan = true (geriye dönük: eski hesaplar kesilmesin).
 * category: "chat" | "jobUpdates" | "nearbyJobs"
 */
function prefsFromPushSnap(pushSnap) {
  const p = (pushSnap && pushSnap.exists && pushSnap.data().prefs) || {};
  return {
    chat: p.chat !== false,
    jobUpdates: p.jobUpdates !== false,
    nearbyJobs: p.nearbyJobs !== false,
  };
}

async function isPushCategoryAllowed(uid, category, pushSnapOpt) {
  const snap = pushSnapOpt || await getPushDoc(uid);
  const prefs = prefsFromPushSnap(snap);
  if (category === "chat") return prefs.chat;
  if (category === "nearbyJobs") return prefs.nearbyJobs;
  // jobUpdates (varsayılan) + bilinmeyen
  return prefs.jobUpdates;
}

/** data.type / data.kind → tercih kategorisi. */
function pushCategoryFromData(data) {
  const t = data && data.type;
  if (t === "chat") return "chat";
  if (t === "job" && data.kind === "nearby") return "nearbyJobs";
  return "jobUpdates";
}

async function removeInvalidFcmTokens(uid, invalid, sourceHint) {
  if (!invalid || invalid.length === 0) return;
  const remove = admin.firestore.FieldValue.arrayRemove(...invalid);
  try {
    await db.collection("users").doc(uid)
        .collection("private").doc("push")
        .set({fcmTokens: remove}, {merge: true});
  } catch (e) {
    logger.warn(`Token cleanup private ${uid}: ${e}`);
  }
  // Legacy public alan (varsa) — Admin SDK kuralları bypass.
  try {
    await db.collection("users").doc(uid).update({fcmTokens: remove});
  } catch (e) {
    if (sourceHint === "public") {
      logger.warn(`Token cleanup public ${uid}: ${e}`);
    }
  }
}

/**
 * Tek bir kullanıcıya (tüm kayıtlı cihazlarına) push gönderir; kayıtsız/geçersiz
 * token'ları kullanıcının dizisinden temizler (onMessageCreated ile aynı kalıp).
 * Kullanıcı tercihi kapalıysa (prefs) sessizce çıkar — uygulama içi merkez ayrı.
 */
async function sendPushToUid(uid, title, body, data) {
  const {tokens, source, snap} = await getFcmTokens(uid);
  if (tokens.length === 0) return;

  const category = pushCategoryFromData(data || {});
  if (!(await isPushCategoryAllowed(uid, category, snap))) {
    logger.info(`Push skip ${uid} category=${category} (prefs)`);
    return;
  }

  // FCM data değerleri string olmalı; kind istemciye gerekmez ama type/id kalsın.
  const fcmData = {};
  if (data) {
    for (const [k, v] of Object.entries(data)) {
      if (v == null || k === "kind") continue;
      fcmData[k] = String(v);
    }
  }

  let resp;
  try {
    resp = await admin.messaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: fcmData,
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
    await removeInvalidFcmTokens(uid, invalid, source);
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
 * Token'lar `users/{uid}/private/push.fcmTokens` (H2); legacy public fallback.
 * İstemci girişte yazar (bkz. `push_service.dart`). Geçersiz token temizliği
 * private + public.
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

      // Push tercih: chat kapalıysa FCM yok (merkez kaydı yukarıda yazıldı).
      await sendPushToUid(
          recipientUid,
          senderName || "Yeni mesaj",
          body,
          {type: "chat", chatId},
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
      //  - Hızlı Destek: meslek "other" (Hızlı Destek) veya legacy quick_support.
      //  - Klasik: professions array-contains + legacy profession== (birleşik).
      let profileDocs = [];
      if (isQuickSupport) {
        const [byOther, byQs, bySingleOther] = await Promise.all([
          db.collection("artisanProfiles")
              .where("professions", "array-contains", "other")
              .limit(500)
              .get(),
          db.collection("artisanProfiles")
              .where("professions", "array-contains", QUICK_SUPPORT_CATEGORY)
              .limit(500)
              .get(),
          db.collection("artisanProfiles")
              .where("profession", "==", "other")
              .limit(500)
              .get(),
        ]);
        const map = new Map();
        byOther.docs.forEach((d) => map.set(d.id, d));
        byQs.docs.forEach((d) => map.set(d.id, d));
        bySingleOther.docs.forEach((d) => map.set(d.id, d));
        profileDocs = [...map.values()];
      } else {
        const [byArray, bySingle] = await Promise.all([
          db.collection("artisanProfiles")
              .where("professions", "array-contains", category)
              .limit(500)
              .get(),
          db.collection("artisanProfiles")
              .where("profession", "==", category)
              .limit(500)
              .get(),
        ]);
        const map = new Map();
        byArray.docs.forEach((d) => map.set(d.id, d));
        bySingle.docs.forEach((d) => map.set(d.id, d));
        profileDocs = [...map.values()];
      }
      if (profileDocs.length === 0) return;

      // Bölgede hizmet verenler (ilan sahibi hariç). Hızlı Destek: il+İLÇE.
      const jobDistrict = job.district || "";
      const recipientUids = [];
      profileDocs.forEach((d) => {
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

      // Alıcı token'ları (private/push + legacy public) — token→sahip haritası.
      // nearbyJobs tercihi kapalı ustalar atlanır (uygulama içi merkez yukarıda yazıldı).
      const tokens = [];
      const tokenOwner = new Map();
      let prefsSkipped = 0;
      for (const uid of recipientUids) {
        const {tokens: list, snap} = await getFcmTokens(uid);
        if (!(await isPushCategoryAllowed(uid, "nearbyJobs", snap))) {
          prefsSkipped++;
          continue;
        }
        list.forEach((t) => {
          if (!tokenOwner.has(t)) {
            tokenOwner.set(t, uid);
            tokens.push(t);
          }
        });
      }
      if (tokens.length === 0) {
        logger.info(
            `Job ${jobId}: no push tokens ` +
            `(artisans=${recipientUids.length}, prefsSkip=${prefsSkipped})`,
        );
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

      for (const [uid, bad] of invalidByOwner) {
        await removeInvalidFcmTokens(uid, bad, "mixed");
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
      // adminStats: bucket + openDisputes (silme dahil).
      try {
        await applyStatsDelta(jobStatsDelta(before || null, after || null));
        if (!before && after) await bumpDaily("jobsCreated", 1);
      } catch (e) {
        logger.warn(`adminStats job ${event.params.jobId}: ${e}`);
      }
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
          const who = custNew ? "Müşteri" : "Usta";
          const cTitle = custNew ?
            "Usta: müşteri işi onayladı" :
            "Müşteri: usta işi teslim etti";
          const cBody = `"${after.title || "İş"}" — ${who.toLowerCase()} ` +
            `tamamlandı olarak işaretledi. Onayınızı verin; ` +
            `${AUTO_COMPLETE_DAYS} gün içinde yanıt vermezseniz iş ` +
            "otomatik tamamlanır.";
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
          autoCompleteRemindedAt: admin.firestore.FieldValue.delete(),
        });
        completed += 1;

        // Her iki tarafa net bilgi; müşteriye değerlendirme CTA.
        const parties = [j.customerId, j.selectedArtisanId].filter(Boolean);
        for (const uid of parties) {
          const isCustomer = uid === j.customerId;
          const aTitle = "İş otomatik tamamlandı";
          const aBody = isCustomer ?
            `"${j.title || "İş"}" süre dolduğu için tamamlandı. ` +
              "Ustanızı değerlendirmek için ilan detayına gidin." :
            `"${j.title || "İş"}" süre dolduğu için tamamlandı olarak ` +
              "işaretlendi. Teşekkürler.";
          await saveNotification(uid, `job_${d.id}`, {
            type: "job",
            title: aTitle,
            body: aBody,
            jobId: d.id,
          });
          await sendPushToUid(uid, aTitle, aBody,
              {type: "job", jobId: d.id});
        }
      }
      logger.info(
          `autoCompleteJobs: ${snap.size} aday, ${completed} tamamlandı`);
    },
);

/**
 * Tek taraflı onayda son 24 saate giren işler için hatırlatma (gün ~2/3).
 * `autoCompleteRemindedAt` ile bir kez gönderilir.
 */
exports.remindJobAutoComplete = onSchedule(
    {schedule: "every 6 hours", region: REGION, timeZone: "Europe/Istanbul"},
    async () => {
      const now = Date.now();
      const nowIso = new Date(now).toISOString();
      // Son 36 saat içinde bitecek olanlar (hatırlatma penceresi).
      const windowEnd = new Date(now + 36 * 3600 * 1000).toISOString();
      const snap = await db.collection("jobs")
          .where("autoCompleteAt", ">=", nowIso)
          .where("autoCompleteAt", "<=", windowEnd)
          .limit(300)
          .get();
      if (snap.empty) return;

      let sent = 0;
      for (const d of snap.docs) {
        const j = d.data();
        if (j.autoCompleteRemindedAt) continue;
        const oneSided = (j.customerConfirmedDone === true) !==
          (j.artisanConfirmedDone === true);
        const active = j.status === "workerSelected" ||
          j.status === "inProgress";
        if (!(active && oneSided)) continue;

        const recipient = j.customerConfirmedDone === true ?
          j.selectedArtisanId :
          j.customerId;
        if (!recipient) continue;

        const rTitle = "Hatırlatma: onayınız bekleniyor";
        const rBody = `"${j.title || "İş"}" için karşı taraf onayladı. ` +
          "Yakında otomatik tamamlanacak — şimdi onaylayabilir veya " +
          "sorun bildirebilirsiniz.";
        await saveNotification(recipient, `job_${d.id}_reminder`, {
          type: "job",
          title: rTitle,
          body: rBody,
          jobId: d.id,
        });
        await sendPushToUid(recipient, rTitle, rBody,
            {type: "job", jobId: d.id});
        await d.ref.update({
          autoCompleteRemindedAt: new Date().toISOString(),
        });
        sent += 1;
      }
      logger.info(`remindJobAutoComplete: ${snap.size} aday, ${sent} push`);
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
      try {
        await applyStatsDelta({usersTotal: -1});
      } catch (e) {
        logger.warn(`adminStats deleteAccount: ${e}`);
      }
      logger.info(`deleteAccount tamamlandı: ${uid}`);
      return {ok: true};
    },
);

// users create → usersTotal (+ daily). Suspend sayacı CF adminSetUserSuspended.
exports.onUserWritten = onDocumentWritten(
    {document: "users/{uid}", region: REGION},
    async (event) => {
      const before =
        event.data && event.data.before && event.data.before.exists;
      const after =
        event.data && event.data.after && event.data.after.exists;
      try {
        if (!before && after) {
          await applyStatsDelta({usersTotal: 1});
          await bumpDaily("usersCreated", 1);
        } else if (before && !after) {
          // deleteAccount zaten −1 yazar; recursiveDelete burayı da tetikler
          // → çift sayımı önlemek için silmede sayaç YOK (deleteAccount yolu).
        }
      } catch (e) {
        logger.warn(`adminStats user: ${e}`);
      }
    },
);

exports.onArtisanProfileWritten = onDocumentWritten(
    {document: "artisanProfiles/{uid}", region: REGION},
    async (event) => {
      const before =
        event.data && event.data.before && event.data.before.exists;
      const after =
        event.data && event.data.after && event.data.after.exists;
      try {
        if (!before && after) {
          await applyStatsDelta({artisansTotal: 1});
          await bumpDaily("artisansCreated", 1);
        } else if (before && !after) {
          await applyStatsDelta({artisansTotal: -1});
        }
      } catch (e) {
        logger.warn(`adminStats artisan: ${e}`);
      }
    },
);

// openReports tek kaynak: reports onWrite (resolve CF sayaç yazmaz).
exports.onReportWritten = onDocumentWritten(
    {document: "reports/{reportId}", region: REGION},
    async (event) => {
      const before = event.data && event.data.before && event.data.before.exists ?
        event.data.before.data() :
        null;
      const after = event.data && event.data.after && event.data.after.exists ?
        event.data.after.data() :
        null;
      try {
        await applyStatsDelta(reportStatsDelta(before, after));
        if (!before && after) await bumpDaily("reportsCreated", 1);
      } catch (e) {
        logger.warn(`adminStats report: ${e}`);
      }
    },
);

// Superadmin: full scan ile adminStats/global yeniden kur (rate limit 10 dk).
exports.adminRebuildStats = onCall(
    {region: REGION, timeoutSeconds: 300},
    async (request) => {
      assertSuperadmin(request.auth);
      const lockRef = db.collection("adminStats").doc("_rebuildLock");
      const lockSnap = await lockRef.get();
      const last = lockSnap.exists ?
        Date.parse(lockSnap.data().at || "0") :
        0;
      if (last && Date.now() - last < 10 * 60 * 1000) {
        throw new HttpsError(
            "resource-exhausted",
            "Yeniden kurulum en fazla 10 dakikada bir.");
      }
      await lockRef.set({at: new Date().toISOString(), by: request.auth.uid});

      const counts = {
        usersTotal: 0,
        usersSuspended: 0,
        artisansTotal: 0,
        jobsOpen: 0,
        jobsInProgress: 0,
        jobsCompleted: 0,
        jobsDisputed: 0,
        jobsCancelled: 0,
        jobsOther: 0,
        openReports: 0,
        openDisputes: 0,
      };

      // users
      let lastUser = null;
      for (;;) {
        let q = db.collection("users").orderBy(admin.firestore.FieldPath.documentId())
            .limit(400);
        if (lastUser) q = q.startAfter(lastUser);
        const snap = await q.get();
        if (snap.empty) break;
        for (const d of snap.docs) {
          counts.usersTotal++;
          if (d.data().suspended === true) counts.usersSuspended++;
        }
        lastUser = snap.docs[snap.docs.length - 1];
        if (snap.size < 400) break;
      }

      // artisans
      let lastArt = null;
      for (;;) {
        let q = db.collection("artisanProfiles")
            .orderBy(admin.firestore.FieldPath.documentId()).limit(400);
        if (lastArt) q = q.startAfter(lastArt);
        const snap = await q.get();
        if (snap.empty) break;
        counts.artisansTotal += snap.size;
        lastArt = snap.docs[snap.docs.length - 1];
        if (snap.size < 400) break;
      }

      // jobs
      let lastJob = null;
      for (;;) {
        let q = db.collection("jobs")
            .orderBy(admin.firestore.FieldPath.documentId()).limit(400);
        if (lastJob) q = q.startAfter(lastJob);
        const snap = await q.get();
        if (snap.empty) break;
        for (const d of snap.docs) {
          const st = d.data().status;
          const b = jobStatsBucket(st);
          if (b) counts[b] = (counts[b] || 0) + 1;
          if (st === "disputed") counts.openDisputes++;
        }
        lastJob = snap.docs[snap.docs.length - 1];
        if (snap.size < 400) break;
      }

      // reports
      let lastRep = null;
      for (;;) {
        let q = db.collection("reports")
            .orderBy(admin.firestore.FieldPath.documentId()).limit(400);
        if (lastRep) q = q.startAfter(lastRep);
        const snap = await q.get();
        if (snap.empty) break;
        for (const d of snap.docs) {
          if (isOpenReportStatus(d.data().status)) counts.openReports++;
        }
        lastRep = snap.docs[snap.docs.length - 1];
        if (snap.size < 400) break;
      }

      counts.updatedAt = new Date().toISOString();
      counts.rebuiltAt = counts.updatedAt;
      await db.collection("adminStats").doc("global").set(counts);
      await writeAuditLog({
        actorUid: request.auth.uid,
        action: "stats_rebuild",
        targetType: "adminStats",
        targetId: "global",
        after: counts,
      });
      logger.info(`adminRebuildStats by ${request.auth.uid}`, counts);
      return {ok: true, counts};
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
      // Claim MERGE — suspended vb. korunur (K19/K20).
      const userRec = await admin.auth().getUser(auth.uid);
      const prev = userRec.customClaims || {};
      await admin.auth().setCustomUserClaims(auth.uid, {
        ...prev,
        admin: true,
        role: "superadmin",
      });
      await db.collection("adminRoles").doc(auth.uid).set({
        role: "superadmin",
        email,
        updatedBy: auth.uid,
        updatedAt: new Date().toISOString(),
      }, {merge: true});
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
      assertSuperadmin(auth);
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
        // merge:true — capabilities silinmez (K20).
        const patch = {
          role,
          email: (target.email || "").toLowerCase() || null,
          updatedBy: auth.uid,
          updatedAt: new Date().toISOString(),
        };
        if (role === "moderator") {
          const existing = await rosterRef.get();
          const hasCaps = existing.exists &&
            Array.isArray(existing.data().capabilities);
          if (!hasCaps) {
            patch.capabilities = [...DEFAULT_MODERATOR_CAPABILITIES];
          }
        }
        await rosterRef.set(patch, {merge: true});
      }

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

// Superadmin: moderatör capabilities listesini günceller (token revoke YOK).
exports.adminSetCapabilities = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      assertSuperadmin(auth);
      const {uid, capabilities} = request.data || {};
      if (typeof uid !== "string" || !uid.trim()) {
        throw new HttpsError("invalid-argument", "uid gerekli.");
      }
      const caps = validateCapabilities(capabilities);
      const rosterRef = db.collection("adminRoles").doc(uid.trim());
      const snap = await rosterRef.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Kadro kaydı yok.");
      }
      if (snap.data().role === "superadmin") {
        throw new HttpsError(
            "failed-precondition",
            "Süper yönetici yetkileri liste ile kısıtlanmaz.");
      }
      const before = snap.data().capabilities || null;
      await rosterRef.set({
        capabilities: caps,
        updatedBy: auth.uid,
        updatedAt: new Date().toISOString(),
      }, {merge: true});
      await writeAuditLog({
        actorUid: auth.uid,
        action: "set_capabilities",
        targetType: "user",
        targetId: uid.trim(),
        before: {capabilities: before},
        after: {capabilities: caps},
      });
      return {ok: true, capabilities: caps};
    },
);

// Superadmin: e-posta ile moderatör daveti (şifre yok; superadmin davet yasak).
exports.adminCreateInvite = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      assertSuperadmin(auth);
      const email = normalizeEmail(request.data && request.data.email);
      if (!email || !email.includes("@")) {
        throw new HttpsError("invalid-argument", "Geçerli e-posta gerekli.");
      }
      let caps = DEFAULT_MODERATOR_CAPABILITIES;
      if (request.data && request.data.capabilities != null) {
        caps = validateCapabilities(request.data.capabilities);
      }
      // staff.manage vb. superadmin-only cap'leri davetten çıkar.
      caps = caps.filter((c) =>
        !["staff.manage", "config.manage", "export.run", "audit.read"]
            .includes(c));

      const pendingSnap = await db.collection("adminInvites")
          .where("status", "==", "pending")
          .limit(INVITE_PENDING_CAP + 1)
          .get();
      if (pendingSnap.size >= INVITE_PENDING_CAP) {
        throw new HttpsError(
            "resource-exhausted",
            "Bekleyen davet limiti doldu (20).");
      }

      // Aynı e-posta için önceki pending'leri iptal.
      const sameEmail = await db.collection("adminInvites")
          .where("emailNormalized", "==", email)
          .where("status", "==", "pending")
          .get();
      const batch = db.batch();
      for (const d of sameEmail.docs) {
        batch.update(d.ref, {
          status: "revoked",
          updatedAt: new Date().toISOString(),
        });
      }

      const days = Number(request.data && request.data.expiresInDays) ||
          INVITE_DEFAULT_DAYS;
      const expDays = Math.min(Math.max(days, 1), 30);
      const now = new Date();
      const expiresAt = new Date(
          now.getTime() + expDays * 24 * 60 * 60 * 1000).toISOString();
      const ref = db.collection("adminInvites").doc();
      batch.set(ref, {
        email,
        emailNormalized: email,
        role: "moderator",
        capabilities: caps,
        status: "pending",
        createdBy: auth.uid,
        createdAt: now.toISOString(),
        expiresAt,
        acceptedByUid: null,
      });
      await writeAuditLog({
        actorUid: auth.uid,
        action: "invite_create",
        targetType: "invite",
        targetId: ref.id,
        after: {email, capabilities: caps, expiresAt},
      }, batch);
      await batch.commit();
      return {inviteId: ref.id, email, expiresAt};
    },
);

exports.adminRevokeInvite = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      assertSuperadmin(auth);
      const inviteId = request.data && request.data.inviteId;
      if (typeof inviteId !== "string" || !inviteId.trim()) {
        throw new HttpsError("invalid-argument", "inviteId gerekli.");
      }
      const ref = db.collection("adminInvites").doc(inviteId.trim());
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Davet bulunamadı.");
      }
      if (snap.data().status !== "pending") {
        throw new HttpsError(
            "failed-precondition", "Davet zaten kapalı.");
      }
      await ref.update({
        status: "revoked",
        updatedAt: new Date().toISOString(),
      });
      await writeAuditLog({
        actorUid: auth.uid,
        action: "invite_revoke",
        targetType: "invite",
        targetId: inviteId.trim(),
        before: {status: "pending"},
        after: {status: "revoked"},
      });
      return {ok: true};
    },
);

// Doğrulanmış e-posta ile pending daveti kabul et → moderator claim + roster.
exports.adminAcceptInvite = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      const email = normalizeEmail(auth.token.email);
      if (!email || auth.token.email_verified !== true) {
        throw new HttpsError(
            "failed-precondition", "Doğrulanmış e-posta gerekli.");
      }
      if (auth.token.admin === true) {
        throw new HttpsError(
            "failed-precondition",
            "Zaten yönetici. Rol değişimi için superadmin gerekir.");
      }

      const pending = await db.collection("adminInvites")
          .where("emailNormalized", "==", email)
          .where("status", "==", "pending")
          .limit(5)
          .get();
      if (pending.empty) {
        throw new HttpsError("not-found", "Bekleyen davet yok.");
      }
      // En yeni pending.
      const docs = pending.docs.slice().sort((a, b) =>
        String(b.data().createdAt || "").localeCompare(
            String(a.data().createdAt || "")));
      const inv = docs[0];
      const data = inv.data();
      if (data.expiresAt && Date.parse(data.expiresAt) < Date.now()) {
        await inv.ref.update({status: "expired"});
        throw new HttpsError("failed-precondition", "Davetin süresi dolmuş.");
      }

      const userRec = await admin.auth().getUser(auth.uid);
      const prev = userRec.customClaims || {};
      await admin.auth().setCustomUserClaims(auth.uid, {
        ...prev,
        admin: true,
        role: "moderator",
      });

      const caps = Array.isArray(data.capabilities) && data.capabilities.length ?
        data.capabilities :
        [...DEFAULT_MODERATOR_CAPABILITIES];

      await db.collection("adminRoles").doc(auth.uid).set({
        role: "moderator",
        capabilities: caps,
        email,
        updatedBy: auth.uid,
        updatedAt: new Date().toISOString(),
      }, {merge: true});

      await inv.ref.update({
        status: "accepted",
        acceptedByUid: auth.uid,
        acceptedAt: new Date().toISOString(),
      });

      try {
        await admin.auth().revokeRefreshTokens(auth.uid);
      } catch (e) {
        logger.warn(`revokeRefreshTokens invite accept: ${e}`);
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: "invite_accept",
        targetType: "invite",
        targetId: inv.id,
        after: {role: "moderator", capabilities: caps},
      });
      return {granted: true, role: "moderator", capabilities: caps};
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
      await assertCap(auth, "reports.manage");
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
      await assertCap(auth, "reports.manage");
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
      await assertCap(auth, "disputes.manage");
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
// H2: e-posta public users'ta yok → admin arama Auth Admin SDK ile.
// users.read; e-posta yalnız admin paneline döner (audit yok — salt okuma).
exports.adminLookupUser = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "users.read");
      const {uid, email} = request.data || {};
      let record;
      try {
        if (typeof uid === "string" && uid.trim()) {
          record = await admin.auth().getUser(uid.trim());
        } else if (typeof email === "string" && email.trim()) {
          record = await admin.auth().getUserByEmail(normalizeEmail(email));
        } else {
          throw new HttpsError("invalid-argument", "uid veya email gerekli.");
        }
      } catch (e) {
        if (e instanceof HttpsError) throw e;
        throw new HttpsError("not-found", "Kullanıcı bulunamadı.");
      }
      const snap = await db.collection("users").doc(record.uid).get();
      const pub = snap.exists ? (snap.data() || {}) : {};
      return {
        uid: record.uid,
        email: record.email || null,
        emailVerified: record.emailVerified === true,
        displayName: record.displayName || pub.displayName || null,
        suspended: pub.suspended === true ||
          (record.customClaims && record.customClaims.suspended === true),
        hasArtisanProfile: pub.hasArtisanProfile === true,
        createdAt: pub.createdAt || null,
        profilePhotoURL: pub.profilePhotoURL || record.photoURL || null,
      };
    },
);

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
      await assertCap(auth, "users.suspend");
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

      // usersSuspended sayacı: yalnız claim geçişinde (tek kaynak).
      const wasSus = claims.suspended === true;
      if (wasSus !== suspended) {
        try {
          await applyStatsDelta({usersSuspended: suspended ? 1 : -1});
        } catch (e) {
          logger.warn(`adminStats suspend: ${e}`);
        }
      }

      logger.info(
          `user ${uid} suspended=${suspended} by admin ${auth.uid}`);
      return {ok: true, suspended};
    },
);

// ── Wave 4 moderasyon ─────────────────────────────────────────────────────

// İlan gizle / göster / zorla iptal.
exports.adminModerateJob = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "jobs.moderate");
      const {jobId, decision, note} = request.data || {};
      const allowed = ["hide", "unhide", "force_cancel"];
      if (typeof jobId !== "string" || !allowed.includes(decision)) {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      const ref = db.collection("jobs").doc(jobId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "İlan bulunamadı.");
      }
      const before = snap.data() || {};
      const now = new Date().toISOString();
      const update = {
        moderatedBy: auth.uid,
        moderatedAt: now,
      };
      if (decision === "hide") {
        update.moderationHidden = true;
      } else if (decision === "unhide") {
        update.moderationHidden = false;
      } else {
        // force_cancel
        update.status = "cancelled";
        update.cancelReason = "Yönetici kararı";
        update.moderationHidden = true;
        if (typeof note === "string" && note.trim()) {
          update.adminModerationNote = note.trim();
        }
      }
      await ref.update(update);
      await writeAuditLog({
        actorUid: auth.uid,
        action: "moderate_job",
        targetType: "job",
        targetId: jobId,
        before: {
          status: before.status || null,
          moderationHidden: before.moderationHidden === true,
        },
        after: {decision, ...update},
      });

      // M8: force_cancel → taraflara bildirim + push.
      if (decision === "force_cancel") {
        const title = "İlan yönetici tarafından iptal edildi";
        const body = (typeof note === "string" && note.trim()) ?
          note.trim() :
          (before.title || "İlan") + " iptal edildi.";
        const customerId = before.customerId;
        const artisanId = before.selectedArtisanId;
        if (customerId) {
          await saveNotification(customerId, `job_mod_${jobId}`, {
            type: "job",
            title,
            body,
            jobId,
          });
          await sendPushToUid(customerId, title, body, {type: "job", jobId});
        }
        if (artisanId && artisanId !== customerId) {
          await saveNotification(artisanId, `job_mod_${jobId}`, {
            type: "job",
            title,
            body,
            jobId,
          });
          await sendPushToUid(artisanId, title, body, {type: "job", jobId});
        }
      }

      return {ok: true, decision};
    },
);

// Usta bayrakları: adminVerified / featured / moderationHidden.
exports.adminSetArtisanFlags = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "artisans.moderate");
      const {uid, adminVerified, featured, moderationHidden} =
        request.data || {};
      if (typeof uid !== "string" || !uid.trim()) {
        throw new HttpsError("invalid-argument", "uid gerekli.");
      }
      const patch = {};
      if (typeof adminVerified === "boolean") {
        patch.adminVerified = adminVerified;
      }
      if (typeof featured === "boolean") patch.featured = featured;
      if (typeof moderationHidden === "boolean") {
        patch.moderationHidden = moderationHidden;
      }
      if (Object.keys(patch).length === 0) {
        throw new HttpsError("invalid-argument", "En az bir bayrak gerekli.");
      }
      patch.moderatedBy = auth.uid;
      patch.moderatedAt = new Date().toISOString();
      const ref = db.collection("artisanProfiles").doc(uid.trim());
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Usta profili yok.");
      }
      const before = snap.data() || {};
      await ref.set(patch, {merge: true});
      await writeAuditLog({
        actorUid: auth.uid,
        action: "set_artisan_flags",
        targetType: "artisan",
        targetId: uid.trim(),
        before: {
          adminVerified: before.adminVerified === true,
          featured: before.featured === true,
          moderationHidden: before.moderationHidden === true,
        },
        after: patch,
      });
      return {ok: true, ...patch};
    },
);

// Değerlendirme soft-hide (puan toplamı MVP'de değişmez).
exports.adminHideReview = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "reviews.moderate");
      const {reviewId, hidden} = request.data || {};
      if (typeof reviewId !== "string" || typeof hidden !== "boolean") {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      const ref = db.collection("reviews").doc(reviewId);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Değerlendirme yok.");
      }
      await ref.update({
        hiddenByAdmin: hidden,
        moderatedBy: auth.uid,
        moderatedAt: new Date().toISOString(),
      });
      await writeAuditLog({
        actorUid: auth.uid,
        action: "hide_review",
        targetType: "review",
        targetId: reviewId,
        after: {hiddenByAdmin: hidden},
      });
      return {ok: true, hidden};
    },
);

// Sohbet kanıtı — reportId + chatId zorunlu (K18).
exports.adminGetChatTranscript = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "chats.read");
      const {reportId, chatId, limit} = request.data || {};
      if (typeof reportId !== "string" || typeof chatId !== "string" ||
          !reportId.trim() || !chatId.trim()) {
        throw new HttpsError(
            "invalid-argument", "reportId ve chatId zorunlu.");
      }
      const lim = Math.min(
          Math.max(Number(limit) || 100, 1), 100);

      // Rate limit 20 / saat
      const rlRef = db.collection("adminRateLimits").doc(auth.uid);
      const rlSnap = await rlRef.get();
      const now = Date.now();
      const windowMs = 60 * 60 * 1000;
      let hits = [];
      if (rlSnap.exists && Array.isArray(rlSnap.data().transcriptHits)) {
        hits = rlSnap.data().transcriptHits
            .map((t) => Number(t))
            .filter((t) => now - t < windowMs);
      }
      if (hits.length >= 20) {
        throw new HttpsError(
            "resource-exhausted", "Saatlik sohbet okuma limiti (20).");
      }
      hits.push(now);
      await rlRef.set({transcriptHits: hits}, {merge: true});

      const repSnap = await db.collection("reports").doc(reportId.trim()).get();
      if (!repSnap.exists) {
        throw new HttpsError("not-found", "Şikayet bulunamadı.");
      }
      const rep = repSnap.data() || {};
      const st = rep.status || "open";
      const closed = st === "resolved" || st === "dismissed";
      if (closed) {
        const resolvedAt = Date.parse(rep.resolvedAt || "0");
        if (!resolvedAt || now - resolvedAt > 7 * 24 * 60 * 60 * 1000) {
          throw new HttpsError(
              "failed-precondition",
              "Kapalı şikayette 7 günden eski transcript yok.");
        }
      } else if (st !== "open" && st !== "reviewing") {
        throw new HttpsError("failed-precondition", "Şikayet durumu uygun değil.");
      }

      const wantChat = chatId.trim();
      const tt = rep.targetType || "";
      let ok = false;
      if (tt === "message") {
        ok = rep.chatId === wantChat ||
          (typeof rep.targetId === "string" &&
            (rep.targetId === wantChat || rep.targetId.startsWith(wantChat)));
      } else if (tt === "job") {
        const jobSnap = await db.collection("jobs").doc(String(rep.targetId)).get();
        ok = jobSnap.exists && jobSnap.data().chatId === wantChat;
      } else {
        throw new HttpsError(
            "failed-precondition",
            "Kullanıcı şikayetinde sohbet transcript yok.");
      }
      if (!ok) {
        throw new HttpsError(
            "permission-denied", "chatId şikayet bağlamıyla uyuşmuyor.");
      }

      const msgSnap = await db.collection("chats").doc(wantChat)
          .collection("messages")
          .orderBy("createdAt", "asc")
          .limit(lim)
          .get();
      const messages = msgSnap.docs.map((d) => {
        const m = d.data() || {};
        return {
          id: d.id,
          senderUid: m.senderUid || null,
          text: m.deleted === true ? null : (m.text || null),
          imageHandle: m.deleted === true ? null : (m.imageHandle || null),
          deleted: m.deleted === true,
          createdAt: m.createdAt || null,
        };
      });

      await writeAuditLog({
        actorUid: auth.uid,
        action: "get_chat_transcript",
        targetType: "chat",
        targetId: wantChat,
        after: {reportId: reportId.trim(), messageCount: messages.length},
      });
      return {messages, chatId: wantChat, reportId: reportId.trim()};
    },
);

// ── Wave 5 ops ────────────────────────────────────────────────────────────

/** Ops config string alanı (max karakter). */
function pickConfigString(patch, key, maxLen) {
  if (!(key in patch)) return undefined;
  if (patch[key] === null) return null;
  if (typeof patch[key] !== "string") return undefined;
  const v = patch[key].trim();
  if (!v) return null;
  return v.slice(0, maxLen);
}

// Runtime config (adminConfig/runtime) — bayraklar + platform içeriği.
// Yalnız config.manage.
exports.adminUpdateConfig = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "config.manage");
      const patch = request.data || {};
      const ref = db.collection("adminConfig").doc("runtime");
      const snap = await ref.get();
      const before = snap.exists ? (snap.data() || {}) : {};

      const next = {};
      if (typeof patch.premiumFreeDuringBeta === "boolean") {
        next.premiumFreeDuringBeta = patch.premiumFreeDuringBeta;
      }
      if (typeof patch.maintenanceMode === "boolean") {
        next.maintenanceMode = patch.maintenanceMode;
      }
      if (patch.minAppVersion === null) {
        next.minAppVersion = null;
      } else if (typeof patch.minAppVersion === "string") {
        const v = patch.minAppVersion.trim();
        next.minAppVersion = v.length ? v : null;
      }

      // Platform / marka / iletişim (public read — gizli anahtar koyma).
      const strFields = [
        ["appDisplayName", 80],
        ["tagline", 160],
        ["supportEmail", 120],
        ["supportPhone", 40],
        ["playStoreUrl", 300],
        ["appStoreUrl", 300],
        ["websiteUrl", 300],
        ["logoUrl", 500],
        ["aboutShort", 800],
        ["announcementTitle", 120],
        ["announcementBody", 500],
        ["announcementCtaLabel", 40],
        ["announcementCtaUrl", 300],
      ];
      for (const [key, max] of strFields) {
        const v = pickConfigString(patch, key, max);
        if (v !== undefined) next[key] = v;
      }
      if (typeof patch.announcementEnabled === "boolean") {
        next.announcementEnabled = patch.announcementEnabled;
      }

      if (Object.keys(next).length === 0) {
        throw new HttpsError(
            "invalid-argument", "En az bir config alanı gerekli.");
      }
      next.updatedAt = new Date().toISOString();
      next.updatedBy = auth.uid;

      // İlk yazımda bilinmeyen alanlara güvenli varsayılanlar.
      const seed = {
        premiumFreeDuringBeta: true,
        maintenanceMode: false,
        minAppVersion: null,
        announcementEnabled: false,
      };
      await ref.set({...seed, ...before, ...next}, {merge: true});

      await writeAuditLog({
        actorUid: auth.uid,
        action: "update_config",
        targetType: "adminConfig",
        targetId: "runtime",
        before: {
          premiumFreeDuringBeta: before.premiumFreeDuringBeta,
          maintenanceMode: before.maintenanceMode,
          minAppVersion: before.minAppVersion ?? null,
          announcementEnabled: before.announcementEnabled === true,
        },
        after: next,
      });
      return {ok: true, ...next};
    },
);

/**
 * Segment: meslek kodu → usta uid listesi (professions[] + legacy profession).
 */
async function uidsByProfession(code) {
  const c = String(code || "").trim();
  if (!c) return [];
  const set = new Set();
  const a = await db.collection("artisanProfiles")
      .where("professions", "array-contains", c).limit(200).get();
  a.docs.forEach((d) => set.add(d.id));
  const b = await db.collection("artisanProfiles")
      .where("profession", "==", c).limit(200).get();
  b.docs.forEach((d) => set.add(d.id));
  return [...set].slice(0, 300);
}

/**
 * Segment: il → serviceAreaKeys "İl|İlçe" öneki (son 500 profil taraması).
 */
async function uidsByProvince(province) {
  const p = String(province || "").trim();
  if (!p) return [];
  const snap = await db.collection("artisanProfiles")
      .orderBy("createdAt", "desc").limit(500).get();
  const uids = [];
  for (const d of snap.docs) {
    const keys = d.data().serviceAreaKeys;
    const areas = d.data().serviceAreas;
    let ok = false;
    if (Array.isArray(keys)) {
      ok = keys.some((k) => typeof k === "string" &&
        (k === p || k.startsWith(p + "|")));
    }
    if (!ok && Array.isArray(areas)) {
      ok = areas.some((a) => a && a.province === p);
    }
    if (ok) uids.push(d.id);
    if (uids.length >= 300) break;
  }
  return uids;
}

const BROADCAST_AUDIENCES = [
  "all", "artisans", "customers", "profession", "province",
];

/**
 * Kitle → uid listesi (max 300).
 * @return {Promise<string[]>}
 */
async function resolveBroadcastUids(aud, profession, province) {
  if (aud === "profession") {
    return uidsByProfession(profession);
  }
  if (aud === "province") {
    return uidsByProvince(province);
  }
  let q = db.collection("users").orderBy("createdAt", "desc").limit(300);
  if (aud === "artisans") {
    q = db.collection("users")
        .where("hasArtisanProfile", "==", true)
        .orderBy("createdAt", "desc")
        .limit(300);
  } else if (aud === "customers") {
    q = db.collection("users")
        .where("hasArtisanProfile", "==", false)
        .orderBy("createdAt", "desc")
        .limit(300);
  }
  const usersSnap = await q.get();
  return usersSnap.docs.map((d) => d.id);
}

/**
 * Fan-out: in-app + opsiyonel push. Anında veya zamanlanmış kampanya ortak.
 * @return {Promise<{broadcastId: string, recipients: number, inApp: number, pushOk: number}>}
 */
async function executeBroadcastFanout({
  title,
  body,
  audience,
  profession,
  province,
  sendPush,
  actorUid,
  source,
}) {
  const t = String(title || "").trim().slice(0, 120);
  const b = String(body || "").trim().slice(0, 500);
  const aud = audience || "all";
  const doPush = sendPush === true;
  const uids = await resolveBroadcastUids(aud, profession, province);
  const broadcastId = `bc_${Date.now()}_${String(actorUid || "sys").slice(0, 6)}`;
  let inApp = 0;
  let pushOk = 0;

  for (const uid of uids) {
    await saveNotification(uid, broadcastId, {
      type: "system",
      title: t,
      body: b,
      source: source || "admin_broadcast",
      audience: aud,
      profession: profession || null,
      province: province || null,
    });
    inApp++;
    if (doPush) {
      try {
        await sendPushToUid(uid, t, b, {type: "system", broadcastId});
        pushOk++;
      } catch (e) {
        logger.warn(`broadcast push fail ${uid}: ${e}`);
      }
    }
  }

  return {
    broadcastId,
    recipients: uids.length,
    inApp,
    pushOk,
  };
}

function parseBroadcastPayload(data) {
  const patch = data || {};
  if (typeof patch.title !== "string" || !patch.title.trim()) {
    throw new HttpsError("invalid-argument", "title gerekli.");
  }
  if (typeof patch.body !== "string" || !patch.body.trim()) {
    throw new HttpsError("invalid-argument", "body gerekli.");
  }
  const title = patch.title.trim().slice(0, 120);
  const body = patch.body.trim().slice(0, 500);
  const audience = (typeof patch.audience === "string" && patch.audience.trim()) ?
    patch.audience.trim() : "all";
  if (!BROADCAST_AUDIENCES.includes(audience)) {
    throw new HttpsError("invalid-argument", "audience geçersiz.");
  }
  const profession = (typeof patch.profession === "string") ?
    patch.profession.trim() : "";
  const province = (typeof patch.province === "string") ?
    patch.province.trim() : "";
  if (audience === "profession" && !profession) {
    throw new HttpsError("invalid-argument", "profession gerekli.");
  }
  if (audience === "province" && !province) {
    throw new HttpsError("invalid-argument", "province gerekli.");
  }
  return {
    title,
    body,
    audience,
    profession: profession || null,
    province: province || null,
    sendPush: patch.sendPush === true,
  };
}

/**
 * Anında toplu bildirim (+ FCM). Rate: 5 dk / admin.
 */
exports.adminBroadcastNotification = onCall(
    {region: REGION, timeoutSeconds: 120},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "config.manage");
      const payload = parseBroadcastPayload(request.data);

      const rlRef = db.collection("adminRateLimits").doc(
          `broadcast_${auth.uid}`);
      const rlSnap = await rlRef.get();
      const lastMs = rlSnap.exists ?
        Number(rlSnap.data().lastAtMs || 0) : 0;
      if (lastMs && Date.now() - lastMs < 5 * 60 * 1000) {
        throw new HttpsError(
            "resource-exhausted",
            "Toplu bildirim en fazla 5 dakikada bir gönderilebilir.");
      }

      const result = await executeBroadcastFanout({
        ...payload,
        actorUid: auth.uid,
        source: "admin_broadcast",
      });

      if (result.recipients === 0) {
        throw new HttpsError(
            "failed-precondition",
            "Hedef kitlede alıcı bulunamadı.");
      }

      await rlRef.set({
        lastAtMs: Date.now(),
        lastAudience: payload.audience,
        lastCount: result.recipients,
      }, {merge: true});

      await writeAuditLog({
        actorUid: auth.uid,
        action: "broadcast_notification",
        targetType: "broadcast",
        targetId: result.broadcastId,
        after: {
          ...payload,
          recipients: result.recipients,
          inApp: result.inApp,
          pushAttempted: result.pushOk,
        },
      });

      return {
        ok: true,
        broadcastId: result.broadcastId,
        recipients: result.recipients,
        inApp: result.inApp,
        push: payload.sendPush,
      };
    },
);

/**
 * Zamanlanmış kampanya oluştur (pending).
 * scheduledAt: ISO string, en az ~2 dk sonrası.
 */
exports.adminScheduleCampaign = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "config.manage");
      const payload = parseBroadcastPayload(request.data);
      const rawWhen = request.data && request.data.scheduledAt;
      if (typeof rawWhen !== "string" || !rawWhen.trim()) {
        throw new HttpsError("invalid-argument", "scheduledAt (ISO) gerekli.");
      }
      const when = new Date(rawWhen.trim());
      if (Number.isNaN(when.getTime())) {
        throw new HttpsError("invalid-argument", "scheduledAt geçersiz.");
      }
      const minMs = Date.now() + 2 * 60 * 1000;
      if (when.getTime() < minMs) {
        throw new HttpsError(
            "invalid-argument",
            "Zamanlama en az 2 dakika sonrası olmalı.");
      }
      // Max 90 gün ileri
      if (when.getTime() > Date.now() + 90 * 24 * 60 * 60 * 1000) {
        throw new HttpsError(
            "invalid-argument",
            "En fazla 90 gün ileri planlanabilir.");
      }

      const ref = await db.collection("scheduledCampaigns").add({
        ...payload,
        status: "pending",
        scheduledAt: when.toISOString(),
        scheduledAtMs: when.getTime(),
        createdBy: auth.uid,
        createdAt: new Date().toISOString(),
        processedAt: null,
        result: null,
        error: null,
      });

      await writeAuditLog({
        actorUid: auth.uid,
        action: "schedule_campaign",
        targetType: "scheduledCampaign",
        targetId: ref.id,
        after: {
          ...payload,
          scheduledAt: when.toISOString(),
        },
      });

      return {
        ok: true,
        campaignId: ref.id,
        scheduledAt: when.toISOString(),
      };
    },
);

/**
 * Bekleyen kampanyayı iptal et.
 */
exports.adminCancelCampaign = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "config.manage");
      const id = request.data && request.data.campaignId;
      if (typeof id !== "string" || !id.trim()) {
        throw new HttpsError("invalid-argument", "campaignId gerekli.");
      }
      const ref = db.collection("scheduledCampaigns").doc(id.trim());
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Kampanya yok.");
      }
      const data = snap.data() || {};
      if (data.status !== "pending") {
        throw new HttpsError(
            "failed-precondition",
            "Yalnız bekleyen kampanya iptal edilebilir (status=" +
            data.status + ").");
      }
      await ref.set({
        status: "cancelled",
        cancelledAt: new Date().toISOString(),
        cancelledBy: auth.uid,
      }, {merge: true});

      await writeAuditLog({
        actorUid: auth.uid,
        action: "cancel_campaign",
        targetType: "scheduledCampaign",
        targetId: id.trim(),
        before: {status: "pending"},
        after: {status: "cancelled"},
      });
      return {ok: true, campaignId: id.trim()};
    },
);

/**
 * Vakti gelen pending kampanyaları işler (her 5 dk).
 * Aynı anda max 3 kampanya; kilit için status → processing.
 */
exports.processScheduledCampaigns = onSchedule(
    {
      schedule: "every 5 minutes",
      region: REGION,
      timeZone: "Europe/Istanbul",
      timeoutSeconds: 300,
    },
    async () => {
      const nowMs = Date.now();
      let snap;
      try {
        snap = await db.collection("scheduledCampaigns")
            .where("status", "==", "pending")
            .where("scheduledAtMs", "<=", nowMs)
            .orderBy("scheduledAtMs", "asc")
            .limit(3)
            .get();
      } catch (e) {
        logger.error("processScheduledCampaigns query failed", e);
        return;
      }
      if (snap.empty) return;

      for (const doc of snap.docs) {
        // Optimistic lock
        try {
          await db.runTransaction(async (tx) => {
            const fresh = await tx.get(doc.ref);
            if (!fresh.exists || fresh.data().status !== "pending") return;
            tx.update(doc.ref, {
              status: "processing",
              processingAt: new Date().toISOString(),
            });
          });
        } catch (e) {
          logger.warn(`campaign lock skip ${doc.id}: ${e}`);
          continue;
        }

        const c = (await doc.ref.get()).data() || {};
        if (c.status !== "processing") continue;

        try {
          const result = await executeBroadcastFanout({
            title: c.title,
            body: c.body,
            audience: c.audience || "all",
            profession: c.profession,
            province: c.province,
            sendPush: c.sendPush === true,
            actorUid: c.createdBy || "scheduler",
            source: "scheduled_campaign",
          });
          await doc.ref.set({
            status: "sent",
            processedAt: new Date().toISOString(),
            result: {
              broadcastId: result.broadcastId,
              recipients: result.recipients,
              inApp: result.inApp,
              pushOk: result.pushOk,
            },
            error: null,
          }, {merge: true});

          await writeAuditLog({
            actorUid: c.createdBy || "scheduler",
            action: "campaign_sent",
            targetType: "scheduledCampaign",
            targetId: doc.id,
            after: result,
          });
        } catch (e) {
          logger.error(`campaign send fail ${doc.id}: ${e}`);
          await doc.ref.set({
            status: "failed",
            processedAt: new Date().toISOString(),
            error: String(e && e.message ? e.message : e).slice(0, 500),
          }, {merge: true});
        }
      }
    },
);

/**
 * Kullanıcı destek talebi oluşturur.
 */
exports.createSupportTicket = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      if (auth.token.suspended === true) {
        throw new HttpsError("permission-denied", "Hesap askıda.");
      }
      const {subject, body, category} = request.data || {};
      if (typeof subject !== "string" || subject.trim().length < 3) {
        throw new HttpsError("invalid-argument", "Konu en az 3 karakter.");
      }
      if (typeof body !== "string" || body.trim().length < 10) {
        throw new HttpsError("invalid-argument", "Mesaj en az 10 karakter.");
      }
      const cat = (typeof category === "string" && category.trim()) ?
        category.trim().slice(0, 40) : "general";
      const email = (auth.token.email && String(auth.token.email)) || null;
      const ref = await db.collection("supportTickets").add({
        uid: auth.uid,
        email,
        subject: subject.trim().slice(0, 120),
        body: body.trim().slice(0, 2000),
        category: cat,
        status: "open",
        adminNote: null,
        resolvedBy: null,
        resolvedAt: null,
        createdAt: new Date().toISOString(),
        updatedAt: new Date().toISOString(),
      });
      return {ok: true, ticketId: ref.id};
    },
);

/**
 * Destek talebi güncelle (admin): status open|in_progress|resolved|closed + not.
 */
exports.adminUpdateSupportTicket = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "reports.manage");
      const {ticketId, status, adminNote} = request.data || {};
      if (typeof ticketId !== "string" || !ticketId.trim()) {
        throw new HttpsError("invalid-argument", "ticketId gerekli.");
      }
      const allowed = ["open", "in_progress", "resolved", "closed"];
      if (typeof status !== "string" || !allowed.includes(status)) {
        throw new HttpsError("invalid-argument", "status geçersiz.");
      }
      const id = ticketId.trim();
      const ref = db.collection("supportTickets").doc(id);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Talep bulunamadı.");
      }
      const before = snap.data() || {};
      const patch = {
        status,
        updatedAt: new Date().toISOString(),
      };
      if (typeof adminNote === "string") {
        patch.adminNote = adminNote.trim().slice(0, 1000) || null;
      }
      if (status === "resolved" || status === "closed") {
        patch.resolvedBy = auth.uid;
        patch.resolvedAt = new Date().toISOString();
      }
      await ref.set(patch, {merge: true});

      // Kullanıcıya bilgi
      if (before.uid) {
        await saveNotification(before.uid, `support_${id}`, {
          type: "system",
          title: "Destek talebiniz güncellendi",
          body: status === "resolved" || status === "closed" ?
            "Talebiniz kapatıldı. Teşekkürler." :
            "Destek ekibimiz talebinizi inceliyor.",
          ticketId: id,
        });
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: "support_ticket_update",
        targetType: "supportTicket",
        targetId: id,
        before: {status: before.status},
        after: patch,
      });
      return {ok: true, ticketId: id, status};
    },
);

// Toplu askıya alma — max 25; her hedef için ayrı audit (per-uid).
exports.adminBulkSuspend = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "users.suspend");
      const {uids, suspended, reason} = request.data || {};
      if (!Array.isArray(uids) || typeof suspended !== "boolean") {
        throw new HttpsError("invalid-argument", "Geçersiz istek.");
      }
      if (uids.length === 0 || uids.length > 25) {
        throw new HttpsError(
            "invalid-argument", "uids 1–25 arasında olmalı.");
      }
      const reasonStr = (typeof reason === "string" && reason.trim()) ?
        reason.trim() : null;
      const results = [];

      for (const raw of uids) {
        if (typeof raw !== "string" || !raw.trim()) {
          results.push({uid: raw, ok: false, error: "invalid-uid"});
          continue;
        }
        const uid = raw.trim();
        if (uid === auth.uid) {
          results.push({uid, ok: false, error: "self"});
          continue;
        }
        try {
          let target;
          try {
            target = await admin.auth().getUser(uid);
          } catch (e) {
            results.push({uid, ok: false, error: "not-found"});
            continue;
          }
          const claims = target.customClaims || {};
          if (claims.admin === true) {
            results.push({uid, ok: false, error: "is-admin"});
            continue;
          }
          const newClaims = {...claims};
          if (suspended) {
            newClaims.suspended = true;
          } else {
            delete newClaims.suspended;
          }
          await admin.auth().setCustomUserClaims(uid, newClaims);

          const del = admin.firestore.FieldValue.delete();
          await db.collection("users").doc(uid).set(
              suspended ?
                {suspended: true, suspendedAt: new Date().toISOString()} :
                {suspended: del, suspendedAt: del},
              {merge: true});

          if (suspended) {
            try {
              await admin.auth().revokeRefreshTokens(uid);
            } catch (e) {
              logger.warn(`bulk revokeRefreshTokens ${uid}: ${e}`);
            }
          }

          await writeAuditLog({
            actorUid: auth.uid,
            action: suspended ? "suspend_user" : "unsuspend_user",
            targetType: "user",
            targetId: uid,
            before: {suspended: claims.suspended === true},
            after: {suspended, reason: reasonStr, bulk: true},
          });

          const wasSus = claims.suspended === true;
          if (wasSus !== suspended) {
            try {
              await applyStatsDelta({usersSuspended: suspended ? 1 : -1});
            } catch (e) {
              logger.warn(`adminStats bulk suspend: ${e}`);
            }
          }
          results.push({uid, ok: true, suspended});
        } catch (e) {
          logger.error(`bulkSuspend ${uid}: ${e}`);
          results.push({uid, ok: false, error: "internal"});
        }
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: "bulk_suspend",
        targetType: "user",
        targetId: "batch",
        after: {
          suspended,
          reason: reasonStr,
          count: uids.length,
          okCount: results.filter((r) => r.ok).length,
        },
      });

      return {results};
    },
);

// İstemci CSV dışa aktarım denetimi (satır verisi sunucuya gelmez).
exports.adminLogExport = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "export.run");
      const {kind, rowCount} = request.data || {};
      const k = typeof kind === "string" ? kind.trim().slice(0, 40) : "unknown";
      const n = Math.max(0, Math.min(Number(rowCount) || 0, 50000));
      await writeAuditLog({
        actorUid: auth.uid,
        action: "export_run",
        targetType: "export",
        targetId: k,
        after: {kind: k, rowCount: n},
      });
      return {ok: true};
    },
);

// ---------------------------------------------------------------------------
// Play Billing — abonelik doğrulama + isPremium sunucu yazımı
// ---------------------------------------------------------------------------
//
// Kurulum (bir kez):
// 1) Play Console → Monetization → Subscriptions: usta_cepte_pro_monthly
// 2) Google Cloud → IAM: Cloud Functions runtime SA'ya
//    "Service Account User" + Play tarafında erişim (aşağı)
// 3) Play Console → Users and permissions → Invite users →
//    service account e-postası (…@appspot.gserviceaccount.com veya
//    …@….iam.gserviceaccount.com) → "View financial data" +
//    "Manage orders and subscriptions"
// 4) İstemci: billing_config.dart → kBillingEnabled = true
// 5) firebase deploy --only functions:verifyMembershipPurchase
//
// googleapis, Application Default Credentials (CF runtime SA) kullanır.

const {google} = require("googleapis");
const crypto = require("crypto");

const PLAY_PACKAGE_NAME = "com.ustacepte.usta_cepte";
const ALLOWED_PRODUCT_IDS = new Set([
  "usta_cepte_pro_monthly",
  "usta_cepte_pro_yearly",
]);

/** Abonelik hâlâ hak tanır (bitiş tarihi gelecekteyse). */
const GRANT_SUB_STATES = new Set([
  "SUBSCRIPTION_STATE_ACTIVE",
  "SUBSCRIPTION_STATE_IN_GRACE_PERIOD",
  "SUBSCRIPTION_STATE_CANCELED",
]);

/**
 * @return {Promise<import("googleapis").androidpublisher_v3.Androidpublisher>}
 */
async function getAndroidPublisherClient() {
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  return google.androidpublisher({version: "v3", auth});
}

/**
 * Play Developer API ile aboneliği doğrular.
 * @return {Promise<{ok: boolean, productId: string, expiry: Date|null, state: string, reason?: string}>}
 */
async function verifyPlaySubscription({productId, purchaseToken}) {
  const androidpublisher = await getAndroidPublisherClient();

  // 1) subscriptionsv2 (tercih)
  try {
    const res = await androidpublisher.purchases.subscriptionsv2.get({
      packageName: PLAY_PACKAGE_NAME,
      token: purchaseToken,
    });
    const data = res.data || {};
    const state = String(data.subscriptionState || "");
    const lineItems = Array.isArray(data.lineItems) ? data.lineItems : [];
    let item = lineItems.find((li) => li && li.productId === productId);
    if (!item && lineItems.length === 1) item = lineItems[0];
    if (!item) {
      return {
        ok: false,
        productId,
        expiry: null,
        state,
        reason: "line_item_missing",
      };
    }
    const resolvedId = String(item.productId || productId);
    if (!ALLOWED_PRODUCT_IDS.has(resolvedId)) {
      return {
        ok: false,
        productId: resolvedId,
        expiry: null,
        state,
        reason: "unknown_product",
      };
    }
    const expiryMs = item.expiryTime ? Date.parse(item.expiryTime) : NaN;
    const expiry = Number.isFinite(expiryMs) ? new Date(expiryMs) : null;
    if (!expiry || expiry.getTime() <= Date.now()) {
      return {
        ok: false,
        productId: resolvedId,
        expiry,
        state,
        reason: "expired",
      };
    }
    if (!GRANT_SUB_STATES.has(state)) {
      return {
        ok: false,
        productId: resolvedId,
        expiry,
        state,
        reason: state || "inactive",
      };
    }
    return {ok: true, productId: resolvedId, expiry, state};
  } catch (err) {
    const code = err && (err.code || err.status);
    logger.warn("subscriptionsv2 failed, trying v1", {
      code,
      message: err && err.message,
    });
  }

  // 2) v1 purchases.subscriptions.get (eski token / API)
  try {
    const res = await androidpublisher.purchases.subscriptions.get({
      packageName: PLAY_PACKAGE_NAME,
      subscriptionId: productId,
      token: purchaseToken,
    });
    const data = res.data || {};
    const expiryMs = data.expiryTimeMillis
      ? Number(data.expiryTimeMillis)
      : NaN;
    const expiry = Number.isFinite(expiryMs) ? new Date(expiryMs) : null;
    // paymentState: 1 = received, 2 = free trial, 3 = pending deferred
    const paymentState = data.paymentState;
    const cancelReason = data.cancelReason;
    if (!expiry || expiry.getTime() <= Date.now()) {
      return {
        ok: false,
        productId,
        expiry,
        state: "v1_expired",
        reason: "expired",
      };
    }
    // 0 = payment pending — henüz hak yok
    if (paymentState === 0) {
      return {
        ok: false,
        productId,
        expiry,
        state: "v1_pending",
        reason: "payment_pending",
      };
    }
    // İptal edilmiş ama süre bitmemiş → hâlâ ok
    void cancelReason;
    return {
      ok: true,
      productId,
      expiry,
      state: "v1_active",
    };
  } catch (err) {
    const msg = (err && err.message) || String(err);
    logger.error("Play API verify failed", {message: msg});
    // 401/403 genelde SA yetkisi / Play bağlantısı
    if (/insufficient|permission|403|401|login/i.test(msg)) {
      throw new HttpsError(
          "failed-precondition",
          "Play abonelik API yetkisi yok. Cloud Functions servis hesabını "
          + "Play Console → Users and permissions ile davet edin "
          + "(View financial data + Manage orders and subscriptions).",
      );
    }
    throw new HttpsError(
        "internal",
        "Play doğrulama başarısız. Daha sonra tekrar deneyin.",
    );
  }
}

/**
 * Sunucu tarafı premium alanlarını yazar (istemci yazamaz — rules guard).
 */
async function grantArtisanPremium(uid, {
  productId,
  expiry,
  purchaseToken,
  playState,
}) {
  const expiresAt = expiry instanceof Date
    ? expiry
    : new Date(Date.now() + 32 * 24 * 60 * 60 * 1000);
  const tokenHash = crypto
      .createHash("sha256")
      .update(String(purchaseToken))
      .digest("hex")
      .slice(0, 32);

  const premiumPatch = {
    isPremium: true,
    premiumExpiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    premiumProductId: productId,
    premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
  };

  // Profil yoksa bile merge ile açılabilir; müsaitlik alanlarına dokunma.
  await db.collection("artisanProfiles").doc(uid).set(premiumPatch, {
    merge: true,
  });

  await db.collection("membershipPurchases").doc(uid).set({
    uid,
    productId,
    tokenHash,
    // Yenileme / RTDN için token saklanır (yalnız Admin SDK okur).
    purchaseToken: String(purchaseToken),
    playState: playState || null,
    expiresAt: admin.firestore.Timestamp.fromDate(expiresAt),
    packageName: PLAY_PACKAGE_NAME,
    updatedAt: admin.firestore.FieldValue.serverTimestamp(),
  }, {merge: true});
}

/**
 * Play abonelik doğrulama (üretim).
 *
 * İstemci: billing_service.dart → productId + purchaseToken.
 * Başarı: artisanProfiles.isPremium + premiumExpiresAt (yalnız sunucu).
 */
exports.verifyMembershipPurchase = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      const {productId, purchaseToken, source} = request.data || {};
      if (typeof productId !== "string" || !productId.trim()) {
        throw new HttpsError("invalid-argument", "productId gerekli.");
      }
      const pid = productId.trim();
      if (!ALLOWED_PRODUCT_IDS.has(pid)) {
        throw new HttpsError(
            "invalid-argument",
            "Desteklenmeyen ürün kimliği.",
        );
      }
      if (typeof purchaseToken !== "string" || purchaseToken.length < 8) {
        throw new HttpsError("invalid-argument", "purchaseToken gerekli.");
      }

      // iOS / storekit şimdilik yok
      if (source && String(source).toLowerCase().includes("app_store")) {
        throw new HttpsError(
            "failed-precondition",
            "App Store aboneliği henüz desteklenmiyor.",
        );
      }

      const verified = await verifyPlaySubscription({
        productId: pid,
        purchaseToken,
      });

      if (!verified.ok) {
        logger.info("verifyMembershipPurchase rejected", {
          uid: auth.uid,
          productId: pid,
          reason: verified.reason,
          state: verified.state,
        });
        // Premium'u kapat (süresi dolmuş restore denemesi)
        if (verified.reason === "expired") {
          await db.collection("artisanProfiles").doc(auth.uid).set({
            isPremium: false,
            premiumExpiresAt: verified.expiry
              ? admin.firestore.Timestamp.fromDate(verified.expiry)
              : admin.firestore.FieldValue.delete(),
            premiumUpdatedAt: admin.firestore.FieldValue.serverTimestamp(),
          }, {merge: true});
        }
        throw new HttpsError(
            "failed-precondition",
            verified.reason === "expired"
              ? "Abonelik süresi dolmuş."
              : "Abonelik aktif değil (" + (verified.reason || "inactive") + ").",
        );
      }

      await grantArtisanPremium(auth.uid, {
        productId: verified.productId,
        expiry: verified.expiry,
        purchaseToken,
        playState: verified.state,
      });

      logger.info("verifyMembershipPurchase ok", {
        uid: auth.uid,
        productId: verified.productId,
        expiry: verified.expiry && verified.expiry.toISOString(),
        state: verified.state,
      });

      return {
        ok: true,
        productId: verified.productId,
        expiresAt: verified.expiry
          ? verified.expiry.toISOString()
          : null,
        state: verified.state,
      };
    },
);
