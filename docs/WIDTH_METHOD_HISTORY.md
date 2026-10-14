# Historical Width Development Notes

Archived from the RpEGEN-integrated development snapshot on 2026-10-14.
The interface paths and function names below are historical, not current launch
instructions. Use the EyeLayerWidth User Guide for the standalone application.


Load saved group MATs in **Compare Groups**, then select **Widths** and choose a
**Group**. **Setup > Open Existing Results** also supplies its group to Widths.
The first eye is measured automatically; no intensity extraction or permutation rerun is needed. Widths are
computed on demand and cached per eye in the current GUI session; the original
MAT, polygon, centerline, and intensity results are not modified.
Switching Widths groups reuses compatible cached measurements and does not
change Setup/QC or the permutation pair. The top-right **?** button explains the
current tab/subtab, including width controls and Eye Summary column definitions.

The GUI uses local-normal measurements at the existing centerline pixels:

- **Local normal:** a true-Euclidean polygon cross-section through the original
  point, perpendicular to an arc-length-weighted local centerline trend.
  **Total window (px)** defaults to **25**: 12.5 pixel-distance units before
  and 12.5 after the point, not 25 points in each direction. The adjacent label
  shows the half-window. The window uses cumulative Euclidean path length;
  diagonal pixel steps contribute `sqrt(2)`. Near either tip, only the unavailable
  portion is lost, so total fitting support gradually falls from 25 to 12.5.
  Tip widths are retained and are not artificially tapered. The fit direction
  is obtained by an orthogonal line fit weighted by continuous path length,
  avoiding orientation-dependent weighting of skeleton pixels.
- **Development reference, distance x 2:** twice the quasi-Euclidean distance to the nearest background
  pixel of the ROI mask, matching the distance metric described in ChanGeom.
  The mask is padded with background to handle image-border contact.
- **Development reference, angle-fixed:** a straight cross-section through the centerline point, with
  direction taken from its saved RpEGEN angular coordinate, not a local tangent.
  The image-coordinate unit vector is `[sin(tilt-angle), cos(tilt-angle)]` in
  degrees, undoing the existing rounded tilt and reflected angle convention.
  MATLAB polygon/line intersection finds the connected interior segment that
  contains that point. Separate, distant portions of a concave ROI are not added
  to its width.

Only local normal is displayed. Reference-method point columns remain in exports
for compatibility, but their validity does not control local profile inclusion.

The GUI reports **pixels**, assuming square pixels, not calibrated microns
or 3-D thickness. Distance-transform values refer to background pixel centers;
local-normal and angle-fixed sections use continuous polygon edges. Their difference therefore
includes rasterization and metric effects as well as geometric effects. The
reference methods remain available for development comparisons. Blue shows the local-normal cross-section;
gold highlights the centerline portion used for its fit. The local-normal helper
also accepts explicit x/y pixel sizes and units for calibrated programmatic use;
the GUI does not infer calibration from image names or magnification.

Use the arrow buttons, Page Up / Page Down, or sample dropdown to move between eyes. **QC angle**
selects the nearest measured centerline angle for the image overlay; changing it
preserves image zoom. The full image is shown initially, without ROI cropping.
The gray curve shows individual local-normal measurements and **Profile bin**
chooses the blue 1-, 5-, or 10-degree within-eye median stairstep, spanning each
full bin and aligned with the IQR blocks. Click a profile
to select the nearest included real measurement; an orange plot marker, white
image marker, cross-section, and point/coordinate/width readout update together.
Point selection preserves zoom. Only local validity and the chosen end-exclusion
rule control inclusion. The last width bin includes 180 degrees. **Measurements**
retains every point with local fields and flags; **Eye Summary** summarizes the
eyes measured so far using local-only statistics.

**Show within-bin IQR**, off by default, shades the 25th-75th percentiles of
included measurements in each angular bin. This describes within-eye variation,
not a confidence interval; bins with fewer than two points have no band. The
toggle preserves selection and zoom. MAT exports include a `profiles` table
with counts, medians, and quartiles regardless of the display setting. Figure
exports follow the toggle; CSV exports remain point-level measurements.

