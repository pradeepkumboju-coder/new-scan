const client = require('prom-client');
client.collectDefaultMetrics({ prefix: 'dispatcher_' });

const register = client;
const webhooks_total = new client.Counter({ name: 'dispatcher_webhooks_total', help: 'Total webhooks received' });
const webhooks_ignored = new client.Counter({ name: 'dispatcher_webhooks_ignored', help: 'Ignored webhooks' });
const webhook_invalid = new client.Counter({ name: 'dispatcher_webhook_invalid_total', help: 'Invalid signature webhooks' });
const enqueued_total = new client.Counter({ name: 'dispatcher_enqueued_total', help: 'Events enqueued' });
const dispatches_total = new client.Counter({ name: 'dispatcher_dispatches_total', help: 'Dispatches made' });
const dispatch_errors = new client.Counter({ name: 'dispatcher_dispatch_errors_total', help: 'Dispatch errors' });

module.exports = { register, webhooks_total, webhooks_ignored, webhook_invalid, enqueued_total, dispatches_total, dispatch_errors };
