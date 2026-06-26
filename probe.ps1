# pw/probe.ps1 — what does this network actually allow? (PowerShell only, no exe)
# Run on the laptop:  irm https://raw.githubusercontent.com/gruncode/pw-lab/main/probe.ps1 | iex
$ErrorActionPreference = 'SilentlyContinue'

# mirror what cloudflared/irm will use: system proxy
$ieKey = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings'
$pe = (Get-ItemProperty $ieKey).ProxyEnable
$ps = (Get-ItemProperty $ieKey).ProxyServer
if ($pe -eq 1 -and $ps) {
  Write-Host ("PROXY: {0}" -f $ps) -ForegroundColor Yellow
  $env:HTTP_PROXY = "http://$ps"; $env:HTTPS_PROXY = "http://$ps"
} else {
  Write-Host "PROXY: none (direct)" -ForegroundColor Yellow
}
Write-Host "REACHED = domain allowed (even an HTTP error code means it got through). BLOCKED = filter dropped it." -ForegroundColor Cyan
Write-Host ("-" * 60)

$targets = @(
  'raw.githubusercontent.com',     # control: known GOOD
  'api.trycloudflare.com',         # control: known BAD
  'api.cloudflare.com',            # named-tunnel registration
  'update.argotunnel.com',         # cloudflared edge
  'region1.v2.argotunnel.com',     # cloudflared edge region
  'huggingface.co',                # HF Spaces option
  'tunnel.us.ngrok.com',           # ngrok option
  'www.google.com'                 # generic
)

foreach ($t in $targets) {
  $sw = [Diagnostics.Stopwatch]::StartNew()
  try {
    $r = Invoke-WebRequest -UseBasicParsing -Uri ("https://{0}/" -f $t) -Method Head -TimeoutSec 8
    "{0,-30} REACHED  HTTP {1}  {2}ms" -f $t, $r.StatusCode, $sw.ElapsedMilliseconds
  } catch {
    $code = $_.Exception.Response.StatusCode.value__
    if ($code) {
      "{0,-30} REACHED  HTTP {1}  {2}ms" -f $t, $code, $sw.ElapsedMilliseconds
    } else {
      "{0,-30} BLOCKED  ({1})" -f $t, ($_.Exception.Message -split "`n")[0].Trim()
    }
  }
}
Write-Host ("-" * 60)
Write-Host "Send this whole list to George." -ForegroundColor Green
