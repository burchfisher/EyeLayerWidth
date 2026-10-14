function assess_width_disagreement
% Descriptive geometry audit; no source data or production methods are changed.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
out = fileparts(mfilename('fullpath'));
names = {'DMSO_4dpi','IWR1_4dpi','DMSO_9dpf','IWR1_9dpf'};
eyes = struct([]); summaries = table; allPoints = table; initialRng = rng;
for g = 1:numel(names)
    loaded = load(fullfile(root,'examples',[names{g} '.mat']));
    data = loaded.(names{g});
    for k = 1:numel(data.IMGname)
        p = layerwidth_reference_widths(data.ROIxy{k},logical(data.ROIBW{k}),data.CLine{k});
        shape = simplify(polyshape(data.ROIxy{k},'Simplify',false));
        vertices = shape.Vertices; a = vertices; b = circshift(vertices,-1,1);
        edge = b-a; edgeSquared = sum(edge.^2,2);
        nearest = nan(height(p),1);
        for j = 1:height(p)
            t = sum(([p.X(j),p.Y(j)]-a).*edge,2)./edgeSquared;
            t = max(0,min(1,t)); foot = a+t.*edge;
            nearest(j) = min(hypot(foot(:,1)-p.X(j),foot(:,2)-p.Y(j)));
        end
        p.ContinuousDistanceWidthPx = 2*nearest;
        % Exact additive decomposition, not independent causal contributions.
        p.SideAsymmetryPx = abs(p.PlusRadiusPx-p.MinusRadiusPx);
        p.DirectionExcessPx = 2*min(p.PlusRadiusPx,p.MinusRadiusPx)-2*nearest;
        p.RasterMetricOffsetPx = 2*nearest-p.DistanceWidthPx;
        p.AsymmetryFraction = p.SideAsymmetryPx./p.AngleWidthPx;
        p.AbsoluteDifferencePx = abs(p.DifferencePx);
        p.RelativeDifferencePct = 100*p.AbsoluteDifferencePx./p.AngleWidthPx;
        % Ten-pixel path offsets suppress one-pixel skeleton stair steps.
        d = double(data.CLine{k}.distance); [d,ia] = unique(d);
        xy = [p.X(ia),p.Y(ia)]; query = double(data.CLine{k}.distance);
        before = interp1(d,xy,query-10,'linear',NaN);
        after = interp1(d,xy,query+10,'linear',NaN);
        left = [p.X,p.Y]-before; right = after-[p.X,p.Y];
        p.TurnDegrees = acosd(max(-1,min(1,sum(left.*right,2)./ ...
            (vecnorm(left,2,2).*vecnorm(right,2,2)))));
        tangent = after-before; normal = [-tangent(:,2),tangent(:,1)];
        p.NormalMisalignmentDegrees = acosd(min(1,abs(sum(normal.* ...
            [p.DirectionX,p.DirectionY],2))./vecnorm(normal,2,2)));
        unavailable = ~all(isfinite(before),2) | ~all(isfinite(after),2);
        p.TurnDegrees(unavailable) = NaN;
        p.NormalMisalignmentDegrees(unavailable) = NaN;
        valid = p.ValidPair; interior = valid & ~p.EndpointRisk;
        assert(max(abs(p.DifferencePx(valid)-p.SideAsymmetryPx(valid)- ...
            p.DirectionExcessPx(valid)-p.RasterMetricOffsetPx(valid)))<1e-8);
        assert(all(p.DirectionExcessPx(valid)>-1e-7));
        e = numel(eyes)+1; p.EyeID = repmat(e,height(p),1);
        eyes(e).Group = names{g}; eyes(e).Name = data.IMGname{k};
        eyes(e).Image = data.IMG{k}; eyes(e).Polygon = vertices; eyes(e).Points = p;
        absDiff = p.AbsoluteDifferencePx(interior);
        row = table(e,string(names{g}),string(data.IMGname{k}),height(p),nnz(~valid), ...
            nnz(interior),nnz(valid & p.EndpointRisk),median(absDiff),prctile(absDiff,95),max(absDiff), ...
            100*mean(absDiff>2),100*mean(absDiff>5), ...
            100*mean(p.RelativeDifferencePct(interior)>20), ...
            'VariableNames',{'EyeID','Group','Eye','Points','Invalid','Interior','Ends', ...
            'MedianAbsPx','P95AbsPx','MaxAbsPx','PctAbove2Px','PctAbove5Px','PctAbove20Percent'});
        summaries = [summaries;row]; allPoints = [allPoints;p]; %#ok<AGROW>
    end
