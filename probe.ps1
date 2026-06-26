# pw/probe.ps1 — what does this network allow? Sends results back to George via ntfy (no screenshot needed).
# Run on the laptop:  irm https://raw.githubusercontent.com/gruncode/pw-lab/main/probe.ps1 | iex
$ErrorActionPreference = 'SilentlyContinue'
$SINK = 'https://tskuk-pwrelay.hf.space/up'   # George reads this channel
$out = New-Object System.Collections.ArrayList
function Say($m){ [void]$out.Add($m); Write-Host $m }

# mirror what cloudflared/irm will use: system proxy
$ieKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$pe = (Get-ItemProperty $ieKey).ProxyEnable
$ps = (Get-ItemProperty $ieKey).ProxyServer
if ($pe -eq 1 -and $ps) { $env:HTTP_PROXY = "http://$ps"; $env:HTTPS_PROXY = "http://$ps"; Say ("PROXY: {0}" -f $ps) }
else { Say "PROXY: none (direct)" }
Say ("arch={0}" -f $env:PROCESSOR_ARCHITECTURE)

$targets = @(
  'raw.githubusercontent.com',     # control GOOD
  'api.trycloudflare.com',         # control BAD
  'api.cloudflare.com',            # named-tunnel registration
  'update.argotunnel.com',         # cloudflared edge
  'region1.v2.argotunnel.com',     # cloudflared edge region
  'huggingface.co',                # HF Spaces option
  'tunnel.us.ngrok.com',           # ngrok option
  'tskuk-pwrelay.hf.space',        # HF Space (transport + reply channel candidate)
  'www.google.com'
)
foreach ($t in $targets) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri ("https://{0}/" -f $t) -Method Head -TimeoutSec 8
    Say ("{0,-30} REACHED  HTTP {1}  {2}ms" -f $t, $r.StatusCode, $sw.ElapsedMilliseconds)
  } catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code) { Say ("{0,-30} REACHED  HTTP {1}  {2}ms" -f $t, $code, $sw.ElapsedMilliseconds) }
    else { Say ("{0,-30} BLOCKED  ({1})" -f $t, ($_.Exception.Message -split "`n")[0].Trim()) }
  }
}

# --- send results back to George (so no screenshot is needed) ---
$body = ($out -join "`n")
try {
  Invoke-WebRequest -UseBasicParsing -Uri $SINK -Method Post -Body $body -TimeoutSec 15 | Out-Null
  Write-Host "`n>> Results sent to George (via HF Space)." -ForegroundColor Green
} catch {
  Write-Host "`n>> Could not reach HF Space (it may be blocked) -- screenshot this instead." -ForegroundColor Yellow
}
