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
//     Ürün talebi: aynı il + kategori satıcılarına anlık.
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
const {onMessagePublished} = require("firebase-functions/v2/pubsub");
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
// Node yerleşiği — ucuz, tembel yüklemeye gerek yok. Kullanan iki yer var:
// premium token hash'i ve moderatör hesabının geçici şifresi.
const crypto = require("crypto");

initializeApp();
const db = getFirestore();

// Maliyet emniyeti: istismar/sonsuz döngü durumunda fonksiyonlar sınırsız
// ölçeklenmesin (Gen2 varsayılan tavanı 100 örnek). Bu ölçekte 10 örnek
// fazlasıyla yeter; yük artarsa istekler kuyrukta bekler, fatura patlamaz.
setGlobalOptions({maxInstances: 10});

// Fonksiyonları Firestore veritabanına yakın bölgede çalıştır (gecikme/maliyet).
const REGION = "europe-west1";

// App Check zorlaması — tüketici (mobil) çağrıları. İstemci jetonu otomatik
// gönderir (main.dart → FirebaseAppCheck.activate).
const CONSUMER_CALL_OPTS = {region: REGION, enforceAppCheck: true};

// App Check zorlaması — admin (web paneli) çağrıları.
//
// 2026-08-15'e kadar admin callable'ları YALNIZ `{region: REGION}` kullanıyordu,
// yani App Check zorlanmıyordu. Gerekçe "web'de reCAPTCHA anahtarı henüz yok"
// idi; anahtar Oturum 76'da dolduruldu (`kAppCheckWebRecaptchaKey`) ve
// `main_admin.dart` onu etkinleştiriyor — gerekçe geçersizleşti.
//
// Neden önemli: `assertCap` yetkiyi doğrular ama isteğin GERÇEK panelden mi
// geldiğini doğrulamaz. App Check'in işi tam olarak budur — çalınmış bir admin
// oturumunun curl/script ile kullanılmasını zorlaştırır. Admin yetkileri
// (kullanıcı askıya alma, premium tanımlama, toplu işlem) en değerli hedeftir.
//
// ⚠️ ŞU AN KAPALI — ÖNCE reCAPTCHA ALAN ADI KAYDI GEREKİYOR.
//
// 2026-08-15'te açıldı ve panel ANINDA kilitlendi: reCAPTCHA v3 anahtarı
// yalnız `alljob1.web.app`, `alljob1.firebaseapp.com` ve `localhost` için
// kayıtlıydı; panel ise ÖZEL ALAN ADINDAN (`admin.ilandahizmet.com`)
// açılıyor. Kayıtlı olmayan alanda jeton üretilemez → her admin çağrısı
// `unauthenticated` döner ve yönetici paneli tamamen erişilemez olur.
//
// AÇMA SIRASI (bu sırayla, atlanırsa panel yine kilitlenir):
//   1. https://www.google.com/recaptcha/admin → mevcut v3 anahtarına
//      `admin.ilandahizmet.com` alan adını EKLE
//   2. Firebase Console → App Check → web uygulaması kaydını doğrula
//   3. Panelden birkaç işlem yap; App Check metriklerinde "doğrulanmış"
//      istek göründüğünü teyit et (MONITOR modunda)
//   4. Ancak o zaman burayı `enforceAppCheck: true` yap ve deploy et
//
// Yetki kaybı YOK: `assertCap` / `assertSuperadmin` kapıları yerinde
// duruyor. App Check ek bir katmandır (çalınmış oturumun panel dışından
// kullanılmasını zorlaştırır), tek başına yetki sınırı değildir.
const ADMIN_CALL_OPTS = {region: REGION};

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
// USTA fan-out'una girmez. Alıcı: aynı il + aynı productCategoryCode
// satıcıları (yayında ürün veya mağaza kategorisi). Anlık bildirim
// `onJobCreated` → `notifyProductRequestSellers`; akşam özeti
// `sendProductRequestDigest` (anlık almış olanı atlar).
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
  // Marka adresi — kurucu ikinci yönetici hesabı (2026-08-15).
  // Bu liste yalnız BOOTSTRAP içindir: adres burada olsa bile kişi
  // `claimAdminAccess` akışını çalıştırmadan yönetici OLMAZ, ayrıca
  // e-postasının Auth tarafında doğrulanmış olması gerekir.
  "ilandahizmet@gmail.com",
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
 * Birden çok kullanıcının push dökümanını TEK turda okur (2026-08-14).
 *
 * Neden: fan-out her alıcı için ayrı `getFcmTokens(uid)` çağırıyordu —
 * 120 alıcı = 120 ayrı Firestore round-trip. `getAll` aynı işi tek istekte
 * yapar: okuma SAYISI aynı kalır (Firestore doküman başına faturalar) ama
 * ağ gidiş-dönüşü 120 → 1 olur; CF süresi ve dolayısıyla hesaplama
 * faturası belirgin düşer.
 *
 * Legacy public `users/{uid}.fcmTokens` yalnız private boşsa okunur —
 * ikinci tur yalnız gerektiği kadar dökümanı kapsar.
 *
 * Dönen: Map<uid, {tokens, snap}>
 */
async function getFcmTokensBulk(uids) {
  const sonuc = new Map();
  if (!uids || uids.length === 0) return sonuc;

  // Firestore getAll tek çağrıda sınırlı sayıda referans alır; parçala.
  const CHUNK = 250;
  const eksikLegacy = [];

  for (let i = 0; i < uids.length; i += CHUNK) {
    const dilim = uids.slice(i, i + CHUNK);
    const refs = dilim.map((uid) =>
      db.collection("users").doc(uid).collection("private").doc("push"));
    const snaps = await db.getAll(...refs);
    snaps.forEach((snap, k) => {
      const uid = dilim[k];
      const d = snap.exists ? (snap.data() || {}) : {};
      const list = Array.isArray(d.fcmTokens) ? d.fcmTokens : [];
      sonuc.set(uid, {tokens: list, snap});
      if (list.length === 0) eksikLegacy.push(uid);
    });
  }

  // Legacy yedek: yalnız private'ta token bulunmayanlar için.
  for (let i = 0; i < eksikLegacy.length; i += CHUNK) {
    const dilim = eksikLegacy.slice(i, i + CHUNK);
    const refs = dilim.map((uid) => db.collection("users").doc(uid));
    const snaps = await db.getAll(...refs);
    snaps.forEach((snap, k) => {
      const uid = dilim[k];
      const d = snap.exists ? (snap.data() || {}) : {};
      if (Array.isArray(d.fcmTokens) && d.fcmTokens.length > 0) {
        const mevcut = sonuc.get(uid) || {tokens: [], snap: null};
        sonuc.set(uid, {tokens: d.fcmTokens, snap: mevcut.snap});
      }
    });
  }

  return sonuc;
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
  // Anlık ürün talebi — aynı tercih (kullanıcı bir anahtarla ikisini keser).
  if (t === "job" && data.kind === "productRequest") return "productDigest";
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
 * Neden gerekli: ilan yayınlanınca EŞLEŞEN USTALARA bildirim gider
 * (`onJobCreated` fan-out). Limit olmadan tek kullanıcı sınırsız ilan açıp
 * platform çapında bildirim spam'i üretebilir.
 */
const MAX_OPEN_JOBS = 5;
const MAX_JOBS_PER_DAY = 10;

// ── Maliyet tavanları (2026-08-11) ──────────────────────────────────────
// Amaç: fatura patlamasın, kullanıcı da "bildirim gelmiyor" demesin.
// Kalabalık meslek+ilde 500×N sorgu + herkese yazı pahalıydı. Tavanlar
// makul; fazlası Keşfet → İlanlar listesinden hâlâ görünür.
/** Meslek sorgusu başına en fazla profil okuması (eskiden 500). */
const JOB_FANOUT_QUERY_LIMIT = 200;
/** İl eşleşmesinden sonra bildirim alacak en fazla usta (eskiden limitsiz). */
const JOB_FANOUT_RECIPIENT_CAP = 120;
// NOT: `JOB_FANOUT_TOKEN_CONCURRENCY` 2026-08-14'te kaldırıldı. Token/prefs
// okuması artık `getFcmTokensBulk` ile TEK turda yapılıyor; paralel worker
// havuzuna gerek kalmadı (bkz. onJobCreated).

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
    // Sayaç yalnız "limitin altında mı?" sorusuna hizmet ediyor; tam sayıya
    // ihtiyaç yok. Limitsiz `.get()` bırakılırsa 10.000 ilanı olan bir hesapta
    // HER ilan yazımında 10.000 doküman okunurdu. Tavan = limit + biraz pay
    // (süresi dolmuşlar elendiği için birkaç fazla okumak gerekir).
    const snap = await db.collection("jobs")
        .where("customerId", "==", customerId)
        .where("status", "==", "open")
        .limit(50)
        .get();
    // Süresi dolmuş ilanlar `open` yazar ama yeni ilana engel OLMAMALI.
    const now = Date.now();
    let open = 0;
    snap.forEach((d) => {
      const exp = Number(d.data().expiresAtMs || 0);
      if (!exp || exp > now) open += 1;
    });
    // `updatedAtMs`: rezervasyon damgasıyla KARŞILAŞTIRILABİLİR olması için
    // sayısal. `onJobCreated` içindeki eşzamanlılık kapısı "rezervasyon bu
    // tazelemeden sonra mı yapıldı?" sorusunu bu iki sayıyla yanıtlar; ISO
    // dizesi karşılaştırması kırılgan olurdu.
    await db.collection("users").doc(customerId)
        .collection("private").doc("jobStats")
        .set({
          openCount: open,
          updatedAt: new Date().toISOString(),
          updatedAtMs: Date.now(),
        }, {merge: true});
  } catch (e) {
    logger.warn(`refreshOpenJobCount failed for ${customerId}: ${e}`);
  }
}

