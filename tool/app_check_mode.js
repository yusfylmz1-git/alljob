'use strict';
/**
 * App Check enforcement mode.
 * UNENFORCED = monitor (token yoksa da istek geçer; admin web + debug kolay)
 * ENFORCED = token zorunlu
 *
 * Usage:
 *   set NODE_OPTIONS=--dns-result-order=ipv4first
 *   node tool/app_check_mode.js UNENFORCED
 *   node tool/app_check_mode.js ENFORCED
 */
const fs = require('fs');
const path = require('path');

const mode = (process.argv[2] || 'UNENFORCED').toUpperCase();
if (!['OFF', 'UNENFORCED', 'ENFORCED'].includes(mode)) {
  console.error('Mode: OFF | UNENFORCED | ENFORCED');
  process.exit(1);
}

const cfg = JSON.parse(
  fs.readFileSync(
    path.join(
      process.env.USERPROFILE || process.env.HOME,
      '.config',
      'configstore',
      'firebase-tools.json',
    ),
    'utf8',
  ),
);
const at = cfg.tokens && cfg.tokens.access_token;
if (!at) {
  console.error('firebase login required');
  process.exit(1);
}
const H = {
  Authorization: 'Bearer ' + at,
  'Content-Type': 'application/json',
};
const project = 'alljob1';
const services = [
  'firestore.googleapis.com',
  'firebasestorage.googleapis.com',
];

(async () => {
  for (const s of services) {
    const url =
      'https://firebaseappcheck.googleapis.com/v1/projects/' +
      project +
      '/services/' +
      encodeURIComponent(s) +
      '?updateMask=enforcementMode';
    const r = await fetch(url, {
      method: 'PATCH',
      headers: H,
      body: JSON.stringify({
        name: 'projects/' + project + '/services/' + s,
        enforcementMode: mode,
      }),
    });
    const t = await r.text();
    console.log(s, r.status, t.slice(0, 200));
  }
})().catch((e) => {
  console.error(e);
  process.exit(1);
});
