function test_two_sided_widths
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root,fullfile(root,'comparison_preview'));
polygon = [10 20;110 20;110 40;10 40]; mask = poly2mask(polygon(:,1),polygon(:,2),60,120);
x = (12:108)'; y = repmat(26,size(x)); distance = x-x(1); angle = zeros(size(x));
c = table(x,y,distance,angle); original = rng;
[a,g] = two_sided_widths(polygon,mask,c);
middle = x>=40 & x<=80;
% poly2mask's inclusion convention determines the two exterior seed rows.
top = find(mask(:,60),1,'first')-1; bottom = find(mask(:,60),1,'last')+1;
expected = bottom-top;
assert(all(abs(a.TwoSidedWidthPx(middle)-expected)<1e-5));
assert(all(a.AddedWidthPx(middle)>0));
assert(~any(a.SplitRisk(middle) | a.OutsideShortcut(middle)));
assert(all(a.LegAngleDegrees(middle)==180));
c.y(:) = 33; b = two_sided_widths(polygon,mask,c);
assert(max(abs(a.TwoSidedWidthPx(middle)-b.TwoSidedWidthPx(middle)))<1e-5);
c.y(:) = 26; reverse = two_sided_widths(flipud(polygon),mask,c);
assert(max(abs(a.TwoSidedWidthPx(middle)-reverse.TwoSidedWidthPx(middle)))<1e-5);
assert(any(a.SplitRisk));
assert(isequal(rng,original) && numel(g.Cuts)==2);
fprintf('Two-sided rectangle tests passed: known raster width %.1f px, off-center invariance, reversed polygon, end flags, and RNG.\n',expected);
theta = linspace(0,pi,181)';
polygon = [100+80*sin(theta),100-80*cos(theta); ...
    flipud([100+60*sin(theta),100-60*cos(theta)])];
mask = poly2mask(polygon(:,1),polygon(:,2),200,200);
xy = unique(round([100+65*sin(theta),100-65*cos(theta)]),'rows','stable');
x = xy(:,1); y = xy(:,2); distance = [0;cumsum(vecnorm(diff(xy),2,2))];
angle = linspace(0,180,numel(x))'; c = table(x,y,distance,angle);
[curved,g] = two_sided_widths(polygon,mask,c);
interior = distance>25 & distance<max(distance)-25;
assert(all(curved.TwoSidedWidthPx(interior)>18 & curved.TwoSidedWidthPx(interior)<25));
assert(~any(curved.OutsideShortcut(interior)));
for index = round(linspace(20,height(c)-20,5))
    delta = abs(g.RingXY-[x(index),y(index)]);
    direct = max(delta,[],2)+(sqrt(2)-1)*min(delta,[],2);
    expected = min(direct(g.RingSide1))+min(direct(~g.RingSide1));
    assert(abs(expected-curved.TwoSidedWidthPx(index))<1e-4);
end
fprintf('Curved 20-pixel ribbon passed: bounded raster/quasi widths and independent brute-force side distances.\n');
end
