function test_layerwidth_profiles
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
file = fullfile(root,'examples','DMSO_4dpi.mat'); loaded = load(file); data = loaded.DMSO_4dpi;
fields = {'IMG','IMGname','ROIxy','ROIBW','CLine'};
for field = fields, data.(field{1}) = data.(field{1})(1:2); end
fig = uifigure('Visible','off','Position',[100 100 1180 780]); cleanup = onCleanup(@() delete(fig));
grid = uigridlayout(fig,[1 1]); tabs = uitabgroup(grid); tab = uitab(tabs,'Title','Widths');
api = layerwidth_workspace(tab,root); api.SetData(data,file); api.Activate();
[results,~,summary] = api.GetResults(); points = results{1};
assert(summary.IncludedPoints==nnz(points.LocalValid));
imageAx = findall(fig,'Tag','WidthImageAxes'); profileAx = findall(fig,'Tag','WidthProfileAxes');
assert(isequal(imageAx.XLim,[.5 size(data.IMG{1},2)+.5]));
assert(isequal(imageAx.YLim,[.5 size(data.IMG{1},1)+.5]));
raw = findall(fig,'Tag','WidthRawProfile'); curve = findall(fig,'Tag','WidthLocalProfile');
[angles,order] = sort(points.Angle); widths = points.LocalWidthPx; widths(~points.LocalValid) = NaN;
assert(isequal(raw.XData(:),angles) && isequaln(raw.YData(:),widths(order)));
assert(profileAx.YLim(1)<=min(widths,[],'omitnan') && profileAx.YLim(2)>=max(widths,[],'omitnan'));
bins = layerwidth_bins(points,5,false,'local');
assert(isa(curve,'matlab.graphics.chart.primitive.Stair'));
assert(isequal(curve.XData(:),(0:5:180)'));
assert(isequaln(curve.YData(:),[bins.LocalMedianPx;bins.LocalMedianPx(end)]));
binMenu = findall(fig,'Tag','WidthBin');
for width = [1 10 5]
    binMenu.Value = width; feval(binMenu.ValueChangedFcn,binMenu,[]);
    expectedBins = layerwidth_bins(points,width,false,'local');
    curve = findall(fig,'Tag','WidthLocalProfile');
    assert(isequal(curve.XData(:),(0:width:180)'));
    assert(isequaln(curve.YData(:),[expectedBins.LocalMedianPx;expectedBins.LocalMedianPx(end)]));
end
raw = findall(fig,'Tag','WidthRawProfile');
labels = string(get(findall(fig,'Type','line'),'DisplayName'));
assert(~any(contains(labels,'Distance x 2') | contains(labels,'Angle-fixed')));

% Reference-method validity must not control the local-only summaries.
referenceInvalid = points; referenceInvalid.ValidPair(:) = false;
assert(isequaln(bins,layerwidth_bins(referenceInvalid,5,false,'local')));
assert(all(layerwidth_bins(referenceInvalid,5,false).Points==0));
assert(sum(bins.Points)==nnz(points.LocalValid));
for b = 1:height(bins)
    included = points.LocalValid & points.Angle>=bins.Angle(b)-2.5 & ...
        (points.Angle<bins.Angle(b)+2.5 | (b==height(bins) & points.Angle==180));
    if nnz(included)>1
        assert(isequal([bins.LocalQ25Px(b),bins.LocalQ75Px(b)],prctile(points.LocalWidthPx(included),[25 75])));
    end
end
sparse = points(1:2,:); sparse.Angle = [0;180]; sparse.LocalValid(:) = true;
sparse.LocalWidthPx = [10;20]; sparse.EndpointRisk(:) = false;
sparseBins = layerwidth_bins(sparse,5,false,'local');
assert(sparseBins.Points(1)==1 && sparseBins.Points(end)==1);
assert(all(isnan(sparseBins.LocalQ25Px)) && all(isnan(sparseBins.LocalQ75Px)));
assert(sparseBins.LocalMedianPx(1)==10 && sparseBins.LocalMedianPx(end)==20);

rows = find(points.LocalValid);
[~,uniqueRows] = unique([points.Angle(rows),points.LocalWidthPx(rows)],'rows','stable');
q = rows(uniqueRows(round(end/2)));
xlim(imageAx,[100 300]); ylim(imageAx,[100 300]);
xlim(profileAx,[20 160]); ylim(profileAx,[0 60]);
event = struct('IntersectionPoint',[points.Angle(q),points.LocalWidthPx(q),0]);
feval(raw.ButtonDownFcn,raw,event);
assertSelection(q);
assert(isequal(imageAx.XLim,[100 300]) && isequal(profileAx.XLim,[20 160]));
assert(isequal(imageAx.YLim,[100 300]) && isequal(profileAx.YLim,[0 60]));
section = findall(fig,'Tag','WidthLocalSection');
assert(isequal(section.XData,[points.LocalSectionX1(q),points.LocalSectionX2(q)]));
assert(isequal(section.YData,[points.LocalSectionY1(q),points.LocalSectionY2(q)]));

% Clicks on the median or plot background also resolve to an actual measurement.
q2 = rows(uniqueRows(10)); event.IntersectionPoint = [points.Angle(q2),points.LocalWidthPx(q2),0];
curve = findall(fig,'Tag','WidthLocalProfile'); feval(curve.ButtonDownFcn,curve,event); assertSelection(q2);
event.IntersectionPoint = [points.Angle(q),points.LocalWidthPx(q),0];
feval(profileAx.ButtonDownFcn,profileAx,event); assertSelection(q);
api.SetBusy(true);
event.IntersectionPoint = [points.Angle(q2),points.LocalWidthPx(q2),0];
feval(profileAx.ButtonDownFcn,profileAx,event); assertSelection(q);
api.SetBusy(false);
iqrToggle = findall(fig,'Tag','WidthIQR'); assert(~iqrToggle.Value);
assert(isempty(findall(fig,'Tag','WidthIQRBand')));
iqrToggle.Value = true; feval(iqrToggle.ValueChangedFcn,iqrToggle,[]);
band = findall(fig,'Tag','WidthIQRBand'); assert(isscalar(band));
validBins = isfinite(bins.LocalQ25Px);
assert(isequal(band.YData,[bins.LocalQ25Px(validBins),bins.LocalQ75Px(validBins), ...
    bins.LocalQ75Px(validBins),bins.LocalQ25Px(validBins)]'));
left = bins.Angle(validBins)-2.5; right = bins.Angle(validBins)+2.5;
assert(isequal(band.XData,[left left right right]'));
assertSelection(q);
assert(isequal(imageAx.XLim,[100 300]) && isequal(profileAx.XLim,[20 160]));
feval(band.ButtonDownFcn,band,event); assertSelection(q2);
iqrToggle.Value = false; feval(iqrToggle.ValueChangedFcn,iqrToggle,[]);
assert(isempty(findall(fig,'Tag','WidthIQRBand')));
assertSelection(q2);

angle = findall(fig,'Tag','WidthQCAngle'); angle.Value = 45; feval(angle.ValueChangedFcn,angle,[]);
[~,expected] = min(abs(points.Angle-45)); assertSelection(expected);
ends = findall(fig,'Tag','WidthExcludeEnds'); ends.Value = true; feval(ends.ValueChangedFcn,ends,[]);
raw = findall(fig,'Tag','WidthRawProfile'); widths(points.EndpointRisk) = NaN;
assert(isequaln(raw.YData(:),widths(order)));
next = findall(fig,'Tag','WidthNext'); feval(next.ButtonPushedFcn,next,[]);
assert(isequal(imageAx.XLim,[.5 size(data.IMG{2},2)+.5]));
assert(isequal(imageAx.YLim,[.5 size(data.IMG{2},1)+.5]));
assert(findall(fig,'Tag','WidthPrevious').Layout.Column+1==next.Layout.Column);
% Distinct widths at an identical rounded angle must retain the exact clicked row.
data.CLine{1}.angle(:) = 30;
data.CLine{1}.angle([100 400]) = 90;
api.SetData(data,file); api.Activate(); [results,~,~] = api.GetResults(); points = results{1};
assert(points.LocalValid(100) && points.LocalValid(400));
assert(abs(points.LocalWidthPx(100)-points.LocalWidthPx(400))>0.1);
raw = findall(fig,'Tag','WidthRawProfile');
event.IntersectionPoint = [90,points.LocalWidthPx(400),0];
feval(raw.ButtonDownFcn,raw,event); assertSelection(400);
iqrToggle.Value = true; feval(iqrToggle.ValueChangedFcn,iqrToggle,[]); assertSelection(400);
curve = findall(fig,'Tag','WidthLocalProfile');
sparseBins = layerwidth_bins(points,5,true,'local');
assert(isequaln(curve.YData(:),[sparseBins.LocalMedianPx;sparseBins.LocalMedianPx(end)]));
assert(any(isnan(curve.YData)));
fig.Position = [100 100 1000 700]; fig.Visible = 'on'; drawnow; pause(1); drawnow;
exportapp(fig,fullfile(tempdir,'rpegen_width_profiles_compact.png'));
disp('Local-only profiles passed: full image, raw/binned data, linked point clicks, IQR values/toggle/sparse bins, busy guard, zoom, exclusions, and navigation.');

    function assertSelection(row)
        selected = findall(fig,'Tag','WidthSelectedPoint'); location = findall(fig,'Tag','WidthSelectedLocation');
        assert(selected.UserData==row && location.UserData==row);
        assert(selected.XData==points.Angle(row) && selected.YData==points.LocalWidthPx(row));
        assert(location.XData==points.X(row) && location.YData==points.Y(row));
    end
end
