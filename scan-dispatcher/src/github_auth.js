const jwt = require('jsonwebtoken');
const axios = require('axios');

function generateAppJwt(appId, privateKey) {
  const now = Math.floor(Date.now() / 1000);
  const payload = { iat: now - 60, exp: now + (9 * 60), iss: appId };
  return jwt.sign(payload, privateKey, { algorithm: 'RS256' });
}

async function getInstallationToken(installationId, appId, privateKey) {
  const appJwt = generateAppJwt(appId, privateKey);
  const res = await axios.post(
    `https://api.github.com/app/installations/${installationId}/access_tokens`,
    {},
    { headers: { Authorization: `Bearer ${appJwt}`, Accept: 'application/vnd.github+json' } }
  );
  return res.data.token;
}

module.exports = { generateAppJwt, getInstallationToken };
