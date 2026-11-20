========================================================================
 ClawTweaks 1600x1000 & 1536x960 Resolution Support Patcher
 For MSI Claw 8 AI+ & Handhelds running ClawTweaks
========================================================================

WHY THIS IS NEEDED:
-------------------
ClawTweaks filters all screen resolutions through an internal hardcoded
whitelist ('CuratedResolutions' in XboxGamingBarHelper.exe).
Even when 1600x1000 or 1536x960 are added to Windows, ClawTweaks discards them
because they are missing from that list.

WHAT THIS PATCH DOES:
---------------------
1. Safely creates a backup:
   XboxGamingBarHelper.exe.original.bak
2. Patches the 'CuratedResolutions' whitelist in XboxGamingBarHelper.exe to include:
   - 1600x1000 (1000p, clean 16:10, 1.20x scale)
   - 1536x960  (960p,  clean 16:10, 1.25x scale)
3. Leaves 100% of the rest of ClawTweaks (TDP, fans, gyro, UI, controller) untouched.
4. Restarts the helper service and Xbox Game Bar.

HOW TO RUN:
-----------
Right click 'patch_clawtweaks.ps1' -> 'Run with PowerShell'
(or run from PowerShell: .\patch_clawtweaks.ps1)

HOW TO ROLL BACK:
-----------------
Right click 'restore_clawtweaks.ps1' -> 'Run with PowerShell'
It restores the original unmodified XboxGamingBarHelper.exe from the backup.
