const crypto = require('crypto');
const { enqueueEvent, scheduleDispatch, popDue, getEventPayload, redis } = require('./queue');
const { getInstallationToken } = require('./github_auth');
const { dispatchWorkflow } = require('./dispatcher');
const metrics = require('./metrics');

const APP_ID = process.env.GITHUB_APP_ID;
const PRIVATE_KEY = process.env.GITHUB_APP_PRIVATE_KEY; // PEM as env var

function verifySignature(req) {
  const sig = req.headers['x-hub-signature-256'];
  if (!sig) return false;
  const hmac = crypto.createHmac('sha256', process.env.WEBHOOK_SECRET);
  const digest = 'sha256=' + hmac.update(JSON.stringify(req.body)).digest('hex');
  return crypto.timingSafeEqual(Buffer.from(sig), Buffer.from(digest));
}

async function handleWebhook(req, res, { logger }) {
  if (!verifySignature(req)) {
    metrics.webhook_invalid.inc();
    res.status(401).send('invalid signature');
    return;
  }
  metrics.webhooks_total.inc();

  const event = req.headers['x-github-event'];
  if (event !== 'push' && event !== 'pull_request') {
    res.status(204).send('ignored');
    return;
  }

  const body = req.body;
  const repoFull = body.repository.full_name;
  const ref = body.ref || (body.pull_request && body.pull_request.head.ref);
  const branch = (ref || '').replace('refs/heads/', '');
  const sha = body.after || (body.pull_request && body.pull_request.head.sha);
  const actor = body.pusher?.name || body.sender?.login || '';

  if (actor.toLowerCase().includes('dependabot')) {
    metrics.webhooks_ignored.inc();
    return res.status(204).send('ignored dependabot');
  }

  await enqueueEvent(repoFull, branch, sha, { body });
  await scheduleDispatch(repoFull, branch);

  metrics.enqueued_total.inc();
  res.status(200).send('queued');
}

async function startWorker({ logger, intervalSec = 10 } = {}) {
  logger.info('Worker starting');
  while (true) {
    try {
      const now = Math.floor(Date.now() / 1000);
      const members = await popDue(now);
      for (const member of members) {
        const [repoFull, branch] = member.split('|');
        const data = await getEventPayload(repoFull, branch);
        if (!data) continue;
        const { sha, payload } = data;
        const installationId = payload?.body?.installation?.id;
        if (!installationId) {
          logger.warn({ repoFull }, 'No installation id');
          continue;
        }
        try {
          const token = await getInstallationToken(installationId, APP_ID, PRIVATE_KEY);
          await dispatchWorkflow(token, repoFull, sha, branch);
          metrics.dispatches_total.inc();
          logger.info({ repoFull, branch, sha }, 'Dispatched orchestrator');
        } catch (err) {
          logger.error({ err }, 'Dispatch failed');
          metrics.dispatch_errors.inc();
        }
      }
    } catch (err) {
      logger.error({ err }, 'Worker loop error');
    }
    await new Promise(r => setTimeout(r, intervalSec * 1000));
  }
}

module.exports = { handleWebhook, startWorker };
