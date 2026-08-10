"use strict";

// Ustasından — Cloud Functions (Gen 2, Node 22).
//
// Amaç: istemci-tarafı "geçici çözümleri" sunucuya taşımak + push bildirimleri:
//  1) Puan (rating) toplamlarını `artisanProfiles` üzerine denormalize et →
//     müşteri araması artık her seferinde `reviews` koleksiyonunu TARAMAZ.
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
// DIKKAT: "firebase-functions/v2" (kok) import'u TUM v2 agacini ceker; icinde
// database saglayicisi @firebase/app peer'ini ister ve cozulemeyip cold start'ta
// patlar. setGlobalOptions zaten kendi alt yolunda -> yalniz onu al.
const {setGlobalOptions} = require("firebase-functions/v2/options");
// firebase-functions v7: logger artik kok export'ta DEGIL, kendi alt yolunda.
const logger = require("firebase-functions/logger");
// firebase-admin v14: eski namespace API'si (admin.firestore / admin.auth)
// KALDIRILDI; modul alt yollari kullanilir.
const {initializeApp} = require("firebase-admin/app");
const {
  getFirestore,
  FieldValue,
  FieldPath,
  Timestamp,
} = require("firebase-admin/firestore");
const {getAuth} = require("firebase-admin/auth");
const {getStorage} = require("firebase-admin/storage");
const {getMessaging} = require("firebase-admin/messaging");

initializeApp();
const db = getFirestore();

// Maliyet emniyeti: istismar/sonsuz döngü durumunda fonksiyonlar sınırsız
// ölçeklenmesin (Gen2 varsayılan tavanı 100 örnek). Bu ölçekte 10 örnek
// fazlasıyla yeter; yük artarsa istekler kuyrukta bekler, fatura patlamaz.
setGlobalOptions({maxInstances: 10});

// Fonksiyonları Firestore veritabanına yakın bölgede çalıştır (gecikme/maliyet).
const REGION = "europe-west1";

// App Check zorlaması YALNIZ tüketici (mobil) çağrılarında: mobil istemci
// jetonu otomatik gönderir (main.dart activate). admin* callable'ları web
// panelinden çağrılır ve web'de App Check reCAPTCHA anahtarı henüz yok —
// onlara eklenirse panel kilitlenir (yetki zaten admin claim + assertCap'te).
const CONSUMER_CALL_OPTS = {region: REGION, enforceAppCheck: true};

// Tek taraf "işi tamamladım" dedikten sonra karşı tarafın yanıt süresi (gün).
// Mock paritesi: mock_job_repository.confirmDone aynı sayıyı kullanır.
const AUTO_COMPLETE_DAYS = 3;

// "Hemen Lazım" ilan kategorisi: market/taşıma/kısa gidiş gibi kısa işler.
// Yalnız Hemen Lazım hizmeti açık ("other") ustalara, İL düzeyinde gider.
// İstemci paritesi: job.dart (Job.matchesArtisan).
const QUICK_SUPPORT_CATEGORY = "quick_support";

// Ürün talebi kategorisi (Mağaza > İlan Ver). İstemci paritesi:
// lib/data/models/job.dart kProductRequestCategory.
//
// Bu kategori USTA fan-out'una girmez; alıcısı satıcılardır ve bildirim
// anlık değil GÜNLÜK ÖZET olarak gider (sendProductRequestDigest).
const PRODUCT_REQUEST_CATEGORY = "product_request";

// İş sonu değerlendirmesindeki OLUMLU etiketler. Yalnız bunlar usta
// profilinde tagCounts/topTags olarak birikir (kart rozetleri). Olumsuz
// etiketler sayaca girmez. İstemci paritesi: lib/data/models/review.dart
// → ReviewTags.positive (bu liste onunla birebir senkron tutulmalıdır).
const POSITIVE_REVIEW_TAGS = new Set([
  "Temiz işçilik",
  "Zamanında geldi",
  "Profesyonel",
  "Güler yüzlü",
  "Hızlı çözüm",
  "Kaliteli işçilik",
  "Güvenilir",
  "Uygun fiyat",
]);

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
  "users.read",
  "users.suspend",
  "jobs.read",
  "jobs.moderate",
  "artisans.read",
  "artisans.moderate",
  "reviews.moderate",
  "stats.read",
  // Mağaza (ürün vitrini) — 2026-08-10'da geri geldi. "Herkes satabilir"
  // olduğu için moderasyon yükü ustaya kısıtlı olduğu dönemden yüksek;
  // okuma + gizleme varsayılan moderatör setinde.
  "products.read",
  "products.moderate",
]);

const ALL_CAPABILITIES = new Set([
  ...DEFAULT_MODERATOR_CAPABILITIES,
  "chats.read",
  "audit.read",
  "staff.manage",
  "config.manage",
  "export.run",
  // Manuel premium tanimlama/iptal — para etkili. Varsayilan moderatorde
  // BILEREK yok; superadmin veya acikca yetkilendirilmis admin kullanir.
  "finance.manage",
  // Ürünü Storage'tan kalıcı silme (hard_purge). GERİ DÖNÜŞÜ YOK — bu yüzden
  // varsayılan moderatörde değil; superadmin zaten muaf.
  "products.purge",
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

/**
 * Yalniz uc yasayan durum var (open/cancelled/expired). Canlida kalmis eski
 * degerler (workerSelected, completed, disputed...) "jobsOther"a duser —
 * sayimdan kaybolmasinlar diye.
 * @param {string|undefined|null} status
 */
function jobStatsBucket(status) {
  switch (status) {
    case "open":
      return "jobsOpen";
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
  } else if (before && !after) {
    bump(jobStatsBucket(before.status), -1);
  } else if (before && after) {
    const b = jobStatsBucket(before.status);
    const a = jobStatsBucket(after.status);
    if (b !== a) {
      bump(b, -1);
      bump(a, 1);
    }
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
      patch[k] = FieldValue.increment(v);
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
        [field]: FieldValue.increment(n),
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
    // Eksik alan = AÇIK (eski hesaplar bozulmasın). İstemci paritesi:
    // NotificationPrefs.fromMap aynı "!= false" kuralını uygular.
    productDigest: p.productDigest !== false,
  };
}

async function isPushCategoryAllowed(uid, category, pushSnapOpt) {
  const snap = pushSnapOpt || await getPushDoc(uid);
  const prefs = prefsFromPushSnap(snap);
  if (category === "chat") return prefs.chat;
  if (category === "nearbyJobs") return prefs.nearbyJobs;
  if (category === "productDigest") return prefs.productDigest;
  // jobUpdates (varsayılan) + bilinmeyen
  return prefs.jobUpdates;
}

/** data.type / data.kind → tercih kategorisi. */
function pushCategoryFromData(data) {
  const t = data && data.type;
  if (t === "chat") return "chat";
  if (t === "job" && data.kind === "nearby") return "nearbyJobs";
  // Ürün talebi günlük özeti — AYRI tercih. `jobUpdates`'e bağlansaydı,
  // özeti susturmak isteyen kullanıcı iş bildirimlerini de kapatmak
  // zorunda kalırdı. İstemci paritesi: NotificationPrefs.productDigest.
  if (t === "job" && data.kind === "productDigest") return "productDigest";
  // Takip bildirimi sosyal bir olay; "iş güncellemeleri" tercihine bağlamak
  // yanlış olurdu (kullanıcı iş bildirimlerini kapatınca takipçi haberi de
  // susardı). İstemcide ayrı bir tercih YOK → şimdilik chat kategorisiyle
  // birlikte yönetilir (ikisi de kişiye özel/sosyal).
  if (t === "follow") return "chat";
  return "jobUpdates";
}

async function removeInvalidFcmTokens(uid, invalid, sourceHint) {
  if (!invalid || invalid.length === 0) return;
  const remove = FieldValue.arrayRemove(...invalid);
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
  // Token yoksa SESSİZCE çıkmak teşhisi imkânsız kılıyordu: uygulama içi
  // bildirim (Admin SDK) çalışırken sistem push'u hiç gelmez ve logda tek
  // satır iz kalmazdı. Sebep genelde istemcide token yazımının düşmesidir
  // (izin reddi / App Check / kural) — bkz. PushService.registerFor.
  if (tokens.length === 0) {
    logger.warn(`Push skip ${uid}: cihaz token'ı YOK (fcmTokens boş)`);
    return;
  }

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

  // Android: monokrom status bar ikonu + marka rengi (large/image yok — sade).
  let resp;
  try {
    resp = await getMessaging().sendEachForMulticast({
      tokens,
      notification: {title, body},
      data: fcmData,
      android: {
        priority: "high",
        notification: {
          sound: "default",
          icon: "ic_stat_notification",
          color: "#E8611A",
          channelId: "high_importance_channel",
        },
      },
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
          expireAt: Timestamp.fromMillis(
              Date.now() + NOTIFICATION_TTL_DAYS * 24 * 3600 * 1000),
        });
  } catch (e) {
    logger.warn(`Notification save failed for ${uid}/${docId}: ${e}`);
  }
}

/**
 * Alıcının `users/{uid}/private/chatMeta` sayacını artırır (thread başına 0/1).
 * Mesaj create anında chat dökümanı çoğu zaman henüz güncellenmemiştir →
 * önceki lastMessageSenderUid / lastRead ile "zaten okunmamış mı?" bakılır;
 * zaten 1 ise tekrar +1 yapılmaz (çift sayım yok).
 */
async function bumpChatUnreadMeta(recipientUid, chat) {
  if (!recipientUid) return;
  const lastSender = chat.lastMessageSenderUid;
  let alreadyUnread = false;
  if (lastSender && lastSender !== recipientUid) {
    const lr = chat.lastRead && chat.lastRead[recipientUid];
    if (!lr) {
      alreadyUnread = true;
    } else {
      const lrMs = typeof lr.toMillis === "function" ? lr.toMillis() :
        (lr instanceof Date ? lr.getTime() : Date.parse(lr) || 0);
      const up = chat.updatedAt;
      const upMs = up && typeof up.toMillis === "function" ? up.toMillis() :
        (up instanceof Date ? up.getTime() : (up ? Date.parse(up) || 0 : 0));
      if (upMs > lrMs) alreadyUnread = true;
    }
  }
  if (alreadyUnread) return;

  const asArtisan = recipientUid === chat.artisanUid;
  const patch = {
    unreadTotal: FieldValue.increment(1),
    updatedAt: FieldValue.serverTimestamp(),
  };
  if (asArtisan) {
    patch.unreadArtisan = FieldValue.increment(1);
  } else {
    patch.unreadCustomer = FieldValue.increment(1);
  }
  try {
    await db.collection("users").doc(recipientUid)
        .collection("private").doc("chatMeta")
        .set(patch, {merge: true});
  } catch (e) {
    logger.warn(`chatMeta bump failed for ${recipientUid}: ${e}`);
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

      // USTA → MÜŞTERİ (a2c): ayrı yol.
      //
      // İKİ YERE yazılır:
      //  1. `users/{uid}/private/rating` — AYRINTI (toplam puan, ortalama).
      //     Yalnız sahibi okur; müşterinin aldığı puanın kendisi hassas veri.
      //  2. `users/{uid}.reviewCountAsCustomer` — herkese açık SAYI.
      //     Profil sadeleştirmesiyle (2026-08-07) müşteri profili de
      //     görünür bir sayfa oldu ve "kaç değerlendirme almış" bilgisi
      //     orada gösteriliyor. PUAN değil, yalnız ADET paylaşılır —
      //     düşük puanlı müşteri teşhir edilmesin.
      //     İstemci bu alanı yazamaz (rules: notSettingPublicPii + allowlist).
      const direction = (after && after.direction) ||
        (before && before.direction) || "c2a";
      if (direction === "a2c") {
        const customerUid = (after && after.customerUID) ||
          (before && before.customerUID);
        if (!customerUid) return;
        if (!countDelta && !sumDelta) return;
        try {
          await db.collection("users").doc(customerUid)
              .collection("private").doc("rating")
              .set({
                totalReviews: FieldValue.increment(countDelta),
                totalRatingSum: FieldValue.increment(sumDelta),
                updatedAt: new Date().toISOString(),
              }, {merge: true});
          // Ortalama okunurken hesaplanabilir ama tek alanda tutmak istemci
          // tarafını basitleştirir; toplamlardan türetilir.
          const snap = await db.collection("users").doc(customerUid)
              .collection("private").doc("rating").get();
          const d = snap.data() || {};
          const n = Number(d.totalReviews || 0);
          const s = Number(d.totalRatingSum || 0);
          await snap.ref.set(
              {averageRating: n > 0 ? s / n : 0}, {merge: true});

          // Herkese açık ADET + ORTALAMA (2026-08-08).
          //
          // Eskiden yalnız adet herkese açıktı, puanın kendisi private'ta
          // kalıyordu: müşteri profili "vitrin değil" sayılıyor, düşük
          // puanlı müşterinin damgalanmaması isteniyordu. Artık her profil
          // aynı dili konuşuyor — usta da müşteri de aldığı puanı gösteriyor.
          //
          // `n`/`s` private toplamdan okunur; increment yerine MUTLAK değer
          // yazılır ki iki kayıt drift edemesin.
          await db.collection("users").doc(customerUid)
              .set({
                reviewCountAsCustomer: n,
                ratingAsCustomer: n > 0 ? s / n : 0,
              }, {merge: true});

          logger.info(`customer rating updated for ${customerUid} ` +
            `(count ${countDelta}, sum ${sumDelta}, public ${n})`);
        } catch (e) {
          logger.error(`customer rating update failed for ${customerUid}: ${e}`);
        }
        return;
      }

      // Etiket deltası: eski etiketleri düş, yenileri say. Yalnız etiket
      // değişse bile (rating sabit) topTags güncellenmeli — bu yüzden erken
      // çıkış hem sayı/toplam hem etiket değişimini birlikte kontrol eder.
      const beforeTags = (before && Array.isArray(before.tags)) ?
        before.tags : [];
      const afterTags = (after && Array.isArray(after.tags)) ?
        after.tags : [];
      const tagDelta = {};
      for (const t of beforeTags) {
        if (POSITIVE_REVIEW_TAGS.has(t)) tagDelta[t] = (tagDelta[t] || 0) - 1;
      }
      for (const t of afterTags) {
        if (POSITIVE_REVIEW_TAGS.has(t)) tagDelta[t] = (tagDelta[t] || 0) + 1;
      }
      const tagsChanged = Object.keys(tagDelta).length > 0;
      if (countDelta === 0 && sumDelta === 0 && !tagsChanged) return;

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

          // Etiket sayaçlarını uygula (0'a düşenleri temizle) ve en sık 3
          // olumlu etiketi topTags olarak türet (karttaki rozetler için).
          const tagCounts = {...(cur.tagCounts || {})};
          for (const [t, d] of Object.entries(tagDelta)) {
            const next = (Number(tagCounts[t]) || 0) + d;
            if (next > 0) tagCounts[t] = next;
            else delete tagCounts[t];
          }
          const topTags = Object.entries(tagCounts)
              .sort((a, b) => b[1] - a[1])
              .slice(0, 3)
              .map((e) => e[0]);

          tx.update(ref, {
            totalReviews,
            totalRatingSum,
            averageRating:
              totalReviews > 0 ? totalRatingSum / totalReviews : 0,
            tagCounts,
            topTags,
          });
        });
        logger.info(
            `Rating updated for artisan ${artisanUid} ` +
            `(count ${countDelta}, sum ${sumDelta}, tags ${tagsChanged})`);
      } catch (e) {
        logger.error(`Rating update failed for ${artisanUid}: ${e}`);
      }
    },
);