/**
 * Kullanıcının TASLAK ürün sayacını tazeler (`private/productStats`).
 *
 * Yayınlama tarafı `publishProduct` içinde korunuyordu (10/gün + 50 aktif),
 * ama taslak yazımı doğrudan Firestore'a gidiyor ve adet sınırı yoktu:
 * doğrulanmış e-postalı bir hesap SDK ile yüz binlerce taslak yazıp hem
 * koleksiyonu şişirebilir hem her yazımda bu trigger'ı tetikleyip fatura
 * üretebilirdi. Kural (`productDraftQuotaOk`) bu sayaca bakar.
 *
 * `refreshOpenJobCount` ile aynı desen: sayaç yalnız "limitin altında mı?"
 * sorusuna hizmet eder, bu yüzden okuma tavanlıdır.
 */
async function refreshDraftProductCount(ownerUid) {
  if (!ownerUid) return;
  try {
    const snap = await db.collection("products")
        .where("ownerUid", "==", ownerUid)
        .where("status", "==", "draft")
        .limit(150)
        .get();
    await db.collection("users").doc(ownerUid)
        .collection("private").doc("productStats")
        .set({
          draftCount: snap.size,
          updatedAt: new Date().toISOString(),
          updatedAtMs: Date.now(),
        }, {merge: true});
  } catch (e) {
    logger.warn(`refreshDraftProductCount failed for ${ownerUid}: ${e}`);
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

// ───────────────── ARGO / MÜSTEHCEN DENETİMİ ─────────────────
//
// SUNUCU TARAFI KALDIRILDI (2026-08-23, kullanıcı kararı).
//
// Kısa süre boyunca burada bir küfür sözlüğü ve `severeMatches` vardı;
// ağır içerikli mesajı otomatik olarak `reports` kuyruğuna yazıyordu.
// Yanlış bir süreçti — bkz. `onMessageCreated` içindeki not.
//
// Filtrenin tamamı artık İSTEMCİDE yaşıyor:
// `lib/core/utils/content_filter.dart`
//   * gönderirken uyarı (`ContentFilter.inspect`)
//   * alıcının ekranında maskeleme (`ContentFilter.mask`)
//
// Sözlüğü tek yerde tutmak ayrıca bir bakım yükünü kaldırdı: iki liste
// ayrışırsa istemci uyarıp sunucu kaçırıyordu, artık tek kaynak var.
//
// Moderasyon YALNIZ kullanıcı şikâyetiyle başlar (`reports` koleksiyonu).

// `flagMessageForReview` KALDIRILDI (2026-08-23).
//
// Ağır içerikli mesajı otomatik olarak `reports` kuyruğuna yazıyordu.
// Kullanıcı kararıyla kaldırıldı: kimsenin şikâyet etmediği mesaj
// moderasyona düşmemeli — kuyruk dolar, gerçek şikâyetler kaybolur ve
// özel yazışma istenmeden incelemeye alınmış olur.
//
// Yerine istemcide MASKELEME var (`ContentFilter.mask`); moderasyon
// yalnız kullanıcı şikâyetiyle başlar.

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

      // OTOMATİK ŞİKÂYET KALDIRILDI (2026-08-23, kullanıcı kararı).
      //
      // Kısa süre boyunca ağır içerikli her mesaj `reports` kuyruğuna
      // otomatik düşüyordu. Yanlış bir süreçti:
      //
      //  * Moderatör kuyruğu, kimsenin şikâyet etmediği mesajlarla dolar ve
      //    GERÇEK şikâyetler arasında kaybolur.
      //  * İki kişinin kendi aralarında konuşurken küfretmesi bir ihlal
      //    değildir — mağdur yoksa moderasyon konusu da yoktur.
      //  * Kimse istemeden özel yazışmayı incelemeye almak, kullanıcının
      //    beklediği gizliliği aşar.
      //
      // Yerine iki katman kaldı:
      //  1. İstemcide MASKELEME — alıcı `***` görür (`ContentFilter.mask`).
      //  2. ŞİKÂYET YOLU — rahatsız olan kişi mesajı bildirir, kayıt
      //     kuyruğa o zaman düşer ve gerçek metniyle incelenir.
      //
      // `severeMatches` yardımcısı duruyor: şikâyet gelen mesajı moderatöre
      // "filtre bunu ağır buldu" diye işaretlemek için ileride kullanılabilir.

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
 * Ürün talebi alıcıları: aynı il + (varsa) aynı ürün kategorisi.
 *
 * İki kaynak birleşir (uid tekilleşir):
 *  1) Yayında (`active`, gizlenmemiş) ürünü olanlar — davranıştan türer.
 *  2) Mağaza açmış ve `shopCategories` içinde kodu seçmiş olanlar —
 *     henüz ürünü olmayan satıcı da talebi görsün.
 *
 * [categoryCode] boşsa yalnız il eşleşir (eski talepler / eksik form).
 * @return {Promise<Set<string>>}
 */
async function collectProductRequestSellerUids({
  province, categoryCode, excludeUid, productDocs,
}) {
  const uids = new Set();
  if (!province) return uids;

  // uid → yayındaki ürünlerinden çıkan iller. shopServiceAreas boş
  // kayıtlarda il buradan türer (canlı vaka: Yusuf, Bursa ürünü var,
  // mağaza bölgesi yazılmamış → eski kod "satıcı yok" diyordu).
  const ownerProvinces = new Map();
  try {
    const urunler = productDocs || await db.collection("products")
        .where("status", "==", "active")
        .limit(1200)
        .get();
    urunler.docs.forEach((d) => {
      const p = d.data() || {};
      if (p.moderationHidden === true) return;
      const uid = p.ownerUid;
      if (!uid || uid === excludeUid) return;
      const il = p.province || "";
      if (il) {
        if (!ownerProvinces.has(uid)) ownerProvinces.set(uid, new Set());
        ownerProvinces.get(uid).add(il);
      }
      if (il !== province) return;
      if (categoryCode && (p.categoryCode || "") !== categoryCode) return;
      uids.add(uid);
    });
  } catch (e) {
    logger.warn(`productRequest ürün sorgusu: ${e}`);
  }

  if (categoryCode) {
    try {
      const shops = await db.collection("users")
          .where("shopCategories", "array-contains", categoryCode)
          .limit(JOB_FANOUT_QUERY_LIMIT)
          .get();
      const eksikBolge = [];
      shops.docs.forEach((d) => {
        if (d.id === excludeUid) return;
        const u = d.data() || {};
        if (u.hasShopProfile !== true) return;
        const areas = Array.isArray(u.shopServiceAreas) ?
          u.shopServiceAreas : [];
        const alandan = areas.some((a) => a && a.province === province);
        const urunden = ownerProvinces.has(d.id) &&
            ownerProvinces.get(d.id).has(province);
        if (alandan || urunden) {
          uids.add(d.id);
          return;
        }
        if (areas.length === 0) eksikBolge.push(d.id);
      });
      // Mağaza bölgesi hiç yazılmamışsa usta hizmet bölgesine bak.
      if (eksikBolge.length > 0) {
        const refs = eksikBolge
            .slice(0, 50)
            .map((id) => db.collection("artisanProfiles").doc(id));
        const snaps = await db.getAll(...refs);
        snaps.forEach((s, i) => {
          if (!s.exists) return;
          const areas = Array.isArray(s.data().serviceAreas) ?
            s.data().serviceAreas : [];
          if (areas.some((a) => a && a.province === province)) {
            uids.add(eksikBolge[i]);
          }
        });
      }
    } catch (e) {
      logger.warn(`productRequest mağaza sorgusu: ${e}`);
    }
  }
  return uids;
}

