# PowerShell script to apply 1600x1000 & 1536x960 EDID Override
# Requires Administrator privileges (will auto-prompt UAC if needed)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

$scriptDir = Split-Path -Parent $PSCommandPath
$binPath = Join-Path $scriptDir "edid_custom.bin"

if (-not (Test-Path $binPath)) {
    Write-Host "Error: $binPath not found!" -ForegroundColor Red
    Pause
    exit 1
}

$bytes = [System.IO.File]::ReadAllBytes($binPath)
if ($bytes.Length -ne 256) {
    Write-Host "Error: EDID file must be 256 bytes, found $($bytes.Length)" -ForegroundColor Red
    Pause
    exit 1
}

$block0 = $bytes[0..127]
$block1 = $bytes[128..255]

# Registry target 1: Device Parameters
$targetPath1 = "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\CSW0801\4&8f346&1&UID8388688\Device Parameters\EDID_OVERRIDE"
if (-not (Test-Path $targetPath1)) {
    New-Item -Path $targetPath1 -Force | Out-Null
}
Set-ItemProperty -Path $targetPath1 -Name "0" -Value $block0 -Type Binary
Set-ItemProperty -Path $targetPath1 -Name "1" -Value $block1 -Type Binary
Write-Host "Applied EDID_OVERRIDE to Device Parameters: OK" -ForegroundColor Green

# Registry target 2: Monitor Driver Class
$targetPath2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96e-e325-11ce-bfc1-08002be10318}\0001\EDID_OVERRIDE"
if (-not (Test-Path $targetPath2)) {
    New-Item -Path $targetPath2 -Force | Out-Null
}
Set-ItemProperty -Path $targetPath2 -Name "0" -Value $block0 -Type Binary
Set-ItemProperty -Path $targetPath2 -Name "1" -Value $block1 -Type Binary
Write-Host "Applied EDID_OVERRIDE to Monitor Class: OK" -ForegroundColor Green

# Restart graphics driver
$restartExe = Join-Path $scriptDir "..\3_CRU_Utility\restart64.exe"
if (Test-Path $restartExe) {
    Write-Host "Restarting graphics driver via CRU restart64.exe..." -ForegroundColor Yellow
    Start-Process -FilePath $restartExe -ArgumentList "/q" -Wait
    Write-Host "Graphics driver restarted successfully!" -ForegroundColor Green
} else {
    pnputil /restart-device "PCI\VEN_8086&DEV_64A0&SUBSYS_146C1462&REV_04\3&11583659&0&10" | Out-Null
    Write-Host "Graphics device restarted via pnputil: OK" -ForegroundColor Green
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " SUCCESS! 1600x1000 and 1536x960 EDID overrides applied." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
