function [points,metadata] = layerwidth_measure_eye(data,k,window)
% Shared point schema for individual-eye and group width workflows.
if isfield(data,'ROIBW'), mask = logical(data.ROIBW{k});
else, mask = poly2mask(data.ROIxy{k}(:,1),data.ROIxy{k}(:,2),size(data.IMG{k},1),size(data.IMG{k},2)); end
[points,metadata] = layerwidth_reference_widths(data.ROIxy{k},mask,data.CLine{k});
[local,metadata.LocalNormal] = layerwidth_local_normal(data.ROIxy{k},mask,data.CLine{k},window);
fields = {'Width','PathDistance','BeforeLength','AfterLength','WindowTruncated', ...
    'TangentX','TangentY','NormalX','NormalY','FitLinearity','FitRMS','MinusDistance','PlusDistance', ...
    'SectionX1','SectionY1','SectionX2','SectionY2','MultipleSegments','AmbiguousSection','DegenerateTrend','Valid'};
names = {'LocalWidthPx','LocalPathDistancePx','LocalWindowBeforePx','LocalWindowAfterPx','LocalWindowShortened', ...
    'LocalTangentX','LocalTangentY','LocalNormalX','LocalNormalY','LocalFitLinearity','LocalFitRMSPx','LocalMinusRadiusPx','LocalPlusRadiusPx', ...
    'LocalSectionX1','LocalSectionY1','LocalSectionX2','LocalSectionY2','LocalMultipleSegments','LocalAmbiguousSection','LocalDegenerateTrend','LocalValid'};
local = local(:,fields); local.Properties.VariableNames = names;
local.LocalWindowTotalPx = repmat(window,height(local),1);
points = [points local];
end