Changing the total window clears the width cache for all eyes and recomputes the
current eye; other eyes are measured on demand using the new setting. Image zoom
is preserved. No intensity analysis or permutation rerun is needed.

**Exclude end regions**, off by default, optionally removes points whose path distance to
the nearest centerline endpoint is no greater than the distance-transform radius.
This is a QC heuristic for end-cap effects, not a guarantee of anatomical
validity. A shortened fitting window is not itself an exclusion. Invalid local
measurements are always excluded from profiles; multiple line segments
are flagged even when the containing segment can be unambiguously measured.
Polygon simplification is recorded and accepted only for one connected, hole-free
region whose rasterized mask is unchanged; otherwise width measurement stops
with an ROI-review error. No repaired geometry is written back to source files.

Visiting an eye measures it automatically. **Measure N More** shows how many eyes
remain unmeasured and completes the current group's cache; the button becomes
**All Eyes Measured** when finished. **Export Results** measures
all eyes if needed, then writes all point measurements, flags, eye IDs, source
path, local window lengths and total setting, local-fit validity and shortened-window
flags, local Euclidean metric, and profile inclusion flags to CSV or MAT. MAT additionally contains method
metadata and the per-eye summary. **Export Figure** offers Current Eye or All Eyes,
saving image overlays and individual/binned local profiles as vector PDFs. All Eyes
writes one numbered PDF per eye with its full sample name inside, keeping the
current window, bin, exclusion, and IQR settings. Point-export
reference columns are retained; summary exports now use `IncludedPoints` and
local statistics instead of paired-method differences.

The 25-unit local window is a starting default, not a validated anatomical optimum.
The 25/50/75-unit example audit found a median within-point width range of 0.061 px
and a 95th percentile of 0.805 px, but isolated bulges differed by as much as
18.744 px. Inspect sensitivity before selecting a setting for an analysis.

Verified on MATLAB R2026b using straight and rotated strips, a curved ribbon,
concave shapes with disconnected line intersections, invalid points, border
contact, and all 44 supplied example eyes. Across those eyes, the median of the
within-eye median paired differences (angle-fixed minus distance x 2) was 0.724 px;
the median of within-eye median absolute differences was 0.885 px, excluding end
regions. These are descriptive method comparisons, not treatment tests or proof
that either method is more accurate. See `comparison_preview/width_method_summary.png`
and `comparison_preview/width_method_comparison.csv`.

Method references: [ChanGeom, Fisher et al. (2013)](https://bodobookhagen.github.io/pdf/fisher13_channel_width.pdf),
[MATLAB distance metrics](https://www.mathworks.com/help/images/distance-transform-of-a-binary-image.html),
and [polygon/line intersection](https://www.mathworks.com/help/matlab/ref/polyshape.intersect.html).

Run the geometry and GUI checks with:

```matlab
addpath('tests')
test_rpegen_widths
test_local_normal_widths
test_rpegen_width_profiles
test_rpegen_width_group_profile
test_rpegen_width_group_gui
verify_rpegen_widths
verify_rpegen_width_window
```

## Group Width Profiles

Load full group MAT files in Compare Groups, then open **Widths > Group Profiles**.
Select the groups to show and click **Plot Groups**. Curves overlay pooled
centerline-width medians in each angular bin, with optional **Point-based median
CI (nominal 95%)** and **Whole-eye bootstrap CI (95%)** bands. These are not
medians of eye medians: eyes contributing more centerline points have more weight.
The bootstrap resamples whole eyes 5,000 times, keeping each measurement in its
original angle bin and retaining continuous width values without rounding.

The shared bin, total fitting window, and end-exclusion settings apply to all
groups. Changing settings invalidates the group plot until Plot Groups is run
again. Geometry is cached and shared with individual-eye inspection; changing
bins or exclusions does not remeasure it. **Export PDF** saves the overlaid plot;
**Export Results** saves selected groups' summaries, both CIs, contributing-eye
and point counts, and settings as CSV/MAT. Use matching image pixel sizes: widths
are in pixels, not calibrated micrometers. No width significance test is added.

