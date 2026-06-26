# pw/setup.ps1 — portable Node + Playwright smoke test on a locked-down Windows laptop (no admin)
# Run on the laptop:  irm https://iekoci.ydns.eu/pw/setup.ps1 | iex
$ErrorActionPreference = 'Stop'
Write-Host "==== Playwright laptop setup ====" -ForegroundColor Cyan
Write-Host ("Arch: {0}" -f $env:PROCESSOR_ARCHITECTURE)

# --- working dir in TEMP (user-writable, no admin) ---
$work = Join-Path $env:TEMP 'pwlab'
New-Item -ItemType Directory -Force -Path $work | Out-Null
Set-Location $work

# --- detect system proxy from registry, so node/npm/playwright downloads work ---
$ieKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$pe = (Get-ItemProperty $ieKey -ErrorAction SilentlyContinue).ProxyEnable
$ps = (Get-ItemProperty $ieKey -ErrorAction SilentlyContinue).ProxyServer
if ($pe -eq 1 -and $ps) {
  Write-Host ("Proxy detected: {0}" -f $ps) -ForegroundColor Yellow
  $env:HTTP_PROXY  = "http://$ps"
  $env:HTTPS_PROXY = "http://$ps"
} else {
  Write-Host "No system proxy configured (direct)."
}

# --- portable Node (download + unzip, no install) ---
$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$ver  = 'v20.17.0'
$dir  = "node-$ver-win-$arch"
$nodeDir = Join-Path $work $dir
if (-not (Test-Path (Join-Path $nodeDir 'node.exe'))) {
  $url = "https://nodejs.org/dist/$ver/$dir.zip"
  Write-Host ("Downloading portable Node: {0}" -f $url)
  Invoke-WebRequest -UseBasicParsing -Uri $url -OutFile (Join-Path $work 'node.zip')
  Write-Host "Extracting..."
  Expand-Archive -Force -Path (Join-Path $work 'node.zip') -DestinationPath $work
}
$node = Join-Path $nodeDir 'node.exe'
$npm  = Join-Path $nodeDir 'npm.cmd'
$env:Path = "$nodeDir;" + $env:Path
Write-Host ("Node OK: {0}" -f (& $node -v)) -ForegroundColor Green

# --- project + Playwright ---
if (-not (Test-Path 'package.json')) { '{ "name":"pwlab","private":true }' | Out-File -Encoding ascii package.json }
Write-Host "Installing playwright (npm)..."
& $npm i playwright --no-fund --no-audit
Write-Host "Installing Chromium browser..."
& $node (Join-Path $work 'node_modules\playwright\cli.js') install chromium

# --- smoke test: open a real (visible) browser ---
$test = @'
const { chromium } = require('playwright');
(async () => {
  console.log('Launching Chromium (headed)...');
  const b = await chromium.launch({ headless: false });
  const p = await b.newPage();
  await p.goto('https://www.bing.com', { timeout: 60000 });
  console.log('PAGE TITLE:', await p.title());
  await p.screenshot({ path: 'shot.png' });
  await p.waitForTimeout(4000);
  await b.close();
  console.log('OK -- Playwright works on this laptop.');
})().catch(e => { console.error('FAILED:', e.message); process.exit(1); });
'@
$test | Out-File -Encoding ascii (Join-Path $work 'test.js')
Write-Host "Running smoke test..." -ForegroundColor Cyan
& $node (Join-Path $work 'test.js')
Write-Host ("Done. Folder: {0}" -f $work) -ForegroundColor Green
