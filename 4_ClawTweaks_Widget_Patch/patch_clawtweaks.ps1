<#
.SYNOPSIS
    Patches ClawTweaks XboxGamingBarHelper.exe to add 1600x1000 and 1536x960 resolution support.

.DESCRIPTION
    ClawTweaks uses an internal hardcoded whitelist 'CuratedResolutions' in XboxGamingBarHelper.exe
    that filters display resolutions returned by Windows API before passing them to the Game Bar widget.
    This script inserts 1600x1000 (1000p) and 1536x960 (960p) (both 16:10 aspect ratio) into that whitelist
    using Mono.Cecil, allowing them to be selected directly from the ClawTweaks UI and Quick Settings.
    
    A backup of the original executable is saved as XboxGamingBarHelper.exe.original.bak.
#>

[CmdletBinding()]
param(
    [string]$CustomHelperPath = ""
)

$ErrorActionPreference = "Stop"

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " ClawTweaks 1600x1000 & 1536x960 Support Patcher" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# 1. Locate XboxGamingBarHelper.exe
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
    Write-Error "Could not find XboxGamingBarHelper.exe. Please specify -CustomHelperPath."
    exit 1
}

$helperDir = Split-Path -Parent $helperPath
Write-Host "[+] Target helper: $helperPath" -ForegroundColor Green

# 2. Check Mono.Cecil.dll dependency
$cecilPath = Join-Path $PSScriptRoot "Mono.Cecil.dll"
if (-not (Test-Path $cecilPath)) {
    Write-Error "Mono.Cecil.dll not found in $PSScriptRoot."
    exit 1
}

# 3. Stop running helper process and scheduled task
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

# 4. Create backup of original binary if not already present
$backupPath = "$helperPath.original.bak"
if (-not (Test-Path $backupPath)) {
    Write-Host "[+] Creating original backup: $backupPath" -ForegroundColor Green
    Copy-Item -Path $helperPath -Destination $backupPath -Force
} else {
    Write-Host "[i] Backup already exists: $backupPath" -ForegroundColor Gray
}

# 5. Load Mono.Cecil and perform assembly patch via MemoryStream
Write-Host "[*] Inspecting assembly metadata..." -ForegroundColor Yellow
Add-Type -Path $cecilPath

# If currently patched, we can read from backup to always produce a clean array
$sourcePath = if (Test-Path $backupPath) { $backupPath } else { $helperPath }
$bytes = [System.IO.File]::ReadAllBytes($sourcePath)
$ms = [System.IO.MemoryStream]::new($bytes)
$assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($ms)

$type = $assembly.MainModule.GetType("XboxGamingBarHelper.Windows.User32")
if (-not $type) {
    Write-Error "Class XboxGamingBarHelper.Windows.User32 not found in assembly."
    exit 1
}

$cctor = $null
foreach ($m in $type.Methods) {
    if ($m.Name -eq ".cctor") {
        $cctor = $m
        break
    }
}

if (-not $cctor) {
    Write-Error "Static constructor (.cctor) in User32 not found."
    exit 1
}

$il = $cctor.Body.GetILProcessor()
$startInstr = $null
$endInstr = $null

for ($i = 0; $i -lt $cctor.Body.Instructions.Count; $i++) {
    $instr = $cctor.Body.Instructions[$i]
    if ($instr.OpCode.Name -eq "ldc.i4.s" -and $cctor.Body.Instructions[$i + 1].OpCode.Name -eq "newarr") {
        $startInstr = $instr
    }
    if ($startInstr -and $instr.OpCode.Name -eq "stsfld" -and $instr.Operand.Name -eq "CuratedResolutions") {
        $endInstr = $instr
        break
    }
}

if (-not $startInstr -or -not $endInstr) {
    Write-Error "Could not locate CuratedResolutions array initialization instructions."
    exit 1
}

