function [samples,mapped,geometry] = boundary_euclidean_widths(polygon,mask,centerline,spacing)
% Experimental continuous-edge distances, joined by segment midpoint.
if nargin<4, spacing = 1; end
validateattributes(spacing,{'numeric'},{'scalar','positive','finite'});
base = layerwidth_reference_widths(polygon,mask,centerline);
shape = simplify(polyshape(polygon,'Simplify',false)); vertices = shape.Vertices;
closed = [vertices;vertices(1,:)]; lengths = vecnorm(diff(closed),2,2);
cumulative = [0;cumsum(lengths)]; perimeter = cumulative(end);
[~,first] = min(centerline.distance); [~,last] = max(centerline.distance);
centerXY = [base.X,base.Y];
[~,~,cuts] = nearestSegment(centerXY([first last],:),closed);
cuts = sort(cuts);
assert(diff(cuts)>1e-6 && perimeter-diff(cuts)>1e-6,'EyeLayerWidth:BoundaryWidth', ...
    'Endpoint projections do not separate the polygon into two boundary arcs.');
arcS1 = [cuts(1);cumulative(cumulative>cuts(1) & cumulative<cuts(2));cuts(2)];
wrapped = sort([cumulative(1:end-1);cumulative(1:end-1)+perimeter]);
arcS2 = [cuts(2);wrapped(wrapped>cuts(2) & wrapped<cuts(1)+perimeter);cuts(1)+perimeter];
arc1 = interpolate(arcS1); arc2 = interpolate(arcS2);
arcLengths = [diff(cuts),perimeter-diff(cuts)]; arcs = {arc1,arc2};
samples = table;
for side = 1:2
    source = arcs{side}; target = arcs{3-side};
    localS = [0;cumsum(vecnorm(diff(source),2,2))];
    count = ceil(localS(end)/spacing);
    s = ((1:count)'-.5)*localS(end)/count;
    a = interp1(localS,source,s,'linear');
    [width,b,targetS] = nearestSegment(a,target);
    midpoint = (a+b)/2;
    [point,joinDistance] = knnsearch(centerXY,midpoint);
    splitDistance = min([s,arcLengths(side)-s,targetS,arcLengths(3-side)-targetS],[],2);
    splitRisk = splitDistance<=width;
    outside = false(count,1);
    for j = 1:count
        if width(j)<1e-8, outside(j) = true; continue; end
        pieces = intersect(shape,[a(j,:);b(j,:)]);
        steps = diff(pieces,1,1); finite = all(isfinite(steps),2);
        insideLength = sum(vecnorm(steps(finite,:),2,2));
        outside(j) = abs(insideLength-width(j))>1e-6*max(1,width(j));
    end
    included = ~splitRisk & ~outside & base.ValidPair(point) & ~base.EndpointRisk(point);
    t = table(repmat(side,count,1),a(:,1),a(:,2),b(:,1),b(:,2),width,midpoint(:,1),midpoint(:,2), ...
        point,base.Angle(point),joinDistance,splitRisk,outside,included, ...
        'VariableNames',{'SourceSide','SourceX','SourceY','TargetX','TargetY','WidthPx','MidX','MidY', ...
        'CenterlinePoint','Angle','JoinDistancePx','SplitRisk','OutsideShortcut','Included'});
    samples = [samples;t]; %#ok<AGROW>
end
n = height(base); counts = zeros(n,2); medians = nan(n,2);
for side = 1:2
    good = samples.SourceSide==side & samples.Included;
    counts(:,side) = accumarray(samples.CenterlinePoint(good),1,[n 1],@sum,0);
    medians(:,side) = accumarray(samples.CenterlinePoint(good),samples.WidthPx(good),[n 1],@median,NaN);
end
distance1 = nearestSegment(centerXY,arc1); distance2 = nearestSegment(centerXY,arc2);
mapped = base;
mapped.CountA = counts(:,1); mapped.CountB = counts(:,2);
mapped.BoundaryAtoBPx = medians(:,1); mapped.BoundaryBtoAPx = medians(:,2);
mapped.ContinuousTwoSidePx = distance1+distance2;
mapped.ContinuousNearestX2Px = 2*min(distance1,distance2);
geometry = struct('ArcA',arc1,'ArcB',arc2,'Cuts',cuts,'Vertices',vertices, ...
    'RequestedSpacingPx',spacing,'ActualSpacingPx',arcLengths./ceil(arcLengths/spacing), ...
    'Metric','True Euclidean distance to continuous polygon segments', ...
    'Assignment','Nearest centerline pixel to the connection midpoint; no interpolation of missing values', ...
    'Aggregation','Median per direction per centerline pixel; directions remain separate', ...
    'SplitRiskRule','Either connection endpoint is within one measured width of an arc end, measured along its boundary');

    function xy = interpolate(s)
        xy = interp1(cumulative,closed,mod(s,perimeter),'linear');
    end
end

function [distance,foot,arcPosition] = nearestSegment(points,polyline)
a = polyline(1:end-1,:); edge = diff(polyline); squared = sum(edge.^2,2);
assert(all(squared>0)); lengths = sqrt(squared); prefix = [0;cumsum(lengths)];
distance = zeros(size(points,1),1); foot = zeros(size(points)); arcPosition = distance;
for j = 1:size(points,1)
    t = sum((points(j,:)-a).*edge,2)./squared;
    t = max(0,min(1,t)); projections = a+t.*edge;
    [minimum,which] = min(sum((projections-points(j,:)).^2,2));
    distance(j) = sqrt(minimum); foot(j,:) = projections(which,:);
    arcPosition(j) = prefix(which)+t(which)*lengths(which);
end
end
