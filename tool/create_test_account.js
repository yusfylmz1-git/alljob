/**
 * Play inceleme ekibi için test hesabı oluşturur.
 *
 * NEDEN GEREKLİ: Play Console → Uygulama içeriği → "Oturum açma bilgileri"
 * bölümü, incelemecinin uygulamanın TÜM bölümlerine girebilmesini ister.
 * Giremezse uygulama reddedilir.
 *
 * Ne yapar (hepsi tek hesapta — uygulama tek hesapta çift rolü destekler):
 *   1. Firebase Auth'ta e-posta/şifre kullanıcısı açar (varsa şifreyi tazeler)
 *   2. `emailVerified = true` işaretler — incelemeci e-posta kutusuna
 *      erişemez; doğrulanmamış hesap ilan veremez, sohbet açamaz
 *   3. `users/{uid}` dokümanını usta + mağaza profili AÇIK olarak yazar
 *   4. `artisanProfiles/{uid}` vitrinini doldurur (meslek, bölge, müsait)
 *
 * Kimlik: `firebase login` oturumunu kullanır (tool/verify_admin_email.js
 * ile aynı kalıp) — depoya servis hesabı anahtarı KOYULMAZ.
 *
 * Kullanım:
 *   firebase login            (bir kez)
 *   node tool/create_test_account.js
 *   node tool/create_test_account.js ozel@eposta.com "Sifre123!"
 *
 * ⚠️ Bu hesap gerçek bir kullanıcıdır: ürettiği ilan/mesaj canlı veridir.
 *    İnceleme bitince silmek isterseniz Firebase Console → Authentication.
 */
const fs = require("fs");
const os = require("os");
const path = require("path");
const https = require("https");

const PROJECT = "alljob1";
const EMAIL = (process.argv[2] || "play.review@ilandahizmet.com")
  .trim()
  .toLowerCase();
const PASSWORD = process.argv[3] || "PlayReview2026!";
const DISPLAY_NAME = "Play İnceleme";

// ---------------------------------------------------------------- kimlik

function readFirebaseToolsConfig() {
  const candidates = [
    path.join(os.homedir(), ".config", "configstore", "firebase-tools.json"),
    path.join(process.env.APPDATA || "", "configstore", "firebase-tools.json"),
  ];
  for (const p of candidates) {
    if (p && fs.existsSync(p)) {
      return JSON.parse(fs.readFileSync(p, "utf8"));
    }
  }
  throw new Error("firebase-tools.json bulunamadı. Önce: firebase login");
}

function request(method, url, body, token) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const data = body ? JSON.stringify(body) : null;
    const headers = { Authorization: `Bearer ${token}` };
    if (data) {
      headers["Content-Type"] = "application/json";
      headers["Content-Length"] = Buffer.byteLength(data);
    }
    const req = https.request(
      { hostname: u.hostname, path: u.pathname + u.search, method, headers },
      (res) => {
        let out = "";
        res.on("data", (c) => (out += c));
        res.on("end", () => {
          let parsed = {};
          try {
            parsed = out ? JSON.parse(out) : {};
          } catch (_) {
            parsed = { raw: out };
          }
          if (res.statusCode >= 400) {
            reject(
              new Error(
                `${method} ${u.pathname} → ${res.statusCode}: ` +
                  JSON.stringify(parsed)
              )
            );
            return;
          }
          resolve(parsed);
        });
      }
    );
    req.on("error", reject);
    if (data) req.write(data);
    req.end();
  });
}

async function accessToken() {
  const cfg = readFirebaseToolsConfig();
  const refreshToken = cfg.tokens && cfg.tokens.refresh_token;
  if (!refreshToken) throw new Error("Oturum yok. Önce: firebase login");

  // firebase-tools'un genel istemci kimliği (public, gizli değil).
  const body = new URLSearchParams({
    client_id:
      "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com",
    client_secret: "j9iVZfS8kkCEFUPaAeJV0sAi",
    refresh_token: refreshToken,
    grant_type: "refresh_token",
  }).toString();

  return new Promise((resolve, reject) => {
    const req = https.request(
      {
        hostname: "oauth2.googleapis.com",
        path: "/token",
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Content-Length": Buffer.byteLength(body),
        },
      },
      (res) => {
        let out = "";
        res.on("data", (c) => (out += c));
        res.on("end", () => {
          const j = JSON.parse(out);
          if (!j.access_token) {
            reject(new Error("Erişim jetonu alınamadı: " + out));
            return;
          }
          resolve(j.access_token);
        });
      }
    );
    req.on("error", reject);
    req.write(body);
    req.end();
  });
}

// ------------------------------------------------------------------ auth

const IDT = `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}`;

