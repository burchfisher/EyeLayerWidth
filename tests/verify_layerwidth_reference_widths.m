function verify_layerwidth_reference_widths
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
names = {'DMSO_4dpi','IWR1_4dpi','DMSO_9dpf','IWR1_9dpf'};
audit = table; initialRng = rng;
for g = 1:numel(names)
    file = fullfile(root,'examples',[names{g} '.mat']);
    loaded = load(file); data = loaded.(names{g});
    for k = 1:numel(data.IMGname)
        [points,metadata] = layerwidth_reference_widths(data.ROIxy{k},logical(data.ROIBW{k}),data.CLine{k});
        valid = points.ValidPair & ~points.EndpointRisk;
        assert(any(valid));
        assert(all(points.AngleWidthPx(valid)>0 & points.DistanceWidthPx(valid)>0));
        % Cross-sections follow the saved angular frame, never a local slope.
        expected = [sind(metadata.TiltDegrees-points.Angle),cosd(metadata.TiltDegrees-points.Angle)];
        assert(max(abs(expected-[points.DirectionX,points.DirectionY]),[],'all')<1e-12);
        lengths = hypot(points.SectionX2-points.SectionX1,points.SectionY2-points.SectionY1);
        assert(max(abs(lengths(valid)-points.AngleWidthPx(valid)))<1e-8);
        bins = layerwidth_bins(points,5,true);
        assert(sum(bins.Points)==nnz(valid));
        row = table(string(names{g}),string(data.IMGname{k}),height(points),nnz(valid), ...
            median(points.DistanceWidthPx(valid)),median(points.AngleWidthPx(valid)), ...
            median(points.DifferencePx(valid)),median(abs(points.DifferencePx(valid))), ...
            nnz(points.MultipleSegments),nnz(points.EndpointRisk),metadata.PolygonCleaned, ...
            'VariableNames',{'Group','Eye','TotalPoints','PairedPoints','DistanceMedianPx','AngleMedianPx', ...
            'MedianDifferencePx','MedianAbsoluteDifferencePx','MultipleSegments','EndRegionPoints','PolygonCleaned'});
        audit = [audit;row]; %#ok<AGROW>
    end
