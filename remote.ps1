# pw/remote.ps1 — expose laptop's Playwright server to the internet via Cloudflare (no admin)
# Run on the laptop AFTER setup.ps1:  irm https://raw.githubusercontent.com/gruncode/pw-lab/main/remote.ps1 | iex
$ErrorActionPreference = 'Stop'
$work = Join-Path $env:TEMP 'pwlab'
if (-not (Test-Path $work)) { Write-Host "Run setup.ps1 first." -ForegroundColor Red; return }
Set-Location $work

# --- proxy (so cloudflared/download work through corporate proxy) ---
$ieKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$pe = (Get-ItemProperty $ieKey -ErrorAction SilentlyContinue).ProxyEnable
$ps = (Get-ItemProperty $ieKey -ErrorAction SilentlyContinue).ProxyServer
$useProxy = $false
if ($pe -eq 1 -and $ps) {
  Write-Host ("Proxy detected: {0}" -f $ps) -ForegroundColor Yellow
  $env:HTTP_PROXY = "http://$ps"; $env:HTTPS_PROXY = "http://$ps"; $useProxy = $true
}

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$node = Join-Path $work "node-v20.17.0-win-$arch\node.exe"

# --- get cloudflared.exe (from GitHub releases — allowed by your filter) ---
$cf = Join-Path $work 'cloudflared.exe'
if (-not (Test-Path $cf)) {
  $cfurl = "https://github.com/cloudflare/cloudflared/releases/latest/download/cloudflared-windows-$arch.exe"
  Write-Host ("Downloading cloudflared: {0}" -f $cfurl)
  Invoke-WebRequest -UseBasicParsing -Uri $cfurl -OutFile $cf
}

# --- start Playwright server (WebSocket) on localhost:9333/pw ---
Write-Host "Starting Playwright server on 127.0.0.1:9333/pw ..." -ForegroundColor Cyan
Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $node } | Stop-Process -Force -ErrorAction SilentlyContinue
$srv = Start-Process -FilePath $node `
  -ArgumentList "node_modules\playwright\cli.js","run-server","--port","9333","--host","127.0.0.1","--path","/pw" `
  -PassThru -WindowStyle Minimized
Start-Sleep -Seconds 3

# --- expose via Cloudflare quick tunnel; prints a https://*.trycloudflare.com URL ---
Write-Host "===========================================================" -ForegroundColor Green
Write-Host " Starting Cloudflare tunnel. Below you will see a line like:" -ForegroundColor Green
Write-Host "   https://something-random.trycloudflare.com" -ForegroundColor Green
Write-Host " SEND THAT URL TO GEORGE. Keep this window OPEN." -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
$proto = if ($useProxy) { @('--protocol','http2') } else { @() }
& $cf tunnel @proto --url http://127.0.0.1:9333
