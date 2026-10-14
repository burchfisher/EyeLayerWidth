function [measurements,metadata] = layerwidth_reference_widths(polygon,mask,centerline)
% Compare ChanGeom-style radii with cross-sections fixed by RpEGEN's angle.
validateattributes(polygon,{'numeric'},{'2d','ncols',2,'finite','real'});
validateattributes(mask,{'logical'},{'2d','nonempty'});
required = {'x','y','distance','angle'};
assert(istable(centerline) && all(ismember(required,centerline.Properties.VariableNames)), ...
    'EyeLayerWidth:Widths','Centerline requires x, y, distance, and angle columns.');
for field = required
    validateattributes(centerline.(field{1}),{'numeric'},{'column','finite','real','nonempty'});
end
xy = double(polygon);
xy = xy([true;any(diff(xy,1,1)~=0,2)],:);
if size(xy,1)>1 && isequal(xy(1,:),xy(end,:)), xy(end,:) = []; end
assert(size(xy,1)>=3,'EyeLayerWidth:Widths','ROI needs at least three distinct vertices.');
shape = polyshape(xy,'Simplify',false);
polygonCleaned = ~issimplified(shape);
if polygonCleaned, shape = simplify(shape); end
assert(issimplified(shape) && area(shape)>0 && shape.NumRegions==1 && shape.NumHoles==0, ...
    'EyeLayerWidth:Widths','ROI must describe one connected region without holes. Review its geometry.');
[rows,cols] = size(mask);
assert(isequal(mask,poly2mask(xy(:,1),xy(:,2),rows,cols)), ...
    'EyeLayerWidth:Widths','The saved mask does not match the polygon.');
boundary = shape.Vertices;
assert(isequal(mask,poly2mask(boundary(:,1),boundary(:,2),rows,cols)), ...
    'EyeLayerWidth:Widths','Polygon cleanup changes the tissue mask. Review the ROI before measuring widths.');
x = double(centerline.x); y = double(centerline.y); n = numel(x);
assert(all(x==round(x) & y==round(y) & x>=1 & x<=cols & y>=1 & y<=rows), ...
    'EyeLayerWidth:Widths','Width sampling requires centerline pixels inside the image.');
angle = double(centerline.angle);
assert(all(angle>=0 & angle<=180),'EyeLayerWidth:Widths','Angles must be between 0 and 180 degrees.');
distance = double(centerline.distance);
[firstDistance,first] = min(distance); [lastDistance,last] = max(distance);
assert(lastDistance>firstDistance && (x(first)~=x(last) || y(first)~=y(last)), ...
    'EyeLayerWidth:Widths','The centerline must have distinct endpoints.');
% Invert the existing reflected angle, including its rounded tilt correction.
tilt = round(atan2d(x(first)-x(last),y(first)-y(last)),1);
direction = [sind(tilt-angle),cosd(tilt-angle)];
insideMask = mask(sub2ind(size(mask),y,x));
[insidePolygon,onBoundary] = inpolygon(x,y,boundary(:,1),boundary(:,2));
% Padding supplies background even when the ROI touches the image border.
radiusMap = bwdist(~padarray(mask,[1 1],false),'quasi-euclidean');
radius = double(radiusMap(sub2ind(size(radiusMap),y+1,x+1)));
radius(~insideMask) = NaN;
angleWidth = nan(n,1); minusRadius = angleWidth; plusRadius = angleWidth;
ends = nan(n,4); multiple = false(n,1); ambiguous = false(n,1);
reach = 2*hypot(rows,cols); tolerance = 1e-8*max(rows,cols);
for k = 1:n
    if ~insidePolygon(k) || onBoundary(k), continue; end
    point = [x(k),y(k)]; vector = direction(k,:);
    segments = intersect(shape,[point-reach*vector;point+reach*vector]);
    if isempty(segments), ambiguous(k) = true; continue; end
    finite = all(isfinite(segments),2);
    starts = find(finite & [true;~finite(1:end-1)]);
    stops = find(finite & [~finite(2:end);true]);
    multiple(k) = numel(starts)>1;
    containing = zeros(0,2);
    for j = 1:numel(starts)
        span = (segments([starts(j),stops(j)],:)-point)*vector';
        span = sort(span);
        if span(1)<-tolerance && span(2)>tolerance
            containing(end+1,:) = span'; %#ok<AGROW>
        end
    end
    if size(containing,1)~=1
        ambiguous(k) = true; continue;
    end
    minusRadius(k) = -containing(1); plusRadius(k) = containing(2);
    angleWidth(k) = sum([minusRadius(k),plusRadius(k)]);
    ends(k,:) = [point+containing(1)*vector,point+containing(2)*vector];
end
distanceWidth = 2*radius;
endDistance = min(distance-firstDistance,lastDistance-distance);
endpointRisk = endDistance<=max(radius,0) | endDistance==0;
valid = insideMask & insidePolygon & ~onBoundary & ~ambiguous & isfinite(angleWidth);
measurements = table((1:n)',angle,x,y,distanceWidth,angleWidth,angleWidth-distanceWidth, ...
    minusRadius,plusRadius,ends(:,1),ends(:,2),ends(:,3),ends(:,4),direction(:,1),direction(:,2), ...
    insideMask,insidePolygon,onBoundary,multiple,ambiguous,endpointRisk,valid, ...
    'VariableNames',{'Point','Angle','X','Y','DistanceWidthPx','AngleWidthPx','DifferencePx', ...
    'MinusRadiusPx','PlusRadiusPx','SectionX1','SectionY1','SectionX2','SectionY2','DirectionX','DirectionY', ...
    'InsideMask','InsidePolygon','AtPolygonBoundary','MultipleSegments','AmbiguousSection','EndpointRisk','ValidPair'});
measurements.PolygonCleaned = repmat(polygonCleaned,n,1);
metadata = struct('DistanceMetric','quasi-euclidean','Units','pixels', ...
    'PolygonCleaned',polygonCleaned,'CleanupChangedMask',false, ...
    'TiltDegrees',tilt,'OriginXY',([x(first),y(first)]+[x(last),y(last)])/2, ...
    'DistanceMethod','Twice distance to nearest background pixel at the existing centerline', ...
    'AngleMethod','Polygon segment containing centerline point; direction [sin(tilt-angle), cos(tilt-angle)]', ...
    'EndpointRule','Distance along centerline to nearest end <= distance-transform radius', ...
    'RasterCaveat','Distance transform uses background pixel centers; cross-sections use continuous polygon edges');
end
