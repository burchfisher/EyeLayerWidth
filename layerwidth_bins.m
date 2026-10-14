function bins = layerwidth_bins(points,width,excludeEnds,method)
% Use the same valid centerline points for the displayed width summaries.
if nargin<4, method = 'paired'; end
method = validatestring(method,{'paired','local'});
validateattributes(width,{'numeric'},{'scalar','integer','positive'});
assert(mod(180,width)==0,'EyeLayerWidth:Widths','Bin width must divide 180.');
if strcmp(method,'local')
    valid = points.LocalValid & isfinite(points.LocalWidthPx);
    if excludeEnds, valid = valid & ~points.EndpointRisk; end
    angle = ((width/2):width:180)'; samples = zeros(size(angle)); values = nan(size(angle));
    lower = values; upper = values;
    for k = 1:numel(angle)
        selected = valid & points.Angle>=(k-1)*width & ...
            (points.Angle<k*width | (k==numel(angle) & points.Angle==180));
        samples(k) = nnz(selected);
        if samples(k)>0, values(k) = median(points.LocalWidthPx(selected)); end
        if samples(k)>1
            quartiles = prctile(points.LocalWidthPx(selected),[25 75]);
            lower(k) = quartiles(1); upper(k) = quartiles(2);
        end
    end
    bins = table(angle,samples,values,lower,upper, ...
        'VariableNames',{'Angle','Points','LocalMedianPx','LocalQ25Px','LocalQ75Px'});
    return;
end
valid = points.ValidPair;
hasLocal = ismember('LocalWidthPx',points.Properties.VariableNames);
if hasLocal, valid = valid & points.LocalValid; end
if excludeEnds, valid = valid & ~points.EndpointRisk; end
count = 180/width; values = nan(count,3); samples = zeros(count,1); local = nan(count,1);
for k = 1:count
    selected = valid & points.Angle>=(k-1)*width & ...
        (points.Angle<k*width | (k==count & points.Angle==180));
    samples(k) = nnz(selected);
    if samples(k)>0
        values(k,:) = median([points.DistanceWidthPx(selected),points.AngleWidthPx(selected), ...
            points.DifferencePx(selected)],1);
        if hasLocal, local(k) = median(points.LocalWidthPx(selected)); end
    end
end
bins = table(((width/2):width:180)',samples,values(:,1),values(:,2),values(:,3), ...
    'VariableNames',{'Angle','Points','DistanceMedianPx','AngleMedianPx','DifferenceMedianPx'});
if hasLocal, bins.LocalMedianPx = local; end
end