/**
 * Aynı anda AÇIK tutulabilecek ilan sayısı ve günlük ilan hakkı.
 *
 * Neden gerekli: ilan yayınlanınca EŞLEŞEN TÜM USTALARA bildirim gider
 * (`onJobCreated` fan-out). Limit olmadan tek kullanıcı sınırsız ilan açıp
 * platform çapında bildirim spam'i üretebilir.
 */
const MAX_OPEN_JOBS = 5;
const MAX_JOBS_PER_DAY = 10;

/**
 * `users/{uid}/private/jobStats.openCount` sayacını tazeler.
 *
 * Kural motoru `count()` yapamadığı için "aynı anda 5 açık ilan" kısıtı ancak
 * DENORMALIZE sayaçla uygulanabilir; kural bu dokümanı okur. Sayaç istemci
 * yazımına kapalıdır (rules) — yalnız burası yazar.
 *
 * Doğrudan sorguyla yeniden hesaplanır (increment/decrement yerine): durum
 * geçişleri çok yollu (open → workerSelected → open, expired, cancelled…) ve
 * kaçan bir geçiş sayacı kalıcı olarak bozardı.
 */
async function refreshOpenJobCount(customerId) {
  if (!customerId) return;
  try {
    const snap = await db.collection("jobs")
        .where("customerId", "==", customerId)
        .where("status", "==", "open")
        .get();
    // Süresi dolmuş ilanlar `open` yazar ama yeni ilana engel OLMAMALI.
    const now = Date.now();
    let open = 0;
    snap.forEach((d) => {
      const exp = Number(d.data().expiresAtMs || 0);
      if (!exp || exp > now) open += 1;
    });
    await db.collection("users").doc(customerId)
        .collection("private").doc("jobStats")
        .set({openCount: open, updatedAt: new Date().toISOString()},
            {merge: true});
  } catch (e) {
    logger.warn(`refreshOpenJobCount failed for ${customerId}: ${e}`);
  }
}

/**
 * Sohbete SİSTEM mesajı yazar (yaşam döngüsü şeridi).
 *
 * `type: "system"` kurallarda istemci yazımına KAPALI — sahte "Usta seçildi"
 * bildirimi üretilemez. `senderUid: "system"` balon yerine ortada şerit olarak
 * çizilmesini sağlar. Sohbetin `lastMessage` özeti de tazelenir ki listede
 * son durum görünsün.
 */
async function postSystemMessage(chatId, text) {
  try {
    const now = new Date();
    await db.collection("chats").doc(chatId).collection("messages").add({
      senderUid: "system",
      type: "system",
      text,
      createdAt: Timestamp.fromDate(now),
    });
    await db.collection("chats").doc(chatId).set({
      lastMessage: text,
      lastMessageSenderUid: "system",
      updatedAt: Timestamp.fromDate(now),
    }, {merge: true});
  } catch (e) {
    logger.warn(`postSystemMessage failed for ${chatId}: ${e}`);
  }
}

/**
 * Bir ilanın sohbetlerini bulur (`chats.jobId == jobId`).
 *
 * Sohbet kimliği `chat_{müşteri}__{usta}__{jobId}` biçimindedir ama sorgu
 * KİMLİK ÜZERİNDEN yapılamaz (Firestore önek sorgusu + eşitlik karışımı burada
 * güvenilmez); bu yüzden `jobId` alanı denormalize yazılır ve tek eşitlik
 * filtresiyle sorgulanır (composite index gerekmez).
 */
async function jobChatDocs(jobId) {
  const snap = await db.collection("chats")
      .where("jobId", "==", jobId)
      .get();
  return snap.docs;
}

/**
 * TAKİP BİLDİRİMİ — biri seni takip edince haber verir (Instagram kalıbı).
 *
 * Tetikleyici: `favorites/{favId}` create. Kimlik deterministiktir
 * (`followerUid__followedUid`), yani AYNI çift için tek doküman olur.
 *
 * SPAM KORUMASI: bildirim doküman kimliği `follow_{followerUid}` —
 * takip-bırak-takip yapan biri AYNI dokümanı üzerine yazar, alıcının
 * listesinde tek satır kalır. (Instagram da tekrar bildirim göstermez.)
 * Push ise her create'te gider; bunu sınırlamak için ayrı bir debounce
 * gerekirse `follow_meta` damgası eklenmelidir — şu an gerek görülmedi.
 *
 * Kendini takip create kuralda zaten yasak; yine de savunmacı kontrol var.
 */
