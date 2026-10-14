function test_boundary_euclidean_widths
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root,fullfile(root,'comparison_preview'));
polygon = [10 20;110 20;110 40;10 40]; mask = poly2mask(polygon(:,1),polygon(:,2),60,120);
x = (12:108)'; y = repmat(26,size(x)); distance = x-x(1); angle = zeros(size(x));
c = table(x,y,distance,angle); initial = rng;
[s,m,g] = boundary_euclidean_widths(polygon,mask,c);
assert(all(abs(s.WidthPx(s.Included)-20)<1e-10));
assert(all(abs(sqrt((s.SourceX-s.TargetX).^2+(s.SourceY-s.TargetY).^2)-s.WidthPx)<1e-10));
assert(all(s.MidX==(s.SourceX+s.TargetX)/2 & s.MidY==(s.SourceY+s.TargetY)/2));
assert(all(g.ActualSpacingPx<=1));
assert(sum(m.CountA+m.CountB)==nnz(s.Included));
assert(all(isnan(m.BoundaryAtoBPx(m.CountA==0))));
c.y(:) = 33; shifted = boundary_euclidean_widths(polygon,mask,c);
assert(all(abs(shifted.WidthPx(shifted.Included)-20)<1e-10));
reversed = boundary_euclidean_widths(flipud(polygon),mask,c);
assert(all(abs(reversed.WidthPx(reversed.Included)-20)<1e-10));
fprintf('Continuous-edge strip tests passed: exactly 20 px, independent of centerline offset; midpoint joins, counts, and gaps verified.\n');

% Rotate a 20-pixel strip to distinguish continuous Euclidean geometry from raster distance.
R = [cosd(27) -sind(27);sind(27) cosd(27)];
polygon = ([0 -10;100 -10;100 10;0 10]*R')+[40 40];
mask = poly2mask(polygon(:,1),polygon(:,2),140,160);
xy = round([(2:98)',repmat(-3,97,1)]*R'+[40 40]); xy = unique(xy,'rows','stable');
x = xy(:,1); y = xy(:,2); distance = [0;cumsum(vecnorm(diff(xy),2,2))]; angle = zeros(size(x));
c = table(x,y,distance,angle); rotated = boundary_euclidean_widths(polygon,mask,c);
assert(any(rotated.Included) && all(abs(rotated.WidthPx(rotated.Included)-20)<1e-9));
fprintf('Rotated strip passed: exactly 20 px with non-axis-aligned continuous boundaries.\n');

theta = linspace(0,pi,361)';
polygon = [100+80*sin(theta),100-80*cos(theta);flipud([100+60*sin(theta),100-60*cos(theta)])];
mask = poly2mask(polygon(:,1),polygon(:,2),200,200);
xy = unique(round([100+65*sin(theta),100-65*cos(theta)]),'rows','stable');
x = xy(:,1); y = xy(:,2); distance = [0;cumsum(vecnorm(diff(xy),2,2))];
angle = linspace(0,180,numel(x))'; c = table(x,y,distance,angle);
curved = boundary_euclidean_widths(polygon,mask,c);
assert(all(abs(curved.WidthPx(curved.Included)-20)<.01));
assert(~any(curved.OutsideShortcut));
assert(isequal(initial,rng));
fprintf('Curved 20-pixel ribbon passed within 0.01 px polygon-discretization tolerance; RNG unchanged.\n');
end
