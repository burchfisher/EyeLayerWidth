function selected = preview_width_cross_sections
% Inspect actual centerline-pixel measurements without changing source data.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
source = fullfile(root,'examples','DMSO_4dpi.mat');
loaded = load(source); data = loaded.DMSO_4dpi; eye = 1;
[points,metadata] = layerwidth_reference_widths(data.ROIxy{eye},logical(data.ROIBW{eye}),data.CLine{eye});
targets = [30;45;90;140]; indices = zeros(4,1);
valid = find(points.ValidPair & ~points.EndpointRisk);
for k = 1:4
    [~,nearest] = min(abs(points.Angle(valid)-targets(k))); indices(k) = valid(nearest);
end
assert(numel(unique(indices))==4);
selected = points(indices,:);
selected = addvars(selected,(1:4)',targets,'Before',1,'NewVariableNames',{'Example','RequestedAngle'});
selected.Eye = repmat(string(data.IMGname{eye}),4,1);
writetable(selected,fullfile(root,'comparison_preview','width_cross_sections.csv'));

fig = figure('Visible','off','Color','w','Position',[100 100 1500 950]);
cleanup = onCleanup(@() close(fig));
tiles = tiledlayout(fig,2,3,'TileSpacing','compact','Padding','compact');
overview = nexttile(tiles,1,[2 1]); showImage(overview);
origin = metadata.OriginXY;
for k = 1:4
    plot(overview,[origin(1),selected.X(k)],[origin(2),selected.Y(k)], ...
        ':','Color',[0.4 0.4 0.4],'LineWidth',0.8,'HandleVisibility','off');
    drawSection(overview,k,false);
    text(overview,selected.X(k)+14,selected.Y(k),sprintf('%d',k), ...
        'FontSize',12,'FontWeight','bold','Color','k','BackgroundColor','w','Margin',2);
end
plot(overview,origin(1),origin(2),'+','Color','k','MarkerSize',10,'LineWidth',1.5,'HandleVisibility','off');
text(overview,origin(1)+12,origin(2),'Angular origin','FontSize',9,'BackgroundColor','w','Margin',2);
xy = data.ROIxy{eye}; margin = 35;
xlim(overview,[min([xy(:,1);origin(1)])-margin,max(xy(:,1))+margin]);
ylim(overview,[min(xy(:,2))-margin,max(xy(:,2))+margin]);
title(overview,{'DMSO 4 dpi | example eye 1';'Four centerline pixels'},'FontSize',12);
panelIndices = [2 3 5 6]; halfSpan = 40;
for k = 1:4
    ax = nexttile(tiles,panelIndices(k)); showImage(ax); drawSection(ax,k,true);
    xlim(ax,selected.X(k)+[-halfSpan halfSpan]); ylim(ax,selected.Y(k)+[-halfSpan halfSpan]);
    title(ax,{sprintf('%d | %.1f deg | pixel (%d, %d)',k,selected.Angle(k),selected.X(k),selected.Y(k)); ...
        sprintf('Angle-fixed %.2f px | distance x 2 %.2f px',selected.AngleWidthPx(k),selected.DistanceWidthPx(k))}, ...
        'FontSize',11,'FontWeight','normal');
    plot(ax,selected.X(k)+[20 30],selected.Y(k)+[32 32],'k-','LineWidth',2,'HandleVisibility','off');
    text(ax,selected.X(k)+25,selected.Y(k)+28,'10 px','HorizontalAlignment','center','FontSize',9,'BackgroundColor','w');
end
handles = gobjects(4,1);
handles(1) = plot(overview,nan,nan,'Color',[0.65 0.15 0.55],'LineWidth',1.3);
handles(2) = plot(overview,nan,nan,'Color',[0.1 0.65 0.45],'LineWidth',1.3);
handles(3) = plot(overview,nan,nan,'Color',[0.9 0.4 0.05],'LineWidth',2);
handles(4) = plot(overview,nan,nan,'--','Color',[0.05 0.4 0.7],'LineWidth',1.6);
key = legend(overview,handles,{'ROI boundary','Centerline','Angle-fixed cross-section','Distance radius (approx.)'}, ...
    'NumColumns',4,'FontSize',11);
key.Layout.Tile = 'south';
title(tiles,'Angle-fixed cross-sections at individual centerline pixels','FontSize',16);
xlabel(tiles,{'White dots: measured centerline pixels. Orange squares: polygon intersections. All close-ups span 80 x 80 pixels.'; ...
    'Blue circles illustrate quasi-Euclidean distance radii; raster and metric effects mean they need not touch the polygon exactly.'},'FontSize',10);
exportgraphics(fig,fullfile(root,'comparison_preview','width_cross_sections.png'),'Resolution',160);
exportgraphics(fig,fullfile(root,'comparison_preview','width_cross_sections.pdf'),'ContentType','vector');
disp(selected(:,{'Example','Angle','X','Y','DistanceWidthPx','AngleWidthPx','DifferencePx'}));

    function showImage(ax)
        imagesc(ax,repmat(double(data.IMG{eye})/255,1,1,3)); hold(ax,'on');
        polygon = data.ROIxy{eye}; polygon = [polygon;polygon(1,:)];
        plot(ax,polygon(:,1),polygon(:,2),'Color',[0.65 0.15 0.55],'LineWidth',1.1,'HandleVisibility','off');
        plot(ax,points.X,points.Y,'Color',[0.1 0.65 0.45],'LineWidth',1.1,'HandleVisibility','off');
        axis(ax,'image'); ax.YDir = 'reverse'; ax.XTick = []; ax.YTick = []; ax.Box = 'on';
    end

    function drawSection(ax,k,showCircle)
        if showCircle
            theta = linspace(0,2*pi,160); radius = selected.DistanceWidthPx(k)/2;
            plot(ax,selected.X(k)+radius*cos(theta),selected.Y(k)+radius*sin(theta), ...
                '--','Color',[0.05 0.4 0.7],'LineWidth',1.6,'HandleVisibility','off');
        end
        segmentX = [selected.SectionX1(k),selected.SectionX2(k)];
        segmentY = [selected.SectionY1(k),selected.SectionY2(k)];
        assert(abs(hypot(diff(segmentX),diff(segmentY))-selected.AngleWidthPx(k))<1e-8);
        plot(ax,segmentX,segmentY,'-s','Color',[0.9 0.4 0.05], ...
            'LineWidth',2,'MarkerSize',4,'MarkerFaceColor',[0.9 0.4 0.05],'HandleVisibility','off');
        plot(ax,selected.X(k),selected.Y(k),'wo','MarkerFaceColor','w', ...
            'MarkerEdgeColor',[0.2 0.2 0.2],'MarkerSize',5,'HandleVisibility','off');
    end
end