exports.onFollowCreated = onDocumentCreated(
    {document: "favorites/{favId}", region: REGION},
    async (event) => {
      const fav = event.data && event.data.data();
      if (!fav) return;

      // Alan adları TARİHSEL: customerUid = takip EDEN, artisanUid = takip
      // EDİLEN (2026-08-08 yönsüzleştirme; veri göçü yapılmadı).
      const followerUid = fav.customerUid;
      const followedUid = fav.artisanUid;
      if (!followerUid || !followedUid) return;
      if (followerUid === followedUid) return;

      const followerName =
        (typeof fav.customerName === "string" && fav.customerName.trim()) ?
          fav.customerName.trim() :
          "Bir kullanıcı";

      const title = "👤 Yeni takipçi";
      const body = `${followerName} seni takip etmeye başladı.`;

      await saveNotification(followedUid, `follow_${followerUid}`, {
        type: "follow",
        title,
        body,
        // İstemci bu uid ile profil sayfasını açar.
        actorUid: followerUid,
      });
      await sendPushToUid(followedUid, title, body,
          {type: "follow", actorUid: followerUid});
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

      // Alt bar rozeti: tek döküman sayacı (tüm chat listesini dinlemeden).
      await bumpChatUnreadMeta(recipientUid, chat);

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

      // GÜNLÜK İLAN LİMİTİ. Aynı anda açık ilan sayısı kural tarafında
      // (jobStats.openCount) kesiliyor; günlük hak ise sayaç gerektirdiği için
      // burada. Aşılırsa ilan İPTAL edilir (silinmez — kullanıcı içeriğini
      // kaybetmesin, ne olduğunu görebilsin) ve fan-out yapılmaz.
      if (job.customerId) {
        const rlRef = db.collection("adminRateLimits")
            .doc(`job_create_${job.customerId}`);
        const day = istanbulDayKey();
        let overLimit = false;
        try {
          await db.runTransaction(async (tx) => {
            const snap = await tx.get(rlRef);
            const r = snap.exists ? (snap.data() || {}) : {};
            const dayCount = r.dayKey === day ? Number(r.dayCount || 0) : 0;
            if (dayCount >= MAX_JOBS_PER_DAY) {
              overLimit = true;
              return;
            }
            tx.set(rlRef, {dayKey: day, dayCount: dayCount + 1,
              lastAtMs: Date.now()}, {merge: true});
          });
        } catch (e) {
          // Sayaç yazılamadıysa ilanı ENGELLEME (kullanıcı mağdur olmasın).
          logger.warn(`job rate limit skipped for ${job.customerId}: ${e}`);
        }
        if (overLimit) {
          await db.collection("jobs").doc(jobId).update({
            status: "cancelled",
            cancelReason: "rateLimited",
          });
          const t = "İlan yayınlanamadı";
          const b = `Günlük ilan hakkınızı doldurdunuz (${MAX_JOBS_PER_DAY}). ` +
            "Yarın tekrar deneyebilirsiniz.";
          await saveNotification(job.customerId, `job_${jobId}`,
              {type: "job", title: t, body: b, jobId});
          logger.warn(`job ${jobId} rate-limited for ${job.customerId}`);
          return;
        }
      }

      // Yalnızca açık (yeni) ilanlar; kategori/il yoksa eşleşme yapılamaz.
      if ((job.status || "open") !== "open") return;
      const category = job.category || "";
      const province = job.province || "";
      if (!category || !province) return;

      // ÜRÜN TALEBİ buradan ÇIKAR. Alıcısı usta değil satıcı, ve bildirim
      // anlık değil günlük özet — `sendProductRequestDigest` gönderir.
      // Günlük ilan limiti YUKARIDA zaten işledi (talep de ona tabidir).
      if (category === PRODUCT_REQUEST_CATEGORY) return;

      const isQuickSupport = category === QUICK_SUPPORT_CATEGORY;

      // Alıcı profilleri:
      //  - Hemen Lazım: "other" kodu veya legacy quick_support.
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

      // Bölgede hizmet verenler (ilan sahibi hariç).
      // NOT: Hemen Lazım da artık İL düzeyinde eşleşir (eskiden il+ilçeydi) —
      // kısa işlerde usta sayısı az olduğundan ilçeye kısılan ilanların çoğu
      // alıcısız kalıyordu. İstemci paritesi: Job.matchesArtisan (job.dart).
      const recipientUids = [];
      profileDocs.forEach((d) => {
        if (d.id === job.customerId) return; // kendi ilanına bildirim gitmesin
        const areas = Array.isArray(d.data().serviceAreas) ?
          d.data().serviceAreas :
          [];
        if (areas.some((a) => a && a.province === province)) {
          recipientUids.push(d.id);
        }
      });
      if (recipientUids.length === 0) {
        logger.info(`Job ${jobId}: no matching artisans in ${province}`);
        return;
      }

      // Not: il adına ek ("'de/'da") ünlü uyumu gerektirdiğinden ekli kalıp
      // kullanılmaz ("İstanbul'de" gibi hatalar oluşuyordu).
      // Hemen Lazım il geneline gittiğinden başlıkta İL yazar; ilçe zaten
      // gövdede görünür (aksi halde uzak bir ilçe "bölgenizde" sanılırdı).
      // Görünen ad "Kolay İş" (2026-08-08); depolama kodu quick_support
      // olarak DEĞİŞMEDİ (istemci paritesi: kQuickSupportName).
      const kind = isQuickSupport ? "Kolay İş ilanı" : "iş ilanı";
      const title =
        `${isQuickSupport ? "⚡ " : ""}${province} bölgesinde yeni ${kind}`;
      const district = job.district ? ` · ${job.district}` : "";
      const body = `${job.title || "Yeni ilan"}${district}`;

      // Uygulama içi bildirim merkezi: eşleşen HER ustaya kayıt (push'tan
      // bağımsız). 500 işlem/batch sınırına karşı parçalı yazım.
      const expireAt = Timestamp.fromMillis(
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
          resp = await getMessaging().sendEachForMulticast({
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
 * Tek isi kaldi: acik ilan sayacini (`users/{uid}/private/jobStats.openCount`)
 * tazelemek. Kural (`jobs create`) o sayaci okuyup MAX_OPEN_JOBS kapisini
 * uygular; sayac istemci yazimina kapalidir.
 *
 * Ilan silinince de sayac duser — yoksa kullanici sildigi ilanlar yuzunden
 * limite takili kalirdi.
 */
// products create/update/delete → productsTotal (yalnız "active" ürünler
// sayılır; draft/paused/removed hariç). Ana Sayfa "büyüyor" sayacı için.
//
// Bu sayacı YALNIZ burası yazar; `adminRebuildStats` aynı ölçütle yeniden
// sayar (status == "active"). İkisi ayrışırsa sayaç sürüklenir.
exports.onProductWritten = onDocumentWritten(
    {document: "products/{productId}", region: REGION},
    async (event) => {
      const beforeActive =
        event.data && event.data.before && event.data.before.exists &&
        event.data.before.data().status === "active";
      const afterActive =
        event.data && event.data.after && event.data.after.exists &&
        event.data.after.data().status === "active";
      try {
        if (!beforeActive && afterActive) {
          await applyStatsDelta({productsTotal: 1});
          await bumpDaily("productsActivated", 1);
        } else if (beforeActive && !afterActive) {
          await applyStatsDelta({productsTotal: -1});
        }
      } catch (e) {
        logger.warn(`adminStats product: ${e}`);
      }
    },
);

exports.onJobWritten = onDocumentWritten(
    {document: "jobs/{jobId}", region: REGION},
    async (event) => {
      const before =
        event.data && event.data.before && event.data.before.data();
      const after = event.data && event.data.after && event.data.after.data();
      // adminStats: durum bucket'i (silme dahil).
      try {
        await applyStatsDelta(jobStatsDelta(before || null, after || null));
        if (!before && after) await bumpDaily("jobsCreated", 1);
      } catch (e) {
        logger.warn(`adminStats job ${event.params.jobId}: ${e}`);
      }
      if (!after) {
        // Ilan silindi → acik ilan sayaci dussun.
        await refreshOpenJobCount(before && before.customerId);
        return;
      }
      const jobId = event.params.jobId;

      // 0) Açık ilan sayacı: yeni ilan ya da durum değişimi → yeniden hesapla.
      //    Kural (`jobs create`) bu sayacı okuyup MAX_OPEN_JOBS kapısını
      //    uygular; sayaç istemci yazımına kapalıdır.
      if (!before || before.status !== after.status) {
        await refreshOpenJobCount(after.customerId);
      }

      // Eskiden burada uc dal daha vardi: completed'a gecis (completedJobs
      // sayaci), usta secildi push'u + diger sohbetlerin kilitlenmesi, ve
      // tek tarafli tamamlama onayi (autoCompleteAt + push). Is akisi
      // 2026-08-08'de kalkti, bu gecisler artik URETILMIYOR — dallar sessizce
      // hic atesenmiyordu. 2026-08-09'da silindi.
    },
);

// ---------------------------------------------------------------------------
// Hesap silme (Google Play zorunluluğu + KVKK) — YOL_HARITASI P0-2.
// ---------------------------------------------------------------------------

// Silinen kullanıcının kalan kayıtlarda görünen adı.
const DELETED_USER_NAME = "Silinmiş Kullanıcı";

// Storage'da kullanıcıya ait klasör kökleri (storage.rules allowlist'i ile
// birebir): {klasör}/{uid}/... yolundaki her şey silinir.
const STORAGE_FOLDERS = [
  "profile", "work", "job", "certificate", "chat", "product",
];

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
 *  - membershipPurchases/{uid}: SİL (Play token'ı kişisel veridir, hesap
 *    yokken işlevi de yok).
 *  - supportTickets: gövde KALIR, kimlik (uid/email) anonimleşir — destek
 *    yazışması iki taraflı kayıttır, ama e-posta kişisel veridir.
 *  - reports: KALIR. Kötüye kullanım kaydıdır; silinirse "şikayet edilince
 *    hesabı sil, temize çık" açığı doğar (meşru menfaat). Şikayet EDENİN
 *    kimliği anonimleşir; şikayet EDİLEN kimliği kalır — kayıt onsuz
 *    anlamsız olur. Doküman KİMLİĞİ ({tip}_{hedef}__{reporterUid}) uid
 *    içerir ve değiştirilmez: taşımak kuralın dayandığı "hedef başına tek
 *    şikayet" tekilliğini bozar.
 *  - adminUserNotes / premiumOverrides: KALIR (yönetici denetim izi).
 *  - Storage {klasör}/{uid}/*: SİL. En son Auth kaydı silinir — böylece bir
 *    adım yarıda kalırsa kullanıcı tekrar deneyebilir.
 */
exports.deleteAccount = onCall(
    {...CONSUMER_CALL_OPTS, timeoutSeconds: 300},
    async (request) => {
      const uid = request.auth && request.auth.uid;
      if (!uid) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      logger.info(`deleteAccount başladı: ${uid}`);

      // 1) Sahibi olduğu ilanlar → hepsi silinir.
      //    İlan bir duyurudur; "usta atanmış aktif iş" diye bir şey yok, o
      //    yüzden anonimleştirip saklamaya da gerek yok. Sohbetler ilandan
      //    bağımsız yaşar — karşı tarafın mesaj geçmişi bundan etkilenmez.
      const myJobs = await db.collection("jobs")
          .where("customerId", "==", uid).get();
      for (const d of myJobs.docs) {
        await d.ref.delete();
      }

      // 2) İki yönlü takip kayıtları + eleman modülü → sil.
      //    Eleman: "iş arıyorum" kartı (worker_{uid}) + tüm eleman ilanları —
      //    herkese açık kart/ilan, hesap silindikten sonra YAYINDA KALAMAZ
      //    (KVKK; ayrıca işveren ölü hesaba yazmaya çalışmasın).
      const writer = db.bulkWriter();
      // Anonimleştirme `update` kullanır ve `update` OLMAYAN dokümanda
      // NOT_FOUND fırlatır. Varsayılan işleyici bunu yutmaz: hata
      // `writer.close()` üzerinden dışarı çıkar ve Auth kaydı silinmeden
      // fonksiyon düşer → kullanıcı "hesabım silinmedi" der (13. bulgu).
      //
      // Bu yazımlar TEMİZLİKTİR, silmenin ön koşulu değildir: kaybolan tek
      // şey bir anonimleştirme olur, hesap yine de silinmelidir. Bu yüzden
      // NOT_FOUND yutulur; gerçek altyapı hataları (UNAVAILABLE/ABORTED)
      // varsayılan gibi yeniden denenir.
      writer.onWriteError((err) => {
        if (err.code === 5 /* NOT_FOUND */) {
          logger.info(
              `deleteAccount: kayıt yok, atlandı (${err.documentRef.path})`);
          return false;
        }
        return err.failedAttempts < 5;
      });
      const [favsOut, favsIn, myStaffNeeds, myProducts] =
        await Promise.all([
          db.collection("favorites").where("customerUid", "==", uid).get(),
          db.collection("favorites").where("artisanUid", "==", uid).get(),
          db.collection("staffNeeds").where("employerUid", "==", uid).get(),
          db.collection("products").where("ownerUid", "==", uid).get(),
        ]);
      favsOut.forEach((d) => writer.delete(d.ref));
      favsIn.forEach((d) => writer.delete(d.ref));
      myStaffNeeds.forEach((d) => writer.delete(d.ref));
      myProducts.forEach((d) => writer.delete(d.ref));
      writer.delete(db.collection("staffWorkers").doc(`worker_${uid}`));

      // 4) Değerlendirmeler: yazdıkları anonim kalır, hakkındakiler silinir
      //    (onReviewWritten profil yoksa toplam güncellemesini zaten atlar).
      const [reviewsBy, reviewsAbout] = await Promise.all([
        db.collection("reviews").where("customerUID", "==", uid).get(),
        db.collection("reviews").where("artisanUID", "==", uid).get(),
      ]);
      reviewsBy.forEach((d) =>
        writer.update(d.ref, {customerDisplayName: DELETED_USER_NAME}));
      reviewsAbout.forEach((d) => writer.delete(d.ref));

      // 4b) Üyelik satın alma kaydı → SİL. Play token'ı kişisel veridir ve
      //     hesap silinince yenileme/RTDN yolu zaten işlemez.
      //     `delete` olmayan dokümanda sorun çıkarmaz (update'in aksine).
      writer.delete(db.collection("membershipPurchases").doc(uid));

      // 4c) Destek talepleri → gövde kalır, kimlik anonimleşir. Yazışma iki
      //     taraflı kayıttır (itiraz/denetim), ama e-posta kişisel veridir.
      // 4d) Şikayetler → KALIR (kötüye kullanım kaydı, meşru menfaat).
      //     Yalnız şikayet EDENİN kimliği düşer; edilenin kimliği kaydın
      //     kendisidir. Doküman kimliğindeki uid'e dokunulmaz — bkz. başlık.
      const [myTickets, myReports] = await Promise.all([
        db.collection("supportTickets").where("uid", "==", uid).get(),
        db.collection("reports").where("reporterUid", "==", uid).get(),
      ]);
      myTickets.forEach((d) => writer.update(d.ref, {
        uid: null,
        email: null,
        deletedAccount: true,
      }));
      myReports.forEach((d) => writer.update(d.ref, {
        reporterUid: null,
        reporterDeleted: true,
      }));

      // 5) Sohbetlerde ad/foto anonimleştir (mesajlar karşı tarafta kalır).
      const chats = await db.collection("chats")
          .where(`members.${uid}`, "==", true).get();
      chats.forEach((d) => {
        const c = d.data() || {};
        const asCustomer = c.customerUid === uid;
        writer.update(d.ref, asCustomer ?
          {
            customerName: DELETED_USER_NAME,
            customerPhotoURL: FieldValue.delete(),
          } :
          {
            artisanName: DELETED_USER_NAME,
            artisanPhotoURL: FieldValue.delete(),
          });
      });
      // Anonimleştirme temizliktir, silmenin ön koşulu DEĞİL: burada bir
      // hata kalırsa hesabın silinmemesi kullanıcı için çok daha kötüdür
      // (KVKK talebi karşılıksız kalır). Logla, silmeye devam et.
      try {
        await writer.close();
      } catch (e) {
        logger.warn(`deleteAccount anonimleştirme kısmen atlandı (${uid}): ${e}`);
      }

      // 6) Profil dökümanları (users alt koleksiyonlarıyla birlikte).
      await db.recursiveDelete(db.collection("users").doc(uid));
      await db.collection("artisanProfiles").doc(uid).delete();

      // 7) Storage: kullanıcının tüm klasörleri.
      const bucket = getStorage().bucket();
      for (const folder of STORAGE_FOLDERS) {
        try {
          await bucket.deleteFiles({prefix: `${folder}/${uid}/`});
        } catch (e) {
          logger.warn(`Storage temizliği atlandı (${folder}/${uid}): ${e}`);
        }
      }

      // 8) En son Auth kaydı — buraya kadar geldiyse veri temizlendi.
      //    Auth kaydı zaten yoksa (yarıda kalmış önceki deneme) bu adım
      //    NOT_FOUND verir; kullanıcı açısından sonuç AYNIDIR → başarı say.
      try {
        await getAuth().deleteUser(uid);
      } catch (e) {
        if (e && e.code === "auth/user-not-found") {
          logger.info(`deleteAccount: Auth kaydı zaten yok (${uid})`);
        } else {
          throw e;
        }
      }
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

      // Belge listesi DEGISTIYSE inceleme durumunu sifirla (pending).
      // Istemci certificateStatus yazamaz (rules); onay listesini degistirip
      // "onayli" rozetini koruyamasin -- yeni belge yeniden incelenir.
      try {
        if (!after) return;
        const b = (event.data.before && event.data.before.exists) ?
          (event.data.before.data() || {}) : {};
        const a = event.data.after.data() || {};
        const beforeCerts = Array.isArray(b.certificates) ? b.certificates : [];
        const afterCerts = Array.isArray(a.certificates) ? a.certificates : [];
        const changed =
          beforeCerts.length !== afterCerts.length ||
          afterCerts.some((c, i) => c !== beforeCerts[i]);
        if (!changed) return;

        const nextStatus = afterCerts.length === 0 ? "none" : "pending";
        if (a.certificateStatus === nextStatus) return;
        await event.data.after.ref.set({
          certificateStatus: nextStatus,
          certificateNote: FieldValue.delete(),
          certificateUpdatedAt:
            FieldValue.serverTimestamp(),
        }, {merge: true});
      } catch (e) {
        logger.warn(`certificate status reset: ${e}`);
      }
    },
);

/**
 * Belge (sertifika) inceleme karari — usta bazinda tek onay.
 *
 * Uygulama ustaya "Belgeler yonetici onayindan gecer" diyor; bu CF o sozun
 * karsiligi. Onay YALNIZ rozet verir: mavi tik (telefon/platform onayi)
 * mantigina dokunmaz.
 */
exports.adminReviewCertificates = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "artisans.moderate");
      const {uid, approve, note} = request.data || {};
      if (typeof uid !== "string" || !uid.trim()) {
        throw new HttpsError("invalid-argument", "uid gerekli.");
      }
      if (typeof approve !== "boolean") {
        throw new HttpsError("invalid-argument", "approve gerekli.");
      }
      const reason = String(note || "").trim();
      // Reddetmede gerekce ZORUNLU: usta neyi duzeltecegini bilmeli.
      if (!approve && reason.length < 5) {
        throw new HttpsError(
            "invalid-argument",
            "Red gerekcesi zorunlu (en az 5 karakter).",
        );
      }
      if (reason.length > 500) {
        throw new HttpsError("invalid-argument", "Gerekce cok uzun.");
      }

      const ref = db.collection("artisanProfiles").doc(uid.trim());
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Usta profili yok.");
      }
      const before = snap.data() || {};
      const certs = Array.isArray(before.certificates) ?
        before.certificates : [];
      if (certs.length === 0) {
        throw new HttpsError(
            "failed-precondition",
            "Bu ustanin yuklenmis belgesi yok.",
        );
      }

      await ref.set({
        certificateStatus: approve ? "approved" : "rejected",
        certificateNote: approve ?
          FieldValue.delete() : reason,
        certificateReviewedBy: auth.uid,
        certificateUpdatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});

      // Ustaya bildir: sonucu ogrenmeli (ozellikle red gerekcesini).
      try {
        const title = approve ?
          "Belgeleriniz onaylandi" : "Belgeleriniz reddedildi";
        const body = approve ?
          "Profilinizde \"Belgeli usta\" rozeti gorunecek." :
          `Gerekce: ${reason}`;
        await saveNotification(uid.trim(), `certs_${Date.now()}`, {
          type: "system",
          title,
          body,
        });
        await sendPushToUid(uid.trim(), title, body, {type: "system"});
      } catch (e) {
        logger.warn(`certificate notify: ${e}`);
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: approve ? "approve_certificates" : "reject_certificates",
        targetType: "artisan",
        targetId: uid.trim(),
        reason: approve ? null : reason,
        before: {certificateStatus: before.certificateStatus || "none"},
        after: {certificateStatus: approve ? "approved" : "rejected"},
      });
      return {ok: true, status: approve ? "approved" : "rejected"};
    },
);

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

