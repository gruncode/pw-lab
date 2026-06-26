// agent.js — runs on the laptop. Bridges the HF relay to the local Playwright run-server.
//   relay (wss://.../agent)  <-->  local (ws://127.0.0.1:9333/pw)
const WebSocket = require('ws');
const RELAY = process.env.RELAY || 'wss://tskuk-pwrelay.hf.space/agent';
const LOCAL = process.env.LOCAL || 'ws://127.0.0.1:9333/pw';
const log = (m) => console.log(new Date().toISOString(), m);

function connect() {
  const up = new WebSocket(RELAY);
  let local = null;
  const q = [];

  function ensureLocal() {
    if (local) return;
    local = new WebSocket(LOCAL);
    local.on('open', () => { while (q.length) { const [d, b] = q.shift(); local.send(d, { binary: b }); } });
    local.on('message', (d, b) => { if (up.readyState === 1) up.send(d, { binary: b }); });
    local.on('close', () => { local = null; });           // session ended; allow a fresh one
    local.on('error', (e) => log('local error: ' + e.message));
  }

  up.on('open', () => log('connected to relay; waiting for controller (d7070)'));
  up.on('message', (d, b) => {
    ensureLocal();
    if (local && local.readyState === 1) local.send(d, { binary: b });
    else q.push([d, b]);
  });
  up.on('close', () => { log('relay closed; reconnecting in 2s'); if (local) { try { local.close(); } catch (e) {} } setTimeout(connect, 2000); });
  up.on('error', (e) => log('relay error: ' + e.message));
}
log('agent starting -> ' + RELAY);
connect();
