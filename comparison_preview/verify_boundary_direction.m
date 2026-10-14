function verify_boundary_direction
% Independently audit both possible bottom-right panels and show directionality.
root = fileparts(fileparts(mfilename('fullpath'))); out = fileparts(mfilename('fullpath'));
d = load(fullfile(out,'boundary_euclidean_comparison.mat'));
examples = [4 5]; audit = table;
fig = figure('Visible','off','Color','w','Position',[100 100 1300 780]);
cleanup = onCleanup(@() close(fig)); tiles = tiledlayout(fig,1,2,'TileSpacing','compact');
for j = 1:2
    r = d.selectedSegments(d.selectedSegments.Example==examples(j) & d.selectedSegments.SourceSide==2,:);
    geo = d.geometries{r.EyeID}; source = [r.SourceX r.SourceY]; target = [r.TargetX r.TargetY];
    a = geo.ArcA; b = geo.ArcB;
    s = [0;cumsum(vecnorm(diff(a),2,2))];
    dense = interp1(s,a,linspace(0,s(end),ceil(s(end)/.005)+1));
    independent = min(vecnorm(dense-source,2,2));
    assert(independent>=r.WidthPx-1e-8 && independent-r.WidthPx<.005);
    edges = diff(b); starts = b(1:end-1,:);
    t = sum((target-starts).*edges,2)./sum(edges.^2,2); t = max(0,min(1,t));
    feet = starts+t.*edges; [reverse,index] = min(vecnorm(feet-target,2,2)); back = feet(index,:);
    s = [0;cumsum(vecnorm(diff(b),2,2))];
    dense = interp1(s,b,linspace(0,s(end),ceil(s(end)/.005)+1));
    independentReverse = min(vecnorm(dense-target,2,2));
    assert(independentReverse>=reverse-1e-8 && independentReverse-reverse<.005);
    row = table(examples(j),r.EyeID,r.WidthPx,independent,reverse,independentReverse, ...
        'VariableNames',{'Example','EyeID','OriginalDirectedWidthPx','IndependentForwardPx','ReverseWidthPx','IndependentReversePx'});
    audit = [audit;row]; %#ok<AGROW>
    summary = d.summary(d.summary.EyeID==r.EyeID,:); group = char(summary.Group);
    loaded = load(fullfile(root,'examples',[group '.mat'])); data = loaded.(group);
    eyeIndex = find(strcmp(data.IMGname,char(summary.Eye))); assert(isscalar(eyeIndex));
    ax = nexttile(tiles); imagesc(ax,repmat(double(data.IMG{eyeIndex})/255,1,1,3)); hold(ax,'on');
    axis(ax,'image'); set(ax,'YDir','reverse','XTick',[],'YTick',[]);
    v = geo.Vertices; xy = [v;v(1,:)]; plot(ax,xy(:,1),xy(:,2),'-','Color',[.4 .25 .4],'LineWidth',1.2);
    p = d.allMapped(d.allMapped.EyeID==r.EyeID,:);
    plot(ax,p.X,p.Y,'-','Color',[.1 .65 .45],'LineWidth',1);
    magenta = [.8 .1 .5]; orange = [.9 .45 .05];
    quiver(ax,source(1),source(2),target(1)-source(1),target(2)-source(2),0, ...
        'Color',magenta,'LineWidth',2,'MaxHeadSize',.25);
    quiver(ax,target(1),target(2),back(1)-target(1),back(2)-target(2),0, ...
        'Color',orange,'LineWidth',2,'MaxHeadSize',.4);
    anchors = [source;target;back]; labels = {'S','T','R'};
    plot(ax,anchors(:,1),anchors(:,2),'wo','MarkerFaceColor','w','MarkerEdgeColor','k','MarkerSize',5);
    for k = 1:3
        text(ax,anchors(k,1)+2,anchors(k,2)-2,labels{k},'FontWeight','bold','FontSize',12, ...
            'BackgroundColor','w','Margin',1);
    end
    center = (min(anchors,[],1)+max(anchors,[],1))/2;
    half = max(32,ceil(max(max(anchors,[],1)-min(anchors,[],1))/2+16));
    xlim(ax,center(1)+[-half half]); ylim(ax,center(2)+[-half half]);
    panel = 'Close-up figure'; if j==2, panel = 'Summary figure'; end
    title(ax,{sprintf('%s: bottom-right panel | eye %d',panel,r.EyeID); ...
        sprintf('Magenta S to T: %.2f px | orange T to R: %.2f px',r.WidthPx,reverse)}, ...
        'FontSize',11,'FontWeight','normal');
    sx = center(1)-half+5; sy = center(2)+half-7; plot(ax,sx+[0 10],[sy sy],'k-','LineWidth',2);
    text(ax,sx+5,sy-3,'10 px','HorizontalAlignment','center','FontSize',9,'BackgroundColor','w');
end
title(tiles,'A nearest-boundary connection need not be nearest in reverse','FontSize',16);
xlabel(tiles,{'S: original starting point. T: its nearest point on the opposite boundary. R: the nearest return point starting from T.'; ...
    'Both searches checked independently against the entire opposite arc sampled at intervals no larger than 0.005 pixels.'},'FontSize',10);
exportgraphics(fig,fullfile(out,'boundary_direction_check.png'),'Resolution',160);
save(fullfile(out,'boundary_direction_check.mat'),'audit'); disp(audit);
end