end
assert(numel(eyes)==44 && isequal(initialRng,rng));
p = allPoints; interior = p.ValidPair & ~p.EndpointRisk;
categories = {'All interior','End regions','Width < 10 px','Width >= 10 px', ...
    'Turn > 20 deg','Turn <= 20 deg','Misalignment > 30 deg','Misalignment <= 30 deg', ...
    'Side asymmetry > 20%','Side asymmetry <= 20%'};
masks = [interior,p.ValidPair & p.EndpointRisk,interior & p.AngleWidthPx<10, ...
    interior & p.AngleWidthPx>=10,interior & p.TurnDegrees>20,interior & p.TurnDegrees<=20, ...
    interior & p.NormalMisalignmentDegrees>30,interior & p.NormalMisalignmentDegrees<=30, ...
    interior & p.AsymmetryFraction>.2,interior & p.AsymmetryFraction<=.2];
categorySummary = table; categoryEyeMedians = nan(44,numel(categories));
for c = 1:numel(categories)
    m = masks(:,c);
    for e = 1:44
        v = p.AbsoluteDifferencePx(m & p.EyeID==e);
        if ~isempty(v), categoryEyeMedians(e,c) = median(v); end
    end
    v = p.AbsoluteDifferencePx(m);
    row = table(string(categories{c}),nnz(m),nnz(isfinite(categoryEyeMedians(:,c))), ...
        median(categoryEyeMedians(:,c),'omitnan'),median(v),prctile(v,95),100*mean(v>2), ...
        median(p.RelativeDifferencePct(m)), ...
        'VariableNames',{'Category','Points','Eyes','MedianOfEyeMediansPx','PooledMedianPx','PooledP95Px','PooledPctAbove2Px','PooledMedianRelativePct'});
    categorySummary = [categorySummary;row]; %#ok<AGROW>
end

% Four largest interior discrepancies from distinct eyes, then two end cases.
selected = table;
for c = 1:2
    if c==1, mask = interior; count = 4; else, mask = p.ValidPair & p.EndpointRisk; count = 2; end
    candidates = sortrows(p(mask,:),'AbsoluteDifferencePx','descend'); used = [];
    for j = 1:height(candidates)
        if ismember(candidates.EyeID(j),used), continue; end
        selected = [selected;candidates(j,:)]; used(end+1) = candidates.EyeID(j); %#ok<AGROW>
        if numel(used)==count, break; end
    end
end
save(fullfile(out,'width_disagreement_audit.mat'),'allPoints','summaries','categorySummary','categoryEyeMedians','selected');
disp(summaries); disp(categorySummary);
fprintf('\nInterior: %d points; end regions: %d; invalid: %d.\n',nnz(interior),nnz(p.ValidPair & p.EndpointRisk),nnz(~p.ValidPair));
fprintf('Across-eye median: median abs %.3f px; P95 abs %.3f px; fraction >2 px %.2f%%; >5 px %.2f%%; >20%% %.2f%%.\n', ...
    median(summaries.MedianAbsPx),median(summaries.P95AbsPx),median(summaries.PctAbove2Px), ...
    median(summaries.PctAbove5Px),median(summaries.PctAbove20Percent));
fprintf('Pooled interior absolute-difference percentiles [50 90 95 99 100]:\n'); disp(prctile(p.AbsoluteDifferencePx(interior),[50 90 95 99 100]));
fprintf('Pooled interior signed raster/metric offset percentiles [5 50 95]:\n'); disp(prctile(p.RasterMetricOffsetPx(interior),[5 50 95]));
disp(selected(:,{'EyeID','Point','Angle','DistanceWidthPx','AngleWidthPx','DifferencePx', ...
    'EndpointRisk','MultipleSegments','SideAsymmetryPx','DirectionExcessPx','RasterMetricOffsetPx','TurnDegrees','NormalMisalignmentDegrees'}));

