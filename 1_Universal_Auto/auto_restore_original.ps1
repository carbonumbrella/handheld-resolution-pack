# Universal Rollback Script: Remove all EDID overrides and restore factory display settings + ClawTweaks
# Requires Administrator privileges (auto-elevates if needed)

$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    $argv = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "`"$PSCommandPath`"")
    Start-Process powershell.exe -Verb RunAs -ArgumentList $argv
    exit
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Full Rollback: Restore Factory Display & ClawTweaks" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Search and delete any EDID_OVERRIDE under Enum\DISPLAY
$enumOverrides = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "EDID_OVERRIDE" }
foreach ($ov in $enumOverrides) {
    Write-Host "[-] Removing: $($ov.PSPath)" -ForegroundColor Yellow
    Remove-Item -Path $ov.PSPath -Recurse -Force
}

# 2. Search and delete any EDID_OVERRIDE under Control\Class\{4d36e96e-e325-11ce-bfc1-08002be10318}
$classOverrides = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e96e-e325-11ce-bfc1-08002be10318}" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -eq "EDID_OVERRIDE" }
foreach ($ov in $classOverrides) {
    Write-Host "[-] Removing: $($ov.PSPath)" -ForegroundColor Yellow
    Remove-Item -Path $ov.PSPath -Recurse -Force
}

# 3. Restart graphics driver
$scriptDir = Split-Path -Parent $PSCommandPath
$restartPaths = @(
    (Join-Path $scriptDir "restart64.exe"),
    (Join-Path $scriptDir "..\3_CRU_Utility\restart64.exe"),
    (Join-Path $scriptDir "..\CRU\restart64.exe")
)
$restarted = $false
foreach ($rp in $restartPaths) {
    if (Test-Path $rp) {
        Write-Host "[*] Restarting graphics driver with $rp..." -ForegroundColor Cyan
        Start-Process -FilePath $rp -ArgumentList "/q" -Wait
        $restarted = $true
        break
    }
}

if (-not $restarted) {
    $gpu = Get-PnpDevice -Class Display -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq "OK" }
    if ($gpu) {
        Write-Host "[*] Restarting display device via pnputil ($($gpu[0].InstanceId))..." -ForegroundColor Cyan
        pnputil /restart-device "$($gpu[0].InstanceId)" | Out-Null
    }
}

Write-Host "[+] Factory display EDID restored: OK" -ForegroundColor Green

# 4. Check and restore ClawTweaks helper from backup
$packages = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter "*ClawTweaks*" -Directory -ErrorAction SilentlyContinue
foreach ($pkg in $packages) {
    $helper = Join-Path $pkg.FullName "LocalCache\ClawTweaks\Helper\XboxGamingBarHelper.exe"
    $backup = "$helper.original.bak"
    if (Test-Path $backup) {
        Write-Host "[*] Restoring original ClawTweaks helper..." -ForegroundColor Yellow
        try {
            Get-ScheduledTask | Where-Object { $_.TaskName -eq "ClawTweaksHelper" } | Stop-ScheduledTask -ErrorAction SilentlyContinue
        } catch {}
        Get-Process -Name "XboxGamingBarHelper" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 600

        Copy-Item -Path $backup -Destination $helper -Force
        Write-Host "[+] ClawTweaks helper restored from backup: OK" -ForegroundColor Green

        try {
            Get-ScheduledTask | Where-Object { $_.TaskName -eq "ClawTweaksHelper" } | Start-ScheduledTask -ErrorAction SilentlyContinue
        } catch {
            Start-Process -FilePath $helper
        }
        Get-Process -Name "GameBar", "XboxGamingBar" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " ROLLBACK COMPLETED: Everything restored to factory state." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Start-Sleep -Seconds 3
