function compare_boundary_euclidean
% Inspect continuous boundary-to-boundary widths and their spatial joins.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
out = fileparts(mfilename('fullpath')); addpath(out);
names = {'DMSO_4dpi','IWR1_4dpi','DMSO_9dpf','IWR1_9dpf'};
allSamples = table; allMapped = table; summary = table; eyes = struct([]); initialRng = rng;
timer = tic;
for g = 1:numel(names)
    loaded = load(fullfile(root,'examples',[names{g} '.mat'])); data = loaded.(names{g});
    for k = 1:numel(data.IMGname)
        e = numel(eyes)+1;
        [s,m,geometry] = boundary_euclidean_widths(data.ROIxy{k},logical(data.ROIBW{k}),data.CLine{k},1);
        s.EyeID = repmat(e,height(s),1); m.EyeID = repmat(e,height(m),1);
        m.Interior = m.ValidPair & ~m.EndpointRisk;
        m.BothDirections = m.Interior & m.CountA>0 & m.CountB>0;
        m.AnyDirection = m.Interior & (m.CountA>0 | m.CountB>0);
        m.DirectionDifferencePx = m.BoundaryAtoBPx-m.BoundaryBtoAPx;
        both = m.BothDirections;
        row = table(e,string(names{g}),string(data.IMGname{k}),height(s),nnz(s.Included), ...
            nnz(s.SplitRisk),nnz(s.OutsideShortcut),nnz(m.Interior),nnz(m.AnyDirection),nnz(both), ...
            median(abs(m.DirectionDifferencePx(both))),prctile(abs(m.DirectionDifferencePx(both)),95), ...
            median(m.BoundaryAtoBPx(both)-m.DistanceWidthPx(both)), ...
            median(m.BoundaryBtoAPx(both)-m.DistanceWidthPx(both)), ...
            'VariableNames',{'EyeID','Group','Eye','Samples','IncludedSamples','SplitRiskSamples','ShortcutSamples', ...
            'InteriorPoints','AnyDirectionPoints','BothDirectionPoints','MedianDirectionDifferencePx','P95DirectionDifferencePx', ...
            'MedianAminusOriginalPx','MedianBminusOriginalPx'});
        summary = [summary;row]; allSamples = [allSamples;s]; allMapped = [allMapped;m]; %#ok<AGROW>
        eyes(e).Image = data.IMG{k}; eyes(e).Samples = s; eyes(e).Mapped = m;
        eyes(e).Geometry = geometry; eyes(e).Group = names{g};
    end
    fprintf('Measured %s; %d eyes, %.1f seconds.\n',names{g},numel(eyes),toc(timer));
end
assert(numel(eyes)==44 && isequal(initialRng,rng));
s = allSamples; m = allMapped; both = m.BothDirections;
fprintf('\nBoundary samples: total %d, included %d, split-near %d, outside-ROI %d (flags can overlap).\n', ...
    height(s),nnz(s.Included),nnz(s.SplitRisk),nnz(s.OutsideShortcut));
fprintf('Interior centerline coverage: any direction %d/%d (%.2f%%), both %d (%.2f%%).\n', ...
    nnz(m.AnyDirection),nnz(m.Interior),100*nnz(m.AnyDirection)/nnz(m.Interior),nnz(both),100*nnz(both)/nnz(m.Interior));
fprintf('Mapped directional absolute differences, percentiles [50 90 95 99 max]: ');
fprintf(' %.3f',prctile(abs(m.DirectionDifferencePx(both)),[50 90 95 99 100])); fprintf('\n');
fprintf('Across-eye median of median absolute directional difference %.3f px.\n',median(summary.MedianDirectionDifferencePx));
fprintf('Paired-centerline median A/B minus original quasi distance x2: %.3f / %.3f px.\n', ...
    median(m.BoundaryAtoBPx(both)-m.DistanceWidthPx(both)),median(m.BoundaryBtoAPx(both)-m.DistanceWidthPx(both)));
fprintf('Included segment width percentiles [1 50 99 max]: '); fprintf(' %.3f',prctile(s.WidthPx(s.Included),[1 50 99 100])); fprintf('\n');

