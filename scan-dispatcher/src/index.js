// Entrypoint: HTTP server + metrics + worker
const express = require('express');
const bodyParser = require('body-parser');
const { handleWebhook, startWorker } = require('./handlers');
const metrics = require('./metrics');
const pino = require('pino');
const logger = pino({ level: process.env.LOG_LEVEL || 'info' });

const app = express();
app.use(bodyParser.json({ limit: '2mb' }));

app.get('/healthz', (req, res) => res.status(200).send('ok'));
app.get('/readyz', (req, res) => res.status(200).send('ready'));
app.get('/metrics', async (req, res) => {
  res.set('Content-Type', metrics.register.contentType);
  res.end(await metrics.register.metrics());
});

app.post('/webhook', async (req, res) => {
  try {
    await handleWebhook(req, res, { logger });
  } catch (err) {
    logger.error({ err }, 'webhook handler failed');
    res.status(500).send('error');
  }
});

const port = process.env.PORT || 3000;
app.listen(port, async () => {
  logger.info(`scan-dispatcher listening on ${port}`);
  // start worker loop in background
  startWorker({ logger }).catch(err => logger.error(err, 'worker failed'));
});
