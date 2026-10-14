# EyeLayerWidth

EyeLayerWidth is a MATLAB application for measuring eye tissue-layer width from
image polygons and saved centerlines. Its intended applications include photoreceptor
regeneration; the bundled RPE images are test data, not validation in photoreceptors.

## Launch

Download this repository using **Code > Download ZIP** on GitHub and extract it,
or clone it with Git. Open the extracted EyeLayerWidth folder in MATLAB.

In MATLAB, set the Current Folder to this repository and run:

```matlab
EyeLayerWidth_GUI
```

Tested with MATLAB R2026b. Image Processing Toolbox and Statistics and Machine
Learning Toolbox are required. No GPU or parallel pool is required.
No toolboxes are installed automatically.

1. Click **Example Groups** to load the four bundled groups, or **Add Groups...**
   to select compatible geometry MATs or full RpEGEN group MATs.
2. Inspect **Profiles**, **Measurements**, and **Eye Summary**. Visiting an eye
   measures it automatically. **Measure N More** measures the remaining eyes.
3. Open **Group Profiles** and click **Plot Groups**. All selected groups appear
   together with pooled width medians and both confidence bands.
4. Use the two CI checkboxes independently. Export figures as editable PDFs and
   numerical results as CSV or MAT.

The **?** button explains the currently selected view, controls, columns, and
confidence bands. **Clear Groups** discards session caches, never input files.

## Analysis Features

- Local-normal polygon cross-sections at each centerline point, using true
  Euclidean distance. Default fitting window: **25 total pixel-distance units**,
  12.5 before and 12.5 after. Tips lose unavailable support without shifting the
  window or trimming points.
- Linked image inspection, raw profiles, angular-bin median steps, and optional
  within-eye IQR blocks. Entire images remain visible before zooming.
- Eye Summary and per-point geometry tables; current-eye and all-eye PDF export.
- Group Profiles pool centerline widths within each angular bin, not eye medians.
  Eyes contributing more points receive more weight.
- Independently toggleable **point-based median CI (nominal 95%)** and
  **whole-eye bootstrap CI (95%)**, with 5,000 bootstrap draws. The same whole-eye
  draw is used at every angle; widths never move between bins.
- Geometry cache reuse, setting invalidation, fixed bootstrap seed, exported
  method/settings metadata, and full-group numerical exports.

These are pixel measurements assuming square pixels, not calibrated micrometers
or 3-D thickness. Compare matching pixel sizes. CIs are pointwise and are not a
group significance test. No width permutation test is implemented.

## Documentation

- [User Guide](docs/USER_GUIDE.md)
- [Input Format and Example Provenance](examples/README.md)
- [Measurement Method](docs/MEASUREMENT_METHOD.md)
- [Validation and Tests](docs/VALIDATION.md)

EyeLayerWidth imports saved geometry. It does not yet generate
centerlines from new image/ROI pairs or offer segmentation tools.

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

The example dataset and source image-processing workflow are from RpEGEN:
Leach, Fisher, and Gross (2022), JoVE,
DOI: [10.3791/63658](https://doi.org/10.3791/63658). That article does not describe
EyeLayerWidth's local-normal width method or bootstrap displays.
Code derived from RpEGEN retains its GPL-3.0 license; see [LICENSE](LICENSE).

This is research software under active development. The bundled examples and
tests check software behavior; users should validate measurements for their
own tissue layers and imaging conditions before drawing biological conclusions.