// Eleman ilanı tavanı: kullanıcı başına en fazla bu kadar AÇIK ilan.
// Kural sayım yapamaz; istemci dostça engeller (staff_need_edit_screen),
// burası kötü niyetli/eski istemciye karşı sunucu güvencesi: tavan aşan
// ilan oluşur oluşmaz SİLİNİR (spam listede kalmaz).
const MAX_OPEN_STAFF_NEEDS = 5;

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
        productsTotal: 0,
        jobsOpen: 0,
        jobsCancelled: 0,
        jobsOther: 0,
        openReports: 0,
      };

      // users
      let lastUser = null;
      for (;;) {
        let q = db.collection("users").orderBy(FieldPath.documentId())
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
            .orderBy(FieldPath.documentId()).limit(400);
        if (lastArt) q = q.startAfter(lastArt);
        const snap = await q.get();
        if (snap.empty) break;
        counts.artisansTotal += snap.size;
        lastArt = snap.docs[snap.docs.length - 1];
        if (snap.size < 400) break;
      }

      // products (yalnız "active" olanlar sayılır — onProductWritten paritesi)
      let lastProd = null;
      for (;;) {
        let q = db.collection("products")
            .orderBy(FieldPath.documentId()).limit(400);
        if (lastProd) q = q.startAfter(lastProd);
        const snap = await q.get();
        if (snap.empty) break;
        for (const d of snap.docs) {
          if (d.data().status === "active") counts.productsTotal++;
        }
        lastProd = snap.docs[snap.docs.length - 1];
        if (snap.size < 400) break;
      }

      // jobs
      let lastJob = null;
      for (;;) {
        let q = db.collection("jobs")
            .orderBy(FieldPath.documentId()).limit(400);
        if (lastJob) q = q.startAfter(lastJob);
        const snap = await q.get();
        if (snap.empty) break;
        for (const d of snap.docs) {
          const st = d.data().status;
          const b = jobStatsBucket(st);
          if (b) counts[b] = (counts[b] || 0) + 1;
        }
        lastJob = snap.docs[snap.docs.length - 1];
        if (snap.size < 400) break;
      }

      // reports
      let lastRep = null;
      for (;;) {
        let q = db.collection("reports")
            .orderBy(FieldPath.documentId()).limit(400);
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
      const userRec = await getAuth().getUser(auth.uid);
      const prev = userRec.customClaims || {};
      await getAuth().setCustomUserClaims(auth.uid, {
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
        target = await getAuth().getUser(uid);
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
      await getAuth().setCustomUserClaims(uid, newClaims);

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
        await getAuth().revokeRefreshTokens(uid);
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

      const userRec = await getAuth().getUser(auth.uid);
      const prev = userRec.customClaims || {};
      await getAuth().setCustomUserClaims(auth.uid, {
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
        await getAuth().revokeRefreshTokens(auth.uid);
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
        update.assignedTo = FieldValue.delete();
        update.assignedAt = FieldValue.delete();
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
          assignedTo: FieldValue.delete(),
          assignedAt: FieldValue.delete(),
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

/**
 * Sikayet edilen bir SOHBET MESAJINI yonetici kaldirir / geri alir.
 *
 * Neden CF: `chats/{id}/messages/{id}` kuralinda update YALNIZ gonderenin
 * kendi yumusak silmesine acik. Yoneticiye kural uzerinden yazma yetkisi
 * verilseydi her admin her sohbete yazabilirdi; burada hedef SIKAYET
 * KAYDINDAN turetilir → yonetici rastgele mesaj gizleyemez.
 *
 * Hedef turetme: rapor targetType == "message" olmali. Istemci
 * `${chatId}_${msgId}` yaziyor (chat_screen.dart); chatId rapordaki chatId
 * alanindan alinir, msgId targetId'nin "chatId_" onekinden SONRASIDIR.
 * (msgId'de "_" bulunabilecegi icin split degil, prefix soyma kullanilir.)
 *
 * `deleted` alanina DOKUNULMAZ: kullanicinin kendi silmesi ile yonetici
 * kaldirmasi ayri kavramlar (istemci ikisine farkli metin gosterir).
 */
exports.adminModerateMessage = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "reports.manage");
      const {reportId, hidden} = request.data || {};
      if (typeof reportId !== "string" || !reportId.trim() ||
          typeof hidden !== "boolean") {
        throw new HttpsError(
            "invalid-argument", "reportId ve hidden zorunlu.");
      }

      const repRef = db.collection("reports").doc(reportId.trim());
      const repSnap = await repRef.get();
      if (!repSnap.exists) {
        throw new HttpsError("not-found", "Sikayet bulunamadi.");
      }
      const rep = repSnap.data() || {};
      if ((rep.targetType || "") !== "message") {
        throw new HttpsError(
            "failed-precondition", "Bu sikayet bir mesaji hedeflemiyor.");
      }

      const chatId = typeof rep.chatId === "string" ? rep.chatId.trim() : "";
      const targetId = typeof rep.targetId === "string" ? rep.targetId : "";
      if (!chatId || !targetId) {
        throw new HttpsError(
            "failed-precondition", "Sikayette sohbet/mesaj baglami yok.");
      }
      const prefix = `${chatId}_`;
      if (!targetId.startsWith(prefix)) {
        throw new HttpsError(
            "failed-precondition", "Mesaj kimligi sohbetle uyusmuyor.");
      }
      const msgId = targetId.slice(prefix.length);
      if (!msgId) {
        throw new HttpsError("failed-precondition", "Mesaj kimligi bos.");
      }

      const msgRef = db.collection("chats").doc(chatId)
          .collection("messages").doc(msgId);
      const msgSnap = await msgRef.get();
      if (!msgSnap.exists) {
        throw new HttpsError("not-found", "Mesaj bulunamadi (silinmis olabilir).");
      }
      const msg = msgSnap.data() || {};

      // Kanit sakla: sohbet/mesaj sonradan silinse de karar gerekcesi dursun.
      // Yalniz ILK gizlemede yazilir (geri al → tekrar gizle akisinda ilk
      // kanit korunur; ustune yazilirsa metin bosalmis olabilirdi).
      const repUpdate = {};
      if (hidden && !rep.evidenceText && !rep.evidenceCapturedAt) {
        repUpdate.evidenceText = typeof msg.text === "string" ?
          msg.text.slice(0, 4000) : null;
        repUpdate.evidenceHasImage = !!msg.imageHandle;
        repUpdate.evidenceCapturedAt = new Date().toISOString();
      }

      const batch = db.batch();
      batch.update(msgRef, {
        moderationHidden: hidden,
        moderatedBy: hidden ? auth.uid : FieldValue.delete(),
        moderatedAt: hidden ?
          new Date().toISOString() :
          FieldValue.delete(),
      });
      if (Object.keys(repUpdate).length > 0) batch.update(repRef, repUpdate);
      await writeAuditLog({
        actorUid: auth.uid,
        action: hidden ? "hide_message" : "unhide_message",
        targetType: "message",
        targetId: `${chatId}/${msgId}`,
        before: {moderationHidden: msg.moderationHidden === true},
        after: {moderationHidden: hidden},
      }, batch);
      await batch.commit();

      logger.info(
          `message ${chatId}/${msgId} moderationHidden=${hidden} ` +
          `(admin ${auth.uid})`);
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
          record = await getAuth().getUser(uid.trim());
        } else if (typeof email === "string" && email.trim()) {
          record = await getAuth().getUserByEmail(normalizeEmail(email));
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

/**
 * 360 derece kullanici ozeti: kimlik + aktivite sayaclari + acik kayitlar.
 *
 * Destek/moderasyon karari verirken adminin "bu kullanici kim, ne yapmis"
 * sorusunu tek cagrida yanitlar. Sayimlar aggregate count() ile yapilir
 * (dokuman okumaz -> ucuz ve indekssiz).
 *
 * PII sinirlidir: telefon/mesaj icerigi DONMEZ. Sohbet icerigi ayri bir
 * yetkiye (chats.read + adminGetChatTranscript) baglidir.
 */
exports.adminUserSummary = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "users.read");
      const {uid} = request.data || {};
      if (typeof uid !== "string" || !uid.trim()) {
        throw new HttpsError("invalid-argument", "uid gerekli.");
      }
      const target = uid.trim();

      // Sayim yardimcisi: hata olursa null (panel yine acilsin).
      const countOf = async (query) => {
        try {
          const agg = await query.count().get();
          return agg.data().count;
        } catch (e) {
          logger.warn(`adminUserSummary count: ${e}`);
          return null;
        }
      };

      const jobs = db.collection("jobs");
      const reports = db.collection("reports");
      const [
        jobsCreated,
        jobsActive,
        reportsAgainst,
        reportsBy,
        reviewsReceived,
        products,
      ] = await Promise.all([
        countOf(jobs.where("customerId", "==", target)),
        countOf(jobs.where("customerId", "==", target)
            .where("status", "==", "open")),
        countOf(reports.where("reportedUid", "==", target)),
        countOf(reports.where("reporterUid", "==", target)),
        // reviews KOK koleksiyon; alan adi artisanUID (buyuk harfli sonek).
        countOf(db.collection("reviews").where("artisanUID", "==", target)),
        countOf(db.collection("products").where("ownerUid", "==", target)),
      ]);

      const [userSnap, artisanSnap] = await Promise.all([
        db.collection("users").doc(target).get(),
        db.collection("artisanProfiles").doc(target).get(),
      ]);
      const pub = userSnap.exists ? (userSnap.data() || {}) : {};
      const art = artisanSnap.exists ? (artisanSnap.data() || {}) : null;

      return {
        uid: target,
        exists: userSnap.exists,
        displayName: pub.displayName || null,
        createdAt: pub.createdAt || null,
        suspended: pub.suspended === true,
        phoneVerified: pub.phoneVerified === true,
        hasArtisanProfile: pub.hasArtisanProfile === true,
        artisan: art ? {
          isPremium: art.isPremium === true,
          premiumExpiresAt: art.premiumExpiresAt ?
            art.premiumExpiresAt.toDate().toISOString() : null,
          premiumProductId: art.premiumProductId || null,
          adminVerified: art.adminVerified === true,
          isVerified: art.isVerified === true,
          moderationHidden: art.moderationHidden === true,
          averageRating: art.averageRating || 0,
          totalReviews: art.totalReviews || 0,
          completedJobs: art.completedJobs || 0,
        } : null,
        counts: {
          jobsCreated,
          jobsActive,
          reportsAgainst,
          reportsBy,
          reviewsReceived,
          products,
        },
      };
    },
);

/**
 * Dahili admin notu ekler (yalniz adminler gorur; kullaniciya gosterilmez).
 * Ornek: "02.08.2026 - kullanici arandi, sertifika orijinalini mail atacak".
 *
 * Notlar SILINMEZ (append-only): destek gecmisi butunlugu icin.
 */
exports.adminAddUserNote = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "users.read");
      const {uid, note} = request.data || {};
      if (typeof uid !== "string" || !uid.trim()) {
        throw new HttpsError("invalid-argument", "uid gerekli.");
      }
      const text = String(note || "").trim();
      if (text.length < 2) {
        throw new HttpsError("invalid-argument", "Not bos olamaz.");
      }
      if (text.length > 2000) {
        throw new HttpsError("invalid-argument", "Not cok uzun (max 2000).");
      }
      const ref = await db.collection("adminUserNotes").add({
        uid: uid.trim(),
        note: text,
        actorUid: auth.uid,
        createdAt: FieldValue.serverTimestamp(),
      });
      await writeAuditLog({
        actorUid: auth.uid,
        action: "add_user_note",
        targetType: "user",
        targetId: uid.trim(),
        after: {noteId: ref.id},
      });
      return {ok: true, id: ref.id};
    },
);

