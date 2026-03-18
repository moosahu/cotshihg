const { createClient } = require('redis');
require('dotenv').config();

const client = createClient({
  url: process.env.REDIS_URL || 'redis://localhost:6379',
});

client.on('connect', () => console.log('✅ Connected to Redis'));
client.on('error', (err) => console.error('❌ Redis error:', err));

(async () => {
  await client.connect();
})();

module.exports = client;
