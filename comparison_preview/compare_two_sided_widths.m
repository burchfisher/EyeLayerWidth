function compare_two_sided_widths
% Compare an experimental two-sided estimator without changing the GUI.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
out = fileparts(mfilename('fullpath')); addpath(out);
names = {'DMSO_4dpi','IWR1_4dpi','DMSO_9dpf','IWR1_9dpf'};
previous = load(fullfile(out,'width_disagreement_audit.mat'),'selected');
allPoints = table; summaries = table; eyes = struct([]); initialRng = rng;
started = tic;
for g = 1:numel(names)
    loaded = load(fullfile(root,'examples',[names{g} '.mat'])); data = loaded.(names{g});
    for k = 1:numel(data.IMGname)
        e = numel(eyes)+1;
        p = layerwidth_reference_widths(data.ROIxy{k},logical(data.ROIBW{k}),data.CLine{k});
        [extra,geometry] = two_sided_widths(data.ROIxy{k},logical(data.ROIBW{k}),data.CLine{k});
        p = [p extra]; p.EyeID = repmat(e,height(p),1);
        p.IncreasePct = 100*p.AddedWidthPx./p.DistanceWidthPx;
        p.Interior = p.ValidPair & ~p.EndpointRisk;
        p.CautiousInterior = p.Interior & ~p.SplitRisk & ~p.OutsideShortcut & p.LegAngleDegrees>=90;
        assert(all(p.AddedWidthPx(p.ValidPair)>-1e-4));
        eyes(e).Group = names{g}; eyes(e).Name = data.IMGname{k};
        eyes(e).Image = data.IMG{k}; eyes(e).Points = p; eyes(e).Geometry = geometry;
        m = p.Interior;
        row = table(e,string(names{g}),string(data.IMGname{k}),nnz(m),median(p.AddedWidthPx(m)), ...
            prctile(p.AddedWidthPx(m),95),max(p.AddedWidthPx(m)),median(p.IncreasePct(m)), ...
            100*mean(p.AddedWidthPx(m)>2),100*mean(p.AddedWidthPx(m)>5), ...
            nnz(p.SplitRisk & m),nnz(p.OutsideShortcut & m),nnz(p.LegAngleDegrees<90 & m), ...
            'VariableNames',{'EyeID','Group','Eye','InteriorPoints','MedianAddedPx','P95AddedPx','MaxAddedPx', ...
            'MedianIncreasePct','PctAbove2Px','PctAbove5Px','SplitRiskPoints','ShortcutPoints','SameSideLegPoints'});
        summaries = [summaries;row]; allPoints = [allPoints;p]; %#ok<AGROW>
    end
    fprintf('Measured %s (%d eyes so far, %.1f seconds).\n',names{g},numel(eyes),toc(started));
end
assert(numel(eyes)==44 && isequal(initialRng,rng));
p = allPoints;
selected = table;
for j = 1:4
    q = previous.selected(j,:);
    selected = [selected;p(p.EyeID==q.EyeID & p.Point==q.Point,:)]; %#ok<AGROW>
end
candidates = p(p.Interior & ~ismember(p.EyeID,selected.EyeID),:);
[~,j] = max(candidates.AddedWidthPx); selected = [selected;candidates(j,:)];
candidates = p(p.ValidPair & p.EndpointRisk,:);
[~,j] = max(candidates.AddedWidthPx); selected = [selected;candidates(j,:)];
geometries = {eyes.Geometry};
save(fullfile(out,'two_sided_width_comparison.mat'),'allPoints','summaries','selected','geometries');
fprintf('\nAcross-eye medians: added %.3f px; within-eye P95 %.3f px; relative increase %.2f%%; >2px %.2f%%; >5px %.2f%%.\n', ...
    median(summaries.MedianAddedPx),median(summaries.P95AddedPx),median(summaries.MedianIncreasePct), ...
    median(summaries.PctAbove2Px),median(summaries.PctAbove5Px));
