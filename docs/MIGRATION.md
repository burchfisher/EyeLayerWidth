# EyeLayerWidth Migration

## Separation on 2026-10-14

The width-analysis application has moved out of RpEGEN into EyeLayerWidth. RpEGEN
retains image/intensity extraction, QC, intensity results, heatmaps, median
profiles, and the pixel-level permutation comparison. Its newer usability and
statistical-display improvements are not reverted to the published code.

EyeLayerWidth preserves the previous width algorithms and defaults. Function names
now use the `layerwidth_` prefix so both projects can coexist without helper-name
collisions. The entry point is `EyeLayerWidth_GUI`. No source MAT conversion or
RpEGEN analysis rerun is required for existing full group MATs.

Previously, groups arrived through RpEGEN Setup or Compare Groups. Now use
EyeLayerWidth's Add Groups or Example Groups. The four width views, contextual help,
linked measurement inspection, summary tables, IQR display, and exports remain.
Group Profiles retains pooled medians and both point-based and whole-eye
bootstrap CIs. No new group hypothesis test or resampling unit is introduced.

The bundled examples retain all 44 eyes and their geometry but omit intensity
arrays. They are independent local files, not links into an RpEGEN checkout.
The application imports saved geometry; a native raw-image/ROI preparation
workflow is future work.

## Verification

Tests cover synthetic geometry, preserved numerical profiles, literal whole-eye
bootstrap resampling, cache reuse/invalidation, all four help views, both CI
toggles, input validation, clear/reload, all-eye exports, and independent GUI
launch. `test_layerwidth_gui` computes all four example groups (44 eyes), exports
144 five-degree summary rows, and checks no RpEGEN entry point is on the path.

Historical exploratory comparisons are retained under `comparison_preview`.
Their scripts and reference methods are development material, not selectable
GUI measurement methods. Historical plots and the accompanying method notes
may show the former RpEGEN-integrated interface.
