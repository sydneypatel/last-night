const fetch = require('node-fetch');

async function getApnsToken() {
  const keyContent = process.env.APNS_KEY_CONTENT.replace(/\\n/g, '\n');
  
  const pemBody = keyContent
    .replace('-----BEGIN PRIVATE KEY-----', '')
    .replace('-----END PRIVATE KEY-----', '')
    .replace(/\s/g, '');
  const keyBuffer = Buffer.from(pemBody, 'base64');

  const cryptoKey = await crypto.subtle.importKey(
    'pkcs8',
    keyBuffer,
    { name: 'ECDSA', namedCurve: 'P-256' },
    false,
    ['sign']
  );

  const header = Buffer.from(JSON.stringify({ alg: 'ES256', kid: process.env.APNS_KEY_ID })).toString('base64url');
  const now = Math.floor(Date.now() / 1000);
  const payload = Buffer.from(JSON.stringify({ iss: process.env.APNS_TEAM_ID, iat: now })).toString('base64url');
  const signingInput = `${header}.${payload}`;

  const signature = await crypto.subtle.sign(
    { name: 'ECDSA', hash: 'SHA-256' },
    cryptoKey,
    Buffer.from(signingInput)
  );

  const sigBase64 = Buffer.from(signature).toString('base64url');
  return `${signingInput}.${sigBase64}`;
}

async function sendPush(deviceToken, title, body, data = {}) {
  const token = await getApnsToken();
  const url = `https://api.sandbox.push.apple.com/3/device/${deviceToken}`;

  const payload = {
    aps: {
      alert: { title, body },
      sound: 'default',
      badge: 1,
    },
    ...data,
  };

  const res = await fetch(url, {
    method: 'POST',
    headers: {
      'authorization': `bearer ${token}`,
      'apns-topic': process.env.APNS_BUNDLE_ID,
      'apns-push-type': 'alert',
      'content-type': 'application/json',
    },
    body: JSON.stringify(payload),
  });

  if (!res.ok) {
    const err = await res.json();
    console.error('APNs error:', err);
  }
}

module.exports = { sendPush };