async function findUser(token) {
  const r = await request("POST", `${IDT}/accounts:lookup`, { email: [EMAIL] }, token);
  return r.users && r.users[0] ? r.users[0] : null;
}

async function ensureAuthUser(token) {
  const mevcut = await findUser(token);
  if (mevcut) {
    // Şifreyi tazele + doğrulanmış işaretle (hesap eskiden kalmış olabilir).
    await request(
      "POST",
      `${IDT}/accounts:update`,
      {
        localId: mevcut.localId,
        password: PASSWORD,
        emailVerified: true,
        displayName: DISPLAY_NAME,
      },
      token
    );
    return { uid: mevcut.localId, yeni: false };
  }

  const olustu = await request(
    "POST",
    `${IDT}/accounts`,
    {
      email: EMAIL,
      password: PASSWORD,
      displayName: DISPLAY_NAME,
      emailVerified: true,
    },
    token
  );
  return { uid: olustu.localId, yeni: true };
}

// ------------------------------------------------------------- firestore

const FS = `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents`;

const S = (v) => ({ stringValue: v });
const B = (v) => ({ booleanValue: v });
const I = (v) => ({ integerValue: String(v) });
const D = (v) => ({ doubleValue: v });
const T = (v) => ({ timestampValue: v });
const A = (vals) => ({ arrayValue: { values: vals } });
const M = (fields) => ({ mapValue: { fields } });

async function writeDoc(token, yol, fields) {
  // PATCH + updateMask yok → tüm dokümanı yazar (idempotent: tekrar
  // çalıştırınca aynı sonucu verir, çift kayıt oluşmaz).
  await request("PATCH", `${FS}/${yol}`, { fields }, token);
}

async function main() {
  console.log(`Proje : ${PROJECT}`);
  console.log(`E-posta: ${EMAIL}`);

  const token = await accessToken();
  const { uid, yeni } = await ensureAuthUser(token);
  console.log(`Auth  : ${yeni ? "oluşturuldu" : "güncellendi"} · uid=${uid}`);

  const simdi = new Date().toISOString();

  // users/{uid} — usta VE mağaza açık: incelemeci her iki tarafı da görür.
  await writeDoc(token, `users/${uid}`, {
    displayName: S(DISPLAY_NAME),
    createdAt: T(simdi),
    hasArtisanProfile: B(true),
    hasShopProfile: B(true),
    available: B(true),
    activeMode: S("artisan"),
    aboutText: S("Play inceleme ekibi için hazırlanmış test hesabıdır."),
    // Kodlar `lib/data/models/product_category.dart` sabitleriyle birebir.
    shopCategories: A([S("elektronik"), S("hirdavat")]),
    // ServiceArea alanları: province / district / neighborhood
    // (`lib/data/models/geo_models.dart`). Kimlikler assets/data içinden:
    // İstanbul=34, Kadıköy=3423.
    shopServiceAreas: A([
      M({ province: S("34"), district: S("3423"), neighborhood: S("") }),
    ]),
    // publicPhone BİLEREK yazılmıyor: numara isteğe bağlıdır ve gerçek bir
    // numara olmadan WhatsApp düğmesi çalışmayan bir bağlantıya giderdi.
  });
  console.log("users : yazıldı (usta + mağaza açık, müsait)");

  // artisanProfiles/{uid} — Keşfet'te görünmesi için meslek + bölge şart.
  await writeDoc(token, `artisanProfiles/${uid}`, {
    uid: S(uid),
    displayName: S(DISPLAY_NAME),
    // Meslek kodları `assets/data/professions.json` ile birebir (İngilizce).
    professions: A([S("electrician"), S("plumber")]),
    serviceAreas: A([
      M({ province: S("34"), district: S("3423"), neighborhood: S("") }),
    ]),
    aboutText: S(
      "Play inceleme hesabı — elektrik ve tesisat işleri (test verisi)."
    ),
    alwaysAvailable: B(true),
    manualPause: B(false),
    showPhoneOnProfile: B(false),
    averageRating: D(0),
    totalReviews: I(0),
    totalRatingSum: I(0),
    completedJobs: I(0),
    createdAt: T(simdi),
    // isVerified / adminVerified / isPremium YAZILMIYOR: bunlar yalnız
    // CF ve admin tarafından yazılabilir (firestore.rules).
  });
  console.log("artisan: vitrin yazıldı (elektrikçi + tesisatçı, İstanbul)");

  console.log("\n─────────── PLAY CONSOLE'A GİRİLECEK ───────────");
  console.log(`Kullanıcı adı : ${EMAIL}`);
  console.log(`Şifre         : ${PASSWORD}`);
  console.log("────────────────────────────────────────────────");
}

main().catch((e) => {
  console.error("\nHATA:", e.message);
  process.exit(1);
});
