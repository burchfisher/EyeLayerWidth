function [result,geometry] = two_sided_widths(polygon,mask,centerline)
% Experimental two-arc distance estimator, using the production raster convention.
[base,~] = layerwidth_reference_widths(polygon,mask,centerline);
shape = simplify(polyshape(polygon,'Simplify',false));
v = shape.Vertices; edge = circshift(v,-1,1)-v;
lengths = vecnorm(edge,2,2); cumulative = [0;cumsum(lengths)]; perimeter = cumulative(end);
[~,first] = min(centerline.distance); [~,last] = max(centerline.distance);
[~,cuts] = project([base.X([first last]),base.Y([first last])]);
cuts = sort(cuts); assert(diff(cuts)>1e-6 && perimeter-diff(cuts)>1e-6, ...
    'EyeLayerWidth:TwoSides','Endpoint projections do not separate the polygon into two arcs.');
% Every nearest background pixel lies on this exterior 8-neighbor ring.
padded = padarray(logical(mask),[1 1],false);
ring = imdilate(padded,ones(3)) & ~padded;
[ry,rx] = find(ring); ringIndex = find(ring);
[feet,arc] = project([rx-1,ry-1]);
side1 = arc>=cuts(1) & arc<cuts(2);
seed1 = false(size(padded)); seed1(ringIndex(side1)) = true;
seed2 = ring & ~seed1;
assert(any(seed1,'all') && any(seed2,'all'));
[d1,i1] = bwdist(seed1,'quasi-euclidean');
[d2,i2] = bwdist(seed2,'quasi-euclidean');
sample = sub2ind(size(padded),base.Y+1,base.X+1);
d1 = double(d1(sample)); d2 = double(d2(sample));
i1 = double(i1(sample)); i2 = double(i2(sample));
[y1,x1] = ind2sub(size(padded),i1); [y2,x2] = ind2sub(size(padded),i2);
x1 = x1-1; y1 = y1-1; x2 = x2-1; y2 = y2-1;
lookup = zeros(size(padded)); lookup(ringIndex) = 1:numel(ringIndex);
r1 = lookup(i1); r2 = lookup(i2);
assert(all(r1>0 & r2>0));
onMask = base.InsideMask;
assert(max(abs(2*min(d1(onMask),d2(onMask))-base.DistanceWidthPx(onMask)))<1e-4, ...
    'EyeLayerWidth:TwoSides','The two seed maps do not reproduce the original nearest-background distance.');
foot1 = feet(r1,:); foot2 = feet(r2,:);
cap1 = cutDistance(arc(r1)); cap2 = cutDistance(arc(r2));
splitRisk = cap1<=d1 | cap2<=d2;
outside = false(height(base),1);
for k = 1:height(base)
    if ~base.InsidePolygon(k) || base.AtPolygonBoundary(k), outside(k) = true; continue; end
    point = [base.X(k),base.Y(k)];
    outside(k) = ~visible(point,foot1(k,:)) || ~visible(point,foot2(k,:));
end
leg1 = [x1-base.X,y1-base.Y]; leg2 = [x2-base.X,y2-base.Y];
cosine = sum(leg1.*leg2,2)./(vecnorm(leg1,2,2).*vecnorm(leg2,2,2));
legAngle = acosd(max(-1,min(1,cosine)));
width = d1+d2; width(~onMask) = NaN;
result = table(d1,d2,width,width-base.DistanceWidthPx,x1,y1,x2,y2, ...
    foot1(:,1),foot1(:,2),foot2(:,1),foot2(:,2),legAngle,splitRisk,outside, ...
    'VariableNames',{'Side1DistancePx','Side2DistancePx','TwoSidedWidthPx','AddedWidthPx', ...
    'Side1X','Side1Y','Side2X','Side2Y','Side1FootX','Side1FootY','Side2FootX','Side2FootY', ...
    'LegAngleDegrees','SplitRisk','OutsideShortcut'});
geometry = struct('Vertices',v,'Cuts',cuts,'Perimeter',perimeter, ...
    'RingXY',[rx-1,ry-1],'RingSide1',side1,'SplitXY',projectAt(cuts), ...
    'Method','Sum of quasi-Euclidean distances to two disjoint exterior-background boundary arcs', ...
    'SplitRule','Nearest continuous-boundary projections of the two centerline endpoints', ...
    'SplitRiskRule','Nearest seed projection is within its side distance of either cut along the boundary', ...
    'OutsideShortcutRule','Straight connection to seed boundary projection is not entirely inside the polygon');

    function [foot,s] = project(points)
        foot = zeros(size(points)); s = zeros(size(points,1),1);
        for n = 1:size(points,1)
            t = sum((points(n,:)-v).*edge,2)./(lengths.^2);
            t = max(0,min(1,t)); projections = v+t.*edge;
            [~,which] = min(sum((projections-points(n,:)).^2,2));
            foot(n,:) = projections(which,:);
            s(n) = mod(cumulative(which)+t(which)*lengths(which),perimeter);
        end
    end

    function xy = projectAt(s)
        xy = zeros(numel(s),2);
        for n = 1:numel(s)
            which = find(cumulative(1:end-1)<=s(n),1,'last');
            xy(n,:) = v(which,:)+(s(n)-cumulative(which))/lengths(which)*edge(which,:);
        end
    end

    function d = cutDistance(s)
        delta = abs(s-cuts'); d = min(min(delta,perimeter-delta),[],2);
    end

    function yes = visible(a,b)
        total = norm(b-a);
        if total<1e-8, yes = true; return; end
        segments = intersect(shape,[a;b]);
        steps = diff(segments,1,1); good = all(isfinite(steps),2);
        insideLength = sum(vecnorm(steps(good,:),2,2));
        yes = abs(total-insideLength)<1e-6*max(1,total);
    end
end
