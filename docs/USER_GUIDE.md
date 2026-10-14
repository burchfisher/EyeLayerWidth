# EyeLayerWidth User Guide

EyeLayerWidth measures tissue-layer widths, displays each measurement on the
eye image, and compares width profiles across treatment groups. This guide
covers loading data, reviewing measurements, interpreting plots, and exporting results.

## Start and Load Groups

In MATLAB, change the Current Folder to EyeLayerWidth and run `EyeLayerWidth_GUI`.
Click **Example Groups** to load all four test groups. There is no Setup analysis
step: the bundled MATs already contain images, polygons, and centerlines.

**Add Groups...** accepts multiple MAT files at once, one group per file. Load
full RpEGEN results or the geometry format documented in `examples/README.md`.
Paths are deduplicated, not file contents: do not load two copies of the same
group as independent treatments. Malformed inputs are rejected before the
session's group list is changed.

Use **Group** to choose a group for individual-eye inspection. The first eye is
measured automatically. **Left Arrow / Right Arrow** select the previous/next eye;
the adjacent buttons and Page Up / Page Down also work. The dropdown jumps directly
to a named eye. Navigation stops at the first and last eye and is inactive in Group
Profiles. Arrow keys retain normal editing and selection behavior in input controls;
click an image or navigation button to resume eye navigation.

The top-right **?** opens help for whichever of the four views is selected.
Click it again after switching views to update the help window.

## Profiles

The image shows the polygon in purple, centerline in green, fitted window in
gold, and measured cross-section in blue. The full stored image is displayed
initially. The plot shows individual local-normal widths in gray and binned
medians as blue steps. Click the plot to select a real measurement and see its
position and cross-section on the image. A bin median is a summary, not a new
geometric measurement. **QC angle** selects the nearest saved angular position.

**Show within-bin IQR** adds optional blocks from the 25th to 75th percentiles
of measurements within that eye and angular bin. This describes spatial
variation, not confidence in a treatment-group median. Fewer than two included
points gives no IQR block. Selecting measurements preserves current image zoom.

## Measurement Settings

**Total window (px)** defaults to **25 total**, not 25 each side. A local trend is
fitted using 12.5 Euclidean pixel-distance units before and after the centerline
point. Diagonal steps contribute their Euclidean length. The fit weights by
continuous path length, not by the number of raster points. Its perpendicular
passes through the actual centerline point, and distances to both polygon
boundaries are added.

Near tips, unavailable fitting support is dropped without shifting the window.
Measured widths are not tapered and tips are not trimmed. The 25-unit default is
a practical starting setting, not a proven optimum for every tissue or resolution.
Changing this window invalidates measured geometry for all groups.

**Profile bin** selects 1-, 5-, or 10-degree intervals. It changes individual and
group summaries without remeasuring geometry. Final bins include exactly 180
degrees. **Exclude end regions** is an optional geometry-based end exclusion,
off by default. A shortened fitting window alone does not remove a measurement.

Distances shown by the GUI are pixels, assuming square pixels. Image names and
magnification are not used to infer physical calibration. Compare groups only
at matching pixel sizes. Programmatic `layerwidth_local_normal` supports explicit
x/y pixel sizes, but that does not calibrate the GUI automatically.

## Measurements and Eye Summary

**Measurements** lists individual centerline points, angles, coordinates,
widths, fit diagnostics, and validity flags. `LocalWidthPx` is the full section;
`LocalMinusRadiusPx` and `LocalPlusRadiusPx` are the two side lengths.
`LocalSectionX1/Y1` and `LocalSectionX2/Y2` locate the boundary intersections.
`LocalValid` marks usable geometry. Invalid rows remain exported but are excluded
from profiles; they are not replaced with zeros. The help window defines each
displayed measurement column.

**Eye Summary** includes only eyes already measured:

| Column | Meaning |
| --- | --- |
| Eye | Saved sample name |
| TotalPoints | All saved centerline rows, including invalid measurements |
| IncludedPoints | Valid finite widths after optional end exclusion |
| LocalMedianPx | Median of included individual widths, not median of bin medians |
| ShortWindowPoints | Included points with shortened fitting support at a tip |
| LocalWindowTotalPx | Requested fitting window, not actual shortened support |

**Measure N More** measures only uncached eyes and completes this table. Visiting
an eye measures it automatically, so a visible profile does not imply all other
eyes have been measured. When complete, the button reads **All Eyes Measured**.
Changing bins or IQR display does not change this summary.

## Group Profiles and Confidence Bands

Choose **Group Profiles**, select the groups' **Show** checkboxes, and click
**Plot Groups**. Group names can be edited for display and export. Each curve
pools all included centerline widths within each angular bin and takes their
median. It is not a median of per-eye medians: an eye with more points in a bin
has more weight. The same settings apply across selected groups.

The two confidence bands can be checked on or off independently:

- **Point-based median CI (nominal 95%)** uses a median-rank approach
  applied to width measurements. It treats points as independent and can be very
  narrow when many correlated points come from only a few eyes.
- **Whole-eye bootstrap CI (95%)** resamples entire eyes with replacement 5,000
  times, recomputing the same pooled median. For a draw A, A, C, a bin contains
  A's widths twice and C's widths once, using only widths from that same bin.
  The same eye draw is used across all bins. No composite eyes are created and
  no widths move between angle ranges. The middle 95% of replicate medians is
  plotted. Continuous widths are not rounded to intensity-like integer values.

Both describe uncertainty in the pooled median, not the range containing 95%
of measurements or eyes. Whole-eye resampling assumes independent eyes and
does not model shared wells or batches. These are pointwise intervals, not
simultaneous bands. Fewer than two contributing eyes, empty bootstrap draws,
or invalid point-rank bounds suppress the corresponding band for that bin.

Legend `n` is the group's total number of eyes; exports also record contributing
eyes and points per bin. Changing bin, window, or exclusion clears group plots
until **Plot Groups** is run again. Geometry is reused when possible. CI toggles
change display only. No width p-value test is included, and CI overlap alone is
not a treatment significance test.

## Export and Reproduce

Individual **Export Results...** measures remaining eyes and exports the entire
current group. CSV contains per-point measurements; MAT also contains binned
profiles, Eye Summary, and method/settings metadata. Development reference
columns for distance-times-two and angle-fixed widths remain in exports but do
not control inclusion of local-normal widths.

Individual **Export Figure...** offers Current Eye or All Eyes. All Eyes produces
one PDF per eye in the selected folder with matching window, bin, exclusion, and
IQR settings. Existing files require confirmation in the GUI.

Group **Export PDF...** saves the selected group curves and visible CI bands in
one figure. Group **Export Results...** writes CSV/MAT with both sets of CI limits,
even if one band is hidden, plus counts, source paths, fitting settings,
bootstrap seed, and draw count. Exported MATs are results, not reloadable sessions.

PDF text, lines, and bands are vector elements; image layers remain raster.
Save both numerical outputs and source geometry files to reproduce an analysis.
Caches and group display names do not persist after closing the app.

## Troubleshooting

- No profile: load a geometry MAT, not a width-export or `_run.mat` file.
- Some eyes absent from Eye Summary: use Measure N More.
- Group plot disappeared after a setting change: click Plot Groups again.
- Missing CI: check contributing-eye/point counts and missing-data flags in the export.
- ROI review error: inspect polygon and mask agreement; invalid geometry is not
  silently repaired into a different tissue shape.
- After a code update: close and relaunch EyeLayerWidth_GUI so callbacks are refreshed.

Clear Groups removes unsaved measurements from the session but never deletes
source MATs or previously exported files.