/** Kullanicinin dahili admin notlari (yeniden eskiye). */
exports.adminListUserNotes = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "users.read");
      const {uid, limit} = request.data || {};
      if (typeof uid !== "string" || !uid.trim()) {
        throw new HttpsError("invalid-argument", "uid gerekli.");
      }
      const cap = Math.min(Math.max(Number(limit) || 30, 1), 100);
      const snap = await db.collection("adminUserNotes")
          .where("uid", "==", uid.trim())
          .orderBy("createdAt", "desc")
          .limit(cap)
          .get();
      return {
        items: snap.docs.map((d) => {
          const v = d.data() || {};
          return {
            id: d.id,
            note: v.note || "",
            actorUid: v.actorUid || null,
            createdAt: v.createdAt ?
              v.createdAt.toDate().toISOString() : null,
          };
        }),
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
        target = await getAuth().getUser(uid);
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
      await getAuth().setCustomUserClaims(uid, newClaims);

      // Herkese açık `users` dökümanına YALNIZ bool ayna (+ zaman); neden yok.
      const del = FieldValue.delete();
      await db.collection("users").doc(uid).set(
          suspended ?
            {suspended: true, suspendedAt: new Date().toISOString()} :
            {suspended: del, suspendedAt: del},
          {merge: true});

      // Askıya alırken oturumları geçersiz kıl (claim kesin yansısın).
      if (suspended) {
        try {
          await getAuth().revokeRefreshTokens(uid);
        } catch (e) {
          logger.warn(`revokeRefreshTokens skipped for ${uid}: ${e}`);
        }
      }

      // Askıya alınan kullanıcının HERKESE AÇIK ürünleri yayından düşer;
      // askı kalkınca geri gelir. Bit ayrı tutulur (`hiddenByUserSuspend`),
      // böylece askı kalkarken moderatörün ayrıca gizlediği ürün açılmaz.
      try {
        await cascadeProductsHideBits(uid, "hiddenByUserSuspend", suspended);
      } catch (e) {
        logger.warn(`product cascade skipped for ${uid}: ${e}`);
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

      // M8: force_cancel → ilan sahibine bildirim + push.
      // (Eskiden secilen ustaya da giderdi; usta atamasi diye bir sey yok.)
      if (decision === "force_cancel") {
        const title = "İlan yönetici tarafından iptal edildi";
        const body = (typeof note === "string" && note.trim()) ?
          note.trim() :
          (before.title || "İlan") + " iptal edildi.";
        const customerId = before.customerId;
        if (customerId) {
          await saveNotification(customerId, `job_mod_${jobId}`, {
            type: "job",
            title,
            body,
            jobId,
          });
          await sendPushToUid(customerId, title, body, {type: "job", jobId});
        }
      }

      return {ok: true, decision};
    },
);

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

      // Profil gizlenirse o kişinin ürünleri de yayından düşer (PRD-006 K9).
      // Gizli profilin vitrini Keşfet'te durmaya devam etmemeli.
      if (typeof moderationHidden === "boolean") {
        try {
          await cascadeProductsHideBits(
              uid.trim(), "hiddenByArtisanHide", moderationHidden);
        } catch (e) {
          logger.warn(`artisan hide product cascade: ${e}`);
        }
      }

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

/**
 * Manuel Premium tanimlama / uzatma / iptal (admin override).
 *
 * Neden ayri: verifyMembershipPurchase Play makbuzuna dayanir. Destek
 * senaryolarinda (odeme alindi ama dogrulama dustu, telafi, kampanya) adminin
 * makbuzsuz premium verebilmesi gerekir.
 *
 * Play kaydini BOZMAZ: membershipPurchases dokumanina dokunulmaz, manuel
 * kayit ayri koleksiyonda (premiumOverrides) tutulur. Boylece kullanicinin
 * gercek aboneligi varsa yenileme akisi bozulmaz.
 *
 * Gerekce ZORUNLUDUR ve audit log'a yazilir (para etkili islem).
 */
