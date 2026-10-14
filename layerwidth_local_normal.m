function [result,metadata] = layerwidth_local_normal(polygon,mask,centerline,windowLength,varargin)
% Local-normal widths with a point-centered, shortened-at-tips arc-length window.
if nargin<4, windowLength = 25; end
validateattributes(windowLength,{'numeric'},{'scalar','positive','finite'});
parser = inputParser;
addParameter(parser,'PixelSize',[1 1],@(v) isnumeric(v) && numel(v)==2 && all(isfinite(v)) && all(v>0));
addParameter(parser,'Units','pixel-distance',@(v) ischar(v) || (isstring(v) && isscalar(v)));
parse(parser,varargin{:}); scale = reshape(double(parser.Results.PixelSize),1,2);
base = layerwidth_reference_widths(polygon,mask,centerline);
shape = simplify(polyshape(polygon,'Simplify',false)); shape = polyshape(shape.Vertices.*scale,'Simplify',false);
xy = [base.X,base.Y].*scale; n = height(base);
[savedDistance,order] = sort(double(centerline.distance));
assert(n>=2 && all(diff(savedDistance)>0),'EyeLayerWidth:LocalNormal','Centerline path ordering must be unique.');
orderedXY = xy(order,:); step = vecnorm(diff(orderedXY),2,2);
assert(all(step>0),'EyeLayerWidth:LocalNormal','Consecutive centerline coordinates must differ.');
path = [0;cumsum(step)]; distance = zeros(n,1); distance(order) = path;
before = min(windowLength/2,distance); after = min(windowLength/2,path(end)-distance);
truncated = before<windowLength/2-1e-9 | after<windowLength/2-1e-9;
tangent = nan(n,2); normal = tangent; linearity = nan(n,1); rms = linearity;
minus = nan(n,1); plus = minus; endpoints = nan(n,4);
multiple = false(n,1); ambiguous = false(n,1); degenerate = false(n,1);
reach = 2*hypot(size(mask,2)*scale(1),size(mask,1)*scale(2));
tolerance = 1e-8*max(1,reach);
for k = 1:n
    lo = distance(k)-before(k); hi = distance(k)+after(k);
    nodes = [interp1(path,orderedXY,lo,'linear');orderedXY(path>lo & path<hi,:);interp1(path,orderedXY,hi,'linear')];
    segment = diff(nodes); length = vecnorm(segment,2,2); keep = length>0;
    starts = nodes(1:end-1,:); starts = starts(keep,:); segment = segment(keep,:); length = length(keep);
    % Two Gauss nodes per segment exactly integrate arc-length-weighted covariance.
    samples = [starts+(.5-1/(2*sqrt(3)))*segment;starts+(.5+1/(2*sqrt(3)))*segment]-xy(k,:);
    weights = [length;length]/(2*sum(length));
    meanPosition = sum(samples.*weights,1);
    [~,singular,vectors] = svd((samples-meanPosition).*sqrt(weights),0);
    variance = diag(singular).^2;
    if numel(variance)<2 || variance(1)<=eps || variance(1)-variance(2)<=1e-8*variance(1)
        degenerate(k) = true; continue;
    end
    direction = vectors(:,1)';
    if dot(direction,nodes(end,:)-nodes(1,:))<0, direction = -direction; end
    tangent(k,:) = direction; normal(k,:) = [-direction(2),direction(1)];
    linearity(k) = variance(1)/sum(variance); rms(k) = sqrt(variance(2));
    if ~base.InsideMask(k) || ~base.InsidePolygon(k) || base.AtPolygonBoundary(k), continue; end
    point = xy(k,:); direction = normal(k,:);
    segments = intersect(shape,[point-reach*direction;point+reach*direction]);
    if isempty(segments), ambiguous(k) = true; continue; end
    finite = all(isfinite(segments),2);
    starts = find(finite & [true;~finite(1:end-1)]);
    stops = find(finite & [~finite(2:end);true]); multiple(k) = numel(starts)>1;
    spans = nan(numel(starts),2);
    for j = 1:numel(starts)
        spans(j,:) = sort((segments([starts(j),stops(j)],:)-point)*direction')';
    end
    spans = spans(spans(:,1)<-tolerance & spans(:,2)>tolerance,:);
    if size(spans,1)~=1, ambiguous(k) = true; continue; end
    minus(k) = -spans(1); plus(k) = spans(2);
    a = (point+spans(1)*direction)./scale; b = (point+spans(2)*direction)./scale;
    endpoints(k,:) = [a,b];
end
width = minus+plus; valid = isfinite(width) & width>0;
result = table(base.Point,base.Angle,base.X,base.Y,distance,before,after,truncated, ...
    tangent(:,1),tangent(:,2),normal(:,1),normal(:,2),linearity,rms,minus,plus,width, ...
    endpoints(:,1),endpoints(:,2),endpoints(:,3),endpoints(:,4),multiple,ambiguous,degenerate,valid, ...
    base.EndpointRisk,base.DistanceWidthPx,base.AngleWidthPx, ...
    'VariableNames',{'Point','Angle','X','Y','PathDistance','BeforeLength','AfterLength','WindowTruncated', ...
    'TangentX','TangentY','NormalX','NormalY','FitLinearity','FitRMS','MinusDistance','PlusDistance','Width', ...
    'SectionX1','SectionY1','SectionX2','SectionY2','MultipleSegments','AmbiguousSection','DegenerateTrend','Valid', ...
    'LegacyEndpointRisk','OriginalQuasiWidthPx','AngleFixedWidthPx'});
metadata = struct('WindowLength',windowLength,'PixelSize',scale,'Units',char(parser.Results.Units), ...
    'WindowRule','Point-centered plus/minus half window in Euclidean arc length; clipped at endpoints without shifting', ...
    'TrendMethod','Continuous arc-length-weighted orthogonal line fit using exact segment quadrature and SVD', ...
    'WidthMethod','True Euclidean length of containing polygon cross-section, normal to trend through original point', ...
    'DistanceRule','Order by saved path distance, then recompute cumulative Euclidean length with x/y calibration', ...
    'CoordinateUnits','Section and point coordinates remain image pixels; directions and lengths use calibrated coordinates', ...
    'OriginalColumns','OriginalQuasiWidthPx and AngleFixedWidthPx remain uncalibrated pixel reference values', ...
    'MaxPathStep',max(step),'PathLength',path(end));
end
