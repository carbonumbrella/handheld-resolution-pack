[English](README.md) | [Русский](README_RU.md)

> **[Download Latest Release (ZIP Asset)](https://github.com/carbonumbrella/handheld-resolution-pack/releases/latest/download/Claw_Resolution_1536x960_Pack.zip)** | **[Release Notes & Files](https://github.com/carbonumbrella/handheld-resolution-pack/releases/latest)**

# MSI Claw Resolution Pack (1600x1000 & 1536x960)

[![release](https://img.shields.io/github/v/release/carbonumbrella/handheld-resolution-pack?include_prereleases&label=release)](https://github.com/carbonumbrella/handheld-resolution-pack/releases)

Automated utility package to add custom 16:10 intermediate resolutions (1600x1000 and 1536x960) for MSI Claw handheld consoles with native VRR 48 to 120 Hz support.

## Why This is Needed

On 16:10 displays, standard intermediate driver modes (1680x1050 and 1440x900) use non-integer scaling ratios (~1.143x and ~1.333x). Fractional grids introduce interpolation artifacts and text blurring when temporal upscalers (Intel XeSS, AMD FSR, TAAU) reconstruct frames.

This package injects two mathematically calibrated alternatives into the display stack:
- **1600x1000 (1000p, exact 1.20x multiplier):** Precise alternative to 1050p. Eliminates fractional grid sampling errors, cuts GPU load by 30.5%, and preserves perceived sharpness at near-native 1200p quality.
- **1536x960 (960p, exact 1.25x / 80% multiplier):** Precise alternative to 900p. Represents exactly 80% of native width and height. Reduces GPU load by 36% and delivers noticeably sharper texture reconstruction in upscalers.
- Both resolutions are injected simultaneously, maintaining the native 16:10 aspect ratio, 120 Hz refresh rate, and Variable Refresh Rate (VRR 48 to 120 Hz) via DisplayID 2.0 blocks.

## Compatibility

| Model | Generation | Status | Notes |
|---|---|---|---|
| Claw 8 AI+ (A2VM, Intel Lunar Lake) | Gen 2 | Verified | Panel CSW PN8007QB1-2, DisplayID 2.0 VRR 48-120 Hz |
| Claw 7 AI+ (A2VM, Intel Lunar Lake) | Gen 2 | Supported | Same platform, 16:10 display |
| Claw A1M (Intel Meteor Lake) | Gen 1 | Supported | 16:10 display |

## Package Contents

1. **1_Universal_Auto (Recommended):**
   - `Run_As_Admin.cmd`: One-click elevated launcher.
   - `auto_add_1536x960.ps1`: Automated installer script. Reads factory EDID from the active panel, injects 1600x1000 and 1536x960 @ 120 Hz and 60 Hz, recalculates checksums, and restarts the graphics driver. Automatically detects ClawTweaks in Xbox Game Bar, creates a backup, and registers new resolutions into the quick menu.
   - `auto_restore_original.ps1`: One-click rollback script, restoring factory EDID and the original ClawTweaks helper.
   - `Mono.Cecil.dll`, `restart64.exe`: Standalone libraries required for offline operation.

2. **2_MSI_Claw_Dedicated:**
   - Dedicated pre-built files for the MSI Claw 8 AI+ display (CSW0801 / PN8007QB1-2).
   - Deployment and rollback scripts (`apply_custom_resolutions.ps1`, `restore_original_claw.ps1`).
   - REG files for manual Windows registry import.
   - EDID binary dumps preserving the DisplayID 2.0 block (VRR 48 to 120 Hz).

3. **3_CRU_Utility:**
   - Custom Resolution Utility 1.5.2 suite (CRU.exe, restart64.exe, reset-all.exe) for manual diagnostics or emergency reset.

4. **4_ClawTweaks_Widget_Patch:**
   - Standalone ClawTweaks helper patcher (Xbox Game Bar) when patching the quick menu without modifying EDID.

## Quick Start

1. Download `Claw_Resolution_1536x960_Pack.zip` from the [Latest Release](https://github.com/carbonumbrella/handheld-resolution-pack/releases/latest).
2. Extract the archive on the device.
3. Open folder `1_Universal_Auto`.
4. Double-click `Run_As_Admin.cmd`.
5. Accept the UAC prompt.
6. The display blinks for one second during graphics driver restart.
7. Resolutions 1600x1000 and 1536x960 become immediately available in Windows Settings, in-game menus, and the ClawTweaks overlay.

## How to Roll Back

- Run `auto_restore_original.ps1` from folder `1_Universal_Auto`. The script restores the factory EDID and original ClawTweaks binary.
- Alternatively, run `reset-all.exe` from folder `3_CRU_Utility` and restart the graphics driver via `restart64.exe`.

## License

MIT License, see [LICENSE](LICENSE).