% Previous difficult locations, plus the greatest directional mismatch.
old = load(fullfile(out,'width_disagreement_audit.mat'),'selected');
selected = table;
for j = 1:4
    q = old.selected(j,:); candidates = m(m.EyeID==q.EyeID & both,:);
    [~,index] = min(hypot(candidates.X-q.X,candidates.Y-q.Y));
    selected = [selected;candidates(index,:)]; %#ok<AGROW>
end
candidates = m(both,:); [~,index] = max(abs(candidates.DirectionDifferencePx)); selected = [selected;candidates(index,:)];
candidates = s(s.Included,:); [~,index] = max(candidates.JoinDistancePx); farthestJoin = candidates(index,:);
selectedSegments = table;
for j = 1:height(selected)
    q = selected(j,:);
    for side = 1:2
        candidates = s(s.EyeID==q.EyeID & s.CenterlinePoint==q.Point & s.SourceSide==side & s.Included,:);
        [~,index] = min(abs(candidates.WidthPx-median(candidates.WidthPx)));
        row = candidates(index,:); row.Example = j; selectedSegments = [selectedSegments;row]; %#ok<AGROW>
    end
end
disp(selected(:,{'EyeID','Point','Angle','DistanceWidthPx','BoundaryAtoBPx','BoundaryBtoAPx','ContinuousTwoSidePx','CountA','CountB'}));
fprintf('Largest accepted midpoint-to-centerline join: %.3f px, eye %d, angle %.1f.\n', ...
    farthestJoin.JoinDistancePx,farthestJoin.EyeID,farthestJoin.Angle);
geometries = {eyes.Geometry};
save(fullfile(out,'boundary_euclidean_comparison.mat'),'allSamples','allMapped','summary','selected','selectedSegments','geometries');