/**
 * Yeni ürün talebi → eşleşen satıcılara anlık bildirim (in-app + push).
 * Tercih `productDigest` kapalıysa ikisi de kesilir.
 * @return {Promise<void>}
 */
async function notifyProductRequestSellers(job, jobId) {
  const province = job.province || "";
  const categoryCode = job.productCategoryCode || "";
  if (!province || !categoryCode) {
    logger.info(
        `productRequest ${jobId}: il veya kategori yok — anlık atlandı`);
    return;
  }
  const uids = await collectProductRequestSellerUids({
    province,
    categoryCode,
    excludeUid: job.customerId,
  });
  if (uids.size === 0) {
    logger.info(
        `productRequest ${jobId}: eşleşen satıcı yok ` +
        `(${province} / ${categoryCode})`);
    return;
  }
  const alicilar = [...uids].slice(0, JOB_FANOUT_RECIPIENT_CAP);
  const title = `${province} bölgesinde yeni ürün talebi`;
  const district = job.district ? ` · ${job.district}` : "";
  const body = `${job.title || "Yeni talep"}${district}`;
  const day = istanbulDayKey();
  let gonderilen = 0;
  for (const uid of alicilar) {
    try {
      const snap = await getPushDoc(uid);
      if (!(await isPushCategoryAllowed(uid, "productDigest", snap))) continue;
      await saveNotification(uid, `productRequest_${jobId}`, {
        type: "job",
        kind: "productRequest",
        title,
        body,
        jobId,
      });
      await sendPushToUid(uid, title, body, {
        type: "job",
        kind: "productRequest",
        jobId,
      });
      // Akşam özeti aynı kişiye ikinci kez gitmesin.
      await db.collection("users").doc(uid)
          .collection("private").doc("push")
          .set({productRequestInstantDay: day}, {merge: true});
      gonderilen++;
    } catch (e) {
      logger.warn(`productRequest ${jobId} ${uid}: ${e}`);
    }
  }
  logger.info(
      `productRequest ${jobId}: ${gonderilen}/${alicilar.length} satıcıya ` +
      `anlık (${province} / ${categoryCode})`);
}

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
        // "günlük" | "eşzamanlı" — kullanıcıya doğru cümleyi kurmak için.
        let limitKind = "daily";

        // EŞZAMANLI AÇIK İLAN LİMİTİ — burada da kesilir.
        //
        // `firestore.rules` → `openJobQuotaOk()` aynı sınırı uygular ama
        // sayacı (`jobStats.openCount`) BU fonksiyon ilan yazıldıktan SONRA
        // tazeler. Yani arka arkaya gönderilen istekler aynı eski sayacı
        // okur ve hepsi kuraldan geçer (TOCTOU). Kural motoru transaction
        // yapamaz; tek atomik yer burasıdır.
        //
        // `openReserved`: aynı rate-limit dokümanında tutulan REZERVASYON
        // sayacı. Gerçek sayaç (`openCount`) sorguyla tazelenmeye devam
        // eder — bu yalnız aynı andaki istekleri sıraya sokar.
        const jobStatsRef = db.collection("users").doc(job.customerId)
            .collection("private").doc("jobStats");
        try {
          await db.runTransaction(async (tx) => {
            // Transaction'da TÜM okumalar yazımlardan önce gelmeli.
            const [snap, statsSnap] = await Promise.all([
              tx.get(rlRef),
              tx.get(jobStatsRef),
            ]);
            const r = snap.exists ? (snap.data() || {}) : {};
            const dayCount = r.dayKey === day ? Number(r.dayCount || 0) : 0;
            if (dayCount >= MAX_JOBS_PER_DAY) {
              overLimit = true;
              limitKind = "daily";
              return;
            }

            // Sunucunun bildiği açık ilan sayısı + bu turda rezerve edilmiş
            // ama sayaca henüz yansımamış olanlar.
            const stats = statsSnap.exists ? (statsSnap.data() || {}) : {};
            const openCount = Number(stats.openCount || 0);
            // Rezervasyon yalnız sayaç tazelenene kadar anlamlı; damga eski
            // ise (sayaç güncellenmiş) sıfırdan sayılır.
            const reservedFresh =
              Number(r.openReservedAtMs || 0) > Number(stats.updatedAtMs || 0);
            const reserved = reservedFresh ? Number(r.openReserved || 0) : 0;
            if (openCount + reserved >= MAX_OPEN_JOBS) {
              overLimit = true;
              limitKind = "concurrent";
              return;
            }

            tx.set(rlRef, {
              dayKey: day,
              dayCount: dayCount + 1,
              openReserved: reserved + 1,
              openReservedAtMs: Date.now(),
              lastAtMs: Date.now(),
            }, {merge: true});
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
          const b = limitKind === "concurrent"
            ? `Aynı anda en fazla ${MAX_OPEN_JOBS} açık ilanınız olabilir. ` +
              "Yayındaki ilanlardan birini kaldırıp tekrar deneyin."
            : `Günlük ilan hakkınızı doldurdunuz (${MAX_JOBS_PER_DAY}). ` +
              "Yarın tekrar deneyebilirsiniz.";
          await saveNotification(job.customerId, `job_${jobId}`,
              {type: "job", title: t, body: b, jobId});
          logger.warn(
              `job ${jobId} rate-limited (${limitKind}) for ${job.customerId}`);
          return;
        }
      }

      // Yalnızca açık (yeni) ilanlar; kategori/il yoksa eşleşme yapılamaz.
      if ((job.status || "open") !== "open") return;
      const category = job.category || "";
      const province = job.province || "";
      if (!category || !province) return;

      // ÜRÜN TALEBİ ustalara gitmez. Aynı il + kategorideki satıcılara
      // anlık gider; akşam özeti anlık almayanları tamamlar.
      // Günlük ilan limiti YUKARIDA zaten işledi (talep de ona tabidir).
      if (category === PRODUCT_REQUEST_CATEGORY) {
        await notifyProductRequestSellers(job, jobId);
        return;
      }

      const isQuickSupport = category === QUICK_SUPPORT_CATEGORY;

      // Alıcı profilleri:
      //  - Hemen Lazım: "other" kodu veya legacy quick_support.
      //  - Klasik: professions array-contains + legacy profession== (birleşik).
      //  - QUERY_LIMIT: maliyet tavanı (eskiden 500).
      let profileDocs = [];
      if (isQuickSupport) {
        const [byOther, byQs, bySingleOther] = await Promise.all([
          db.collection("artisanProfiles")
              .where("professions", "array-contains", "other")
              .limit(JOB_FANOUT_QUERY_LIMIT)
              .get(),
          db.collection("artisanProfiles")
              .where("professions", "array-contains", QUICK_SUPPORT_CATEGORY)
              .limit(JOB_FANOUT_QUERY_LIMIT)
              .get(),
          db.collection("artisanProfiles")
              .where("profession", "==", "other")
              .limit(JOB_FANOUT_QUERY_LIMIT)
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
              .limit(JOB_FANOUT_QUERY_LIMIT)
              .get(),
          db.collection("artisanProfiles")
              .where("profession", "==", category)
              .limit(JOB_FANOUT_QUERY_LIMIT)
              .get(),
        ]);
        const map = new Map();
        byArray.docs.forEach((d) => map.set(d.id, d));
        bySingle.docs.forEach((d) => map.set(d.id, d));
        profileDocs = [...map.values()];
      }
      if (profileDocs.length === 0) return;

      // Bölgede hizmet verenler (ilan sahibi hariç) + skor.
      // NOT: Hemen Lazım da İL düzeyinde (Job.matchesArtisan paritesi).
      // Müsait olmayan da listede kalır (ürün kararı: görür + bildirim alır).
      const scored = [];
      profileDocs.forEach((d) => {
        if (d.id === job.customerId) return;
        const data = d.data() || {};
        const areas = Array.isArray(data.serviceAreas) ? data.serviceAreas : [];
        if (!areas.some((a) => a && a.province === province)) return;
        // Öncelik: aktif (pause değil) → alwaysAvailable → premium → jitter.
        // Jitter aynı skorda adaleti korur (hep aynı 120 kişi olmasın).
        let score = Math.random();
        if (data.manualPause !== true) score += 100;
        if (data.alwaysAvailable === true) score += 20;
        if (data.isPremium === true) score += 10;
        const done = Number(data.completedJobs || 0);
        if (Number.isFinite(done) && done > 0) {
          score += Math.min(done, 40) * 0.05;
        }
        scored.push({uid: d.id, score});
      });
      if (scored.length === 0) {
        logger.info(`Job ${jobId}: no matching artisans in ${province}`);
        return;
      }
      scored.sort((a, b) => b.score - a.score);
      const matchCount = scored.length;
      const capped = scored.slice(0, JOB_FANOUT_RECIPIENT_CAP);
      const recipientUids = capped.map((x) => x.uid);

      // Not: il adına ek ("'de/'da") ünlü uyumu gerektirdiğinden ekli kalıp
      // kullanılmaz. Görünen ad "Kolay İş"; depolama kodu quick_support.
      const kind = isQuickSupport ? "Kolay İş ilanı" : "iş ilanı";
      const title =
        `${isQuickSupport ? "⚡ " : ""}${province} bölgesinde yeni ${kind}`;
      const district = job.district ? ` · ${job.district}` : "";
      const body = `${job.title || "Yeni ilan"}${district}`;

      // Token + prefs: yalnız tavanlı liste, paralel (eskiden N seri get).
      // nearbyJobs kapalıysa hem push hem in-app yazılmaz (tercihe saygı +
      // yazma tasarrufu). İlan yine Keşfet listesinde görünür.
      const tokens = [];
      const tokenOwner = new Map();
      const notifyUids = [];
      let prefsSkipped = 0;

      // TOPLU OKUMA (2026-08-14 optimizasyonu).
      //
      // Eskiden alıcı başına bir `getFcmTokens(uid)` çağrılıyordu: 120 alıcı
      // = 120 ayrı Firestore round-trip (eşzamanlı worker'larla bile). Artık
      // `getAll` ile tek turda okunuyor — faturalanan doküman sayısı aynı,
      // ama CF çalışma süresi ve ağ yükü belirgin düşüyor.
      //
      // ⚠️ Eski koddaki `return` hatası da burada kapandı: tercihini
      // kapatmış bir kullanıcı artık yalnız KENDİ bildirimini atlatıyor;
      // eskiden o worker'ın kuyruğundaki herkesi sessizce düşürüyordu.
      let pushMap;
      try {
        pushMap = await getFcmTokensBulk(recipientUids);
      } catch (e) {
        logger.warn(`Job ${jobId}: toplu token okuma: ${e}`);
        pushMap = new Map();
      }

      for (const uid of recipientUids) {
        const kayit = pushMap.get(uid);
        if (!kayit) continue;
        if (!prefsFromPushSnap(kayit.snap).nearbyJobs) {
          prefsSkipped++;
          continue;
        }
        notifyUids.push(uid);
        kayit.tokens.forEach((t) => {
          if (!tokenOwner.has(t)) {
            tokenOwner.set(t, uid);
            tokens.push(t);
          }
        });
      }

      // Uygulama içi bildirim: yalnız tercih açık + tavanlı alıcılar.
      const expireAt = Timestamp.fromMillis(
          Date.now() + NOTIFICATION_TTL_DAYS * 24 * 3600 * 1000);
      const nowIso = new Date().toISOString();
      for (let i = 0; i < notifyUids.length; i += 450) {
        const batch = db.batch();
        for (const uid of notifyUids.slice(i, i + 450)) {
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

      if (tokens.length === 0) {
        logger.info(
            `Job ${jobId}: no push tokens ` +
            `(match=${matchCount}, cap=${recipientUids.length}, ` +
            `prefsSkip=${prefsSkipped})`,
        );
        return;
      }

      // FCM multicast en fazla 500 token.
      const invalidByOwner = new Map();
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
          `match=${matchCount}, notify=${notifyUids.length}, ` +
          `push ${success}/${tokens.length} ok` +
          (matchCount > JOB_FANOUT_RECIPIENT_CAP ?
            ` (capped@${JOB_FANOUT_RECIPIENT_CAP})` : ""),
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

      // Taslak kotası sayacı (`private/productStats.draftCount`). Kural
      // `productDraftQuotaOk` bunu okur; sayaç güncellenmezse kota fiilen
      // devre dışı kalır. Sayacı yalnız taslak durumu DEĞİŞTİĞİNDE tazele —
      // her alan düzenlemesinde koleksiyon taramak gereksiz maliyettir.
      try {
        const b = event.data && event.data.before;
        const a = event.data && event.data.after;
        const beforeDraft =
          b && b.exists && b.data().status === "draft";
        const afterDraft =
          a && a.exists && a.data().status === "draft";
        if (beforeDraft !== afterDraft) {
          const owner =
            (a && a.exists && a.data().ownerUid) ||
            (b && b.exists && b.data().ownerUid);
          await refreshDraftProductCount(owner);
        }
      } catch (e) {
        logger.warn(`productStats draft: ${e}`);
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
        if (!before && after) {
          await bumpDaily("jobsCreated", 1);
          // ÜRÜN TALEBİ AYRI SAYILIR (2026-08-15).
          //
          // Talepler de `jobs` koleksiyonunda yaşar, yani `jobsCreated`
          // ikisini birden sayar. Ayrı ölçülmezse "kaç ilan açıldı?" sorusu
          // mağaza talepleriyle şişer ve mağaza modülünün gerçekten
          // kullanılıp kullanılmadığı görülemez.
          //
          // Panel hizmet ilanını `jobsCreated - productRequestsCreated`
          // olarak türetir (bkz. AdminDailyStat.serviceJobsCreated).
          if (after.category === PRODUCT_REQUEST_CATEGORY) {
            await bumpDaily("productRequestsCreated", 1);
          }
        }
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
    {region: REGION, enforceAppCheck: false, timeoutSeconds: 300},
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
      //    `customerUID` SİLİNMEZ: doküman kimliği (`rev_{yazan}__{hedef}`)
      //    zaten o uid'i taşır ve kural motoru yazar kontrolünü bu alandan
      //    yapar — null'lanırsa yorum "sahipsiz" kalır ve düzenleme kuralı
      //    kilitlenir. `supportTickets`/`reports`'ta uid null'lanabiliyor
      //    çünkü orada kimlik alanı yetki kapısı DEĞİL. Bunun yerine kayıt
      //    silinmiş olarak işaretlenir; ad zaten anonimleşiyor.
      reviewsBy.forEach((d) => writer.update(d.ref, {
        customerDisplayName: DELETED_USER_NAME,
        authorDeleted: true,
      }));
      reviewsAbout.forEach((d) => writer.delete(d.ref));

      // 4b) Üyelik satın alma kaydı → SİL. Play token'ı kişisel veridir ve
      //     hesap silinince yenileme/RTDN yolu zaten işlemez.
      //     `delete` olmayan dokümanda sorun çıkarmaz (update'in aksine).
      writer.delete(db.collection("membershipPurchases").doc(uid));

      //     Token sahiplenme kaydı (membershipTokens/{hash}) da SİLİNİR: uid
      //     taşır (kişisel veri) ve hesap gidince kilidi tutmasının anlamı
      //     kalmaz — aksi hâlde kullanıcı hesabını silip yeniden açtığında
      //     KENDİ aboneliği "başkasına ait" diye reddedilirdi.
      //     Sorgu `uid` alanı üzerinden: doküman kimliği hash'tir, token
      //     burada elimizde yok.
      const myTokens = await db.collection("membershipTokens")
          .where("uid", "==", uid).get();
      myTokens.forEach((d) => writer.delete(d.ref));

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
    ADMIN_CALL_OPTS,
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
    {...ADMIN_CALL_OPTS, timeoutSeconds: 300},
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
    ADMIN_CALL_OPTS,
    async (request) => {
      const auth = request.auth;
      if (!auth) {
        throw new HttpsError("unauthenticated", "Oturum gerekli.");
      }
      const email = String(auth.token.email || "").toLowerCase();
      if (!ADMIN_BOOTSTRAP_EMAILS.has(email)) {
        throw new HttpsError(
            "permission-denied", "Bu hesap yönetici olamaz.");
      }

      // E-POSTA DOĞRULAMASI — bootstrap için sunucu tarafında tamamlanır.
      //
      // Eskiden `auth.token.email_verified` şartı vardı ve bootstrap hesabı
      // ilk kez Firebase Console'dan (Add user) açıldığında bu bayrak FALSE
      // olur; Console'da elle açılamaz ve doğrulama e-postası gönderme yolu
      // da panelde yok. Sonuç: kurucu yönetici kendi paneline HİÇ giremiyordu
      // ("Hesap yöneticisi yetkisine sahip değilsiniz").
      //
      // Güvenlik gerekçesi: bu noktaya gelen adres zaten ADMIN_BOOTSTRAP_EMAILS
      // içinde olmak zorunda — yani listeyi kod deposunda değiştirip deploy
      // edebilen biri (proje sahibi) tarafından bilerek eklenmiştir. Rastgele
      // bir kullanıcı bu adresle hesap açamaz; adres sahibi zaten proje
      // sahibidir. Dolayısıyla doğrulama şartı ek güvenlik sağlamıyor, yalnız
      // ilk kurulumu kilitliyordu.
      //
      // Yine de bayrak GERİDE DÜZELTİLİR: `adminAcceptInvite` gibi başka
      // akışlar `email_verified` arar; false kalırsa onlar sessizce düşerdi.
      const userRec = await getAuth().getUser(auth.uid);
      if (userRec.emailVerified !== true) {
        await getAuth().updateUser(auth.uid, {emailVerified: true});
        logger.info(`bootstrap admin e-postasi dogrulandi: ${email}`);
      }

      // Claim MERGE — suspended vb. korunur (K19/K20).
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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

      // AUTH HESABI + ŞİFRE BELİRLEME BAĞLANTISI (2026-08-15).
      //
      // Eskiden davet YALNIZ bir Firestore kaydıydı: "bu e-posta gelirse
      // moderatör yap". Ama o e-postanın Auth hesabını kimse açmıyordu ve
      // panelde kayıt ekranı da yok → davet edilen kişi GİRİŞ YAPAMIYORDU.
      // Tek çare superadmin'in Firebase Console'dan elle hesap açıp şifreyi
      // WhatsApp'tan göndermesiydi (şifre yazılı kanalda dolaşıyor).
      //
      // Artık hesap burada açılır ve ŞİFRE BELİRLEME bağlantısı üretilir.
      // Şifreyi kimse bilmez — davet edilen kişi kendisi belirler.
      //
      // ⚠️ Bağlantı GÖNDERİLMEZ, superadmin'e döndürülür. Projede e-posta
      // gönderim altyapısı yok (SendGrid/Extension kurulu değil); yeni bir
      // dış servis bağımlılığı eklemek yerine superadmin bağlantıyı kendi
      // güvendiği kanaldan iletir. Bağlantı tek kullanımlıktır ve Firebase
      // tarafında süresi dolar — şifrenin kendisinden çok daha güvenlidir.
      let resetLink = null;
      let authUid = null;
      let accountCreated = false;
      try {
        let userRec = null;
        try {
          userRec = await getAuth().getUserByEmail(email);
        } catch (e) {
          if (e && e.code === "auth/user-not-found") {
            // Rastgele geçici şifre: hiçbir yerde saklanmaz/gösterilmez.
            // Kullanıcı zaten şifresini bağlantıdan belirleyecek.
            userRec = await getAuth().createUser({
              email,
              emailVerified: true, // bkz. aşağıdaki not
              password: crypto.randomBytes(24).toString("hex"),
            });
            accountCreated = true;
          } else {
            throw e;
          }
        }
        authUid = userRec.uid;

        // E-POSTA DOĞRULAMASI: `adminAcceptInvite` doğrulanmış e-posta ister.
        // Daveti superadmin oluşturuyor ve adresi kendisi giriyor; ayrıca
        // şifre belirleme bağlantısı ancak o adrese ulaşan kişinin eline
        // geçer — yani adrese erişim zaten kanıtlanmış olur. Mevcut hesap
        // doğrulanmamışsa da doğrulanmış sayılır, aksi hâlde kabul adımı
        // sebebi anlaşılmayan bir hatayla düşerdi.
        if (!userRec.emailVerified) {
          await getAuth().updateUser(userRec.uid, {emailVerified: true});
        }

        resetLink = await getAuth().generatePasswordResetLink(email);
      } catch (e) {
        // Hesap açılamadıysa daveti de OLUŞTURMA: yarım kalan davet,
        // superadmin'in "davet ettim ama giremiyor" sorunuyla baş başa
        // kalmasına yol açar — asıl düzeltmeye çalıştığımız durum bu.
        logger.error(`adminCreateInvite auth hesabi acilamadi (${email})`, e);
        throw new HttpsError(
            "internal",
            "Yönetici hesabı oluşturulamadı. E-postayı kontrol edip " +
            "tekrar deneyin.",
        );
      }

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
        // Hesap bilgisi: kimin için açıldığı ve yeni mi açıldığı.
        // ŞİFRE veya BAĞLANTI SAKLANMAZ — bağlantı yalnız bu çağrının
        // yanıtında döner. Firestore'a yazılsaydı okuma yetkisi olan
        // herkes hesabı ele geçirebilirdi.
        authUid,
        accountCreated,
      });
      await writeAuditLog({
        actorUid: auth.uid,
        action: "invite_create",
        targetType: "invite",
        targetId: ref.id,
        after: {email, capabilities: caps, expiresAt, accountCreated},
      }, batch);
      await batch.commit();
      return {
        inviteId: ref.id,
        email,
        expiresAt,
        accountCreated,
        // Superadmin bu bağlantıyı davet edilen kişiye iletir.
        passwordSetupLink: resetLink,
      };
    },
);

exports.adminRevokeInvite = onCall(
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
 * `province` ZORUNLUDUR (2026-08-23). Once yoktu ve sorgu TUM koleksiyonu
 * tariyordu: Bursa'yi gecirmek isteyen yonetici Turkiye'deki her ustanin
 * musaitligini kapatabiliyordu ve islem GERI ALINAMIYOR. Sehir bazli gecise
 * gecilince bu artik teorik bir risk degil, gunluk bir islem.
 *
 * "Tumu" secenegi BILEREK YOK: birinin yanlislikla secmesi an meselesi.
 * Ulke geneli bir islem gerekirse iller tek tek secilir — yavaslik burada
 * guvenliktir.
 *
 * SAYFALAMA (2026-08-23): eskiden `.get()` ile tek cagrida tum koleksiyon
 * okunuyordu. 10.000 ustada bu 10.000 okuma + muhtemel zaman asimi demek.
 * Artik `orderBy(documentId) + startAfter` ile 500'luk sayfalar halinde
 * yurur. Kod tabanindaki diger 29 dinleyicinin hepsinde limit var; burasi
 * atlanmisti.
 *
 * IL ESLESMESI bellekte yapilir: `serviceAreas` bir DIZI ve icindeki
 * `province` alanina Firestore `where` ile bakilamaz (array-contains tam
 * nesne esitligi ister, ilce adini da bilmek gerekirdi).
 *
 * Gerekce ZORUNLUDUR ve audit log'a yazilir. Islem 400'luk yiginlar halinde
 * yurur (Firestore batch siniri 500).
 */
exports.adminBulkPlanUpdate = onCall(
    {...ADMIN_CALL_OPTS, timeoutSeconds: 540},
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "finance.manage");
      const {mode, reason, onlyWithoutActivePremium, dryRun, province} =
        request.data || {};

      // IL ZORUNLU — bos gecilemez. Bkz. fonksiyon basligindaki not.
      const il = String(province || "").trim();
      if (!il) {
        throw new HttpsError(
            "invalid-argument",
            "province zorunlu: toplu islem yalniz tek bir il icin calisir.",
        );
      }

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

      let etkilenen = 0;
      let atlanan = 0;
      let taranan = 0;   // tum koleksiyonda gezilen kayit
      let ildeki = 0;    // il eslesmesi tutan kayit
      let batch = db.batch();
      let batchAdet = 0;

      // SAYFALI TARAMA — tek `.get()` yerine 500'luk sayfalar.
      const SAYFA = 500;
      let sonDoc = null;
      for (;;) {
        let q = db.collection("artisanProfiles")
            .orderBy(FieldPath.documentId())
            .limit(SAYFA);
        if (sonDoc) q = q.startAfter(sonDoc.id);
        const sayfa = await q.get();
        if (sayfa.empty) break;
        sonDoc = sayfa.docs[sayfa.docs.length - 1];

        for (const doc of sayfa.docs) {
          taranan++;
          const d = doc.data() || {};

          // IL FILTRESI (bellekte): serviceAreas bir dizi, icindeki
          // province alanina Firestore where ile bakilamaz.
          const alanlar = Array.isArray(d.serviceAreas) ? d.serviceAreas : [];
          const ildeMi = alanlar.some(
              (a) => a && String(a.province || "").trim() === il);
          if (!ildeMi) continue; // atlanan SAYILMAZ: kapsam disi
          ildeki++;

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
        if (sayfa.size < SAYFA) break; // son sayfa
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
          province: il,
          etkilenen,
          atlanan,
          // `toplam` artik ILDEKI kayit sayisi — yoneticinin gordugu
          // "N ustadan M tanesi" ifadesi kapsam disi illeri saymamali.
          toplam: ildeki,
          taranan,
          onlyWithoutActivePremium: korunanlariAtla,
          dryRun: dryRun === true,
        },
      });

      logger.info(
          `adminBulkPlanUpdate il=${il} mode=${mode} ` +
          `ildeki=${ildeki} etkilenen=${etkilenen} atlanan=${atlanan} ` +
          `taranan=${taranan} dryRun=${dryRun === true}`,
      );
      return {
        ok: true,
        etkilenen,
        atlanan,
        toplam: ildeki,
        taranan,
        province: il,
        dryRun: dryRun === true,
      };
    },
);

