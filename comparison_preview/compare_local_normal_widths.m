function compare_local_normal_widths
% Compare window lengths while retaining valid tip measurements.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
out = fileparts(mfilename('fullpath')); addpath(out);
names = {'DMSO_4dpi','IWR1_4dpi','DMSO_9dpf','IWR1_9dpf'}; windows = [25 50 75];
allPoints = table; summary = table; eyes = struct([]); initialRng = rng; timer = tic;
for g = 1:numel(names)
    loaded = load(fullfile(root,'examples',[names{g} '.mat'])); data = loaded.(names{g});
    for k = 1:numel(data.IMGname)
        e = numel(eyes)+1; results = cell(1,3); details = cell(1,3);
        for w = 1:3
            [results{w},details{w}] = local_normal_widths(data.ROIxy{k},logical(data.ROIBW{k}),data.CLine{k},windows(w));
            assert(details{w}.MaxPathStep<=sqrt(2)+1e-6,'Example centerline has a discontinuous path.');
        end
        p = results{2}; p.EyeID = repmat(e,height(p),1);
        p.Width25 = results{1}.Width; p.Width50 = p.Width; p.Width75 = results{3}.Width;
        p.ValidAll = results{1}.Valid & results{2}.Valid & results{3}.Valid;
        p.FullWindow75 = ~results{3}.WindowTruncated;
        p.WindowSpan = max([p.Width25 p.Width50 p.Width75],[],2)-min([p.Width25 p.Width50 p.Width75],[],2);
        p.WindowSpan(~p.ValidAll) = NaN;
        p.Abs25vs75 = abs(p.Width25-p.Width75);
        p.TrendChange25vs75 = acosd(min(1,abs(results{1}.NormalX.*results{3}.NormalX+results{1}.NormalY.*results{3}.NormalY)));
        good = p.ValidAll;
        row = table(e,string(names{g}),string(data.IMGname{k}),height(p),nnz(p.Valid),nnz(good), ...
            nnz(p.WindowTruncated & p.Valid),median(p.WindowSpan(good)),prctile(p.WindowSpan(good),95),max(p.WindowSpan(good)), ...
            median(p.Width50(good)-p.OriginalQuasiWidthPx(good)),median(p.Width50(good)),min(p.FitLinearity), ...
            'VariableNames',{'EyeID','Group','Eye','Points','Valid50','ValidAll','ShortWindowValid50', ...
            'MedianWindowSpan','P95WindowSpan','MaxWindowSpan','Median50minusOriginal','MedianWidth50','MinFitLinearity50'});
        summary = [summary;row]; allPoints = [allPoints;p]; %#ok<AGROW>
        eyes(e).Image = data.IMG{k}; eyes(e).Polygon = data.ROIxy{k}; eyes(e).Group = names{g};
        eyes(e).Results = results; eyes(e).Details = details; eyes(e).Points = p;
    end
    fprintf('Measured %s, %d eyes in %.1f seconds.\n',names{g},numel(eyes),toc(timer));
end
assert(numel(eyes)==44 && isequal(initialRng,rng));
p = allPoints;
fprintf('\n50-unit window: %d valid / %d total; %d valid with shortened windows, all retained.\n', ...
    nnz(p.Valid),height(p),nnz(p.Valid & p.WindowTruncated));
for full = [false true]
    m = p.ValidAll; label = 'All valid points (tips retained)';
    if full, m = m & p.FullWindow75; label = 'Full 75-unit support (sensitivity subset only)'; end
    fprintf('%s: n=%d, width span across windows [50 90 95 99 max] = ',label,nnz(m));
    fprintf(' %.3f',prctile(p.WindowSpan(m),[50 90 95 99 100]));
    fprintf('; >2 units %.2f%%, >5 units %.2f%%\n',100*mean(p.WindowSpan(m)>2),100*mean(p.WindowSpan(m)>5));
end
fprintf('50-unit minus original quasi distance x2, paired percentiles [5 50 95]: ');
m = p.Valid & isfinite(p.OriginalQuasiWidthPx); fprintf(' %.3f',prctile(p.Width50(m)-p.OriginalQuasiWidthPx(m),[5 50 95])); fprintf('\n');
fprintf('50-unit width percentiles [1 50 99 max]: '); fprintf(' %.3f',prctile(p.Width50(p.Valid),[1 50 99 100])); fprintf('\n');
fprintf('Across-eye median of within-eye median window span %.3f; median of P95 span %.3f.\n', ...
    median(summary.MedianWindowSpan),median(summary.P95WindowSpan));

old = load(fullfile(out,'width_disagreement_audit.mat'),'selected'); selected = table;
for j = 1:4
    q = old.selected(j,:); row = p(p.EyeID==q.EyeID & p.Point==q.Point,:);
    assert(height(row)==1 && row.ValidAll); selected = [selected;row]; %#ok<AGROW>