fig = figure('Visible','off','Color','w','Position',[100 100 1450 920]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,2,'TileSpacing','compact');
ax = nexttile(tiles); hold(ax,'on');
plot(ax,summary.EyeID,summary.MedianDirectionDifferencePx,'o-','Color',[.05 .45 .65]);
plot(ax,summary.EyeID,summary.P95DirectionDifferencePx,'s-','Color',[.7 .15 .5]);
xlabel(ax,'Eye'); ylabel(ax,'Absolute A-to-B minus B-to-A difference (px)');
title(ax,'Paired centerline pixels: directional disagreement'); legend(ax,{'Median','95th percentile'},'Location','best'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on');
plot(ax,summary.EyeID,100*summary.AnyDirectionPoints./summary.InteriorPoints,'o-','Color',[.05 .45 .65]);
plot(ax,summary.EyeID,100*summary.BothDirectionPoints./summary.InteriorPoints,'s-','Color',[.7 .15 .5]);
ylim(ax,[0 100]); xlabel(ax,'Eye'); ylabel(ax,'Interior centerline pixels covered (%)');
title(ax,'One-pixel boundary sampling; no gap filling'); legend(ax,{'At least one direction','Both directions'},'Location','best'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on'); q = eyes(36).Mapped;
plot(ax,q.Angle,q.DistanceWidthPx,'.','Color',[.6 .6 .6],'MarkerSize',3);
plot(ax,q.Angle,q.BoundaryAtoBPx,'.','Color',[.05 .45 .65],'MarkerSize',5);
plot(ax,q.Angle,q.BoundaryBtoAPx,'.','Color',[.7 .15 .5],'MarkerSize',5);
xlim(ax,[0 180]); xlabel(ax,'Angle (degrees)'); ylabel(ax,'Width at assigned centerline pixel (px)');
title(ax,'Eye 36: unsmoothed spatially joined widths');
legend(ax,{'Original quasi distance x 2','A to B: true Euclidean','B to A: true Euclidean'},'Location','best'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on'); q = selected(end,:); eye = eyes(q.EyeID); drawImage(ax,eye);
drawPair(ax,selectedSegments(selectedSegments.Example==height(selected),:),eye.Mapped);
xlim(ax,q.X+[-40 40]); ylim(ax,q.Y+[-40 40]);
title(ax,{sprintf('Largest directional disagreement: eye %d, %.1f deg',q.EyeID,q.Angle); ...
    sprintf('A to B %.1f px | B to A %.1f px',q.BoundaryAtoBPx,q.BoundaryBtoAPx)},'FontSize',11);
title(tiles,'True Euclidean boundary-to-boundary widths | experimental','FontSize',16);
xlabel(tiles,{'Directions are kept separate. Medians are taken only where multiple accepted segments join to the same centerline pixel.'; ...
    'Polygon-edge measurements and the original background-pixel/quasi method differ in both geometry and distance convention.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'boundary_euclidean_summary.png'),'Resolution',150); clear cleanup;

fig = figure('Visible','off','Color','w','Position',[100 100 1250 1000]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,2,'TileSpacing','compact');
for j = 1:4
    q = selected(j,:); eye = eyes(q.EyeID); ax = nexttile(tiles); drawImage(ax,eye);
    rows = selectedSegments(selectedSegments.Example==j,:); drawPair(ax,rows,eye.Mapped);
    half = max(35,ceil(max(abs([rows.SourceX-q.X;rows.TargetX-q.X;rows.SourceY-q.Y;rows.TargetY-q.Y]))+10));
    xlim(ax,q.X+[-half half]); ylim(ax,q.Y+[-half half]);
    title(ax,{sprintf('Eye %d | %.1f deg | nearest covered point to prior example',q.EyeID,q.Angle); ...
        sprintf('A to B %.1f | B to A %.1f | original %.1f px',q.BoundaryAtoBPx,q.BoundaryBtoAPx,q.DistanceWidthPx)}, ...
        'FontSize',11,'FontWeight','normal');
    sx = q.X-half+5; sy = q.Y+half-7; plot(ax,sx+[0 10],[sy sy],'k-','LineWidth',2);
    text(ax,sx+5,sy-3,'10 px','HorizontalAlignment','center','FontSize',8,'BackgroundColor','w');
end
title(tiles,'Boundary connections and midpoint-to-centerline joins','FontSize',16);
xlabel(tiles,{'Cyan: boundary A to B. Magenta: B to A. Arrows start at circles. Squares: midpoints. White dashed: joins to centerline dots.'; ...
    'Dark purple: ROI. Green: centerline. One representative connection per direction; reported widths are per-pixel medians.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'boundary_euclidean_closeups.png'),'Resolution',160);
fprintf('Finished example audit in %.1f seconds.\n',toc(timer));
end

function drawImage(ax,eye)
img = eye.Image; if ismatrix(img), img = repmat(double(img)/255,1,1,3); end
imagesc(ax,img); hold(ax,'on'); axis(ax,'image'); set(ax,'YDir','reverse');
v = eye.Geometry.Vertices; xy = [v;v(1,:)];
plot(ax,xy(:,1),xy(:,2),'-','Color',[.45 .2 .45],'LineWidth',1.1);
plot(ax,eye.Mapped.X,eye.Mapped.Y,'-','Color',[.1 .65 .45],'LineWidth',1.1);
ax.XTick = []; ax.YTick = []; ax.Box = 'on';
end

function drawPair(ax,rows,mapped)
colors = [.05 .55 .75;.8 .1 .5];
for k = 1:height(rows)
    r = rows(k,:); c = colors(r.SourceSide,:); point = mapped(r.CenterlinePoint,:);
    quiver(ax,r.SourceX,r.SourceY,r.TargetX-r.SourceX,r.TargetY-r.SourceY,0, ...
        'Color',c,'LineWidth',2,'MaxHeadSize',.3);
    plot(ax,r.SourceX,r.SourceY,'o','Color',c,'MarkerFaceColor',c,'MarkerSize',4);
    plot(ax,r.MidX,r.MidY,'s','Color',c,'MarkerFaceColor',c,'MarkerSize',5);
    plot(ax,[r.MidX point.X],[r.MidY point.Y],'w--','LineWidth',1.5);
    plot(ax,point.X,point.Y,'wo','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',5);
end
end
