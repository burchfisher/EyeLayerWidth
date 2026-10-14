function [heading,body] = layerwidth_help(topic)
% Contextual help for the standalone width application.
heading = ['Eye Layer Width Help: ' char(topic)];
switch char(topic)
    case 'Group Profiles'
        body = {
            'GROUP WIDTH PROFILES'
            'The line shows the group median width. Both confidence bands describe how precisely that SAME median is defined, but they answer different questions.'
            ''
            'THE MEDIAN LINE'
            'Within each angular slice, such as 40-45 degrees, combine the measured widths from all eyes in the group and take the middle value. That is the pooled median. Eyes contributing more points have more weight.'
            ''
            'POINT-BASED MEDIAN CI (DARK)'
            'How well do these measured points define the median?'
            'If 10 eyes provide 1,000 widths, this calculation treats those as 1,000 independent observations. Many points can give a very narrow band.'
            ''
            'WHOLE-EYE BOOTSTRAP CI (LIGHT)'
            'How much might the median change with a different sample of eyes?'
            'This calculation treats the example as 10 independent eyes and keeps each eye''s measurements together. Bootstrap means repeatedly drawing from the eyes we already have, allowing repeats.'
            'With eyes A, B, C, one draw could be A, A, C. We recalculate the pooled median for 5,000 draws of the same group size. The band spans the middle 95% of those medians.'
            'Widths stay at their original angles: the 40-45 degree bin uses only 40-45 degree measurements. The same eye draw is used at every angle.'
            ''
            'HOW TO READ BOTH BANDS'
            'CI means confidence interval: an uncertainty band around the estimated median. A median of 20 pixels with a CI of 18-23 pixels shows an estimate of 20 with uncertainty extending from 18 to 23. Individual widths can vary much more widely.'
            '95% is the intended coverage: over many repeated studies, a well-calibrated method would cover the underlying median about 95% of the time.'
            'Use the bootstrap as your main guide to how well the group median is defined across eyes. The point-based band shows precision when treating each measurement separately. To see how much the widths themselves vary within one eye, use the IQR in Profiles.'
            ''
            'KEEP IN MIND'
            'Nearby measurements from one eye are related, so the point-based band can look overly precise. The bootstrap relies on independent eyes and is less reliable with very few eyes; shared wells or batches are not accounted for. Each band applies separately at each angle. Gaps mean there is insufficient usable data for that interval.'
            'These are descriptive group plots. There is no width significance test; overlapping or separated bands alone do not establish whether treatments differ significantly.'
            ''
            'CONTROLS AND EXPORTS'
            'Add Groups loads geometry MAT files; Example Groups loads the four bundled groups. Select Show for the treatment groups to overlay, then Plot Groups. Images, polygons, and centerlines are required.'
            'Every selected eye uses the same local-normal fitting window. Previously measured eyes are reused. Group plotting does not switch the eye you are inspecting.'
            'Profile bin, Total window, and Exclude end regions apply to every group. Changed settings clear the plot until Plot Groups is run again. Changing bin or exclusion reuses geometry; changing the window requires new measurements.'
            'Widths are in pixels, not micrometers. Only compare images acquired at matching pixel sizes; the app cannot infer calibration from these MAT files.'
            'Legend n counts eyes in the group. In exports, Points counts width measurements and ContributingEyes counts the eyes represented in that bin. Exports also include both CIs and the calculation settings.'
            'Check either band on or off; the median stays the same. The final angular bin includes exactly 180 degrees.'
            'Export PDF saves the selected curves and checked bands in one vector PDF. Export Results saves selected group summaries as CSV or MAT. Per-eye measurements remain available through the individual-eye export.'
            };
    case {'Profiles','Measurements','Eye Summary'}
        common = {
            'WIDTHS'
            'Left Arrow selects the previous eye; Right Arrow selects the next in individual-eye views. The adjacent buttons and Page Up / Page Down also work. Navigation stops at the first and last eye and is inactive in Group Profiles. Arrow keys retain normal editing or selection behavior in input controls; click an image or navigation button to resume eye navigation.'
            'Add Groups loads one or more geometry MAT files. Example Groups loads four bundled test groups. Group selects the group to inspect; its first eye is measured automatically. No intensity extraction rerun is needed.'
            'Visiting an eye measures it automatically and caches the result. Seeing one measured eye does not mean the other eyes are already measured.'
            'Measure N More measures only the remaining eyes and completes Eye Summary. It does not change or repeat cached measurements. When every eye is measured, the button reads All Eyes Measured and is disabled. Export Results also measures any remaining eyes.'
            'Selecting a different group reuses compatible cached measurements. Changing the fitting window clears geometry caches. Changing the profile bin or IQR display does not remeasure widths.'
            'Clear Groups discards loaded groups and unsaved measurements, but never changes source files.'
            ''
            'Local-normal width: the sum of distances to both polygon sides along a line through the centerline point, perpendicular to a fitted local trend. Distances are true Euclidean pixels, assuming square pixels, not micrometers.'
            'Total window: distance along the centerline used to fit the trend. Default 25 means 12.5 before and 12.5 after. Tips lose unavailable support without moving the window or trimming points.'
            'Exclude end regions: optional geometry-based end exclusion. Shortened fit windows are retained by default.'};
        if strcmp(topic,'Eye Summary')
            detail = {
                'EYE SUMMARY COLUMNS'
                'What is a typical width for each eye? Each row describes one eye.'
                'Eye: saved image/sample name.'
                'TotalPoints: all centerline rows, including invalid measurements.'
                'IncludedPoints: points with LocalValid = true and finite width, after optional end-region exclusion.'
                'LocalMedianPx: the middle value of all included point widths in this eye. For widths 10, 20, 60 pixels, the median is 20 pixels. With an even count, average the two middle values. Each point has equal weight.'
                'ShortWindowPoints: included points whose fit window is shortened at a tip.'
                'LocalWindowTotalPx: requested total window, not the shorter actual support at tips.'
                ''
                'Only measured eyes appear. Measure N More fills the remaining rows. Profile bin does not affect these columns.'};
        elseif strcmp(topic,'Measurements')
            detail = {
                'MEASUREMENT COLUMNS'
                'Point: centerline row ID. Angle: saved angular position. X / Y: image-pixel coordinates.'
                'LocalWidthPx: full local-normal cross-section width. LocalMinusRadiusPx / LocalPlusRadiusPx are its two side lengths.'
                'LocalSectionX1/Y1 and X2/Y2: polygon intersection endpoints.'
                'LocalPathDistancePx: Euclidean distance along the ordered centerline.'
                'LocalWindowTotalPx: requested total window. LocalWindowBeforePx / AfterPx: actual support. LocalWindowShortened flags missing support at a tip.'
                'LocalTangentX/Y: fitted direction; LocalNormalX/Y: perpendicular direction.'
                'LocalFitLinearity: how clearly the nearby centerline follows one direction. Near 1 means a straighter trend; near 0.5 means no clear direction.'
                'LocalFitRMSPx: how far the nearby centerline sits sideways from its fitted line, summarized in pixels using a root-mean-square average. Smaller values mean a closer fit.'
                'These two scores help you check the fitted direction. Use the image to inspect questionable sections. NaN means the measurement is unavailable.'
                'LocalMultipleSegments: the line intersects more than one polygon interior segment; the containing segment is used if unique.'
                'LocalAmbiguousSection / LocalDegenerateTrend: geometry or fitted direction could not define a unique reliable section.'
                'LocalValid: usable local geometry. EndpointRisk: optional end-region flag. Invalid rows remain in the table and are not used in profiles.'};
        else
            detail = {
                'PROFILE AND IMAGE'
                'Gray curve: individual centerline-point widths. Blue steps: median of included widths in each angular bin.'
                'Median means the middle width after sorting; for an even count, average the two middle values. Each blue step summarizes one angular slice of this eye, such as 40-45 degrees.'
                'WITHIN-BIN IQR: HOW VARIABLE ARE THE WIDTHS?'
                'IQR (interquartile range) covers the middle 50% of widths in a bin. Imagine sorting the widths and setting aside the lowest quarter and highest quarter: the block shows the range in between.'
                'For example, a block spanning 18-26 pixels has an IQR of 8 pixels. Wider blocks mean more variation along that part of the eye.'
                'Check Show within-bin IQR to display these blocks. At least two measurements are needed. IQR shows spread in the widths; the confidence bands in Group Profiles show uncertainty in the group median.'
                'Profile bin changes only the step medians and IQR; it does not change individual widths or Eye Summary.'
                'Click a profile point, step, or band to select a nearby real measurement. The image shows its centerline location and measured cross-section. A bin median does not itself define a new cross-section.'
                'QC angle chooses the nearest saved angular position. ROI is purple, centerline green, fitted window gold, and measured section blue.'
                'The entire stored image is shown initially. Zoom is retained while inspecting points on the same eye.'
                'Export Figure offers Current Eye or All Eyes. All Eyes measures any remaining eyes and saves one PDF per eye in the chosen folder, using the current bin, window, exclusion, and IQR settings. Each PDF identifies the eye; images remain raster.'
                'Export Results always includes the whole group. CSV contains point measurements; MAT also includes binned profiles, Eye Summary, and settings.'};
        end
        body = [detail; {''}; common];
    otherwise
        error('EyeLayerWidth:Help','Unknown help topic: %s',topic);
end
end
