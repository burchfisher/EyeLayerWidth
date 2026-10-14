function test_layerwidth_reference_widths
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
for file = {'layerwidth_reference_widths.m','layerwidth_bins.m','layerwidth_workspace.m','EyeLayerWidth_GUI.m'}
    issues = checkcode(fullfile(root,file{1}),'-id');
    for k = 1:numel(issues), fprintf('%s:%d %s\n',file{1},issues(k).line,issues(k).message); end
end
polygon = [10 10;110 10;110 30;10 30];
line = makeLine((30:10:90)',20*ones(7,1),90*ones(7,1));
mask = poly2mask(polygon(:,1),polygon(:,2),64,128); before = rng;
[points,metadata] = layerwidth_reference_widths(polygon,mask,line);
assert(all(abs(points.AngleWidthPx-20)<1e-9));
distance = bwdist(~padarray(mask,[1 1],false),'quasi-euclidean');
assert(isequal(points.DistanceWidthPx,2*double(distance(sub2ind(size(distance),line.y+1,line.x+1)))));
assert(strcmp(metadata.DistanceMetric,'quasi-euclidean') && isequal(before,rng));
wiggly = line; wiggly.y(2:6) = [18;22;19;21;20];
changed = layerwidth_reference_widths(polygon,mask,wiggly);
assert(max(abs(changed.AngleWidthPx-20))<1e-9);
assert(isequal(changed.DirectionX,points.DirectionX) && isequal(changed.DirectionY,points.DirectionY));
assert(any(changed.DistanceWidthPx~=points.DistanceWidthPx));

% A 45-degree rotation must change the image direction, not the width.
polygon = [20 30;100 110;110 100;30 20];
line = makeLine((35:10:95)',(35:10:95)',90*ones(7,1));
points = layerwidth_reference_widths(polygon,poly2mask(polygon(:,1),polygon(:,2),128,128),line);
assert(max(abs(points.AngleWidthPx-10*sqrt(2)))<1e-8);
assert(max(abs(abs(points.DirectionX)-sqrt(0.5)))<1e-10);

% A cross-section through a concave polygon may meet a second, distant arm.
polygon = [10 10;50 10;50 50;40 50;40 20;20 20;20 50;10 50];
line = makeLine([15;15;15],[25;30;35],[90;90;90]);
points = layerwidth_reference_widths(polygon,poly2mask(polygon(:,1),polygon(:,2),64,64),line);
assert(all(points.MultipleSegments) && all(points.ValidPair));
assert(max(abs(points.AngleWidthPx-10))<1e-9);
line.x(2) = 5;
outside = layerwidth_reference_widths(polygon,poly2mask(polygon(:,1),polygon(:,2),64,64),line);
assert(~outside.ValidPair(2) && isnan(outside.AngleWidthPx(2)) && isnan(outside.DistanceWidthPx(2)));

% Semicircular ribbon: the stored angular frame fixes a radial direction.
theta = linspace(0,180,1001)'; outer = [100+60*sind(theta),100+60*cosd(theta)];
inner = [100+40*sind(flipud(theta)),100+40*cosd(flipud(theta))];
polygon = [outer;inner]; theta = (0:10:180)';
line = makeLine(round(100+50*sind(theta)),round(100+50*cosd(theta)),180-theta);
points = layerwidth_reference_widths(polygon,poly2mask(polygon(:,1),polygon(:,2),200,200),line);
valid = points.ValidPair & ~points.EndpointRisk;
assert(nnz(valid)>10 && max(abs(points.AngleWidthPx(valid)-20))<0.02);
assert(points.EndpointRisk(1) && points.EndpointRisk(end));
bins = layerwidth_bins(points,10,true);
assert(sum(bins.Points)==nnz(valid));

polygon = [0 0;64 0;64 64;0 64]; line = makeLine([20;30;40],[32;32;32],[90;90;90]);
points = layerwidth_reference_widths(polygon,true(64),line);
assert(all(isfinite(points.DistanceWidthPx)) && all(points.AngleWidthPx==64));
mustFail(@() layerwidth_reference_widths([10 10;30 30;30 10;10 30],true(64),line));
mustFail(@() layerwidth_reference_widths(polygon,false(64),line));
disp('Width geometry: fixed angles, rotated strip, curved strip, disconnected sections, invalid points, endpoints, and padding passed.');
end

function result = makeLine(x,y,angle)
distance = [0;cumsum(hypot(diff(x),diff(y)))];
result = table(x,y,distance,angle);
end

function mustFail(callback)
try, callback(); catch problem, assert(strcmp(problem.identifier,'EyeLayerWidth:Widths')); return; end
error('Expected invalid geometry to fail.');
end
