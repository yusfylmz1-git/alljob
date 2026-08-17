'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const PROJECT = 'alljob1';
const JOB_ID = process.argv[2] || 'qXwTvvbGpKtBVV4F65td';

function loadCfg() {
  const candidates = [
    path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
  ];
  for (const p of candidates) {
    if (p && fs.existsSync(p)) return JSON.parse(fs.readFileSync(p, 'utf8'));
  }
  throw new Error('firebase-tools.json yok');
}

function httpsJson(method, url, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const payload = body ? JSON.stringify(body) : null;
    const h = Object.assign({Accept: 'application/json'}, headers || {});
    if (payload) {
      h['Content-Type'] = 'application/json';
      h['Content-Length'] = Buffer.byteLength(payload);
    }
    const r = https.request(
        {
          hostname: u.hostname,
          path: u.pathname + u.search,
          method,
          headers: h,
        },
        (res) => {
          let raw = '';
          res.on('data', (c) => (raw += c));
          res.on('end', () => {
            let j = null;
            try {
              j = raw ? JSON.parse(raw) : null;
            } catch (_) {/* ignore */}
            resolve({status: res.statusCode, json: j, raw: raw.slice(0, 2500)});
          });
        },
    );
    r.on('error', reject);
    if (payload) r.write(payload);
    r.end();
  });
}

async function getToken(cfg) {
  const tokens = cfg.tokens || {};
  const data = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: tokens.refresh_token,
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
  }).toString();
  const tokRes = await new Promise((resolve, reject) => {
    const r = https.request(
        {
          hostname: 'oauth2.googleapis.com',
          path: '/token',
          method: 'POST',
          headers: {
            'Content-Type': 'application/x-www-form-urlencoded',
            'Content-Length': Buffer.byteLength(data),
          },
        },
        (res) => {
          let raw = '';
          res.on('data', (c) => (raw += c));
          res.on('end', () => resolve(JSON.parse(raw)));
        },
    );
    r.on('error', reject);
    r.write(data);
    r.end();
  });
  if (!tokRes.access_token) throw new Error('token yok');
  return tokRes.access_token;
}

function fv(field) {
  if (!field) return null;
  if (field.stringValue != null) return field.stringValue;
  if (field.booleanValue != null) return field.booleanValue;
  if (field.integerValue != null) return Number(field.integerValue);
  if (field.arrayValue) {
    return (field.arrayValue.values || []).map(fv);
  }
  if (field.mapValue) {
    const o = {};
    for (const [k, v] of Object.entries(field.mapValue.fields || {})) {
      o[k] = fv(v);
    }
    return o;
  }
  return field;
}

async function main() {
  const token = await getToken(loadCfg());
  const auth = {Authorization: 'Bearer ' + token};
  const base =
    `https://firestore.googleapis.com/v1/projects/${PROJECT}` +
    '/databases/(default)/documents';

  const jobRes = await httpsJson('GET', `${base}/jobs/${JOB_ID}`, auth);
  if (jobRes.status !== 200) {
    console.log('JOB_GET', jobRes.status, jobRes.raw);
    return;
  }
  const jf = jobRes.json.fields || {};
  const job = {
    id: JOB_ID,
    title: fv(jf.title),
    category: fv(jf.category),
    productCategoryCode: fv(jf.productCategoryCode),
    province: fv(jf.province),
    district: fv(jf.district),
    customerId: fv(jf.customerId),
    status: fv(jf.status),
  };
  console.log('JOB', JSON.stringify(job, null, 2));

  const shops = await httpsJson('POST', `${base}:runQuery`, auth, {
    structuredQuery: {
      from: [{collectionId: 'users'}],
      where: {
        fieldFilter: {
          field: {fieldPath: 'hasShopProfile'},
          op: 'EQUAL',
          value: {booleanValue: true},
        },
      },
      limit: 50,
    },
  });
  const shopRows = Array.isArray(shops.json) ?
    shops.json.filter((x) => x.document) :
    [];
  console.log('SHOP_USERS', shopRows.length, shops.status);
  if (shops.status !== 200) console.log(shops.raw);
  for (const row of shopRows) {
    const f = row.document.fields || {};
    const uid = row.document.name.split('/').pop();
    console.log(' SHOP', JSON.stringify({
      uid,
      name: fv(f.displayName),
      shopCategories: fv(f.shopCategories),
      shopServiceAreas: fv(f.shopServiceAreas),
      available: fv(f.available),
    }));
  }

  const prods = await httpsJson('POST', `${base}:runQuery`, auth, {
    structuredQuery: {
      from: [{collectionId: 'products'}],
      limit: 40,
    },
  });
  const prodRows = Array.isArray(prods.json) ?
    prods.json.filter((x) => x.document) :
    [];
  console.log('PRODUCTS', prodRows.length, prods.status);
  for (const row of prodRows) {
    const f = row.document.fields || {};
    console.log(' PROD', JSON.stringify({
      id: row.document.name.split('/').pop(),
      ownerUid: fv(f.ownerUid),
      status: fv(f.status),
      categoryCode: fv(f.categoryCode),
      province: fv(f.province),
      moderationHidden: fv(f.moderationHidden),
    }));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
