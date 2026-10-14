# Validation and Tests

EyeLayerWidth is research software. Its tests check geometry calculations,
statistical summaries, and application behavior. They do not establish accuracy
for every tissue layer or imaging condition.

## What Is Tested

- Known-width straight and rotated strips, curved ribbons, concave polygons,
  image-border contact, invalid geometry, and clipped fitting windows at tips.
- Continuous path-length weighting, diagonal centerline steps, point ordering,
  and explicit pixel calibration in the programmatic geometry function.
- Pooled medians and confidence intervals checked against direct calculations,
  including whole-eye bootstrap draws, missing bins, and angular endpoints.
- Image inspection, point selection, IQR display, keyboard navigation, cached
  measurements, setting changes, input validation, and help on all four views.
- Individual-eye and group CSV/MAT/PDF exports, including all-eye exports.

The end-to-end GUI test loads all four bundled groups (44 eyes), produces 144
five-degree group-summary rows, and checks both confidence-band controls. It
also verifies that the application runs without another project on the MATLAB path.

## Run the Tests

Tested with MATLAB R2026b and the toolboxes listed in the [README](../README.md).
Start from the EyeLayerWidth folder with unrelated project folders removed from
the MATLAB path:

```matlab
addpath('tests')
test_layerwidth_reference_widths
test_local_normal_widths
test_layerwidth_group_profile
test_layerwidth_profiles
test_layerwidth_group_gui
test_layerwidth_batch_exports
test_layerwidth_gui
test_layerwidth_help
test_layerwidth_navigation
```

Tests write temporary files and an ignored `output` folder. Bundled input data
are not modified. Example-file checksums and provenance are recorded in
[SOURCE_MANIFEST.json](../examples/SOURCE_MANIFEST.json).

## Validate Your Data

Inspect cross-sections on the images, especially near tips, bends, and bulges.
Check how changing the fitting window affects the profiles. Use matching pixel
sizes when comparing groups, and review excluded or unavailable measurements.

The bundled RPE examples support reproducible software checks. Photoreceptor
measurements still need evaluation using appropriate photoreceptor images and
reference measurements.

Exploratory comparison scripts are in `comparison_preview`. Their reference
methods are development tools, not alternative measurement modes in the GUI.
Generated comparison outputs are excluded from version control.
