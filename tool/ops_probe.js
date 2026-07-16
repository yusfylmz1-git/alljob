'use strict';
/**
 * Ops probe / one-shot: PITR, App Check status (uses Firebase CLI token).
 * Run: set NODE_OPTIONS=--dns-result-order=ipv4first && node tool/ops_probe.js
 */
const fs = require('fs');
const path = require('path');

const cfgPath = path.join(
  process.env.USERPROFILE || process.env.HOME,
  '.config',
  'configstore',
  'firebase-tools.json',
);
const cfg = JSON.parse(fs.readFileSync(cfgPath, 'utf8'));
const at = cfg.tokens && cfg.tokens.access_token;
if (!at) {
  console.error('No firebase access_token — run: firebase login');
  process.exit(1);
}
const H = {
  Authorization: 'Bearer ' + at,
  'Content-Type': 'application/json',
};
const project = 'alljob1';
const lines = [];

async function main() {
  // Enable PITR
  const pitrUrl =
    'https://firestore.googleapis.com/v1/projects/' +
    project +
    '/databases/(default)?updateMask=pointInTimeRecoveryEnablement';
  const pitrRes = await fetch(pitrUrl, {
    method: 'PATCH',
    headers: H,
    body: JSON.stringify({
      pointInTimeRecoveryEnablement: 'POINT_IN_TIME_RECOVERY_ENABLED',
    }),
  });
  const pitrBody = await pitrRes.text();
  lines.push('PITR_PATCH ' + pitrRes.status + ' ' + pitrBody.slice(0, 400));

  // Confirm DB
  const dbRes = await fetch(
    'https://firestore.googleapis.com/v1/projects/' +
      project +
      '/databases/(default)',
    {headers: H},
  );
  const db = await dbRes.json();
  lines.push(
    'PITR_NOW ' +
      (db.pointInTimeRecoveryEnablement || '?') +
      ' retention=' +
      (db.versionRetentionPeriod || '?'),
  );

  // App Check services
  for (const s of [
    'firestore.googleapis.com',
    'firebasestorage.googleapis.com',
    'identitytoolkit.googleapis.com',
  ]) {
    const r = await fetch(
      'https://firebaseappcheck.googleapis.com/v1/projects/' +
        project +
        '/services/' +
        encodeURIComponent(s),
      {headers: H},
    );
    const j = await r.json();
    lines.push('AC ' + s + ' => ' + (j.enforcementMode || 'OFF'));
  }

  // Play subs (expect fail without Console product / SA link)
  const subRes = await fetch(
    'https://androidpublisher.googleapis.com/androidpublisher/v3/applications/com.ustacepte.usta_cepte/subscriptions',
    {headers: H},
  );
  lines.push(
    'PLAY_SUBS ' + subRes.status + ' ' + (await subRes.text()).slice(0, 200),
  );

  const out = lines.join('\n');
  fs.writeFileSync(path.join(__dirname, '..', 'probe_ops.txt'), out);
  console.log(out);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
