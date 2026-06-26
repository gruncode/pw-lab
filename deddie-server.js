// server.js — runs on the laptop. Launches a real Chromium browser server that chromium.connect() can attach to.
const { chromium } = require('playwright');
(async () => {
  const server = await chromium.launchServer({
    headless: false,                       // visible window on the laptop
    host: '127.0.0.1',
    port: 9333,
    wsPath: 'pw',                          // endpoint = ws://127.0.0.1:9333/pw
    args: ['--no-sandbox']
  });
  console.log('Browser server listening at', server.wsEndpoint());
  // keep alive
  process.on('SIGINT', async () => { await server.close(); process.exit(0); });
})().catch(e => { console.error('server FAIL:', e.message); process.exit(1); });