fig = figure('Visible','off','Color','w','Position',[100 100 1450 900]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,2,'TileSpacing','compact');
ax = nexttile(tiles); hold(ax,'on');
plot(ax,summaries.EyeID,summaries.MedianAbsPx,'o-','Color',[.05 .4 .7]);
plot(ax,summaries.EyeID,summaries.P95AbsPx,'s-','Color',[.85 .35 .05]);
xlabel(ax,'Eye (grouped by treatment / age)'); ylabel(ax,'Absolute difference (px)');
title(ax,'Interior points: typical difference and upper tail'); legend(ax,{'Median','95th percentile'},'Location','northwest'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on');
for c = 1:numel(categories)
    values = categoryEyeMedians(:,c); good = isfinite(values);
    plot(ax,values(good),c+linspace(-.18,.18,nnz(good))','o','Color',[.4 .5 .55],'MarkerSize',3);
    plot(ax,median(values,'omitnan'),c,'kd','MarkerFaceColor','k','MarkerSize',6);
end
yticks(ax,1:numel(categories)); yticklabels(ax,categories); set(ax,'YDir','reverse'); ylim(ax,[.4 numel(categories)+.6]);
xlabel(ax,'Median absolute difference (px)'); title(ax,'Each circle is one eye; diamond is median across eyes'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on');
indices = find(interior); indices = indices(1:8:end);
scatter(ax,p.AngleWidthPx(indices),p.AbsoluteDifferencePx(indices),5,[.05 .4 .7],'filled');
xlabel(ax,'Angle-fixed width (px)'); ylabel(ax,'Absolute difference (px)'); title(ax,'Width versus disagreement (every eighth interior point)'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on');
components = [selected.SideAsymmetryPx,selected.DirectionExcessPx,selected.RasterMetricOffsetPx];
bars = bar(ax,components,'stacked'); bars(1).FaceColor = [.6 .25 .6]; bars(2).FaceColor = [.85 .4 .1]; bars(3).FaceColor = [.1 .5 .7];
plot(ax,1:height(selected),selected.DifferencePx,'kd','MarkerFaceColor','k'); yline(ax,0,'k:');
xlabel(ax,'Close-up example number'); ylabel(ax,'Contribution to signed difference (px)');
title(ax,'Exact geometry decomposition at selected extremes');
legend(ax,{'Side asymmetry','Direction / nearest-edge difference','Raster / metric offset','Total difference'},'Location','northeast','FontSize',8); grid(ax,'on');
title(tiles,'Width disagreement audit | 44 example eyes','FontSize',16);
xlabel(tiles,{'Descriptive diagnostics, not independent observations or treatment tests. Categories overlap; thresholds are exploratory.'; ...
    'Turn and normal estimates use centerline chords spanning +/-10 path pixels. End regions use the existing radius-based flag.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'width_disagreement_summary.png'),'Resolution',150); clear cleanup;

fig = figure('Visible','off','Color','w','Position',[100 100 1500 1000]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,3,'TileSpacing','compact');
for j = 1:height(selected)
    q = selected(j,:); eye = eyes(q.EyeID); ax = nexttile(tiles); hold(ax,'on');
    img = eye.Image; if ismatrix(img), img = repmat(double(img)/255,1,1,3); end
    imagesc(ax,img); axis(ax,'image'); set(ax,'YDir','reverse');
    xy = eye.Polygon; xy = [xy;xy(1,:)];
    plot(ax,xy(:,1),xy(:,2),'-','Color',[.65 .15 .55],'LineWidth',1.2);
    plot(ax,eye.Points.X,eye.Points.Y,'-','Color',[.1 .65 .45],'LineWidth',1.1);
    theta = linspace(0,2*pi,180); radius = q.DistanceWidthPx/2;
    plot(ax,q.X+radius*cos(theta),q.Y+radius*sin(theta),'--','Color',[.05 .4 .7],'LineWidth',1.5);
    plot(ax,[q.SectionX1 q.SectionX2],[q.SectionY1 q.SectionY2],'-s','Color',[.9 .4 .05],'LineWidth',2,'MarkerSize',4);
    plot(ax,q.X,q.Y,'wo','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',5);
    extent = max(abs([q.SectionX1-q.X,q.SectionX2-q.X,q.SectionY1-q.Y,q.SectionY2-q.Y]));
    half = max(32,ceil(extent+12)); xlim(ax,q.X+[-half half]); ylim(ax,q.Y+[-half half]);
    ax.XTick = []; ax.YTick = []; ax.Box = 'on';
    kind = 'Interior'; if q.EndpointRisk, kind = 'End region'; end
    title(ax,{sprintf('%d | %s | %s eye %d',j,kind,strrep(eye.Group,'_',' '),q.EyeID); ...
        sprintf('Angle %.1f deg | distance %.1f / angle-fixed %.1f px',q.Angle,q.DistanceWidthPx,q.AngleWidthPx); ...
        sprintf('Difference %+.1f px | field %d x %d px',q.DifferencePx,2*half,2*half)},'FontSize',10,'FontWeight','normal');
    sx = q.X-half+5; sy = q.Y+half-7;
    plot(ax,sx+[0 10],[sy sy],'k-','LineWidth',2);
    text(ax,sx+5,sy-3,'10 px','HorizontalAlignment','center','FontSize',8,'BackgroundColor','w');
end
title(tiles,'Largest disagreements | four interior eyes and two end-region eyes','FontSize',16);
xlabel(tiles,{'Purple: polygon. Green: centerline. Orange: angle-fixed section. Blue dashed: approximate quasi-Euclidean radius. White: measured point.'; ...
    'Selected extremes, not representative locations. Fields of view differ to retain complete cross-sections; each panel has a 10-pixel scale.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'width_disagreement_extremes.png'),'Resolution',160);
end
