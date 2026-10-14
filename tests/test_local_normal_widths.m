function test_local_normal_widths
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root,fullfile(root,'comparison_preview'));
initialRng = rng;
polygon = [10 20;110 20;110 40;10 40]; mask = poly2mask(polygon(:,1),polygon(:,2),60,120);
c = makeLine((12:108)',repmat(26,97,1));
[p,meta] = local_normal_widths(polygon,mask,c,50);
assert(all(p.Valid) && max(abs(p.Width-20))<1e-9);
assert(p.BeforeLength(1)==0 && p.AfterLength(1)==25);
assert(p.BeforeLength(end)==25 && p.AfterLength(end)==0);
assert(all(p.BeforeLength(~p.WindowTruncated)==25 & p.AfterLength(~p.WindowTruncated)==25));
assert(sum(p.WindowTruncated)==50 && all(abs(p.NormalX)<1e-12));
assert(strcmp(meta.Units,'pixel-distance'));
c.y(:) = 33; shifted = local_normal_widths(polygon,mask,c,50);
assert(max(abs(shifted.Width-p.Width))<1e-9);
c = makeLine([12;13;19;41;76;100;108],repmat(26,7,1));
sparse = local_normal_widths(polygon,mask,c,50);
assert(max(abs(sparse.Width-20))<1e-9);
[physical,meta] = local_normal_widths(polygon,mask,c,50,'PixelSize',[2 3],'Units','um');
assert(max(abs(physical.Width-60))<1e-9 && strcmp(meta.Units,'um'));
assert(physical.BeforeLength(1)==0 && physical.AfterLength(1)==25);

polygon = [20 30;100 110;110 100;30 20]; mask = poly2mask(polygon(:,1),polygon(:,2),128,128);
c = makeLine((35:95)',(35:95)'); p = local_normal_widths(polygon,mask,c,50);
assert(max(abs(p.Width-10*sqrt(2)))<1e-8);
assert(max(abs(diff(p.PathDistance)-sqrt(2)))<1e-10);
assert(p.AfterLength(1)==25 && max(abs(p.NormalX+sqrt(.5)))<1e-10);

polygon = [10 10;50 10;50 50;40 50;40 20;20 20;20 50;10 50];
mask = poly2mask(polygon(:,1),polygon(:,2),64,64);
c = makeLine(repmat(15,21,1),(25:45)'); p = local_normal_widths(polygon,mask,c,50);
assert(all(p.MultipleSegments & p.Valid) && max(abs(p.Width-10))<1e-9);
c.x(:) = 5; outside = local_normal_widths(polygon,mask,c,50); assert(~any(outside.Valid));

theta = linspace(0,pi,361)';
polygon = [100+80*sin(theta),100-80*cos(theta);flipud([100+60*sin(theta),100-60*cos(theta)])];
mask = poly2mask(polygon(:,1),polygon(:,2),200,200);
xy = unique(round([100+65*sin(theta),100-65*cos(theta)]),'rows','stable');
c = makeLine(xy(:,1),xy(:,2)); p = local_normal_widths(polygon,mask,c,50);
interior = p.Valid & ~p.WindowTruncated;
assert(nnz(interior)>50 && max(abs(p.Width(interior)-20))<.2);
assert(all(abs(p.BeforeLength(p.PathDistance<25)-p.PathDistance(p.PathDistance<25))<1e-10));
assert(max(abs(sum([p.TangentX p.TangentY].*[p.NormalX p.NormalY],2)))<1e-12);
lengths = hypot(p.SectionX2-p.SectionX1,p.SectionY2-p.SectionY1);
assert(max(abs(lengths(p.Valid)-p.Width(p.Valid)))<1e-9);
reordered = c(end:-1:1,:); back = local_normal_widths(polygon,mask,reordered,50);
assert(isequaln(back.Width(end:-1:1),p.Width));
assert(isequal(initialRng,rng));
fprintf('Local-normal tests passed: known widths, arc-length weighting, diagonal steps, centered/clipped tips, calibration, concavity, curvature, row ordering, and RNG.\n');
end

function c = makeLine(x,y)
distance = [0;cumsum(hypot(diff(x),diff(y)))]; angle = linspace(0,180,numel(x))';
c = table(x,y,distance,angle);
end
