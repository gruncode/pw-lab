# pw/remote2.ps1 — start Playwright run-server + bridge it to George via the HF relay (hf.space).
# Run on the laptop AFTER setup.ps1:  irm https://raw.githubusercontent.com/gruncode/pw-lab/main/deddie-remote2.ps1 | iex
$ErrorActionPreference = 'Stop'
$SINK = 'https://tskuk-pwrelay.hf.space/up'
$work = Join-Path $env:TEMP 'pwlab'
if (-not (Test-Path $work)) { Write-Host "Run setup.ps1 first." -ForegroundColor Red; return }
if (-not $env:PWTOKEN) { Write-Host "Set the token first:  `$env:PWTOKEN='...'  then re-run." -ForegroundColor Red; return }
Set-Location $work

# save a private local launcher (token stays only on this PC) for easy future runs
$startFile = Join-Path $env:USERPROFILE 'pw-start.ps1'
if (-not (Test-Path $startFile)) {
  ("`$env:PWTOKEN = '" + $env:PWTOKEN + "'`r`nirm https://raw.githubusercontent.com/gruncode/pw-lab/main/deddie-remote2.ps1 | iex") | Out-File -Encoding ascii $startFile
  Write-Host ("Saved local launcher: {0}" -f $startFile) -ForegroundColor Green
  Write-Host ("Next time just run:  gc `"{0}`" -Raw | iex" -f $startFile) -ForegroundColor Green
}

# proxy (none expected, but mirror anyway)
$ieKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$pe = (Get-ItemProperty $ieKey -ErrorAction SilentlyContinue).ProxyEnable
$ps = (Get-ItemProperty $ieKey -ErrorAction SilentlyContinue).ProxyServer
if ($pe -eq 1 -and $ps) { $env:HTTP_PROXY = "http://$ps"; $env:HTTPS_PROXY = "http://$ps" }

$arch = if ($env:PROCESSOR_ARCHITECTURE -eq 'ARM64') { 'arm64' } else { 'x64' }
$nodeDir = Join-Path $work "node-v20.17.0-win-$arch"
$node = Join-Path $nodeDir 'node.exe'
$npm  = Join-Path $nodeDir 'npm.cmd'
$env:Path = "$nodeDir;" + $env:Path

# need the 'ws' package for the bridge
if (-not (Test-Path (Join-Path $work 'node_modules\ws'))) {
  Write-Host "Installing ws..."; & $npm i ws --no-fund --no-audit
}

# report playwright version so George can match it on his side
$pv = (& $node (Join-Path $work 'node_modules\playwright\cli.js') --version) 2>$null
try { Invoke-WebRequest -UseBasicParsing -Uri $SINK -Method Post -Body ("AGENT: playwright $pv  arch=$arch") -TimeoutSec 12 | Out-Null } catch {}
Write-Host ("Playwright: {0}" -f $pv) -ForegroundColor Cyan

# get server.js (launchServer) + agent.js (bridge) + shell-agent.js (remote shell)
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/gruncode/pw-lab/main/deddie-server.js' -OutFile (Join-Path $work 'server.js')
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/gruncode/pw-lab/main/deddie-agent.js' -OutFile (Join-Path $work 'agent.js')
Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/gruncode/pw-lab/main/deddie-shell-agent.js' -OutFile (Join-Path $work 'shell-agent.js')

# (re)start the browser server on 127.0.0.1:9333/pw
Get-Process node -ErrorAction SilentlyContinue | Where-Object { $_.Path -eq $node } | Stop-Process -Force -ErrorAction SilentlyContinue
Start-Sleep -Seconds 1
Write-Host "Starting Chromium browser server on 127.0.0.1:9333/pw ..." -ForegroundColor Cyan
Start-Process -FilePath $node -ArgumentList "server.js" -WindowStyle Minimized
Start-Sleep -Seconds 4

# start the remote shell agent (room "shell") in the background
Write-Host "Starting remote shell agent (room 'shell') ..." -ForegroundColor Cyan
Start-Process -FilePath $node -ArgumentList "shell-agent.js" -WindowStyle Minimized
Start-Sleep -Seconds 2

Write-Host "===========================================================" -ForegroundColor Green
Write-Host " Bridge running. Keep this window OPEN." -ForegroundColor Green
Write-Host " George connects from d7070 to wss://tskuk-pwrelay.hf.space/ws" -ForegroundColor Green
Write-Host "===========================================================" -ForegroundColor Green
& $node (Join-Path $work 'agent.js')
