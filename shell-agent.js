// shell-agent.js — runs on the laptop. Executes commands sent over the relay (room "shell") in PowerShell.
// Each inbound line = one command. Replies with stdout+stderr followed by an EOT byte (0x04).
const WebSocket = require('ws');
const { exec } = require('child_process');
const RELAY = process.env.SHELL_RELAY || 'wss://tskuk-pwrelay.hf.space/a/shell';
const TOKEN = process.env.PWTOKEN || '';
const EOT = String.fromCharCode(4);   // end-of-output marker

function connect() {
  const ws = new WebSocket(RELAY, { headers: { 'x-pw-token': TOKEN } });
  let buf = '';
  ws.on('open', () => console.log('shell agent connected'));
  ws.on('message', (d) => {
    buf += d.toString();
    let nl;
    while ((nl = buf.indexOf('\n')) >= 0) {
      const cmd = buf.slice(0, nl); buf = buf.slice(nl + 1);
      if (!cmd.trim()) continue;
      // EncodedCommand avoids all quoting issues (UTF-16LE base64)
      const b64 = Buffer.from(cmd, 'utf16le').toString('base64');
      exec('powershell -NoProfile -EncodedCommand ' + b64,
        { maxBuffer: 16 * 1024 * 1024, timeout: 180000, windowsHide: true },
        (err, stdout, stderr) => {
          let out = (stdout || '') + (stderr || '');
          if (err && !stdout && !stderr) out += '\n[exec error] ' + err.message;
          if (ws.readyState === 1) ws.send(out + EOT);
        });
    }
  });
  ws.on('close', () => { setTimeout(connect, 2000); });
  ws.on('error', (e) => console.error('relay error:', e.message));
}
console.log('shell agent starting ->', RELAY);
connect();
