/**
 * Diagnose jobs collection + auth claims for job-create issues.
 * Usage: node tool/diag_jobs.js
 */
'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const PROJECT = 'alljob1';

function loadCfg() {
  const candidates = [
    path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json'),
    path.join(process.env.APPDATA || '', 'configstore', 'firebase-tools.json'),
  ];
  for (const p of candidates) {
    if (p && fs.existsSync(p)) {
      return JSON.parse(fs.readFileSync(p, 'utf8'));
    }
  }
  throw new Error('firebase-tools.json yok');
}

function httpsJson(method, url, headers, body) {
  return new Promise((resolve, reject) => {
    const u = new URL(url);
    const payload = body ? JSON.stringify(body) : null;
    const h = Object.assign({'Accept': 'application/json'}, headers || {});
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
          family: 6,
          servername: u.hostname,
        },
        (res) => {
          let raw = '';
          res.on('data', (c) => (raw += c));
          res.on('end', () => {
            let j = null;
            try {
              j = raw ? JSON.parse(raw) : null;
            } catch (_) {
              /* ignore */
            }
            resolve({status: res.statusCode, json: j, raw: raw.slice(0, 2000)});
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
          family: 6,
          servername: 'oauth2.googleapis.com',
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
  if (!tokRes.access_token) throw new Error('token yok: ' + JSON.stringify(tokRes));
  return tokRes.access_token;
}

async function main() {
  const token = await getToken(loadCfg());
  const auth = {Authorization: 'Bearer ' + token};

  const open = await httpsJson(
      'POST',
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`,
      auth,
      {
        structuredQuery: {
          from: [{collectionId: 'jobs'}],
          where: {
            fieldFilter: {
              field: {fieldPath: 'status'},
              op: 'EQUAL',
              value: {stringValue: 'open'},
            },
          },
          limit: 20,
        },
      },
  );
  const openRows = Array.isArray(open.json) ?
    open.json.filter((x) => x.document) :
    [];
  console.log('open jobs:', openRows.length);
  for (const row of openRows) {
    const f = row.document.fields || {};
    console.log(
        ' -',
        row.document.name.split('/').pop(),
        f.createdAt && f.createdAt.stringValue,
        f.title && f.title.stringValue,
        'modHidden=',
        f.moderationHidden,
    );
  }

  const all = await httpsJson(
      'POST',
      `https://firestore.googleapis.com/v1/projects/${PROJECT}/databases/(default)/documents:runQuery`,
      auth,
      {
        structuredQuery: {
          from: [{collectionId: 'jobs'}],
          limit: 100,
        },
      },
  );
  const allRows = Array.isArray(all.json) ?
    all.json.filter((x) => x.document) :
    [];
  const byStatus = {};
  for (const row of allRows) {
    const s =
      (row.document.fields.status &&
        row.document.fields.status.stringValue) ||
      '?';
    byStatus[s] = (byStatus[s] || 0) + 1;
  }
  console.log('jobs sample (up to 100):', allRows.length, byStatus);

  const rules = await httpsJson(
      'GET',
      `https://firebaserules.googleapis.com/v1/projects/${PROJECT}/releases/cloud.firestore`,
      auth,
  );
  console.log(
      'rules release:',
      rules.status,
      rules.json && rules.json.rulesetName,
  );

  // Test ruleset compile content for jobs create snippet
  if (rules.json && rules.json.rulesetName) {
    const rs = await httpsJson(
        'GET',
        `https://firebaserules.googleapis.com/v1/${rules.json.rulesetName}`,
        auth,
    );
    const src =
      (rs.json &&
        rs.json.source &&
        rs.json.source.files &&
        rs.json.source.files[0] &&
        rs.json.source.files[0].content) ||
      '';
    console.log('rules has moderationHidden:', src.includes('moderationHidden'));
    console.log('rules has isSuspended on jobs create:',
        /jobs[\s\S]*allow create:[\s\S]*isSuspended/.test(src));
    const m = src.match(/allow create: if isSignedIn\(\)[\s\S]{0,400}adminModerationNote[^\n]*/);
    if (m) console.log('create rule snippet:\n', m[0].slice(0, 500));
  }
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