end
assert(height(audit)==44 && isequal(initialRng,rng));
writetable(audit,fullfile(root,'comparison_preview','width_method_comparison.csv'));
preview = figure('Visible','off','Color','w','Position',[100 100 1100 500]);
previewCleanup = onCleanup(@() close(preview));
grid = tiledlayout(preview,1,2,'TileSpacing','compact');
left = nexttile(grid); hold(left,'on'); right = nexttile(grid); hold(right,'on');
colors = lines(4); handles = gobjects(4,1);
for g = 1:4
    rows = audit.Group==names{g}; difference = audit.MedianDifferencePx(rows);
    handles(g) = scatter(left,audit.DistanceMedianPx(rows),audit.AngleMedianPx(rows),35,colors(g,:),'filled');
    scatter(right,g+linspace(-0.12,0.12,nnz(rows))',difference,35,colors(g,:),'filled');
    plot(right,[g-0.23 g+0.23],repmat(median(difference),1,2),'Color',colors(g,:),'LineWidth',2);
end
limits = [min([audit.DistanceMedianPx;audit.AngleMedianPx])-1,max([audit.DistanceMedianPx;audit.AngleMedianPx])+1];
plot(left,limits,limits,'k:'); xlim(left,limits); ylim(left,limits); axis(left,'square'); gridOn(left);
xlabel(left,'Distance x 2: per-eye median width (px)'); ylabel(left,'Angle-fixed: per-eye median width (px)');
title(left,'Method comparison | 44 eyes'); legend(left,handles,names,'Interpreter','none','Location','southoutside','NumColumns',2);
yline(right,0,'k:'); xlim(right,[0.5 4.5]); xticks(right,1:4); xticklabels(right,names); right.TickLabelInterpreter = 'none';
ylabel(right,'Per-eye median paired difference (px)'); title(right,'Angle-fixed minus distance x 2'); gridOn(right);
xlabel(grid,'Same valid centerline points for both methods; end regions excluded. Colored horizontal marks: group medians.','FontSize',9);
exportgraphics(preview,fullfile(root,'comparison_preview','width_method_summary.png'),'Resolution',200);
clear previewCleanup;
fprintf('All %d example eyes measured. Median paired method difference across eyes: %.3f px; median absolute difference: %.3f px.\n', ...
    height(audit),median(audit.MedianDifferencePx),median(audit.MedianAbsoluteDifferencePx));

file = fullfile(root,'examples','DMSO_4dpi.mat'); loaded = load(file); data = loaded.DMSO_4dpi;
original = data; fields = {'IMG','IMGname','ROIxy','ROIBW','CLine'};
for field = fields, data.(field{1}) = data.(field{1})(1:2); end
fig = uifigure('Visible','off','Position',[100 100 1180 780]); cleanup = onCleanup(@() delete(fig));
layout = uigridlayout(fig,[1 1]); tabs = uitabgroup(layout); tab = uitab(tabs,'Title','Widths');
events = []; api = layerwidth_workspace(tab,root,@busy); api.SetData(data,file); api.Activate();
[results,~,summary] = api.GetResults();
assert(~isempty(results{1}) && isempty(results{2}) && height(summary)==1);
assert(isequal(events,[true false]));
angle = findall(fig,'Tag','WidthQCAngle'); angle.Value = 45; feval(angle.ValueChangedFcn,angle,[]);
imageAx = findall(fig,'Tag','WidthImageAxes'); limits = [imageAx.XLim;imageAx.YLim];
for j = 1:3, feval(angle.ValueChangedFcn,angle,[]); end
assert(isequal(limits,[imageAx.XLim;imageAx.YLim]));
assert(isscalar(findall(findall(fig,'Tag','WidthImageAxes'),'Type','scatter')));
next = findall(fig,'Tag','WidthNext'); feval(next.ButtonPushedFcn,next,[]);
assert(strcmp(next.Enable,'off') && strcmp(findall(fig,'Tag','WidthPrevious').Enable,'on'));
[results,~,summary] = api.GetResults(); assert(all(~cellfun(@isempty,results)) && height(summary)==2);
ends = findall(fig,'Tag','WidthExcludeEnds'); ends.Value = false; feval(ends.ValueChangedFcn,ends,[]);
shown = findall(fig,'Tag','WidthMeasurements').Data;
assert(isequal(shown.LocalWidthPx,results{2}.LocalWidthPx));
assert(~ismember('DistanceWidthPx',shown.Properties.VariableNames));
api.SetBusy(true); assert(strcmp(next.Enable,'off') && strcmp(ends.Enable,'off'));
api.SetBusy(false); assert(strcmp(ends.Enable,'on'));
api.Export(fullfile(tempdir,'layerwidth_reference_widths.csv')); api.Export(fullfile(tempdir,'layerwidth_reference_widths.mat'));
saved = load(fullfile(tempdir,'layerwidth_reference_widths.mat'));
assert(height(saved.measurements)==height(results{1})+height(results{2}));
assert(isequal(saved.measurements.IncludedInProfile,saved.measurements.LocalValid));
api.ExportFigure(fullfile(root,'comparison_preview','width_comparison_export.pdf'));
api.ExportFigure(fullfile(tempdir,'layerwidth_reference_widths.pdf'));
api.SetData(data,file); [results,~,summary] = api.GetResults();
assert(all(cellfun(@isempty,results)) && isempty(summary));
assert(isequaln(original,loaded.DMSO_4dpi) && isequal(initialRng,rng));
clear cleanup;

fig = EyeLayerWidth_GUI('ResultsFile',file); cleanup = onCleanup(@() delete(fig));
assert(~isempty(findall(fig,'Tag','WidthMeasurements').Data));
feval(fig.WindowKeyPressFcn,fig,struct('Key','pagedown','Modifier',{{}}));
sample = findall(fig,'Tag','WidthSample'); assert(strcmp(sample.Value,sample.Items{2}));
feval(fig.WindowKeyPressFcn,fig,struct('Key','pageup','Modifier',{{}}));
assert(strcmp(sample.Value,sample.Items{1}));
drawnow; pause(1); drawnow;
exportapp(fig,fullfile(root,'comparison_preview','width_comparison_gui.png'));
disp('Width GUI: saved data, navigation, cache, display controls, exports, busy state, and main-app integration passed.');

    function busy(value)
        events(end+1) = value;
    end
end

function gridOn(ax)
ax.XGrid = 'on'; ax.YGrid = 'on';
end