exports.adminGrantPremium = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "finance.manage");
      const {uid, days, reason, revoke} = request.data || {};
      if (typeof uid !== "string" || !uid.trim()) {
        throw new HttpsError("invalid-argument", "uid gerekli.");
      }
      const note = String(reason || "").trim();
      if (note.length < 5) {
        throw new HttpsError(
            "invalid-argument",
            "Gerekce zorunlu (en az 5 karakter).",
        );
      }
      if (note.length > 500) {
        throw new HttpsError("invalid-argument", "Gerekce cok uzun.");
      }
      const targetUid = uid.trim();
      const ref = db.collection("artisanProfiles").doc(targetUid);
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Usta profili yok.");
      }
      const before = snap.data() || {};
      const beforeState = {
        isPremium: before.isPremium === true,
        premiumExpiresAt: before.premiumExpiresAt ?
          before.premiumExpiresAt.toDate().toISOString() : null,
        premiumProductId: before.premiumProductId || null,
      };

      let patch;
      let expiresAtIso = null;
      if (revoke === true) {
        // Iptal: bayragi kapat, bitis tarihini simdiye cek (gecmise donuk
        // kayit kalsin; alan silinirse "hic premium olmamis" gibi gorunur).
        patch = {
          isPremium: false,
          premiumExpiresAt: Timestamp.fromDate(new Date()),
          premiumUpdatedAt: FieldValue.serverTimestamp(),
        };
      } else {
        const d = Number(days);
        if (!Number.isFinite(d) || d < 1 || d > 3650) {
          throw new HttpsError(
              "invalid-argument",
              "days 1..3650 araliginda olmali.",
          );
        }
        // UZATMA: mevcut bitis ileri tarihliyse onun uzerine ekle, degilse
        // bugunden basla. Aksi halde aktif uyeligin suresi KISALIRDI.
        const now = Date.now();
        const currentEnd = before.premiumExpiresAt ?
          before.premiumExpiresAt.toDate().getTime() : 0;
        const base = currentEnd > now ? currentEnd : now;
        const expiry = new Date(base + d * 24 * 60 * 60 * 1000);
        expiresAtIso = expiry.toISOString();
        patch = {
          isPremium: true,
          premiumExpiresAt: Timestamp.fromDate(expiry),
          premiumProductId: "manual_admin_grant",
          premiumUpdatedAt: FieldValue.serverTimestamp(),
        };
      }

      await ref.set(patch, {merge: true});

      // Manuel mudahale izi (Play kaydindan AYRI).
      await db.collection("premiumOverrides").add({
        uid: targetUid,
        actorUid: auth.uid,
        revoke: revoke === true,
        days: revoke === true ? null : Number(days),
        reason: note,
        expiresAt: expiresAtIso,
        createdAt: FieldValue.serverTimestamp(),
      });

      await writeAuditLog({
        actorUid: auth.uid,
        action: revoke === true ? "revoke_premium" : "grant_premium",
        targetType: "artisan",
        targetId: targetUid,
        reason: note,
        before: beforeState,
        after: {
          isPremium: revoke !== true,
          premiumExpiresAt: expiresAtIso,
          days: revoke === true ? null : Number(days),
        },
      });
      return {ok: true, isPremium: revoke !== true, expiresAt: expiresAtIso};
    },
);

/**
 * TOPLU PLAN YONETIMI (madde 7) — ucretsiz donem bitiminde kullanilir.
 *
 * Ucretsiz donem kapandiginda ustalarin musaitligi KENDILIGINDEN kapanmiyordu.
 * Asil cozum istemci tarafindaki premium KAPISIDIR
 * (`ArtisanProfile.isAvailableAt` premium erisimi yoksa false doner) — o kapi
 * hicbir veri yazmaz ve ucretsiz doneme donulurse herkes eski haline
 * kendiliginden doner.
 *
 * Bu fonksiyon o kapinin YERINE gecmez, yaninda durur: yoneticinin belirli
 * ustalari gercekten ucretsize almasi ya da musaitliklerini elle kapatmasi
 * gereken durumlar icin (kampanya bitisi, kotuye kullanim, toplu duzeltme).
 *
 * `mode`:
 *  - "revokePremium": isPremium=false + premiumExpiresAt=simdi
 *  - "pauseAvailability": manualPause=true (usta kendi acabilir)
 *  - "both": ikisi birden
 *
 * `onlyWithoutActivePremium` (varsayilan true): aktif odemeli aboneligi olan
 * ustalara DOKUNMAZ — parasini odeyen kullaniciyi kapatmak gelir kaybi ve
 * sikayet sebebidir. Yonetici bilerek false gecebilir.
 *
 * Gerekce ZORUNLUDUR ve audit log'a yazilir. Islem 400'luk yiginlar halinde
 * yurur (Firestore batch siniri 500).
 */
exports.adminBulkPlanUpdate = onCall(
    {region: REGION, timeoutSeconds: 540},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "finance.manage");
      const {mode, reason, onlyWithoutActivePremium, dryRun} =
        request.data || {};

      const gecerliModlar = ["revokePremium", "pauseAvailability", "both"];
      if (!gecerliModlar.includes(mode)) {
        throw new HttpsError(
            "invalid-argument",
            `mode su degerlerden biri olmali: ${gecerliModlar.join(", ")}`,
        );
      }
      const note = String(reason || "").trim();
      if (note.length < 5) {
        throw new HttpsError(
            "invalid-argument",
            "Gerekce zorunlu (en az 5 karakter).",
        );
      }
      if (note.length > 500) {
        throw new HttpsError("invalid-argument", "Gerekce cok uzun.");
      }

      // Odemeli aboneligi olanlari koru (varsayilan davranis).
      const korunanlariAtla = onlyWithoutActivePremium !== false;
      const simdi = Date.now();

      const snap = await db.collection("artisanProfiles").get();
      let etkilenen = 0;
      let atlanan = 0;
      let batch = db.batch();
      let batchAdet = 0;

      for (const doc of snap.docs) {
        const d = doc.data() || {};
        const bitis = d.premiumExpiresAt ?
          d.premiumExpiresAt.toDate().getTime() : 0;
        const aktifPremium = d.isPremium === true && bitis > simdi;

        if (korunanlariAtla && aktifPremium) {
          atlanan++;
          continue;
        }

        const patch = {};
        if (mode === "revokePremium" || mode === "both") {
          // Zaten premium degilse yazma — bosuna yazma maliyeti.
          if (d.isPremium === true) {
            patch.isPremium = false;
            patch.premiumExpiresAt = Timestamp.fromDate(new Date());
          }
        }
        if (mode === "pauseAvailability" || mode === "both") {
          if (d.manualPause !== true) {
            patch.manualPause = true;
          }
        }
        if (Object.keys(patch).length === 0) {
          atlanan++;
          continue;
        }

        etkilenen++;
        if (dryRun === true) continue; // yalniz say, yazma

        patch.premiumUpdatedAt = FieldValue.serverTimestamp();
        batch.set(doc.ref, patch, {merge: true});
        batchAdet++;
        if (batchAdet >= 400) {
          await batch.commit();
          batch = db.batch();
          batchAdet = 0;
        }
      }

      if (dryRun !== true && batchAdet > 0) await batch.commit();

      await writeAuditLog({
        actorUid: auth.uid,
        action: dryRun === true ? "bulk_plan_preview" : "bulk_plan_update",
        targetType: "artisanProfiles",
        targetId: null,
        reason: note,
        before: null,
        after: {
          mode,
          etkilenen,
          atlanan,
          toplam: snap.size,
          onlyWithoutActivePremium: korunanlariAtla,
          dryRun: dryRun === true,
        },
      });

      logger.info(
          `adminBulkPlanUpdate mode=${mode} etkilenen=${etkilenen} ` +
          `atlanan=${atlanan} dryRun=${dryRun === true}`,
      );
      return {
        ok: true,
        etkilenen,
        atlanan,
        toplam: snap.size,
        dryRun: dryRun === true,
      };
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
      // Sikayet edilen mesajin kimligi: moderator hangi mesajin bildirildigini
      // 100 mesaj arasinda gozle aramasin (targetId = `${chatId}_${msgId}`).
      let reportedMsgId = null;
      if (tt === "message" && typeof rep.targetId === "string") {
        const pfx = `${wantChat}_`;
        if (rep.targetId.startsWith(pfx)) {
          reportedMsgId = rep.targetId.slice(pfx.length) || null;
        }
      }

      const messages = msgSnap.docs.map((d) => {
        const m = d.data() || {};
        // Kullanicinin KENDI sildigi icerik gosterilmez (mevcut davranis).
        // Yoneticinin kaldirdigi mesaj ise moderatore GORUNUR kalir: karari
        // veren/denetleyen kisi neyi kaldirdigini gorebilmeli.
        const userDeleted = m.deleted === true;
        return {
          id: d.id,
          senderUid: m.senderUid || null,
          text: userDeleted ? null : (m.text || null),
          imageHandle: userDeleted ? null : (m.imageHandle || null),
          deleted: userDeleted,
          moderationHidden: m.moderationHidden === true,
          createdAt: m.createdAt || null,
        };
      });

      // uid → gorunen ad. Sohbetteki taraf sayisi 2 oldugundan tek batch yeter.
      const uids = [...new Set(
          messages.map((m) => m.senderUid).filter((u) => typeof u === "string"),
      )].slice(0, 10);
      const names = {};
      if (uids.length > 0) {
        const userSnaps = await db.getAll(
            ...uids.map((u) => db.collection("users").doc(u)),
        );
        userSnaps.forEach((s) => {
          if (s.exists) {
            const dn = (s.data() || {}).displayName;
            if (typeof dn === "string" && dn.trim()) names[s.id] = dn.trim();
          }
        });
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: "get_chat_transcript",
        targetType: "chat",
        targetId: wantChat,
        after: {reportId: reportId.trim(), messageCount: messages.length},
      });
      return {
        messages,
        names,
        reportedMessageId: reportedMsgId,
        chatId: wantChat,
        reportId: reportId.trim(),
      };
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
      // Mağaza (ürün vitrini) — admin panelinden kill-switch + zorunlu inceleme.
      if (typeof patch.productsEnabled === "boolean") {
        next.productsEnabled = patch.productsEnabled;
      }
      if (typeof patch.productsForceReview === "boolean") {
        next.productsForceReview = patch.productsForceReview;
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
        productsEnabled: true,
        productsForceReview: false,
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
          productsEnabled: before.productsEnabled !== false,
          productsForceReview: before.productsForceReview === true,
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
  "all", "artisans", "customers", "profession", "province", "user",
];

/**
 * Kitle → uid listesi (max 300).
 * audience=user: targetUid veya targetEmail (Auth) ile tek alıcı.
 * @return {Promise<string[]>}
 */