labels = {'All interior','Cautious interior','End regions'};
filters = [p.Interior,p.CautiousInterior,p.ValidPair & p.EndpointRisk];
for j = 1:3
    m = filters(:,j);
    fprintf('%s: n=%d; added percentiles [50 90 95 99 max] = ',labels{j},nnz(m));
    fprintf(' %.3f',prctile(p.AddedWidthPx(m),[50 90 95 99 100]));
    fprintf('; >2px %.2f%%; >5px %.2f%%; >50%% increase %.2f%%\n', ...
        100*mean(p.AddedWidthPx(m)>2),100*mean(p.AddedWidthPx(m)>5),100*mean(p.IncreasePct(m)>50));
end
fprintf('Interior flags: cut-near %d, outside shortcut %d, legs <90deg %d; unique flagged %d / %d.\n', ...
    nnz(p.Interior & p.SplitRisk),nnz(p.Interior & p.OutsideShortcut),nnz(p.Interior & p.LegAngleDegrees<90), ...
    nnz(p.Interior & ~p.CautiousInterior),nnz(p.Interior));
disp(selected(:,{'EyeID','Point','Angle','DistanceWidthPx','TwoSidedWidthPx','AngleWidthPx','AddedWidthPx', ...
    'Side1DistancePx','Side2DistancePx','LegAngleDegrees','EndpointRisk','SplitRisk','OutsideShortcut'}));

