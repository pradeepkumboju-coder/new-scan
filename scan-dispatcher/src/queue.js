const IORedis = require('ioredis');
const redis = new IORedis(process.env.REDIS_URL || 'redis://localhost:6379');

const DEBOUNCE_WINDOW = parseInt(process.env.DEBOUNCE_SECONDS || '45', 10);

// latest payload stored in hash per repo|branch key
function enqueueEvent(repoFull, branch, sha, payload) {
  const key = `scan:latest:${repoFull}:${branch}`;
  return redis
    .multi()
    .hset(key, { sha, payload: JSON.stringify(payload) })
    .expire(key, DEBOUNCE_WINDOW + 120)
    .exec();
}

async function scheduleDispatch(repoFull, branch) {
  const key = `scan:schedule`;
  const member = `${repoFull}|${branch}`;
  const score = Math.floor(Date.now() / 1000) + DEBOUNCE_WINDOW;
  await redis.zadd(key, score, member);
}

async function popDue(nowSec = Math.floor(Date.now() / 1000)) {
  const key = `scan:schedule`;
  const members = await redis.zrangebyscore(key, 0, nowSec);
  if (!members.length) return [];
  // atomically remove them
  const tx = redis.multi();
  members.forEach(m => tx.zrem(key, m));
  await tx.exec();
  return members;
}

async function getEventPayload(repoFull, branch) {
  const key = `scan:latest:${repoFull}:${branch}`;
  const data = await redis.hgetall(key);
  if (!data || !data.sha) return null;
  return { sha: data.sha, payload: JSON.parse(data.payload) };
}

module.exports = { enqueueEvent, scheduleDispatch, popDue, getEventPayload, redis };