end
candidates = p(p.ValidAll & p.FullWindow75,:); [~,index] = max(candidates.WindowSpan); selected = [selected;candidates(index,:)];
candidates = p(p.ValidAll & p.WindowTruncated,:); [~,index] = max(candidates.WindowSpan); selected = [selected;candidates(index,:)];
disp(selected(:,{'EyeID','Point','Angle','Width25','Width50','Width75','OriginalQuasiWidthPx','BeforeLength','AfterLength','FitLinearity'}));
fprintf('Invalid 50-unit rows (retained as missing, not discarded):\n'); disp(p(~p.Valid,{'EyeID','Point','X','Y','DegenerateTrend','AmbiguousSection'}));
details = {eyes.Details}; save(fullfile(out,'local_normal_comparison.mat'),'allPoints','summary','selected','details','windows');

fig = figure('Visible','off','Color','w','Position',[100 100 1400 900]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,2,'TileSpacing','compact');
ax = nexttile(tiles); hold(ax,'on');
plot(ax,summary.EyeID,summary.MedianWindowSpan,'o-','Color',[.05 .4 .7]);
plot(ax,summary.EyeID,summary.P95WindowSpan,'s-','Color',[.7 .15 .5]);
xlabel(ax,'Eye'); ylabel(ax,'Largest minus smallest width across windows');
title(ax,'Window sensitivity within each eye'); legend(ax,{'Median span','95th percentile span'},'Location','best'); grid(ax,'on');
ax = nexttile(tiles); plotProfiles(ax,eyes(36));
title(ax,'Eye 36: 5-degree median profiles, including tips');
ax = nexttile(tiles); hold(ax,'on');
for flag = [false true]
    m = p.ValidAll; if flag, m = m & p.FullWindow75; end
    values = sort(p.WindowSpan(m)); plot(ax,values,100*(1:numel(values))'/numel(values),'LineWidth',1.5);
end
xlabel(ax,'Largest minus smallest width across windows'); ylabel(ax,'Cumulative percentage of points');
title(ax,'Sensitivity distribution, without hiding the extremes');
legend(ax,{'All valid points','Full-window subset'},'Location','southeast'); grid(ax,'on');
ax = nexttile(tiles); q = eyes(1).Points; hold(ax,'on');
plot(ax,q.PathDistance,q.BeforeLength,'Color',[.1 .6 .5],'LineWidth',1.5);
plot(ax,q.PathDistance,q.AfterLength,'Color',[.7 .15 .5],'LineWidth',1.5);
plot(ax,q.PathDistance,q.BeforeLength+q.AfterLength,'k-','LineWidth',1.5);
xlabel(ax,'Distance along centerline (pixel-distance units)'); ylabel(ax,'Fitting-window length');
title(ax,'50-unit window gradually shortens to 25 at each tip');
legend(ax,{'Available before point','Available after point','Total support'},'Location','best'); grid(ax,'on');
title(tiles,'Local-normal width comparison | 44 eyes | true Euclidean geometry','FontSize',16);
xlabel(tiles,{'Total windows: 25, 50, 75 distance units, centered on each point. Shortened-window measurements are retained.'; ...
    'No image calibration supplied: distances are in pixel-distance units, not micrometers. No smoothing or gap filling of measured widths.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'local_normal_summary.png'),'Resolution',150); clear cleanup;

fig = figure('Visible','off','Color','w','Position',[100 100 1500 1080]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,2,3,'TileSpacing','compact');
for j = 1:height(selected)
    q = selected(j,:); eye = eyes(q.EyeID); ax = nexttile(tiles); drawSections(ax,eye,q.Point);
    kind = 'Prior difficult location'; if j==5, kind = 'Largest full-window sensitivity'; elseif j==6, kind = 'Largest shortened-window sensitivity'; end
    title(ax,{sprintf('%d | %s | eye %d',j,kind,q.EyeID); ...
        sprintf('%.1f deg | widths: 25 = %.1f, 50 = %.1f, 75 = %.1f',q.Angle,q.Width25,q.Width50,q.Width75); ...
        sprintf('50-unit support: %.1f before + %.1f after',q.BeforeLength,q.AfterLength)},'FontSize',10,'FontWeight','normal');
end
title(tiles,'Local perpendicular sections through the original centerline point','FontSize',16);
xlabel(tiles,{'Cyan: 25-unit window. Blue: 50. Magenta: 75. Gold: centerline used for the 50-unit fit. Gray dashed: fitted trend direction.'; ...
    'White dot: point being measured. Purple: polygon. Green: full centerline. Each section stops at the first boundary on each side.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'local_normal_closeups.png'),'Resolution',160); clear cleanup;

fig = figure('Visible','off','Color','w','Position',[100 100 1100 700]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,1,2,'TileSpacing','compact');
eye = eyes(1); [~,first] = min(eye.Points.PathDistance); [~,last] = max(eye.Points.PathDistance);
indices = [first last];
for j = 1:2
    q = eye.Points(indices(j),:); ax = nexttile(tiles); drawSections(ax,eye,q.Point);
    title(ax,{sprintf('Tip %d | 50-unit-fit width %.2f pixels',j,q.Width50); ...
        sprintf('Available window: %.1f before + %.1f after',q.BeforeLength,q.AfterLength)},'FontSize',11,'FontWeight','normal');
end
title(tiles,'Tip measurements are kept: only the fitting support gets shorter','FontSize',15);
xlabel(tiles,'Gold is the available centerline for the 50-unit fit. Blue is its perpendicular width; cyan and magenta use 25- and 75-unit windows.','FontSize',10);
exportgraphics(fig,fullfile(out,'local_normal_tips.png'),'Resolution',160);
fprintf('Saved all point measurements and figures in %.1f seconds.\n',toc(timer));
end

function plotProfiles(ax,eye)
hold(ax,'on'); p = eye.Points; angles = (2.5:5:177.5)'; values = nan(numel(angles),4);
for j = 1:numel(angles)
    m = p.ValidAll & p.Angle>=angles(j)-2.5 & p.Angle<angles(j)+2.5;
    if j==numel(angles), m = m | (p.ValidAll & p.Angle==180); end
    values(j,:) = median([p.Width25(m),p.Width50(m),p.Width75(m),p.OriginalQuasiWidthPx(m)],1,'omitnan');
end
colors = [.05 .65 .65;.05 .35 .8;.8 .1 .5;.45 .45 .45];
for j = 1:4, plot(ax,angles,values(:,j),'Color',colors(j,:),'LineWidth',1.4); end
xlim(ax,[0 180]); xlabel(ax,'Angle (degrees)'); ylabel(ax,'Width (pixels)'); grid(ax,'on');
legend(ax,{'Window 25','Window 50','Window 75','Original quasi distance x 2'}, ...
    'Location','southoutside','NumColumns',2,'FontSize',9);
end

function drawSections(ax,eye,index)
p = eye.Results{2}; q = p(index,:); img = eye.Image;
if ismatrix(img), img = repmat(double(img)/255,1,1,3); end
imagesc(ax,img); hold(ax,'on'); axis(ax,'image'); set(ax,'YDir','reverse','XTick',[],'YTick',[]);
v = eye.Polygon; plot(ax,[v(:,1);v(1,1)],[v(:,2);v(1,2)],'-','Color',[.5 .2 .5],'LineWidth',1.1);
[s,order] = sort(p.PathDistance); xy = [p.X(order),p.Y(order)];
plot(ax,xy(:,1),xy(:,2),'-','Color',[.1 .65 .45],'LineWidth',1);
lo = q.PathDistance-q.BeforeLength; hi = q.PathDistance+q.AfterLength;
nodes = [interp1(s,xy,lo);xy(s>lo & s<hi,:);interp1(s,xy,hi)];
plot(ax,nodes(:,1),nodes(:,2),'-','Color',[.9 .65 .05],'LineWidth',2.2);
trend = [q.X q.Y]+[-q.BeforeLength;q.AfterLength]*[q.TangentX q.TangentY];
plot(ax,trend(:,1),trend(:,2),'--','Color',[.35 .35 .35],'LineWidth',1);
colors = [.05 .65 .65;.05 .35 .8;.8 .1 .5]; positions = nodes;
for j = [1 3 2]
    r = eye.Results{j}(index,:); width = 1.3; if j==2, width = 2; end
    plot(ax,[r.SectionX1 r.SectionX2],[r.SectionY1 r.SectionY2],'-o','Color',colors(j,:), ...
        'LineWidth',width,'MarkerSize',3);
    positions = [positions;r.SectionX1 r.SectionY1;r.SectionX2 r.SectionY2]; %#ok<AGROW>
end
plot(ax,q.X,q.Y,'wo','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',5);
half = max(35,ceil(max(abs(positions-[q.X q.Y]),[],'all')+10));
xlim(ax,q.X+[-half half]); ylim(ax,q.Y+[-half half]);
sx = q.X-half+5; sy = q.Y+half-7; plot(ax,sx+[0 10],[sy sy],'k-','LineWidth',2);
text(ax,sx+5,sy-3,'10 px','HorizontalAlignment','center','FontSize',8,'BackgroundColor','w');
end