async function resolveBroadcastUids(
    aud, profession, province, targetUid, targetEmail) {
  if (aud === "user") {
    const uidRaw = (targetUid && String(targetUid).trim()) || "";
    const emailRaw = (targetEmail && String(targetEmail).trim()) || "";
    if (uidRaw) {
      const snap = await db.collection("users").doc(uidRaw).get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "UID ile kullanıcı bulunamadı.");
      }
      return [uidRaw];
    }
    if (emailRaw) {
      try {
        const user = await getAuth().getUserByEmail(emailRaw.toLowerCase());
        return [user.uid];
      } catch (e) {
        throw new HttpsError(
            "not-found", "Bu e-posta ile kayıtlı kullanıcı yok.");
      }
    }
    throw new HttpsError(
        "invalid-argument", "Tek kişi için targetUid veya targetEmail gerekli.");
  }
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
  targetUid,
  targetEmail,
  sendPush,
  actorUid,
  source,
}) {
  const t = String(title || "").trim().slice(0, 120);
  const b = String(body || "").trim().slice(0, 500);
  const aud = audience || "all";
  const doPush = sendPush === true;
  const uids = await resolveBroadcastUids(
      aud, profession, province, targetUid, targetEmail);
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
      targetUid: aud === "user" ? uid : null,
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
  const targetUid = (typeof patch.targetUid === "string") ?
    patch.targetUid.trim() : "";
  const targetEmail = (typeof patch.targetEmail === "string") ?
    patch.targetEmail.trim() : "";
  if (audience === "user" && !targetUid && !targetEmail) {
    throw new HttpsError(
        "invalid-argument", "Tek kişi için targetUid veya targetEmail gerekli.");
  }
  return {
    title,
    body,
    audience,
    profession: profession || null,
    province: province || null,
    targetUid: targetUid || null,
    targetEmail: targetEmail || null,
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
            targetUid: c.targetUid,
            targetEmail: c.targetEmail,
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
    CONSUMER_CALL_OPTS,
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

      // Hız sınırı (spam/maliyet): kullanıcı başına 2 dk'da 1, günde 10 talep.
      // Sayaç `adminRateLimits/support_{uid}` — istemci okuyamaz/yazamaz
      // (rules). Transaction: eşzamanlı çift istekte sayaç tutarlı kalır.
      const rlRef = db.collection("adminRateLimits")
          .doc(`support_${auth.uid}`);
      const day = istanbulDayKey();
      await db.runTransaction(async (tx) => {
        const snap = await tx.get(rlRef);
        const d = snap.exists ? (snap.data() || {}) : {};
        const lastMs = Number(d.lastAtMs || 0);
        const dayCount = d.dayKey === day ? Number(d.dayCount || 0) : 0;
        if (lastMs && Date.now() - lastMs < 2 * 60 * 1000) {
          throw new HttpsError(
              "resource-exhausted",
              "Çok sık talep gönderdiniz. Birkaç dakika sonra tekrar deneyin.");
        }
        if (dayCount >= 10) {
          throw new HttpsError(
              "resource-exhausted",
              "Günlük destek talebi sınırına ulaştınız. " +
              "Yarın tekrar deneyebilirsiniz.");
        }
        tx.set(rlRef, {
          lastAtMs: Date.now(),
          dayKey: day,
          dayCount: dayCount + 1,
        }, {merge: true});
      });

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
            target = await getAuth().getUser(uid);
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
          await getAuth().setCustomUserClaims(uid, newClaims);

          const del = FieldValue.delete();
          await db.collection("users").doc(uid).set(
              suspended ?
                {suspended: true, suspendedAt: new Date().toISOString()} :
                {suspended: del, suspendedAt: del},
              {merge: true});

          if (suspended) {
            try {
              await getAuth().revokeRefreshTokens(uid);
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
    premiumExpiresAt: Timestamp.fromDate(expiresAt),
    premiumProductId: productId,
    premiumUpdatedAt: FieldValue.serverTimestamp(),
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
    expiresAt: Timestamp.fromDate(expiresAt),
    packageName: PLAY_PACKAGE_NAME,
    updatedAt: FieldValue.serverTimestamp(),
  }, {merge: true});
}

/**
 * Play abonelik doğrulama (üretim).
 *
 * İstemci: billing_service.dart → productId + purchaseToken.
 * Başarı: artisanProfiles.isPremium + premiumExpiresAt (yalnız sunucu).
 */
exports.verifyMembershipPurchase = onCall(
    CONSUMER_CALL_OPTS,
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
              ? Timestamp.fromDate(verified.expiry)
              : FieldValue.delete(),
            premiumUpdatedAt: FieldValue.serverTimestamp(),
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

// ---------------------------------------------------------------------------
// Kesfet urunler (PRD-006) - publish / content requeue / moderate / cascade
// ---------------------------------------------------------------------------

function recomputeModerationHidden(d) {
  return d.hiddenByModeration === true ||
    d.hiddenByUserSuspend === true ||
    d.hiddenByArtisanHide === true;
}

/**
 * Türkçe arama katlaması — `lib/core/utils/search_fold.dart` ile AYNI
 * eşlemeyi yapar (istemci ve sunucu aynı `titleFold` değerini üretmeli).
 *
 * DİKKAT: bu dosya bir kez yanlış kodlamayla kaydedilince buradaki eşlemeler
 * bozulmuş (hepsi U+FFFD olmuş) ve katlama sessizce çalışmaz hâle gelmişti.
 * Dosyayı UTF-8 dışında bir kodlamayla kaydeden düzenleyicilerden kaçının;
 * değişiklik sonrası bu fonksiyonu "İnşaat" → "insaat" ile doğrulayın.
 * @param {string} s Katlanacak metin.
 * @return {string} Aramaya hazır sadeleştirilmiş metin.
 */
function foldTrSearchJs(s) {
  return String(s || "")
      .replace(/İ/g, "i").replace(/I/g, "i").replace(/ı/g, "i")
      .replace(/Ş/g, "s").replace(/ş/g, "s")
      .replace(/Ğ/g, "g").replace(/ğ/g, "g")
      .replace(/Ü/g, "u").replace(/ü/g, "u")
      .replace(/Ö/g, "o").replace(/ö/g, "o")
      .replace(/Ç/g, "c").replace(/ç/g, "c")
      .toLowerCase();
}

const PRODUCT_CONTACT_RE =
  /(@[A-Za-z0-9._]{3,})|(\+?\d[\d\s\-()]{8,}\d)|([A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,})|(whatsapp|telegram|instagram|http:\/\/|https:\/\/|www\.)/i;

exports.publishProduct = onCall(
    CONSUMER_CALL_OPTS,
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      if (auth.token.suspended === true) {
        throw new HttpsError("permission-denied", "Hesap askida.");
      }
      const productId = (request.data && request.data.productId) || "";
      if (typeof productId !== "string" || !productId.trim()) {
        throw new HttpsError("invalid-argument", "productId gerekli.");
      }
      const ref = db.collection("products").doc(productId.trim());
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Urun bulunamadi.");
      }
      const d = snap.data() || {};
      if (d.ownerUid !== auth.uid) {
        throw new HttpsError("permission-denied", "Bu urun size ait degil.");
      }
      if (d.status !== "draft" && d.status !== "pending_review") {
        throw new HttpsError(
            "failed-precondition",
            "Yalniz taslak veya incelemedeki urun yayinlanabilir.",
        );
      }
      const title = String(d.title || "").trim();
      const description = String(d.description || "").trim();
      const photos = Array.isArray(d.photos) ? d.photos : [];
      const categoryCode = String(d.categoryCode || "").trim();
      const province = String(d.province || "").trim();
      if (title.length < 3 || title.length > 80 ||
          description.length < 10 || description.length > 2000 ||
          !categoryCode || photos.length < 1 || photos.length > 8 ||
          !province) {
        throw new HttpsError(
            "failed-precondition",
            "Yayin icin zorunlu alanlar eksik veya gecersiz.",
        );
      }
      if (d.priceType !== "negotiable") {
        const amt = Number(d.priceAmount);
        if (!(amt > 0)) {
          throw new HttpsError(
              "failed-precondition",
              "Sabit/baslangic fiyati gerekli.",
          );
        }
      }

      // Rate limit: 10 / Istanbul day + 30s burst
      const rlRef = db.collection("adminRateLimits")
          .doc(`product_publish_${auth.uid}`);
      const day = istanbulDayKey();
      await db.runTransaction(async (tx) => {
        const rlSnap = await tx.get(rlRef);
        const r = rlSnap.exists ? (rlSnap.data() || {}) : {};
        const lastMs = Number(r.lastAtMs || 0);
        const dayCount = r.dayKey === day ? Number(r.dayCount || 0) : 0;
        if (lastMs && Date.now() - lastMs < 30 * 1000) {
          throw new HttpsError(
              "resource-exhausted",
              "Cok sik yayin denemesi. Biraz sonra tekrar deneyin.",
          );
        }
        if (dayCount >= 10) {
          throw new HttpsError(
              "resource-exhausted",
              "Gunluk urun yayin limitine ulastiniz (10). Yarin tekrar deneyin.",
          );
        }
        tx.set(rlRef, {
          lastAtMs: Date.now(),
          dayKey: day,
          dayCount: dayCount + 1,
        }, {merge: true});
      });

      // Active cap
      const activeQ = await db.collection("products")
          .where("ownerUid", "==", auth.uid)
          .where("status", "in", ["active", "paused", "out_of_stock"])
          .limit(51)
          .get();
      if (activeQ.size >= 50 && d.status === "draft") {
        throw new HttpsError(
            "failed-precondition",
            "En fazla 50 aktif/duraklatilmis urun tutabilirsiniz.",
        );
      }

      // Mağaza bayrakları (adminConfig/runtime).
      let forceReview = false;
      try {
        const cfg = await db.collection("adminConfig").doc("runtime").get();
        const c = cfg.exists ? (cfg.data() || {}) : {};
        // productsEnabled yoksa açık sayılır; yalnız açık false kapatır.
        if (c.productsEnabled === false) {
          throw new HttpsError(
              "failed-precondition",
              "Magaza su an kapali. Daha sonra tekrar deneyin.",
          );
        }
        forceReview = c.productsForceReview === true;
      } catch (e) {
        if (e instanceof HttpsError) throw e;
        /* config okunamazsa yayın akışı bozulmasın */
      }

      const contactHit = PRODUCT_CONTACT_RE.test(title + " " + description);
      let nextStatus = "active";
      let moderationNote = null;
      if (forceReview || contactHit) {
        nextStatus = "pending_review";
        if (contactHit) moderationNote = "auto_contact_pattern";
      }

      const bits = {
        hiddenByModeration: d.hiddenByModeration === true,
        hiddenByUserSuspend: d.hiddenByUserSuspend === true,
        hiddenByArtisanHide: d.hiddenByArtisanHide === true,
      };
      const now = new Date().toISOString();
      const patch = {
        status: nextStatus,
        moderationHidden: recomputeModerationHidden(bits),
        updatedAt: now,
        titleFold: foldTrSearchJs(title),
      };
      if (!d.publishedAt) patch.publishedAt = now;
      if (moderationNote) patch.moderationNote = moderationNote;

      await ref.set(patch, {merge: true});
      return {
        ok: true,
        status: nextStatus,
        moderationHidden: patch.moderationHidden,
      };
    },
);

/**
 * Yayindaki urun icerigini gunceller - her zaman pending_review (K4/K33).
 */

exports.updateProductContent = onCall(
    CONSUMER_CALL_OPTS,
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      if (auth.token.suspended === true) {
        throw new HttpsError("permission-denied", "Hesap askida.");
      }
      const data = request.data || {};
      const productId = data.productId;
      if (typeof productId !== "string" || !productId.trim()) {
        throw new HttpsError("invalid-argument", "productId gerekli.");
      }
      const title = String(data.title || "").trim();
      const description = String(data.description || "").trim();
      const categoryCode = String(data.categoryCode || "").trim();
      const photos = Array.isArray(data.photos) ? data.photos : [];
      if (title.length < 3 || title.length > 80 ||
          description.length < 10 || description.length > 2000 ||
          !categoryCode || photos.length < 1 || photos.length > 8) {
        throw new HttpsError("invalid-argument", "Icerik alanlari gecersiz.");
      }
      const ref = db.collection("products").doc(productId.trim());
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Urun bulunamadi.");
      }
      const d = snap.data() || {};
      if (d.ownerUid !== auth.uid) {
        throw new HttpsError("permission-denied", "Bu urun size ait degil.");
      }
      if (d.status === "draft" || d.status === "removed") {
        throw new HttpsError(
            "failed-precondition",
            "Taslak icerigi dogrudan kaydedin; kaldirilmis urun duzenlenemez.",
        );
      }
      const bits = {
        hiddenByModeration: d.hiddenByModeration === true,
        hiddenByUserSuspend: d.hiddenByUserSuspend === true,
        hiddenByArtisanHide: d.hiddenByArtisanHide === true,
      };
      const now = new Date().toISOString();
      await ref.set({
        title,
        titleFold: foldTrSearchJs(title),
        description,
        categoryCode,
        photos,
        status: "pending_review",
        moderationHidden: recomputeModerationHidden(bits),
        updatedAt: now,
      }, {merge: true});
      return {ok: true, status: "pending_review"};
    },
);

