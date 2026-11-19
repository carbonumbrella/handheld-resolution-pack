# PowerShell script to restore original EDID and remove overrides
# Requires Administrator privileges (will auto-prompt UAC if needed)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argv
    exit
}

$scriptDir = Split-Path -Parent $PSCommandPath

# Remove EDID_OVERRIDE from target 1
$targetPath1 = "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY\CSW0801\4&8f346&1&UID8388688\Device Parameters\EDID_OVERRIDE"
if (Test-Path $targetPath1) {
    Remove-Item -Path $targetPath1 -Recurse -Force
    Write-Host "Removed EDID_OVERRIDE from Device Parameters." -ForegroundColor Green
}

# Remove EDID_OVERRIDE from target 2
$targetPath2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96e-e325-11ce-bfc1-08002be10318}\0001\EDID_OVERRIDE"
if (Test-Path $targetPath2) {
    Remove-Item -Path $targetPath2 -Recurse -Force
    Write-Host "Removed EDID_OVERRIDE from Monitor Class." -ForegroundColor Green
}

# Restart graphics driver
$restartExe = Join-Path $scriptDir "..\3_CRU_Utility\restart64.exe"
if (-not (Test-Path $restartExe)) { $restartExe = Join-Path $scriptDir "cru\restart64.exe" }
if (Test-Path $restartExe) {
    Write-Host "Restarting display driver with restart64.exe..." -ForegroundColor Cyan
    Start-Process -FilePath $restartExe -Wait
    Write-Host "Display driver restarted successfully." -ForegroundColor Green
} else {
    Write-Host "Please reboot Windows to restore original state." -ForegroundColor Yellow
}

Write-Host "Restored original EDID state successfully." -ForegroundColor Green
Start-Sleep -Seconds 3
