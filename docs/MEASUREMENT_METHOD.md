# Measurement Method

EyeLayerWidth measures a cross-section at each saved centerline point using
the polygon boundary and a locally fitted centerline direction. See the
[User Guide](USER_GUIDE.md) for GUI controls and exports.

## Local-Normal Width

1. Order the centerline points by their saved path order and calculate cumulative
   Euclidean distance. A diagonal step of one pixel in each direction has length
   `sqrt(2)`.
2. Select a window centered on the measurement point. The default total window
   is 25 pixel-distance units: 12.5 before and 12.5 after the point.
3. Fit a straight line to that window, weighting by continuous path length
   rather than the number of raster points. The implementation uses an
   orthogonal line fit with exactly integrated segment covariance.
4. Pass a line through the measurement point, perpendicular to the fitted
   direction. Find where that line intersects the polygon on each side.
5. Add the two side lengths to obtain the full width. The centerline can be
   closer to one boundary than the other.

Near a tip, the window loses only the unavailable portion. It is not shifted
away from the point, and shortened support does not itself exclude the width.
Widths are not artificially tapered toward the tips.

If a line crosses several disconnected polygon sections, only the unique
section containing the measurement point is used. Ambiguous intersections or
an undefined fitted direction produce an unavailable measurement.

## Units and Fit Checks

The GUI reports pixels and assumes square pixels. It does not infer physical
calibration from image names or magnification. Compare images with matching
pixel sizes. These are two-dimensional cross-sections, not 3-D tissue thickness.

The `layerwidth_local_normal` function also accepts explicit x/y pixel sizes
and units for calibrated programmatic use. This does not automatically calibrate
the GUI.

`LocalFitLinearity` describes how clearly the nearby centerline follows one
direction: near 1 is straighter, while near 0.5 indicates no clear direction.
`LocalFitRMSPx` summarizes sideways distance from the fitted line; smaller values
indicate a closer fit. Inspect the image when these scores suggest a poor fit.

The 25-unit window is a starting default. Check sensitivity to smaller and larger
windows, particularly near bends and bulges, before selecting an analysis setting.

## Validity and End Regions

Invalid measurements remain in the measurement table but are excluded from
profiles. Polygon simplification is accepted only when it leaves one connected,
hole-free region with the same rasterized mask. Otherwise measurement stops
with an ROI-review error. Source geometry is never overwritten.

**Exclude end regions**, off by default, removes points whose path distance to
the nearest centerline endpoint is no greater than the distance-transform radius.
This is a geometric check for end-cap effects; anatomical review is still needed.

## Profiles and Confidence Bands

Individual-eye profiles show every included point width and the median within
each angular bin. Optional IQR blocks cover the middle 50% of widths in the bin.
The final bin includes exactly 180 degrees.

Group curves combine widths from all selected eyes within each angular bin and
take the pooled median. Eyes supplying more points have more weight.
The point-based confidence band treats each measurement as independent. The
whole-eye bootstrap band redraws entire eyes 5,000 times and recalculates that
same pooled median, keeping measurements at their original angles. The same
eye draw is used for every angle, and continuous widths are not rounded.

Both confidence bands describe uncertainty in the median at each angle. IQR
describes variation in the widths themselves. The [User Guide](USER_GUIDE.md)
explains interpretation, missing bands, and assumptions in more detail.

## Reference Calculations

Two additional calculations are available for development comparisons and in
point-level exports; neither controls which local-normal widths enter profiles:

- **Distance times two:** twice the quasi-Euclidean distance to the nearest
  background pixel of the ROI mask, with background padding at image borders.
- **Angle-fixed:** a polygon cross-section using the saved angular coordinate
  rather than a locally fitted direction. Its image-coordinate direction is
  `[sin(tilt-angle), cos(tilt-angle)]`, with angles in degrees.

Distance-transform widths refer to background pixel centers; polygon sections
use continuous edges. Differences therefore reflect rasterization, distance
metrics, and geometry. Reference-method agreement alone does not demonstrate
anatomical accuracy.

See [Validation and Tests](VALIDATION.md) for reproducible checks and the
`comparison_preview` scripts for exploratory comparisons.

## Method References

- [ChanGeom, Fisher et al. (2013)](https://bodobookhagen.github.io/pdf/fisher13_channel_width.pdf)
- [MATLAB distance metrics](https://www.mathworks.com/help/images/distance-transform-of-a-binary-image.html)
- [MATLAB polygon/line intersection](https://www.mathworks.com/help/matlab/ref/polyshape.intersect.html)