// Değerlendirme soft-hide (puan toplamı MVP'de değişmez).
exports.adminHideReview = onCall(
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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

// Mağaza ürün kategorileri (adminConfig/productCategories).
// Yalnız config.manage. Tüketici salt okur; boşsa istemci gömülü yedek kullanır.
exports.adminUpdateProductCategories = onCall(
    ADMIN_CALL_OPTS,
    async (request) => {
      const auth = request.auth;
      await assertCap(auth, "config.manage");
      const raw = request.data || {};
      const list = raw.items;
      if (!Array.isArray(list)) {
        throw new HttpsError("invalid-argument", "items dizi olmalı.");
      }
      if (list.length === 0) {
        throw new HttpsError(
            "invalid-argument", "En az bir kategori gerekli.");
      }
      if (list.length > 60) {
        throw new HttpsError(
            "invalid-argument", "En fazla 60 kategori.");
      }
      const codeRe = /^[a-z][a-z0-9_]{1,39}$/;
      const seen = new Set();
      const items = [];
      for (let i = 0; i < list.length; i++) {
        const row = list[i] || {};
        const code = String(row.code || "").trim();
        const label = String(row.label || "").trim();
        if (!codeRe.test(code)) {
          throw new HttpsError(
              "invalid-argument",
              `Geçersiz kod: ${code || "(boş)"}`);
        }
        if (!label || label.length > 60) {
          throw new HttpsError(
              "invalid-argument",
              `Etiket 1–60 karakter olmalı: ${code}`);
        }
        if (seen.has(code)) {
          throw new HttpsError(
              "invalid-argument", `Mükerrer kod: ${code}`);
        }
        seen.add(code);
        items.push({
          code,
          label: label.slice(0, 60),
          order: Number.isFinite(Number(row.order)) ?
            Math.floor(Number(row.order)) : i,
          active: row.active !== false,
        });
      }
      const activeCount = items.filter((e) => e.active).length;
      if (activeCount === 0) {
        throw new HttpsError(
            "invalid-argument",
            "En az bir aktif kategori olmalı.");
      }

      const ref = db.collection("adminConfig").doc("productCategories");
      const beforeSnap = await ref.get();
      const before = beforeSnap.exists ? (beforeSnap.data() || {}) : {};
      const payload = {
        items,
        updatedAt: new Date().toISOString(),
        updatedBy: auth.uid,
      };
      await ref.set(payload);

      await writeAuditLog({
        actorUid: auth.uid,
        action: "update_product_categories",
        targetType: "adminConfig",
        targetId: "productCategories",
        before: {
          count: Array.isArray(before.items) ? before.items.length : 0,
        },
        after: {count: items.length},
      });
      return {ok: true, count: items.length};
    },
);

// Runtime config (adminConfig/runtime) — bayraklar + platform içeriği.
// Yalnız config.manage.
exports.adminUpdateConfig = onCall(
    ADMIN_CALL_OPTS,
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
    {...ADMIN_CALL_OPTS, timeoutSeconds: 120},
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
    ADMIN_CALL_OPTS,
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
// 1) Play Console → Monetization → Subscriptions: sepette_hizmet_pro_monthly
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

// ⚠️ `googleapis` MODÜL TEPESİNDE require EDİLMEZ — TEMBEL yüklenir.
//
// Paket 110 MB'tır ve yüklenmesi ~1 sn sürer. Deploy sırasında Firebase CLI
// `index.js`'i çalıştırıp fonksiyon listesini çıkarır ("backend specification")
// ve bu adımın **10 saniyelik** sabit bir bütçesi vardır. Soğuk bir deploy
// makinesinde bu yükleme bütçenin büyük bölümünü yer ve şu hata düşer:
//
//   Cannot determine backend specification. Timeout after 10000.
//
// Aynı maliyet TÜM fonksiyonların soğuk başlangıcına da biner — oysa
// `googleapis`'e yalnız `verifyMembershipPurchase` ihtiyaç duyar.
//
// Tembel yükleme ile modül yalnız satın alma doğrulanırken okunur; sonuç
// önbelleğe alınır (aynı örnek ikinci kez yüklemez).
// → vault/05-Operasyon/Bilinen-Tuzaklar.md
let _androidPublisher = null;

const PLAY_PACKAGE_NAME = "com.sepettehizmet.app";
const ALLOWED_PRODUCT_IDS = new Set([
  "sepette_hizmet_pro_monthly",
  "sepette_hizmet_pro_yearly",
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
  // Tembel require: bkz. yukarıdaki not (deploy discovery 10 sn bütçesi).
  if (_androidPublisher) return _androidPublisher;
  const {google} = require("googleapis");
  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/androidpublisher"],
  });
  _androidPublisher = google.androidpublisher({version: "v3", auth});
  return _androidPublisher;
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

  // TOKEN SAHİPLENME (tekrar kullanım kilidi).
  //
  // Play `purchaseToken`'ı doğrulamak "bu abonelik aktif mi?" sorusunu
  // yanıtlar, "bu aboneliği ÇAĞIRAN kişi mi aldı?" sorusunu YANITLAMAZ.
  // Kilit olmadan tek bir ödeme sınırsız hesaba premium verir: token'ı ele
  // geçiren (ya da tek abonelik alıp token'ı paylaşan) herkes
  // `verifyMembershipPurchase`'ı kendi oturumuyla çağırıp premium olur.
  //
  // Bu yüzden token hash'i AYRI bir dokümanda (`membershipTokens/{hash}`)
  // sahibiyle birlikte tutulur ve create yarıştırılamaz bir transaction ile
  // yapılır. Aynı token ikinci bir uid ile gelirse reddedilir.
  //
  // `membershipPurchases/{uid}` bunu ÇÖZMEZ: anahtarı uid olduğu için her
  // hesap kendi dokümanını yazar, token'ın başkasında olduğu görülmez.
  const tokenRef = db.collection("membershipTokens").doc(tokenHash);
  await db.runTransaction(async (tx) => {
    const snap = await tx.get(tokenRef);
    if (snap.exists) {
      const owner = (snap.data() || {}).uid;
      if (owner && owner !== uid) {
        logger.warn("premium token reuse blocked", {
          uid,
          ownerUid: owner,
          productId,
        });
        throw new HttpsError(
            "permission-denied",
            "Bu satın alma başka bir hesaba ait.",
        );
      }
      tx.set(tokenRef, {
        productId,
        expiresAt: Timestamp.fromDate(expiresAt),
        updatedAt: FieldValue.serverTimestamp(),
      }, {merge: true});
      return;
    }
    // create: aynı anda iki istek gelirse transaction biri için patlar.
    tx.create(tokenRef, {
      uid,
      productId,
      expiresAt: Timestamp.fromDate(expiresAt),
      createdAt: FieldValue.serverTimestamp(),
      updatedAt: FieldValue.serverTimestamp(),
    });
  });

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

// Not: karakter sınıfı içinde `-` SONDA ise kaçış gerekmez
// (`[A-Za-z0-9._%+-]`). Eskiden `\-` yazılıydı; davranış birebir aynı,
// yalnız gereksiz kaçış temizlendi (eşdeğerlik testle doğrulandı).
const PRODUCT_CONTACT_RE =
  /(@[A-Za-z0-9._]{3,})|(\+?\d[\d\s\-()]{8,}\d)|([A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,})|(whatsapp|telegram|instagram|http:\/\/|https:\/\/|www\.)/i;

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

      // KATEGORİ, MAĞAZANIN KATEGORİLERİYLE SINIRLI (2026-08-15).
      //
      // Satıcı yalnız mağazasını açarken seçtiği kategorilerde ürün
      // yayınlayabilir. İstemci seçiciyi zaten süzüyor
      // (`_UrunKategoriSecici`) ama istemci kısıtı ATLATILABİLİR — taslak
      // doğrudan SDK ile yazılıp buraya gönderilebilir.
      //
      // Mağaza kategorisi boşsa (eski kayıt) kısıt UYGULANMAZ: kullanıcıyı
      // ürün yayınlayamaz hâle düşürmek yerine serbest bırakılır.
      //
      // ⚠️ Ürün TALEPLERİ buna tabi değildir — müşteri istediği kategoride
      // talep açar (`jobs` koleksiyonu, PRODUCT_REQUEST_CATEGORY).
      try {
        const ownerSnap = await db.collection("users").doc(auth.uid).get();
        const shopCats = ownerSnap.exists ?
          (ownerSnap.data() || {}).shopCategories : null;
        if (Array.isArray(shopCats) && shopCats.length > 0 &&
            !shopCats.includes(categoryCode)) {
          throw new HttpsError(
              "failed-precondition",
              "Bu kategoride ürün yayınlayamazsınız. Mağaza " +
              "kategorilerinizi Profil > Mağaza > Düzenle'den " +
              "güncelleyebilirsiniz.",
          );
        }
      } catch (e) {
        // Kendi attığımız kural hatası yukarı çıkmalı; yalnız OKUMA
        // arızası yutulur (kullanıcı sunucu hatası yüzünden engellenmesin).
        if (e instanceof HttpsError) throw e;
        logger.warn(`publishProduct shopCategories okunamadi (${auth.uid})`, e);
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
    ADMIN_CALL_OPTS,
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
 * gönderir. Anlık bildirim almış satıcıyı atlar (çift push yok).
 *
 * ALICI: aynı il + aynı productCategoryCode. Kaynaklar
 * `collectProductRequestSellerUids` ile birebir (yayında ürün ∪ mağaza
 * kategorisi). Kategorisi olmayan eski talep yalnız ile eşleşir.
 *
 * @return {Promise<void>}
 */
// ─────────────── IL BAZLI MUSAITLIK SAYACI (2026-08-23) ───────────────
//
// Sehir bazli Pro gecisinin olcusu: bir ilde kac kullanici SU AN musait?
// 1.000'e ulasan il ucretli doneme hazir sayilir.
//
// NEDEN GUNLUK TOPLU SAYIM, ARTIRIMLI SAYAC DEGIL:
//
// "Su an musait" durumu sik degisir (haftalik takvim, manuel duraklatma,
// premium suresi). Her degisimde increment yazmak hem pahali hem KAYAR:
// bir CF yeniden denemesi sayaci ikilerdi ve hata birikerek buyurdu. Gunluk
// tam sayim her gun sifirdan hesaplar — kayma imkansiz.
//
// OLCU: `users.available === true`. Bu, istemcinin musaitlik degisiminde
// yazdigi denormalize bayraktir ve Kesfet filtreleri de ayni alani okur
// (`artisanIsAvailableProvider`, `availableDiscoverProductsProvider`).
// Haftalik takvimi burada YENIDEN HESAPLAMIYORUZ: `isAvailableAt` mantiginin
// ikinci bir kopyasi olurdu ve iki taraf zamanla ayrisirdi.
//
// IL: usta profilinin `serviceAreas` ya da magazanin `shopServiceAreas`
// alanindan. Tek il kurali (2026-08-23) geldigi icin kullanici basina TEK
// il dusuyor; eski cok illi kayitta ILK il sayilir (kayitta zaten tek ile
// inecek).
//
// KILIT: bir il 1.000'e ULASTIGINDA `thresholdReachedAt` damgasi yazilir ve
// BIR DAHA DEGISMEZ. Sayi sonradan dususe bile geri sarmaz — kullaniciya
// verilen tarih degismemeli.

/** Il esigi: bu sayiya ulasan il ucretli doneme hazir sayilir. */
const PROVINCE_THRESHOLD = 1000;

/**
 * Bir kullanicinin hizmet ILINI cozer (tek il kurali).
 * @param {object} user `users/{uid}` verisi.
 * @param {object|null} artisan `artisanProfiles/{uid}` verisi (varsa).
 * @return {string} Il adi; cozulemezse bos dize.
 */
function resolveUserProvince(user, artisan) {
  const listeler = [
    artisan && artisan.serviceAreas,
    user && user.shopServiceAreas,
  ];
  for (const liste of listeler) {
    if (!Array.isArray(liste)) continue;
    for (const a of liste) {
      const il = a && String(a.province || "").trim();
      if (il) return il;
    }
  }
  return "";
}

exports.rebuildProvinceStats = onSchedule(
    {
      // Gece 03:00 — trafik dusuk, sayim gunun sonucunu yansitir.
      schedule: "0 3 * * *",
      region: REGION,
      timeZone: "Europe/Istanbul",
      timeoutSeconds: 540,
      memory: "512MiB",
    },
    async () => {
      // uid -> il (yalniz MUSAIT kullanicilar)
      const musaitIller = new Map();

      // 1) Musait kullanicilari topla (sayfali — koleksiyon buyuyecek).
      let sonUser = null;
      for (;;) {
        let q = db.collection("users")
            .orderBy(FieldPath.documentId())
            .limit(500);
        if (sonUser) q = q.startAfter(sonUser);
        const sayfa = await q.get();
        if (sayfa.empty) break;
        sonUser = sayfa.docs[sayfa.docs.length - 1].id;
        for (const doc of sayfa.docs) {
          const d = doc.data() || {};
          if (d.available !== true) continue;
          // Askiya alinmis hesap arzin parcasi degil.
          if (d.suspended === true) continue;
          musaitIller.set(doc.id, {user: d, il: ""});
        }
        if (sayfa.size < 500) break;
      }

      // 2) Usta profillerinden il coz (magaza ili user dokumaninda zaten).
      let sonArtisan = null;
      for (;;) {
        let q = db.collection("artisanProfiles")
            .orderBy(FieldPath.documentId())
            .limit(500);
        if (sonArtisan) q = q.startAfter(sonArtisan);
        const sayfa = await q.get();
        if (sayfa.empty) break;
        sonArtisan = sayfa.docs[sayfa.docs.length - 1].id;
        for (const doc of sayfa.docs) {
          const kayit = musaitIller.get(doc.id);
          if (!kayit) continue; // musait degil, ilgilenmiyoruz
          kayit.artisan = doc.data() || {};
        }
        if (sayfa.size < 500) break;
      }

      // 3) Il il say.
      const sayim = new Map();
      for (const kayit of musaitIller.values()) {
        const il = resolveUserProvince(kayit.user, kayit.artisan || null);
        if (!il) continue; // bolgesiz kullanici hicbir ile sayilmaz
        sayim.set(il, (sayim.get(il) || 0) + 1);
      }

      // 4) Yaz. Esige ULASAN il damgalanir ve damga BIR DAHA DEGISMEZ.
      const kok = db.collection("adminStats").doc("provinces")
          .collection("items");

      // Mevcut damgalari TEK sorguda oku — il basina ayri `get()` 81 ayri
      // okuma demekti ve gunluk isin maliyetini gereksiz katliyordu.
      const damgalar = new Map();
      const mevcutSnap = await kok.get();
      mevcutSnap.docs.forEach((d) => {
        const v = d.data() || {};
        if (v.thresholdReachedAt) damgalar.set(d.id, v.thresholdReachedAt);
      });

      const simdi = new Date().toISOString();
      let batch = db.batch();
      let adet = 0;
      for (const [il, sayi] of sayim.entries()) {
        const patch = {
          province: il,
          availableCount: sayi,
          updatedAt: simdi,
        };
        // Damga YALNIZ bir kez yazilir (kilit): sayi sonradan dususe bile
        // geri sarmaz — kullaniciya verilen tarih degismemeli.
        if (sayi >= PROVINCE_THRESHOLD && !damgalar.has(il)) {
          patch.thresholdReachedAt = simdi;
        }
        batch.set(kok.doc(il), patch, {merge: true});
        adet++;
        if (adet >= 400) {
          await batch.commit();
          batch = db.batch();
          adet = 0;
        }
      }

      // Sayimda HIC gecmeyen il varsa sayacini sifirla — dun 40 musait
      // kullanicisi olan il bugun bosaldiysa tablo eski sayiyi gostermemeli.
      // Damgaya DOKUNULMAZ.
      mevcutSnap.docs.forEach((d) => {
        if (sayim.has(d.id)) return;
        if (((d.data() || {}).availableCount || 0) === 0) return;
        batch.set(d.ref, {availableCount: 0, updatedAt: simdi}, {merge: true});
        adet++;
      });

      if (adet > 0) await batch.commit();

      logger.info(
          `rebuildProvinceStats: ${sayim.size} il, ` +
          `${musaitIller.size} musait kullanici`);
    },
);

exports.sendProductRequestDigest = onSchedule(
    {
      // Akşam 19:00 — anlık kaçıranlar (yeni ürün ekleyen, token'sız) için net.
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

      const talepListesi = [];
      talepler.docs.forEach((d) => {
        const j = d.data() || {};
        const il = j.province || "";
        if (!il) return;
        talepListesi.push({
          customerId: j.customerId || "",
          province: il,
          productCategoryCode: j.productCategoryCode || "",
        });
      });
      if (talepListesi.length === 0) return;

      // uid → kendi kategorisi/iline uyan talep sayısı.
      // Ürün listesi bir kez okunur — her il/kategori çiftinde tekrar
      // 1200 okuma yapılmasın.
      let productDocs;
      try {
        productDocs = await db.collection("products")
            .where("status", "==", "active")
            .limit(1200)
            .get();
      } catch (e) {
        logger.error("productRequestDigest ürün sorgusu düştü", e);
        return;
      }
      const alicilar = new Map();
      const gorulen = new Set();
      for (const t of talepListesi) {
        const anahtar = `${t.province}\t${t.productCategoryCode}`;
        if (gorulen.has(anahtar)) continue;
        gorulen.add(anahtar);
        const uids = await collectProductRequestSellerUids({
          province: t.province,
          categoryCode: t.productCategoryCode,
          productDocs,
        });
        const adet = talepListesi.filter((x) =>
          x.province === t.province &&
          x.productCategoryCode === t.productCategoryCode).length;
        uids.forEach((uid) => {
          alicilar.set(uid, (alicilar.get(uid) || 0) + adet);
        });
      }

      // Kendi talebini açan kişiye kendi talebini haber verme.
      talepListesi.forEach((t) => {
        if (t.customerId) alicilar.delete(t.customerId);
      });

      if (alicilar.size === 0) {
        logger.info("productRequestDigest: eşleşen satıcı yok");
        return;
      }

      const gunAnahtari = istanbulDayKey();
      let gonderilen = 0;
      let anlikAtlanan = 0;
      for (const [uid, adet] of alicilar) {
        const baslik = "Yeni ürün talepleri";
        const govde = adet === 1 ?
          "Kategorinde 1 yeni ürün talebi var." :
          `Kategorinde ${adet} yeni ürün talebi var.`;
        try {
          const snap = await getPushDoc(uid);
          // Bugün anlık almışsa akşam tekrar etme.
          if (snap.exists &&
              snap.data().productRequestInstantDay === gunAnahtari) {
            anlikAtlanan++;
            continue;
          }
          if (!(await isPushCategoryAllowed(uid, "productDigest", snap))) {
            continue;
          }
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
          `productRequestDigest: ${gonderilen} kişiye özet ` +
          `(anlık atlanan ${anlikAtlanan})`);
    },
);


// ---------------------------------------------------------------------------
// MALİYET DUVARI — bütçe aşımında faturalandırmayı kes.
// ---------------------------------------------------------------------------
//
// Blaze planında Google'ın hazır bir "şu tutarda dur" düğmesi YOKTUR.
// Konsoldaki bütçe uyarıları yalnızca e-posta gönderir; harcama sürer. Duvar
// budur: Cloud Billing bütçesi → Pub/Sub konusu → bu fonksiyon → projeden
// faturalandırma hesabını AYIR.
//
// ⚠️ BU SERT BİR DURDURMADIR. Faturalandırma ayrılınca proje TAMAMEN durur:
// Firestore okuma/yazma reddedilir, Auth çalışmaz, uygulama kullanıcılar için
// ölür. Geri açmak MANUELDİR (Console → Billing → hesabı yeniden bağla) ve
// servislerin toparlanması dakikalar alır. Bu bir "fren" değil, imdat frenidir:
// 5.000 $'lık sürpriz faturaya karşı son savunma.
//
// Bu yüzden eşik normal faturanın (bu ölçekte 0–200 ₺/ay) çok üstünde tutulur.
// Uyarı kademeleri (200/1.000/2.000 ₺) bütçenin kendi e-postalarıyla gelir;
// buradaki kod YALNIZ son kademede (4.000 ₺) iş yapar.
//
// Kurulum (docs/OPS_MALIYET_DUVARI.md): bütçeyi ve Pub/Sub konusunu oluştur,
// runtime servis hesabına faturalandırma yöneticisi rolünü ver.

// Faturalandırmanın kesileceği eşik. Bütçe tutarı Console'da ayrı tanımlanır;
// buradaki sayı ondan BAĞIMSIZ bir ikinci emniyettir — bütçe yanlışlıkla
// düşük kurulsa bile bu tutarın altında kesme yapılmaz.
//
// PARA BİRİMİ: hesap TRY (₺) faturalandırılıyor (2026-08-15 doğrulandı),
// bu yüzden eşik de ₺ cinsindendir. 4000 ₺ ≈ 100 $ (kur ~40 ₺/$).
// Beklenen normal fatura 0–200 ₺/ay olduğu için bu gerçek bir imdat freni.
const BILLING_KILL_AMOUNT = 4000;

// Bütçenin para birimi. Bütçe mesajı bundan farklı bir birim taşırsa
// kıyaslama anlamsızdır (100 ₺ ile 100 $ aynı sayı, farklı para) — kesme
// yapılmaz, yalnız uyarı loglanır. Console'daki bütçe bu birimde olmalı.
const BILLING_CURRENCY = "TRY";

// Bütçe uyarılarının aktığı Pub/Sub konusu. Console'daki bütçe bu konuya
// bağlanır; ad birebir aynı olmalıdır.
const BILLING_TOPIC = "butce-uyarilari";

/**
 * Projeden faturalandırma hesabını ayırır (harcamayı durdurur).
 *
 * @return {Promise<string>} İşlem sonucunu anlatan kısa Türkçe özet.
 */
async function detachBillingAccount() {
  const {google} = require("googleapis");
  const projectId =
    process.env.GCLOUD_PROJECT || process.env.GOOGLE_CLOUD_PROJECT;
  if (!projectId) throw new Error("Proje kimliği okunamadı.");

  const auth = new google.auth.GoogleAuth({
    scopes: ["https://www.googleapis.com/auth/cloud-billing"],
  });
  const billing = google.cloudbilling({version: "v1", auth});
  const name = `projects/${projectId}`;

  const info = await billing.projects.getBillingInfo({name});
  if (!info.data || info.data.billingEnabled !== true) {
    return "Faturalandırma zaten kapalı — işlem yapılmadı.";
  }

  // billingAccountName: "" → hesabı ayır. Harcama burada durur.
  await billing.projects.updateBillingInfo({
    name,
    requestBody: {billingAccountName: ""},
  });
  return `Faturalandırma KESİLDİ (${projectId}).`;
}

/**
 * Kesme olayını Firestore'a yazar ki panelde/loglarda iz kalsın.
 *
 * Faturalandırma kesilirse bu yazma da başarısız olabilir (Firestore durur);
 * bu yüzden kesmeden ÖNCE çağrılır ve hatası yutulur.
 *
 * @param {object} kayit Yazılacak alanlar.
 */
async function logBillingEvent(kayit) {
  try {
    await db.collection("adminBillingEvents").add({
      ...kayit,
      at: new Date().toISOString(),
    });
  } catch (e) {
    logger.warn(`billing event yazılamadı: ${e}`);
  }
}

exports.butceBekcisi = onMessagePublished(
    {
      topic: BILLING_TOPIC,
      region: REGION,
      // Tek örnek yeter; eşzamanlı kesme denemesi istemiyoruz.
      maxInstances: 1,
      retry: false,
    },
    async (event) => {
      let veri = {};
      try {
        veri = event.data.message.json || {};
      } catch (e) {
        logger.warn(`bütçe mesajı çözülemedi: ${e}`);
        return;
      }

      // Bütçe mesajının alanları: costAmount (şu ana kadarki harcama),
      // budgetAmount (bütçe tutarı), alertThresholdExceeded (0.5, 0.9, 1.0...).
      const harcama = Number(veri.costAmount || 0);
      const butce = Number(veri.budgetAmount || 0);
      const esik = Number(veri.alertThresholdExceeded || 0);
      const paraBirimi = veri.currencyCode || "USD";

      logger.info(
          `[bütçe] harcama=${harcama} ${paraBirimi} / bütçe=${butce} ` +
          `(eşik=${esik})`);

      // Beklenenden farklı para biriminde eşik kıyaslaması yanıltıcı olur
      // (100 ₺ ile 100 $ aynı sayı, çok farklı tutar) — kesme yapma, uyar.
      if (paraBirimi !== BILLING_CURRENCY) {
        logger.warn(
            `[bütçe] para birimi ${paraBirimi}, beklenen ` +
            `${BILLING_CURRENCY} — kesme atlandı. Bütçeyi ` +
            `${BILLING_CURRENCY} kurun ya da BILLING_CURRENCY'yi güncelleyin.`);
        return;
      }

      if (harcama < BILLING_KILL_AMOUNT) return; // uyarı kademesi: yalnız log

      logger.error(
          `[bütçe] EŞİK AŞILDI (${harcama} ≥ ${BILLING_KILL_AMOUNT} ` +
          `${BILLING_CURRENCY}) — faturalandırma kesiliyor.`);

      await logBillingEvent({
        tur: "kesme_denemesi",
        harcama,
        butce,
        esik: BILLING_KILL_AMOUNT,
        paraBirimi,
      });

      try {
        const sonuc = await detachBillingAccount();
        logger.error(`[bütçe] ${sonuc}`);
      } catch (e) {
        // Kesme başarısızsa bunu GÖRMEK kritiktir: harcama devam ediyor.
        // En sık sebep: runtime servis hesabında faturalandırma yöneticisi
        // rolü yok (bkz. docs/OPS_MALIYET_DUVARI.md).
        logger.error(`[bütçe] KESME BAŞARISIZ — harcama sürüyor: ${e}`);
        await logBillingEvent({tur: "kesme_hatasi", hata: String(e)});
      }
    },
);
