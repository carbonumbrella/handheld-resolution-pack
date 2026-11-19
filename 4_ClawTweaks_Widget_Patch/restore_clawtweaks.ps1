<#
.SYNOPSIS
    Restores the original unmodified XboxGamingBarHelper.exe from backup.
#>

[CmdletBinding()]
param(
    [string]$CustomHelperPath = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " ClawTweaks Helper Restore to Original" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

$helperPath = $CustomHelperPath
if ([string]::IsNullOrWhiteSpace($helperPath)) {
    $packages = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter "*ClawTweaks*" -Directory -ErrorAction SilentlyContinue
    foreach ($pkg in $packages) {
        $candidate = Join-Path $pkg.FullName "LocalCache\ClawTweaks\Helper\XboxGamingBarHelper.exe"
        if (Test-Path $candidate) {
            $helperPath = $candidate
            break
        }
    }
}

if (-not $helperPath -or -not (Test-Path $helperPath)) {
    Write-Error "Could not find XboxGamingBarHelper.exe."
    exit 1
}

$backupPath = "$helperPath.original.bak"
if (-not (Test-Path $backupPath)) {
    Write-Error "Backup file $backupPath does not exist. Nothing to restore."
    exit 1
}

Write-Host "[*] Stopping running helper processes..." -ForegroundColor Yellow
try {
    $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -eq "ClawTweaksHelper" }
    foreach ($t in $tasks) {
        Stop-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue
    }
    Start-Sleep -Milliseconds 800
} catch {}

$procs = Get-Process -Name "XboxGamingBarHelper" -ErrorAction SilentlyContinue
if ($procs) {
    $procs | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 800
}

Write-Host "[+] Restoring original file from $backupPath..." -ForegroundColor Green
Copy-Item -Path $backupPath -Destination $helperPath -Force

Write-Host "[*] Restarting ClawTweaks helper..." -ForegroundColor Yellow
try {
    $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -eq "ClawTweaksHelper" }
    if ($tasks) {
        foreach ($t in $tasks) {
            Start-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue
        }
    } else {
        Start-Process -FilePath $helperPath
    }
} catch {
    Start-Process -FilePath $helperPath
}

Get-Process -Name "GameBar", "XboxGamingBar" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " RESTORE COMPLETED! Original helper is restored." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
