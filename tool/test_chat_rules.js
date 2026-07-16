'use strict';
const fs = require('fs');
const path = require('path');
const https = require('https');
const os = require('os');

const PROJECT = 'alljob1';

function loadCfg() {
  const p = path.join(os.homedir(), '.config', 'configstore', 'firebase-tools.json');
  return JSON.parse(fs.readFileSync(p, 'utf8'));
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
            resolve({status: res.statusCode, json: j});
          });
        },
    );
    r.on('error', reject);
    if (payload) r.write(payload);
    r.end();
  });
}

async function token(cfg) {
  const data = new URLSearchParams({
    grant_type: 'refresh_token',
    refresh_token: cfg.tokens.refresh_token,
    client_id:
      '563584335869-fgrhgmd47bqnekij5i8b5pr03ho849e6.apps.googleusercontent.com',
    client_secret: 'j9iVZfS8kkCEFUPaAeJV0sAi',
  }).toString();
  const tok = await new Promise((resolve, reject) => {
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
  return tok.access_token;
}

async function main() {
  const access = await token(loadCfg());
  const auth = {Authorization: 'Bearer ' + access};
  const src = fs.readFileSync('firestore.rules', 'utf8');
  const base = {
    customerUid: 'c1',
    artisanUid: 'a1',
    participants: ['c1', 'a1'],
    members: {c1: true, a1: true},
    customerName: 'C',
    artisanName: 'A',
  };
  const chatPath = '/databases/(default)/documents/chats/chat_c1__a1';
  const userAuth = {
    uid: 'c1',
    token: {firebase: {sign_in_provider: 'password'}},
  };

  const cases = [
    {
      name: 'ALLOW lastMessage',
      exp: 'ALLOW',
      method: 'update',
      after: Object.assign({}, base, {
        lastMessage: 'hi',
        lastMessageSenderUid: 'c1',
        updatedAt: '2026-07-14T00:00:00Z',
      }),
    },
    {
      name: 'DENY hijack members',
      exp: 'DENY',
      method: 'update',
      after: Object.assign({}, base, {
        members: {c1: true, a1: true, evil: true},
      }),
    },
    {
      name: 'DENY change customerUid',
      exp: 'DENY',
      method: 'update',
      after: Object.assign({}, base, {customerUid: 'evil'}),
    },
    {
      name: 'ALLOW members heal',
      exp: 'ALLOW',
      method: 'update',
      // simulate members missing before → after full heal
      before: Object.assign({}, base, {members: {c1: true}}),
      after: Object.assign({}, base, {members: {c1: true, a1: true}}),
    },
    {
      name: 'ALLOW create',
      exp: 'ALLOW',
      method: 'create',
      after: base,
    },
    {
      name: 'DENY create third member',
      exp: 'DENY',
      method: 'create',
      after: Object.assign({}, base, {
        members: {c1: true, a1: true, x: true},
      }),
    },
  ];

  const testCases = cases.map((c) => {
    const req = {
      auth: userAuth,
      method: c.method,
      path: chatPath,
      resource: {data: c.after},
    };
    const tc = {expectation: c.exp, request: req};
    if (c.method === 'update') {
      tc.resource = {data: c.before || base};
    }
    return tc;
  });

  const res = await httpsJson(
      'POST',
      `https://firebaserules.googleapis.com/v1/projects/${PROJECT}:test`,
      auth,
      {
        source: {files: [{name: 'firestore.rules', content: src}]},
        testSuite: {testCases},
      },
  );

  if (!res.json || !res.json.testResults) {
    console.log(JSON.stringify(res, null, 2));
    process.exit(1);
  }

  let fail = 0;
  cases.forEach((c, i) => {
    const r = res.json.testResults[i];
    const ok = r.state === 'SUCCESS';
    if (!ok) fail++;
    console.log(
        (ok ? 'OK  ' : 'FAIL') +
          ' ' +
          c.name +
          ' exp=' +
          c.exp +
          ' state=' +
          r.state +
          (r.debugMessages ? ' ' + JSON.stringify(r.debugMessages) : ''),
    );
  });
  process.exit(fail ? 1 : 0);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