exports.adminModerateProduct = onCall(
    {region: REGION},
    async (request) => {
      const auth = request.auth;
      const data = request.data || {};
      const decision = data.decision;
      const productId = data.productId;
      const note = typeof data.note === "string" ? data.note.trim() : "";

      if (typeof productId !== "string" || !productId.trim()) {
        throw new HttpsError("invalid-argument", "productId gerekli.");
      }
      const allowed = [
        "hide", "unhide", "approve", "reject", "force_remove", "hard_purge",
      ];
      if (!allowed.includes(decision)) {
        throw new HttpsError("invalid-argument", "Gecersiz karar.");
      }
      if (decision === "hard_purge") {
        if (auth && auth.token.role === "superadmin") {
          // ok
        } else {
          await assertCap(auth, "products.purge");
        }
      } else {
        await assertCap(auth, "products.moderate");
      }

      const ref = db.collection("products").doc(productId.trim());
      const snap = await ref.get();
      if (!snap.exists) {
        throw new HttpsError("not-found", "Urun bulunamadi.");
      }
      const d = snap.data() || {};
      const now = new Date().toISOString();
      const bits = {
        hiddenByModeration: d.hiddenByModeration === true,
        hiddenByUserSuspend: d.hiddenByUserSuspend === true,
        hiddenByArtisanHide: d.hiddenByArtisanHide === true,
      };

      if (decision === "hard_purge") {
        try {
          const bucket = getStorage().bucket();
          await bucket.deleteFiles({
            prefix: `product/${d.ownerUid}/${productId.trim()}`,
          });
        } catch (e) {
          logger.warn(`product hard_purge storage: ${e}`);
        }
        await ref.delete();
        await writeAuditLog({
          actorUid: auth.uid,
          action: "moderate_product",
          targetType: "product",
          targetId: productId.trim(),
          before: {status: d.status, moderationHidden: d.moderationHidden},
          after: {decision: "hard_purge"},
        });
        return {ok: true, decision};
      }

      const patch = {
        moderatedBy: auth.uid,
        moderatedAt: now,
        updatedAt: now,
      };
      if (note) patch.adminModerationNote = note.slice(0, 300);

      if (decision === "hide") {
        bits.hiddenByModeration = true;
        patch.hiddenByModeration = true;
      } else if (decision === "unhide") {
        bits.hiddenByModeration = false;
        patch.hiddenByModeration = false;
      } else if (decision === "approve") {
        if (d.status === "pending_review") patch.status = "active";
        if (!d.publishedAt) patch.publishedAt = now;
        patch.moderationNote = FieldValue.delete();
      } else if (decision === "reject") {
        patch.status = "draft";
        if (note) patch.moderationNote = note.slice(0, 300);
      } else if (decision === "force_remove") {
        bits.hiddenByModeration = true;
        patch.hiddenByModeration = true;
        patch.status = "removed";
        patch.removedBy = "admin";
        patch.removedAt = now;
        if (note) patch.removedReason = note.slice(0, 300);
      }
      patch.moderationHidden = recomputeModerationHidden(bits);

      await ref.set(patch, {merge: true});

      // Notify owner on reject / force_remove
      if ((decision === "reject" || decision === "force_remove") &&
          d.ownerUid) {
        const t = decision === "reject" ?
          "Urun yayini reddedildi" : "Urun kaldirildi";
        const b = decision === "reject" ?
          `"${d.title || "Urun"}" taslaga alindi. Duzenleyip yeniden yayinlayin.` :
          `"${d.title || "Urun"}" yonetim tarafindan kaldirildi.`;
        try {
          await saveNotification(d.ownerUid, `product_${productId.trim()}`, {
            type: "product",
            title: t,
            body: b,
            productId: productId.trim(),
          });
          await sendPushToUid(d.ownerUid, t, b, {
            type: "product",
            productId: productId.trim(),
          });
        } catch (e) {
          logger.warn(`product moderate notify: ${e}`);
        }
      }

      await writeAuditLog({
        actorUid: auth.uid,
        action: "moderate_product",
        targetType: "product",
        targetId: productId.trim(),
        before: {
          status: d.status,
          moderationHidden: d.moderationHidden === true,
        },
        after: {decision, ...patch},
      });
      return {ok: true, decision, moderationHidden: patch.moderationHidden};
    },
);

/**
 * Askiya alma / usta gizleme cascade - urun hide bits.
 */
async function cascadeProductsHideBits(ownerUid, bitField, value) {
  const qs = await db.collection("products")
      .where("ownerUid", "==", ownerUid)
      .limit(100)
      .get();
  if (qs.empty) return;
  const batch = db.batch();
  const now = new Date().toISOString();
  qs.docs.forEach((doc) => {
    const d = doc.data() || {};
    const bits = {
      hiddenByModeration: d.hiddenByModeration === true,
      hiddenByUserSuspend: d.hiddenByUserSuspend === true,
      hiddenByArtisanHide: d.hiddenByArtisanHide === true,
    };
    bits[bitField] = value === true;
    const patch = {
      [bitField]: value === true,
      moderationHidden: recomputeModerationHidden(bits),
      updatedAt: now,
    };
    batch.set(doc.ref, patch, {merge: true});
  });
  await batch.commit();
}

// Report auto-hide for products (threshold 3 unique reporters).

exports.onProductReportWritten = onDocumentWritten(
    {document: "reports/{reportId}", region: REGION},
    async (event) => {
      const before =
        event.data && event.data.before && event.data.before.exists;
      const after =
        event.data && event.data.after && event.data.after.exists;
      if (before || !after) return; // only create
      const r = event.data.after.data() || {};
      if (r.targetType !== "product") return;
      const productId = r.targetId;
      if (!productId) return;
      const ref = db.collection("products").doc(productId);
      try {
        await db.runTransaction(async (tx) => {
          const snap = await tx.get(ref);
          if (!snap.exists) return;
          const d = snap.data() || {};
          const count = Number(d.reportCount || 0) + 1;
          const bits = {
            hiddenByModeration: d.hiddenByModeration === true,
            hiddenByUserSuspend: d.hiddenByUserSuspend === true,
            hiddenByArtisanHide: d.hiddenByArtisanHide === true,
          };
          const patch = {
            reportCount: count,
            updatedAt: new Date().toISOString(),
          };
          if (count >= 3) {
            bits.hiddenByModeration = true;
            patch.hiddenByModeration = true;
            patch.moderationHidden = true;
            patch.moderatedBy = "system";
            patch.moderatedAt = new Date().toISOString();
            patch.adminModerationNote = "auto_hide_report_threshold";
          } else {
            patch.moderationHidden = recomputeModerationHidden(bits);
          }
          tx.set(ref, patch, {merge: true});
        });
      } catch (e) {
        logger.warn(`onProductReportWritten: ${e}`);
      }
    },
);

// Soft-delete purge (30 days)
exports.purgeRemovedProducts = onSchedule(
    {
      schedule: "every 24 hours",
      region: REGION,
      timeZone: "Europe/Istanbul",
    },
    async () => {
      const cutoff = new Date(
          Date.now() - 30 * 24 * 60 * 60 * 1000,
      ).toISOString();
      const qs = await db.collection("products")
          .where("status", "==", "removed")
          .where("removedAt", "<=", cutoff)
          .limit(50)
          .get();
      for (const doc of qs.docs) {
        const d = doc.data() || {};
        try {
          if (d.ownerUid) {
            const bucket = getStorage().bucket();
            await bucket.deleteFiles({
              prefix: `product/${d.ownerUid}/${doc.id}`,
            });
          }
        } catch (e) {
          logger.warn(`purge product storage ${doc.id}: ${e}`);
        }
        await doc.ref.delete();
        logger.info(`purged product ${doc.id}`);
      }
    },
);

// ---------------------------------------------------------------------------
// Ürün talebi GÜNLÜK ÖZETİ (Mağaza > İlan Ver)
// ---------------------------------------------------------------------------

/**
 * Gün içinde açılan ürün taleplerini toplayıp ilgili satıcılara TEK bildirim
 * gönderir.
 *
 * NEDEN ANLIK DEĞİL (kullanıcı kararı — PLAN-Magaza.md §Aşama 3):
 * Her talepte push atmak, talep sayısı arttıkça bildirim yorgunluğu yaratır;
 * kullanıcı push'u tamamen kapatınca İŞ İLANI bildirimlerini de kaçırır.
 * Yani ikincil bir özellik asıl işi bozardı. Özet, kişi başına tavanı
 * **günde 1 bildirime** sabitler — talep sayısından bağımsız.
 *
 * ALICI SEÇİMİ: aynı il + aynı kategoride YAYINDA ürünü olanlar. Ayrı bir
 * "satıcı" rolü yok (herkes satabilir), bu yüzden ölçüt davranıştan türer.
 * Ürünü olmayan ama ilgilenen kişiler için "tercih" kaynağı ERTELENDİ —
 * varsayıma dayanıyor ve şu an test edilemez.
 *
 * @return {Promise<void>}
 */
exports.sendProductRequestDigest = onSchedule(
    {
      // Akşam 19:00 — insanların telefonuna baktığı, mesai dışı bir saat.
      schedule: "0 19 * * *",
      region: REGION,
      timeZone: "Europe/Istanbul",
      timeoutSeconds: 300,
    },
    async () => {
      const since = new Date(Date.now() - 24 * 3600 * 1000).toISOString();
      let talepler;
      try {
        // ⚠️ Alan SIRASI mevcut bileşik indekse uyar:
        //   jobs → category ASC, status ASC, createdAt DESC
        // `status` filtresini sorgudan çıkarıp bellekte yapsaydık YENİ bir
        // indeks (category + createdAt) gerekirdi; onsuz sorgu
        // `failed-precondition` atar ve özet HİÇ gönderilmez.
        talepler = await db.collection("jobs")
            .where("category", "==", PRODUCT_REQUEST_CATEGORY)
            .where("status", "==", "open")
            .where("createdAt", ">=", since)
            .limit(500)
            .get();
      } catch (e) {
        logger.error("productRequestDigest sorgusu düştü", e);
        return;
      }
      if (talepler.empty) {
        logger.info("productRequestDigest: 24 saatte talep yok");
        return;
      }

      // İl → talep sayısı.
      const ilSayaci = new Map();
      talepler.docs.forEach((d) => {
        const j = d.data() || {};
        const il = j.province || "";
        if (!il) return;
        ilSayaci.set(il, (ilSayaci.get(il) || 0) + 1);
      });
      if (ilSayaci.size === 0) return;

      // Alıcılar: o ilde YAYINDA ürünü olanlar. Ürün dokümanı hem ili hem
      // sahibini taşıdığı için tek sorgu yeter (ayrı satıcı listesi yok).
      let urunler;
      try {
        urunler = await db.collection("products")
            .where("status", "==", "active")
            .limit(2000)
            .get();
      } catch (e) {
        logger.error("productRequestDigest ürün sorgusu düştü", e);
        return;
      }

      // uid → o kişinin ilindeki talep sayısı (tekilleştirilmiş).
      const alicilar = new Map();
      urunler.docs.forEach((d) => {
        const p = d.data() || {};
        if (p.moderationHidden === true) return;
        const uid = p.ownerUid;
        const il = p.province || "";
        if (!uid || !il) return;
        const adet = ilSayaci.get(il);
        if (!adet) return;
        alicilar.set(uid, adet);
      });

      // Kendi talebini açan kişiye kendi talebini haber verme.
      talepler.docs.forEach((d) => {
        const j = d.data() || {};
        if (j.customerId) alicilar.delete(j.customerId);
      });

      if (alicilar.size === 0) {
        logger.info("productRequestDigest: eşleşen satıcı yok");
        return;
      }

      let gonderilen = 0;
      for (const [uid, adet] of alicilar) {
        const baslik = "Yeni ürün talepleri";
        const govde = adet === 1 ?
          "Bulunduğun ilde 1 yeni ürün talebi var." :
          `Bulunduğun ilde ${adet} yeni ürün talebi var.`;
        // Günde tek doküman: aynı gün ikinci kez çalışsa üzerine yazar,
        // bildirim merkezi çoğalmaz.
        const gunAnahtari = istanbulDayKey();
        try {
          await saveNotification(uid, `productDigest_${gunAnahtari}`, {
            type: "job",
            kind: "productDigest",
            title: baslik,
            body: govde,
          });
          await sendPushToUid(uid, baslik, govde, {
            type: "job",
            kind: "productDigest",
          });
          gonderilen++;
        } catch (e) {
          logger.warn(`productRequestDigest ${uid}: ${e}`);
        }
      }
      logger.info(
          `productRequestDigest: ${gonderilen} kişiye özet gönderildi ` +
          `(${ilSayaci.size} il)`);
    },
);

