# EyeLayerWidth

EyeLayerWidth is a MATLAB application for measuring eye tissue-layer width from
image polygons and saved centerlines. Its intended applications include photoreceptor
regeneration; the bundled RPE images are test data, not validation in photoreceptors.

## MATLAB GUI

Download this repository using **Code > Download ZIP** on GitHub and extract it,
or clone it with Git. Open the extracted EyeLayerWidth folder in MATLAB.

In MATLAB, set the Current Folder to this repository and run:

```matlab
EyeLayerWidth_GUI
```

Tested with MATLAB R2026b. Image Processing Toolbox and Statistics and Machine
Learning Toolbox are required. No GPU or parallel pool is required.
No toolboxes are installed automatically.

Start by loading groups and checking the shared measurement settings. Then follow
the views in order: [Profiles](#profiles) > [Measurements](#measurements) >
[Eye Summary](#eye-summary) > [Group Profiles](#group-profiles).
**There is no Run Analysis step: visiting an eye measures it automatically.**

The **?** button explains the currently selected view, controls, columns, and
confidence bands. **Clear Groups** discards session caches, never input files.

### Load Groups and Measurement Settings

Click **Example Groups** to load the four bundled groups, or **Add Groups...**
to select compatible geometry MAT files or full
[RpEGEN](https://github.com/burchfisher/RpEGEN) group MAT files. Existing images,
ROI polygons, and saved centerlines can be reused without redrawing ROIs.
EyeLayerWidth imports saved geometry; it does not generate centerlines from new
image/ROI pairs or offer segmentation tools.

Choose a **Group** for individual-eye inspection. **Total window (px)** defaults
to **25 total pixel-distance units**, 12.5 before and 12.5 after each centerline
point. The local trend defines a perpendicular cross-section through the polygon;
the distances to both boundaries are added. Tips lose unavailable fitting support
without shifting the window or trimming points.

**Profile bin** selects 1-, 5-, or 10-degree summaries. **Exclude end regions**
is optional and off by default. Measurements are in pixels, assuming square
pixels, not calibrated micrometers or 3-D thickness. Compare matching pixel sizes.

### Profiles

Review the image alongside individual widths and angular-bin median steps.
Click the profile to show the selected measurement's location and cross-section
on the image. Use **Left Arrow / Right Arrow**, the adjacent navigation buttons,
or the eye dropdown to browse eyes. Each newly visited eye is measured automatically.

**Show within-bin IQR** adds blocks covering the middle 50% of widths within each
bin of that eye. This shows local variation, not confidence in a group median.
**Export Figure...** offers a PDF for the current eye or one PDF per eye for the
entire current group, using the selected measurement and display settings.

### Measurements

Inspect one row per centerline point, including width, boundary intersections,
fit diagnostics, and validity flags. **?** explains the columns. Invalid
measurements are retained in exports but excluded from profiles, not set to zero.

The individual-eye toolbar's **Export Results...** measures any remaining eyes
and exports the **entire current group**, not just the displayed eye. CSV contains
per-point measurements; MAT also includes profiles, Eye Summary, and method/settings metadata.

### Eye Summary

Review one row per measured eye, including its median width and included-point
count. A visible profile does not mean every eye has been measured.
**Measure N More** measures the remaining eyes; the button then reads
**All Eyes Measured**. The same full-group **Export Results...** includes this
summary in the MAT output.

### Group Profiles

Select the groups' **Show** checkboxes and click **Plot Groups**. Each curve is
the pooled median of centerline widths within each angular bin, not a median
of per-eye medians. Eyes contributing more points receive more weight.

Toggle the two bands independently:

- **Point-based median CI (nominal 95%)** estimates how precisely the pooled
  median is defined when each width measurement is treated as independent.
- **Whole-eye bootstrap CI (95%)** estimates how much that same median could
  move with a different sample of eyes. It resamples whole eyes 5,000 times,
  using the same eye draw at every angle; widths never move between bins.

Both describe uncertainty in the median, not the spread of widths. Points from
one eye can be related, so the point-based band can be very narrow. Intervals
apply to each bin separately. No width significance test is implemented, and
CI overlap alone is not a treatment significance test.

**Export PDF...** saves the group curves and visible bands. Group **Export
Results...** saves CSV/MAT with both CI limits, counts, and settings, even when
a band is hidden. Changing the window, bin, or exclusion clears group plots;
click **Plot Groups** again. Cached geometry is reused when possible.

PDF text, lines, and bands remain editable vector elements; images remain raster.
Keep the source geometry MATs and exported results. Session caches and display
names are not saved automatically.

## Documentation

- [User Guide](docs/USER_GUIDE.md)
- [Input Format and Example Provenance](examples/README.md)
- [Measurement Method](docs/MEASUREMENT_METHOD.md)
- [Validation and Tests](docs/VALIDATION.md)

## Tests

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

Run from EyeLayerWidth with other project folders removed from the MATLAB path for
the independence check. Tests create temporary outputs and an ignored `output`
folder; they do not change bundled inputs.

## Attribution

See [Attribution](docs/ATTRIBUTION.md) for source-code credits and the example-data
citation. The code is distributed under the [GPL-3.0 license](LICENSE).

This is research software under active development. The bundled examples and
tests check software behavior; users should validate measurements for their
own tissue layers and imaging conditions before drawing biological conclusions.
