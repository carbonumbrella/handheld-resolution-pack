<#
.SYNOPSIS
    Universal 1600x1000 & 1536x960 Resolution Installer + Automatic ClawTweaks Patcher
    Supports: MSI Claw (Claw 8 AI+, Claw 7 AI+, Claw A1M) and other 16:10 panels.
    Requires Administrator privileges (will auto-prompt UAC if needed).
#>

[CmdletBinding()]
param()

$ErrorActionPreference = "Stop"

# 0. Check / Request Administrator privileges
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if (-not $isAdmin) {
    Write-Host "Requesting Administrator privileges..." -ForegroundColor Yellow
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

Write-Host "==========================================================" -ForegroundColor Cyan
Write-Host " Handheld Resolution Installer (1000p & 960p) + ClawTweaks" -ForegroundColor Cyan
Write-Host "==========================================================" -ForegroundColor Cyan

# =========================================================================
# PART 1: INJECT 1600x1000 & 1536x960 INTO DISPLAY EDID
# =========================================================================
Write-Host "`n--- [1/2] Installing Display Resolutions ---" -ForegroundColor Yellow

# 1. Detect active monitor via WMI
$activeMonitors = Get-CimInstance -Namespace root\wmi -ClassName WmiMonitorID -ErrorAction SilentlyContinue | Where-Object { $_.Active -eq $true }
if (-not $activeMonitors) {
    Write-Host "[i] Querying Enum\DISPLAY for active panel..." -ForegroundColor Gray
    $displayKeys = Get-ChildItem "HKLM:\SYSTEM\CurrentControlSet\Enum\DISPLAY" -Recurse -ErrorAction SilentlyContinue | Where-Object { $_.Property -contains "EDID" }
    if (-not $displayKeys) {
        Write-Error "No display with EDID found in registry."
        exit 1
    }
    $targetDeviceParamPath = $displayKeys[0].PSPath
} else {
    $primary = $activeMonitors[0]
    $inst = $primary.InstanceName
    if ($inst -match "(.*)_[0-9]+$") {
        $inst = $matches[1]
    }
    $targetDeviceParamPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$inst\Device Parameters"
}

Write-Host "[+] Target monitor path: $targetDeviceParamPath" -ForegroundColor Green

if (-not (Test-Path $targetDeviceParamPath)) {
    Write-Error "Device Parameters path not found!"
    exit 1
}

$origEdid = (Get-ItemProperty -Path $targetDeviceParamPath).EDID
if (-not $origEdid -or $origEdid.Length -lt 128) {
    Write-Error "Could not read EDID from $targetDeviceParamPath"
    exit 1
}

Write-Host ("[+] Read factory EDID: {0} bytes." -f $origEdid.Length) -ForegroundColor Gray

# 2. Modify EDID (inject 1600x1000 & 1536x960 @ 120Hz & 60Hz into Standard Timings)
$modEdid = [byte[]]$origEdid.Clone()

# Standard Timings: bytes 38..45
# 1600x1000 @ 120Hz (16:10): 0xA9, 0x3C
# 1600x1000 @ 60Hz (16:10):  0xA9, 0x00
# 1536x960 @ 120Hz (16:10):  0xA1, 0x3C
# 1536x960 @ 60Hz (16:10):   0xA1, 0x00
$modEdid[38] = 0xA9
$modEdid[39] = 0x3C
$modEdid[40] = 0xA9
$modEdid[41] = 0x00
$modEdid[42] = 0xA1
$modEdid[43] = 0x3C
$modEdid[44] = 0xA1
$modEdid[45] = 0x00

# Recalculate Block 0 checksum (byte 127)
$sum0 = 0
for ($i = 0; $i -lt 127; $i++) {
    $sum0 += $modEdid[$i]
}
$csum0 = (256 - ($sum0 % 256)) % 256
$modEdid[127] = [byte]$csum0

$block0 = $modEdid[0..127]
$hasBlock1 = $modEdid.Length -ge 256
if ($hasBlock1) {
    $block1 = $modEdid[128..255]
}

# 3. Write EDID_OVERRIDE to Device Parameters
$overridePath1 = Join-Path $targetDeviceParamPath "EDID_OVERRIDE"
if (-not (Test-Path $overridePath1)) {
    New-Item -Path $overridePath1 -Force | Out-Null
}
Set-ItemProperty -Path $overridePath1 -Name "0" -Value $block0 -Type Binary
if ($hasBlock1) {
    Set-ItemProperty -Path $overridePath1 -Name "1" -Value $block1 -Type Binary
}
Write-Host "[+] Applied EDID_OVERRIDE to Device Parameters: OK" -ForegroundColor Green

# 4. Also write to monitor driver key under Control\Class
$parentInst = Split-Path $targetDeviceParamPath -Parent
$driverKey = (Get-ItemProperty -Path $parentInst -ErrorAction SilentlyContinue).Driver
if ($driverKey) {
    $overridePath2 = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$driverKey\EDID_OVERRIDE"
    if (-not (Test-Path $overridePath2)) {
        New-Item -Path $overridePath2 -Force | Out-Null
    }
    Set-ItemProperty -Path $overridePath2 -Name "0" -Value $block0 -Type Binary
    if ($hasBlock1) {
        Set-ItemProperty -Path $overridePath2 -Name "1" -Value $block1 -Type Binary
    }
    Write-Host "[+] Applied EDID_OVERRIDE to Monitor Class ($driverKey): OK" -ForegroundColor Green
}

# 5. Restart Display Driver
$scriptDir = Split-Path -Parent $PSCommandPath
$restartPaths = @(
    (Join-Path $scriptDir "restart64.exe"),
    (Join-Path $scriptDir "..\3_CRU_Utility\restart64.exe"),
    (Join-Path $scriptDir "..\CRU\restart64.exe")
)
$restarted = $false
foreach ($rp in $restartPaths) {
    if (Test-Path $rp) {
        Write-Host "[*] Restarting graphics driver via restart64.exe..." -ForegroundColor Cyan
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
        $restarted = $true
    }
}

Write-Host "[+] Display stack updated: 1600x1000 and 1536x960 are active in Windows!" -ForegroundColor Green

# =========================================================================
# PART 2: AUTOMATICALLY DETECT AND PATCH CLAWTWEAKS (IF PRESENT)
# =========================================================================
Write-Host "`n--- [2/2] Checking for ClawTweaks Game Bar Widget ---" -ForegroundColor Yellow

$helperPath = $null
$packages = Get-ChildItem -Path "$env:LOCALAPPDATA\Packages" -Filter "*ClawTweaks*" -Directory -ErrorAction SilentlyContinue
foreach ($pkg in $packages) {
    $candidate = Join-Path $pkg.FullName "LocalCache\ClawTweaks\Helper\XboxGamingBarHelper.exe"
    if (Test-Path $candidate) {
        $helperPath = $candidate
        break
    }
}

if (-not $helperPath) {
    # Check running process
    $proc = Get-Process -Name "XboxGamingBarHelper" -ErrorAction SilentlyContinue
    if ($proc -and $proc.Path -and (Test-Path $proc.Path)) {
        $helperPath = $proc.Path
    }
}

if (-not $helperPath) {
    Write-Host "[i] ClawTweaks not found on this machine. (Skipping widget patch - not needed)." -ForegroundColor Gray
} else {
    Write-Host "[+] ClawTweaks detected: $helperPath" -ForegroundColor Green
    
    $cecilPaths = @(
        (Join-Path $scriptDir "Mono.Cecil.dll"),
        (Join-Path $scriptDir "..\4_ClawTweaks_Widget_Patch\Mono.Cecil.dll")
    )
    $cecilFound = $null
    foreach ($cp in $cecilPaths) {
        if (Test-Path $cp) {
            $cecilFound = $cp
            break
        }
    }

    if (-not $cecilFound) {
        Write-Host "[!] Mono.Cecil.dll not found. Could not patch ClawTweaks widget." -ForegroundColor Yellow
    } else {
        $helperDir = Split-Path -Parent $helperPath
        $backupPath = "$helperPath.original.bak"

        # Stop running helper processes
        try {
            $tasks = Get-ScheduledTask | Where-Object { $_.TaskName -eq "ClawTweaksHelper" }
            foreach ($t in $tasks) {
                Stop-ScheduledTask -InputObject $t -ErrorAction SilentlyContinue
            }
            Start-Sleep -Milliseconds 600
        } catch {}

        $procs = Get-Process -Name "XboxGamingBarHelper" -ErrorAction SilentlyContinue
        if ($procs) {
            $procs | Stop-Process -Force -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 600
        }

        # Backup original if not already existing
        if (-not (Test-Path $backupPath)) {
            Write-Host "[+] Creating ClawTweaks original backup: $backupPath" -ForegroundColor Green
            Copy-Item -Path $helperPath -Destination $backupPath -Force
        }

        # Load Cecil
        Add-Type -Path $cecilFound

        $sourcePath = if (Test-Path $backupPath) { $backupPath } else { $helperPath }
        $bytes = [System.IO.File]::ReadAllBytes($sourcePath)
        $ms = [System.IO.MemoryStream]::new($bytes)
        $assembly = [Mono.Cecil.AssemblyDefinition]::ReadAssembly($ms)

        $type = $assembly.MainModule.GetType("XboxGamingBarHelper.Windows.User32")
        $cctor = $null
        if ($type) {
            foreach ($m in $type.Methods) {
                if ($m.Name -eq ".cctor") { $cctor = $m; break }
            }
        }

        if (-not $cctor) {
            Write-Host "[!] Could not inspect User32 in helper binary." -ForegroundColor Yellow
        } else {
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

            if ($startInstr -and $endInstr) {
                $currentResolutions = [System.Collections.Generic.List[string]]::new()
                $scan = $startInstr.Next
                while ($scan -ne $endInstr) {
                    if ($scan.OpCode.Name -eq "ldstr" -and $scan.Operand) {
                        $currentResolutions.Add($scan.Operand.ToString())
                    }
                    $scan = $scan.Next
                }

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

                # Clear old instructions
                $cur = $startInstr
                while ($cur -ne $endInstr) {
                    $next = $cur.Next
                    $il.Remove($cur)
                    $cur = $next
                }

                # Insert new instructions
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
                Write-Host "[+] ClawTweaks helper patched with 1600x1000 and 1536x960!" -ForegroundColor Green

                # Restart helper
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

                # Refresh Game Bar
                Get-Process -Name "GameBar", "XboxGamingBar" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
                Write-Host "[+] ClawTweaks and Xbox Game Bar restarted!" -ForegroundColor Green
            }
        }
    }
}

Write-Host "`n==========================================================" -ForegroundColor Cyan
Write-Host " ALL DONE! 1600x1000 & 1536x960 are installed and ready." -ForegroundColor Green
Write-Host " Open Display Settings or press Win+G in games to test." -ForegroundColor Green
Write-Host "==========================================================" -ForegroundColor Cyan
Start-Sleep -Seconds 3
