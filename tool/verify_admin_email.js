/**
 * One-off: mark bootstrap admin email as verified via Firebase Auth Admin API.
 * Uses firebase-tools login tokens (same user as `firebase login`).
 * Usage: node tool/verify_admin_email.js [email]
 */
const fs = require("fs");
const os = require("os");
const path = require("path");
const https = require("https");

const PROJECT = "alljob1";
const EMAIL = (process.argv[2] || "nflx.tr.avs1@gmail.com").trim().toLowerCase();

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

function postForm(url, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const data = new URLSearchParams(body).toString();
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method: "POST",
        headers: {
          "Content-Type": "application/x-www-form-urlencoded",
          "Content-Length": Buffer.byteLength(data),
        },
      },
      (res) => {
        let raw = "";
        res.on("data", (c) => (raw += c));
        res.on("end", () => {
          try {
            const json = JSON.parse(raw);
            if (res.statusCode >= 400) {
              reject(new Error(`HTTP ${res.statusCode}: ${raw}`));
            } else {
              resolve(json);
            }
          } catch (e) {
            reject(new Error(`Parse error: ${raw}`));
          }
        });
      },
    );
    req.on("error", reject);
    req.write(data);
    req.end();
  });
}

function requestJson(method, url, { token, body } = {}) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const payload = body ? JSON.stringify(body) : null;
    const headers = { Accept: "application/json" };
    if (token) headers.Authorization = `Bearer ${token}`;
    if (payload) {
      headers["Content-Type"] = "application/json";
      headers["Content-Length"] = Buffer.byteLength(payload);
    }
    const req = https.request(
      {
        hostname: u.hostname,
        path: u.pathname + u.search,
        method,
        headers,
      },
      (res) => {
        let raw = "";
        res.on("data", (c) => (raw += c));
        res.on("end", () => {
          let json = null;
          try {
            json = raw ? JSON.parse(raw) : null;
          } catch (_) {
            /* ignore */
          }
          if (res.statusCode >= 400) {
            reject(
              new Error(
                `HTTP ${res.statusCode}: ${raw || res.statusMessage}`,
              ),
            );
          } else {
            resolve(json);
          }
        });
      },
    );
    req.on("error", reject);
    if (payload) req.write(payload);
    req.end();
  });
}

async function getAccessToken(config) {
  // firebase-tools stores tokens under tokens.refresh_token / access_token
  const tokens = config.tokens || config.user?.tokens || {};
  const refresh =
    tokens.refresh_token ||
    tokens.refreshToken ||
    config.refresh_token;
  const existing =
    tokens.access_token || tokens.accessToken || config.access_token;
  const expiresAt = Number(tokens.expires_at || 0);

  // Use cached token if still valid (~2 min margin)
  if (existing && expiresAt > Date.now() + 120000) {
    return existing;
  }

  if (refresh) {
    // Firebase CLI public OAuth client (same as firebase-tools/lib/api.js)
    const clientId =
      "563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com";
    const clientSecret = "j9iVZfS8kkCEFUPaAeJV0sAi";
    const tok = await postForm("https://oauth2.googleapis.com/token", {
      grant_type: "refresh_token",
      refresh_token: refresh,
      client_id: clientId,
      client_secret: clientSecret,
    });
    if (!tok.access_token) {
      throw new Error("Access token alınamadı (refresh başarısız).");
    }
    return tok.access_token;
  }
  if (existing) return existing;
  throw new Error(
    "Login token yok. Terminalde: firebase login  (sonra bu scripti tekrar çalıştır)",
  );
}

async function main() {
  const config = readFirebaseToolsConfig();
  const accessToken = await getAccessToken(config);

  // Lookup user by email (Identity Toolkit)
  const lookup = await requestJson(
    "POST",
    `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`,
    {
      token: accessToken,
      body: { email: [EMAIL] },
    },
  );
  const user = lookup?.users?.[0];
  if (!user) {
    throw new Error(`Kullanıcı bulunamadı: ${EMAIL}`);
  }
  console.log(
    `Bulundu: ${user.email} uid=${user.localId} emailVerified=${user.emailVerified}`,
  );

  if (user.emailVerified === true || user.emailVerified === "true") {
    console.log("Zaten doğrulanmış. Panelde 'Yönetici erişimini etkinleştir' dene.");
    return;
  }

  await requestJson(
    "POST",
    `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:update`,
    {
      token: accessToken,
      body: {
        localId: user.localId,
        emailVerified: true,
      },
    },
  );

  const again = await requestJson(
    "POST",
    `https://identitytoolkit.googleapis.com/v1/projects/${PROJECT}/accounts:lookup`,
    {
      token: accessToken,
      body: { localId: [user.localId] },
    },
  );
  const u2 = again?.users?.[0];
  console.log(
    `Güncellendi: ${u2?.email} emailVerified=${u2?.emailVerified}`,
  );
  console.log(
    "Şimdi admin panelinde çıkış → giriş → 'Yönetici erişimini etkinleştir'.",
  );
}

main().catch((e) => {
  console.error("HATA:", e.message || e);
  process.exit(1);
});
