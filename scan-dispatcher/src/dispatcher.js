const axios = require('axios');

const ORG = process.env.GITHUB_ORG;
const ORCHESTRATOR_REPO = process.env.ORCHESTRATOR_REPO || 'scan-orchestrator';
const ORCHESTRATOR_WORKFLOW = process.env.ORCHESTRATOR_WORKFLOW || 'dispatcher.yml';
const MAX_RETRIES = parseInt(process.env.MAX_RETRIES || '5', 10);

// dispatch workflow using installation token
async function dispatchWorkflow(installationToken, repoFull, sha, branch) {
  const endpoint = `https://api.github.com/repos/${ORG}/${ORCHESTRATOR_REPO}/actions/workflows/${ORCHESTRATOR_WORKFLOW}/dispatches`;
  const payload = { ref: 'main', inputs: { repo: repoFull, sha, branch } };
  const headers = { Authorization: `token ${installationToken}`, Accept: 'application/vnd.github+json' };

  for (let attempt = 1; attempt <= MAX_RETRIES; attempt++) {
    try {
      const r = await axios.post(endpoint, payload, { headers });
      return r.status === 204;
    } catch (err) {
      const status = err.response?.status;
      if (status === 429 || (status >= 500 && status < 600)) {
        const backoff = Math.pow(2, attempt) * 1000;
        await new Promise(r => setTimeout(r, backoff));
        continue;
      }
      throw err;
    }
  }
  throw new Error('Failed to dispatch after retries');
}

module.exports = { dispatchWorkflow };
