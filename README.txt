MSI CLAW RESOLUTION PACK: 1600x1000 & 1536x960 INSTALLATION GUIDE
(Supports MSI Claw 8 AI+, Claw 7 AI+, Claw A1M with 16:10 displays)

WHY THIS IS NEEDED:
On 16:10 handheld screens, standard intermediate resolutions (1680x1050 and 1440x900) have irregular scaling ratios (~1.143x and ~1.333x), causing interpolation blur when running temporal upscalers (XeSS, FSR, TAAU).
This pack adds two mathematically calibrated alternatives:
- 1600x1000 (1000p, exact 1.20x multiplier): Direct alternative to 1050p, reduces GPU load by 30.5% while preserving native 1200p clarity.
- 1536x960 (960p, exact 1.25x / 80% multiplier): Direct alternative to 900p, reduces GPU load by 36% and delivers noticeably sharper texture reconstruction.
Both modes preserve 16:10 aspect ratio and Variable Refresh Rate (VRR 48-120 Hz).

ARCHIVE STRUCTURE:

1. Folder [1_Universal_Auto] (RECOMMENDED):
   - Run_As_Admin.cmd: Fast one-click administrator launch.
   - auto_add_1536x960.ps1: Universal installer script. Reads factory EDID, injects 1600x1000 and 1536x960 @ 120Hz and 60Hz, updates checksums, restarts graphics driver, and patches the ClawTweaks Xbox Game Bar widget if present.
   - auto_restore_original.ps1: Complete rollback script restoring factory EDID and original ClawTweaks helper.
   - Mono.Cecil.dll & restart64.exe: Offline utility binaries.

2. Folder [2_MSI_Claw_Dedicated]:
   - Pre-built files for the MSI Claw 8 AI+ panel (CSW0801 / PN8007QB1-2).
   - apply_custom_resolutions.ps1 / Run_As_Admin.cmd: One-click installer.
   - apply_custom_resolutions.reg: Windows registry script for manual import.
   - restore_original_claw.ps1 & restore_original_claw.reg: Rollback scripts.
   - edid_custom.bin & edid_original.bin: EDID dumps with DisplayID 2.0 (VRR 48-120 Hz).

3. Folder [3_CRU_Utility]:
   - Custom Resolution Utility 1.5.2 suite (CRU.exe, restart64.exe, reset-all.exe).

4. Folder [4_ClawTweaks_Widget_Patch]:
   - Standalone patcher for ClawTweaks Xbox Game Bar widget.

QUICK START:
1. Extract the archive on your handheld.
2. Open folder 1_Universal_Auto.
3. Double-click Run_As_Admin.cmd (or right-click auto_add_1536x960.ps1 -> Run with PowerShell).
4. Accept the UAC prompt.
5. The screen will blink for one second as the graphics driver restarts. 1600x1000 and 1536x960 will immediately appear in Windows, games, and ClawTweaks.

HOW TO ROLL BACK:
- Run auto_restore_original.ps1 in folder 1_Universal_Auto, or run reset-all.exe in folder 3_CRU_Utility and restart via restart64.exe.