# Extract existing resolutions from instructions
$currentResolutions = [System.Collections.Generic.List[string]]::new()
$scan = $startInstr.Next
while ($scan -ne $endInstr) {
    if ($scan.OpCode.Name -eq "ldstr" -and $scan.Operand) {
        $currentResolutions.Add($scan.Operand.ToString())
    }
    $scan = $scan.Next
}

# Build updated resolutions list with 1600x1000 and 1536x960 inserted
$newResolutions = [System.Collections.Generic.List[string]]::new()
$inserted1000 = $false
$inserted960 = $false

foreach ($res in $currentResolutions) {
    if (-not $inserted1000 -and ($res -eq "1440x900" -or $res -eq "1280x800")) {
        if (-not $newResolutions.Contains("1600x1000")) {
            $newResolutions.Add("1600x1000")
        }
        $inserted1000 = $true
    }
    if (-not $inserted960 -and ($res -eq "1440x900" -or $res -eq "1280x800")) {
        if (-not $newResolutions.Contains("1536x960")) {
            $newResolutions.Add("1536x960")
        }
        $inserted960 = $true
    }
    if (-not $newResolutions.Contains($res)) {
        $newResolutions.Add($res)
    }
}

Write-Host ("[+] Curated resolutions list ({0} items):" -f $newResolutions.Count) -ForegroundColor Green
foreach ($r in $newResolutions) {
    if ($r -eq "1600x1000" -or $r -eq "1536x960") {
        Write-Host "    -> $r (ADDED 16:10)" -ForegroundColor Cyan
    } else {
        Write-Host "       $r" -ForegroundColor DarkGray
    }
}

# Remove old initialization instructions
$cur = $startInstr
while ($cur -ne $endInstr) {
    $next = $cur.Next
    $il.Remove($cur)
    $cur = $next
}

# Insert new initialization instructions
$stringType = $assembly.MainModule.TypeSystem.String
$il.InsertBefore($endInstr, $il.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4_S, [sbyte]$newResolutions.Count))
    $il.InsertBefore($endInstr, $il.Create([Mono.Cecil.Cil.OpCodes]::Newarr, $stringType))

for ($i = 0; $i -lt $newResolutions.Count; $i++) {
    $il.InsertBefore($endInstr, $il.Create([Mono.Cecil.Cil.OpCodes]::Dup))
    $il.InsertBefore($endInstr, $il.Create([Mono.Cecil.Cil.OpCodes]::Ldc_I4, [int]$i))
    $il.InsertBefore($endInstr, $il.Create([Mono.Cecil.Cil.OpCodes]::Ldstr, $newResolutions[$i]))
    $il.InsertBefore($endInstr, $il.Create([Mono.Cecil.Cil.OpCodes]::Stelem_Ref))
}

$tempOut = Join-Path $helperDir "XboxGamingBarHelper.patched.tmp"
$assembly.Write($tempOut)
$assembly.Dispose()
$ms.Dispose()

Copy-Item -Path $tempOut -Destination $helperPath -Force
Remove-Item -Path $tempOut -Force
Write-Host "[+] Successfully patched $helperPath!" -ForegroundColor Green

# 6. Restart helper service
Write-Host "[*] Starting ClawTweaks helper..." -ForegroundColor Yellow
try {
    $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -eq "ClawTweaksHelper" }
    if ($tasks) {
        foreach ($t in $tasks) {
            Start-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue
        }
        Start-Sleep -Milliseconds 1000
    } else {
        Start-Process -FilePath $helperPath
    }
} catch {
    Start-Process -FilePath $helperPath
}

# 7. Restart Game Bar to refresh UI widgets
Write-Host "[*] Refreshing Xbox Game Bar..." -ForegroundColor Yellow
Get-Process -Name "GameBar", "XboxGamingBar" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " SUCCESS! 1600x1000 & 1536x960 are now available in ClawTweaks." -ForegroundColor Green
Write-Host " Press Win+G or open the Claw quick menu to verify." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