fig = figure('Visible','off','Color','w','Position',[100 100 1400 900]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,2,'TileSpacing','compact');
ax = nexttile(tiles); hold(ax,'on');
plot(ax,summaries.EyeID,summaries.MedianAddedPx,'o-','Color',[.05 .4 .7]);
plot(ax,summaries.EyeID,summaries.P95AddedPx,'s-','Color',[.8 .1 .25]);
xlabel(ax,'Eye'); ylabel(ax,'Two-sided minus distance x 2 (px)'); grid(ax,'on');
title(ax,'Interior points: change within each of 44 eyes'); legend(ax,{'Median','95th percentile'},'Location','best');
ax = nexttile(tiles); hold(ax,'on'); m = find(p.Interior); m = m(1:8:end);
scatter(ax,p.DistanceWidthPx(m),p.TwoSidedWidthPx(m),5,[.05 .4 .7],'filled');
maximum = max([p.DistanceWidthPx(m);p.TwoSidedWidthPx(m)])+2;
plot(ax,[0 maximum],[0 maximum],'k:'); axis(ax,'equal'); xlim(ax,[0 maximum]); ylim(ax,[0 maximum]);
xlabel(ax,'Distance x 2 (px)'); ylabel(ax,'Two-sided distance sum (px)');
title(ax,'Every eighth interior point; dotted line is equality'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on'); chosenEye = selected.EyeID(1); q = eyes(chosenEye).Points;
angles = (2.5:5:177.5)'; profiles = nan(numel(angles),3);
for j = 1:numel(angles)
    m = q.Interior & q.Angle>=angles(j)-2.5 & q.Angle<angles(j)+2.5;
    if j==numel(angles), m = m | (q.Interior & q.Angle==180); end
    profiles(j,:) = median([q.DistanceWidthPx(m),q.TwoSidedWidthPx(m),q.AngleWidthPx(m)],1,'omitnan');
end
plot(ax,angles,profiles(:,1),'-','Color',[.05 .4 .7],'LineWidth',1.5);
plot(ax,angles,profiles(:,2),'-','Color',[.8 .1 .25],'LineWidth',1.5);
plot(ax,angles,profiles(:,3),'-','Color',[.9 .4 .05],'LineWidth',1.3);
xline(ax,selected.Angle(1),'k:'); xlim(ax,[0 180]); xlabel(ax,'Angle (degrees)'); ylabel(ax,'Median width (px)');
title(ax,sprintf('Previous worst angle-fixed case: eye %d, 5-degree bins',chosenEye));
legend(ax,{'Distance x 2','Two-sided sum','Angle-fixed'},'Location','best'); grid(ax,'on');
ax = nexttile(tiles); hold(ax,'on');
for j = 1:3
    sorted = sort(p.AddedWidthPx(filters(:,j))); count = numel(sorted);
    plot(ax,sorted,100*(1:count)'/count,'LineWidth',1.5);
end
xlabel(ax,'Two-sided minus distance x 2 (px)'); ylabel(ax,'Cumulative percentage of points');
title(ax,'Full distribution, including flagged cases'); legend(ax,labels,'Location','southeast'); grid(ax,'on');
title(tiles,'Two-sided quasi-Euclidean distance | experimental comparison','FontSize',16);
xlabel(tiles,{'Same exterior-background pixel convention as distance x 2. Boundary arcs are split near the two centerline endpoints.'; ...
    'Cautious interior additionally excludes split-near targets, outside-ROI shortcuts, and leg angles below 90 degrees. Descriptive, not inference.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'two_sided_width_summary.png'),'Resolution',150); clear cleanup;

fig = figure('Visible','off','Color','w','Position',[100 100 1500 1050]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,3,'TileSpacing','compact');
for j = 1:height(selected)
    q = selected(j,:); eye = eyes(q.EyeID); ax = nexttile(tiles); drawImage(ax,eye);
    plot(ax,[q.SectionX1 q.SectionX2],[q.SectionY1 q.SectionY2],'-','Color',[.9 .4 .05],'LineWidth',1.5);
    theta = linspace(0,2*pi,180); radius = q.DistanceWidthPx/2;
    plot(ax,q.X+radius*cos(theta),q.Y+radius*sin(theta),'--','Color',[.05 .4 .7],'LineWidth',1.5);
    plot(ax,[q.Side1X q.X q.Side2X],[q.Side1Y q.Y q.Side2Y],'-d','Color',[.8 .1 .25], ...
        'LineWidth',2,'MarkerSize',4,'MarkerFaceColor',[.8 .1 .25]);
    plot(ax,q.X,q.Y,'wo','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',5);
    extent = max(abs([q.SectionX1-q.X,q.SectionX2-q.X,q.SectionY1-q.Y,q.SectionY2-q.Y, ...
        q.Side1X-q.X,q.Side2X-q.X,q.Side1Y-q.Y,q.Side2Y-q.Y]));
    half = max(32,ceil(extent+12)); xlim(ax,q.X+[-half half]); ylim(ax,q.Y+[-half half]);
    kind = 'Prior angle-fixed extreme'; if j==5, kind = 'Largest new change, another eye'; elseif j==6, kind = 'Largest new change at an end'; end
    flags = 'No added QC flags';
    if q.SplitRisk || q.OutsideShortcut || q.LegAngleDegrees<90
        flags = sprintf('QC: split-near %d | shortcut %d | legs %.0f deg',q.SplitRisk,q.OutsideShortcut,q.LegAngleDegrees);
    end
    title(ax,{sprintf('%d | %s | eye %d',j,kind,q.EyeID); ...
        sprintf('Original %.1f | two-sided %.1f | angle-fixed %.1f px',q.DistanceWidthPx,q.TwoSidedWidthPx,q.AngleWidthPx); ...
        sprintf('%.1f deg | %s',q.Angle,flags)},'FontSize',10,'FontWeight','normal');
    sx = q.X-half+5; sy = q.Y+half-7; plot(ax,sx+[0 10],[sy sy],'k-','LineWidth',2);
    text(ax,sx+5,sy-3,'10 px','HorizontalAlignment','center','FontSize',8,'BackgroundColor','w');
end
title(tiles,'Does adding the two sides behave sensibly at difficult locations?','FontSize',16);
xlabel(tiles,{'Red: two nearest-side connections. Blue dashed: original distance radius. Orange: angle-fixed section. Purple: ROI. Green: centerline.'; ...
    'Red endpoints are exterior background pixels; straight legs illustrate nearest targets, not quasi-Euclidean paths. Selected extremes; zoom scales vary.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'two_sided_width_closeups.png'),'Resolution',160); clear cleanup;

fig = figure('Visible','off','Color','w','Position',[100 100 1400 750]);
cleanup = onCleanup(@() close(fig));
for j = 1:4
    q = selected(j,:); eye = eyes(q.EyeID);
    ax = axes(fig,'Position',[.025+(j-1)*.245 .13 .22 .72]); drawImage(ax,eye); geo = eye.Geometry;
    xy = geo.RingXY; a = geo.RingSide1;
    plot(ax,xy(a,1),xy(a,2),'.','Color',[.05 .55 .7],'MarkerSize',3);
    plot(ax,xy(~a,1),xy(~a,2),'.','Color',[.7 .15 .5],'MarkerSize',3);
    plot(ax,geo.SplitXY(:,1),geo.SplitXY(:,2),'kx','MarkerSize',10,'LineWidth',2);
    plot(ax,q.X,q.Y,'ro','MarkerSize',7,'LineWidth',1.5);
    v = geo.Vertices; xlim(ax,[min(v(:,1))-15,max(v(:,1))+15]); ylim(ax,[min(v(:,2))-15,max(v(:,2))+15]);
    title(ax,sprintf('Eye %d | %s',q.EyeID,strrep(eye.Group,'_',' ')),'FontSize',11);
end
annotation(fig,'textbox',[0 .93 1 .05],'String','Boundary-side assignment check', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',16,'FontWeight','bold');
annotation(fig,'textbox',[.04 .015 .92 .065],'String', ...
    'Cyan and magenta: the two background seed arcs. Black crosses: split locations. Red circle: selected interior example.', ...
    'EdgeColor','none','HorizontalAlignment','center','FontSize',10);
exportgraphics(fig,fullfile(out,'two_sided_width_boundary_qc.png'),'Resolution',150);
clear cleanup;
% Inspect the rare flags rather than dropping them from the comparison.
candidates = p(p.Interior,:); [~,j] = min(candidates.LegAngleDegrees); flagged = candidates(j,:);
candidates = p(p.Interior & p.SplitRisk,:); [~,j] = max(candidates.AddedWidthPx); flagged = [flagged;candidates(j,:)];
disp(flagged(:,{'EyeID','Point','Angle','DistanceWidthPx','TwoSidedWidthPx','LegAngleDegrees','SplitRisk','OutsideShortcut'}));
fig = figure('Visible','off','Color','w','Position',[100 100 1100 650]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,1,2,'TileSpacing','compact');
for j = 1:2
    q = flagged(j,:); eye = eyes(q.EyeID); ax = nexttile(tiles); drawImage(ax,eye);
    plot(ax,[q.Side1X q.X q.Side2X],[q.Side1Y q.Y q.Side2Y],'-d','Color',[.8 .1 .25],'LineWidth',2);
    plot(ax,q.X,q.Y,'wo','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',5);
    theta = linspace(0,2*pi,180); radius = q.DistanceWidthPx/2;
    plot(ax,q.X+radius*cos(theta),q.Y+radius*sin(theta),'--','Color',[.05 .4 .7],'LineWidth',1.5);
    xlim(ax,q.X+[-35 35]); ylim(ax,q.Y+[-35 35]);
    title(ax,{sprintf('Eye %d | %.1f deg | original %.1f / two-sided %.1f px',q.EyeID,q.Angle,q.DistanceWidthPx,q.TwoSidedWidthPx); ...
        sprintf('Leg angle %.1f deg | split-near flag %d',q.LegAngleDegrees,q.SplitRisk)},'FontSize',11);
end
title(tiles,'Flagged examples: same-facing legs and proximity to a boundary split','FontSize',14);
xlabel(tiles,'Both fields span 70 x 70 pixels. Red: nearest-side connections; blue: original radius; purple: polygon; green: centerline.','FontSize',10);
exportgraphics(fig,fullfile(out,'two_sided_width_flagged.png'),'Resolution',150);
fprintf('Saved comparison and inspected-location data. Total runtime %.1f seconds.\n',toc(started));
end

function drawImage(ax,eye)
img = eye.Image; if ismatrix(img), img = repmat(double(img)/255,1,1,3); end
imagesc(ax,img); hold(ax,'on'); axis(ax,'image'); set(ax,'YDir','reverse');
v = eye.Geometry.Vertices; xy = [v;v(1,:)];
plot(ax,xy(:,1),xy(:,2),'-','Color',[.65 .15 .55],'LineWidth',1.1);
plot(ax,eye.Points.X,eye.Points.Y,'-','Color',[.1 .65 .45],'LineWidth',1.1);
ax.XTick = []; ax.YTick = []; ax.Box = 'on';
end
