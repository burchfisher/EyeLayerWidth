function api = layerwidth_workspace(tab,root,onBusy)
% Local-normal width profiles and linked geometry inspection.
if nargin<3, onBusy = @(~) []; end
data = []; source = ''; cache = {}; details = {}; running = false; blocked = false;
windowValue = 25;
selectedPoint = []; selectedPointEye = 0;
sourceFiles = {}; sourceStamp = [];
layout = uigridlayout(tab,[5 1],'RowHeight',{30,34,30,'1x',44});
sourceRow = uigridlayout(layout,[1 2],'ColumnWidth',{50,'1x'},'Padding',[0 0 0 0]);
uilabel(sourceRow,'Text','Group');
sourceMenu = uidropdown(sourceRow,'Items',{'No results loaded'},'Enable','off', ...
    'Tag','WidthGroup','ValueChangedFcn',@sourceChanged, ...
    'Tooltip','Loaded groups. Selecting a group computes its first eye from saved geometry; no extraction rerun.');
navigation = uigridlayout(layout,[1 7],'ColumnWidth',{36,36,'1x',60,140,140,140},'Padding',[0 0 0 0]);
previous = uibutton(navigation,'Text','<','Tooltip','Previous eye (Left Arrow)','ButtonPushedFcn',@previousEye,'Tag','WidthPrevious');
next = uibutton(navigation,'Text','>','Tooltip','Next eye (Right Arrow)','ButtonPushedFcn',@nextEye,'Tag','WidthNext');
sample = uidropdown(navigation,'Items',{'No results loaded'},'ValueChangedFcn',@activate,'Tag','WidthSample');
counter = uilabel(navigation,'Text','0 / 0','HorizontalAlignment','center');
allButton = uibutton(navigation,'Text','Measure All Eyes','ButtonPushedFcn',@measureClicked,'Tag','WidthMeasureAll');
exportButton = uibutton(navigation,'Text','Export Results...','ButtonPushedFcn',@exportClicked,'Tag','WidthExport');
figureButton = uibutton(navigation,'Text','Export Figure...','ButtonPushedFcn',@figureClicked,'Tag','WidthExportFigure');
options = uigridlayout(layout,[1 9],'ColumnWidth',{60,75,70,105,180,110,80,120,'1x'},'Padding',[0 0 0 0]);
qcAngleLabel = uilabel(options,'Text','QC angle');
qcAngle = uispinner(options,'Limits',[0 180],'Value',90,'Step',1,'ValueChangedFcn',@angleChanged,'Tag','WidthQCAngle');
uilabel(options,'Text','Profile bin');
bin = uidropdown(options,'Items',{'1 degree','5 degrees','10 degrees'},'ItemsData',[1 5 10], ...
    'Value',5,'ValueChangedFcn',@refresh,'Tag','WidthBin');
excludeEnds = uicheckbox(options,'Text','Exclude end regions','Value',false,'ValueChangedFcn',@refresh,'Tag','WidthExcludeEnds', ...
    'Tooltip','Optional radius-based end-region exclusion; shortened fitting windows are retained by default');
uilabel(options,'Text','Total window (px)');
fitWindow = uispinner(options,'Limits',[1 1000],'Value',windowValue,'Step',1, ...
    'ValueChangedFcn',@windowChanged,'Tag','WidthWindow', ...
    'Tooltip','Total distance along the centerline, not a point count. Half before and half after; unavailable portions shorten at tips.');
halfWindow = uilabel(options,'Text','+/- 12.5 px','Tag','WidthHalfWindow');
views = uitabgroup(layout,'Tag','WidthViews');
plotTab = uitab(views,'Title','Profiles'); pointTab = uitab(views,'Title','Measurements'); summaryTab = uitab(views,'Title','Eye Summary');
plotGrid = uigridlayout(plotTab,[2 1],'RowHeight',{28,'1x'},'Padding',[0 0 0 0]);
iqrToggle = uicheckbox(plotGrid,'Text','Show within-bin IQR','Value',false, ...
    'Tooltip','25th-75th percentiles of widths within each angular bin of this eye; not a confidence interval', ...
    'ValueChangedFcn',@refresh,'Tag','WidthIQR');
panel = uipanel(plotGrid,'BorderType','none');
tiles = tiledlayout(panel,1,2,'TileSpacing','compact','Padding','compact');
imageAxes = nexttile(tiles); profileAxes = nexttile(tiles);
pointGrid = uigridlayout(pointTab,[1 1]); pointTable = uitable(pointGrid,'ColumnEditable',false,'Tag','WidthMeasurements');
summaryGrid = uigridlayout(summaryTab,[1 1]); summaryTable = uitable(summaryGrid,'ColumnEditable',false,'Tag','WidthSummary');
status = uilabel(layout,'Text','No groups loaded','WordWrap','on','Tag','WidthStatus');
groupTab = uitab(views,'Title','Group Profiles');
groupProfiles = layerwidth_group_tab(groupTab,root,@groupBusy);
views.SelectionChangedFcn = @changeView;
api.SetData = @setData; api.SetBusy = @setBusy; api.Activate = @activate;
api.SetSources = @setSources;
api.Clear = @clearGroups;
api.Step = @step;
api.MeasureAll = @measureAll; api.Export = @writeResults; api.ExportFigure = @writeFigure;
api.ExportFigures = @writeAllFigures;
api.GetResults = @getResults;
api.GroupProfiles = groupProfiles;
updateControls();
qcAngle.Tooltip = 'Select the measurement nearest this angular position; click a profile point to select its exact centerline location.';
bin.Tooltip = 'Angular interval for individual-eye or group profiles. Does not change individual widths or Eye Summary. Replot groups after changing it.';
summaryTable.Tooltip = 'One row per measured eye. LocalMedianPx is the median of included point widths, not bin medians. Click ? for column definitions.';
pointTable.Tooltip = 'One row per centerline point; LocalWidthPx is the full cross-section. LocalValid marks usable geometry. Click ? for definitions.';

    function setSources(files)
        sourceFiles = cellstr(string(files));
        updateSources();
    end

    function clearGroups()
        assert(~running && ~blocked,'EyeLayerWidth:Busy','A calculation is running.');
        data = []; source = ''; sourceFiles = {}; sourceStamp = [];
        cache = {}; details = {}; selectedPoint = []; selectedPointEye = 0;
        sample.Items = {'No results loaded'};
        cla(imageAxes,'reset'); cla(profileAxes,'reset');
        pointTable.Data = table; summaryTable.Data = table;
        status.Text = 'No groups loaded'; updateSources();
    end

    function updateSources()
        files = sourceFiles(:)';
        if ~isempty(source), files = unique([files {source}],'stable'); end
        if isempty(files)
            sourceMenu.Items = {'No results loaded'}; sourceMenu.ItemsData = {};
        else
            labels = cell(size(files));
            for j = 1:numel(files), [~,labels{j}] = fileparts(files{j}); end
            sourceMenu.ItemsData = {}; sourceMenu.Items = labels; sourceMenu.ItemsData = files;
            if ~isempty(source), sourceMenu.Value = source; end
        end
        groupProfiles.SetSources(files);
        updateControls();
    end

    function sourceChanged(~,~)
        if running || blocked, return; end
        try
            loadSource(sourceMenu.Value); activate();
        catch problem
            if ~isempty(source), sourceMenu.Value = source; end
            showError(problem);
        end
    end

    function loadSource(file)
        setData(layerwidth_load_group(file),file,true);
    end

    function setData(incoming,file,reuseGroupCache)
        if nargin<3 || ~reuseGroupCache, groupProfiles.InvalidateSource(file); end
        data = incoming; source = file;
        entry = dir(file); sourceStamp = [];
        if ~isempty(entry), sourceStamp = [entry.bytes entry.datenum]; end
        selectedPoint = []; selectedPointEye = 0;
        cache = cell(numel(data.IMGname),1); details = cache;
        sample.Items = cellstr(string(data.IMGname(:)))'; sample.Value = sample.Items{1};
        cla(imageAxes,'reset'); cla(profileAxes,'reset'); pointTable.Data = table; summaryTable.Data = table;
        status.Text = 'Ready'; updateSources();
    end

    function setBusy(value)
        blocked = value; groupProfiles.SetBusy(value); updateControls();
    end

    function groupBusy(value)
        setBusy(value); onBusy(value);
    end

    function syncGroupSettings()
        groupProfiles.SetSettings(struct('Window',windowValue,'Bin',bin.Value,'ExcludeEnds',excludeEnds.Value));
        if ~isempty(data), groupProfiles.SeedMeasurements(source,cache,details,data.IMGname,windowValue,sourceStamp); end
    end

    function changeView(~,~)
        isGroup = views.SelectedTab==groupTab;
        navigation.Visible = matlab.lang.OnOffSwitchState(~isGroup);
        sourceRow.Visible = navigation.Visible; status.Visible = navigation.Visible;
        qcAngle.Visible = navigation.Visible; qcAngleLabel.Visible = navigation.Visible;
        if isGroup
            layout.RowHeight = {0,0,30,'1x',0};
            options.ColumnWidth = {0,0,70,105,180,110,80,120,'1x'};
            syncGroupSettings();
        else
            layout.RowHeight = {30,34,30,'1x',44};
            options.ColumnWidth = {60,75,70,105,180,110,80,120,'1x'};
            activate();
        end
    end

    function k = selectedEye()
        if isempty(data), k = 0; else, k = find(strcmp(data.IMGname,sample.Value),1); end
    end

    function updateControls()
        k = selectedEye(); count = numel(cache); available = ~running && ~blocked && k>0;
        sourceMenu.Enable = matlab.lang.OnOffSwitchState(~running && ~blocked && ~isempty(sourceMenu.ItemsData));
        controls = {sample,allButton,exportButton,qcAngle,bin,excludeEnds,fitWindow,iqrToggle};
        for j = 1:numel(controls), controls{j}.Enable = matlab.lang.OnOffSwitchState(available); end
        settingsAvailable = ~running && ~blocked && ~isempty(sourceMenu.ItemsData);
        for control = {bin,excludeEnds,fitWindow}, control{1}.Enable = matlab.lang.OnOffSwitchState(settingsAvailable); end
        remaining = nnz(cellfun(@isempty,cache));
        if count>0 && remaining==0
            allButton.Text = 'All Eyes Measured';
        else
            allButton.Text = sprintf('Measure %d More',remaining);
        end
        allButton.Enable = matlab.lang.OnOffSwitchState(available && remaining>0);
        allButton.Tooltip = sprintf(['%d of %d eyes are measured. Visiting an eye measures it automatically. ' ...
            'Measure the remaining %d eyes to complete Eye Summary; cached eyes are skipped.'],count-remaining,count,remaining);
        previous.Enable = matlab.lang.OnOffSwitchState(available && k>1);
        next.Enable = matlab.lang.OnOffSwitchState(available && k<count);
        figureButton.Enable = matlab.lang.OnOffSwitchState(available && ~isempty(cache{k}));
        counter.Text = sprintf('%d / %d',k,count);
    end

    function measure(indices)
        assert(~running && ~blocked,'EyeLayerWidth:Widths','Another calculation is running.');
        running = true; onBusy(true); updateControls();
        cleanup = onCleanup(@() finish());
        for k = indices
            if ~isempty(cache{k}), continue; end
            status.Text = sprintf('Measuring widths: %s (%d / %d)',data.IMGname{k},k,numel(cache)); drawnow;
            [cache{k},details{k}] = layerwidth_measure_eye(data,k,windowValue);
        end
    end

    function windowChanged(~,~)
        if running || blocked, fitWindow.Value = windowValue; return; end
        windowValue = fitWindow.Value;
        halfWindow.Text = sprintf('+/- %g px',windowValue/2);
        cache = cell(size(cache)); details = cell(size(details));
        pointTable.Data = table; summaryTable.Data = table;
        syncGroupSettings();
        if views.SelectedTab==groupTab, return; end
        activate();
    end

    function finish()
        running = false; onBusy(false); updateControls();
    end

    function activate(varargin)
        if running || blocked, return; end
        syncGroupSettings();
        if views.SelectedTab==groupTab, return; end
        try
            if isempty(data) && ~isempty(sourceMenu.ItemsData), loadSource(sourceMenu.Value); end
            if isempty(data), return; end
            [groupEyes,groupDetails] = groupProfiles.GetMeasurements(source,windowValue,sourceStamp);
            if numel(groupEyes)==numel(cache)
                for j = 1:numel(cache)
                    if isempty(cache{j}) && ~isempty(groupEyes{j}), cache{j} = groupEyes{j}; details{j} = groupDetails{j}; end
                end
            end
            measure(selectedEye()); refresh();
        catch problem
            cla(imageAxes,'reset'); cla(profileAxes,'reset'); pointTable.Data = table;
            showError(problem);
        end
    end

    function previousEye(~,~)
        step(-1);
    end

    function nextEye(~,~)
        step(1);
    end

    function step(delta)
        if isempty(data) || running || blocked || views.SelectedTab==groupTab, return; end
        k = max(1,min(numel(cache),selectedEye()+delta));
        sample.Value = sample.Items{k}; activate();
    end

    function measureAll()
        assert(~isempty(data),'EyeLayerWidth:Widths','Load saved results first.');
        measure(1:numel(cache)); refresh();
    end

    function measureClicked(~,~)
        try
            measureAll();
        catch problem
            showError(problem);
        end
    end

    function refresh(varargin)
        syncGroupSettings();
        if views.SelectedTab==groupTab, return; end
        k = selectedEye();
        if k==0 || isempty(cache{k}), return; end
        preserveView = isequal(imageAxes.UserData,k);
        preserveProfile = isequal(profileAxes.UserData,[k bin.Value windowValue excludeEnds.Value]);
        limits = [imageAxes.XLim;imageAxes.YLim];
        profileLimits = [profileAxes.XLim;profileAxes.YLim];
        drawPlots(imageAxes,profileAxes,k);
        if preserveView
            xlim(imageAxes,limits(1,:)); ylim(imageAxes,limits(2,:));
        end
        if preserveProfile
            xlim(profileAxes,profileLimits(1,:)); ylim(profileAxes,profileLimits(2,:));
        end
        columns = cache{k}.Properties.VariableNames;
        pointTable.Data = cache{k}(:,ismember(columns,{'Point','Angle','X','Y','EndpointRisk'}) | startsWith(columns,'Local'));
        summaryTable.Data = summarize();
        points = cache{k}; valid = usable(points);
        q = inspectedPoint(points,k);
        status.Text = sprintf(['%d / %d eyes measured | %d / %d included points | Point %d, (%.0f, %.0f), %.1f deg: %.2f px | ' ...
            'window %g = %.1f before + %.1f after | shortened %d, local valid %d, multiple segments %d'], ...
            nnz(~cellfun(@isempty,cache)),numel(cache),nnz(valid),height(points), ...
            points.Point(q),points.X(q),points.Y(q),points.Angle(q),points.LocalWidthPx(q), ...
            windowValue,points.LocalWindowBeforePx(q),points.LocalWindowAfterPx(q), ...
            points.LocalWindowShortened(q),points.LocalValid(q),points.LocalMultipleSegments(q));
        updateControls();
    end

    function valid = usable(points)
        valid = points.LocalValid & isfinite(points.LocalWidthPx);
        if excludeEnds.Value, valid = valid & ~points.EndpointRisk; end
    end

    function q = inspectedPoint(points,k)
        if selectedPointEye==k && ~isempty(selectedPoint) && selectedPoint<=height(points)
            q = selectedPoint;
        else
            [~,q] = min(abs(points.Angle-qcAngle.Value));
        end
    end

    function angleChanged(varargin)
        if running || blocked, return; end
        selectedPoint = []; selectedPointEye = 0;
        refresh();
    end

    function selectProfilePoint(~,event)
        k = selectedEye();
        if running || blocked || k==0 || isempty(cache{k}), return; end
        points = cache{k}; rows = find(usable(points));
        if isempty(rows), return; end
        location = event.IntersectionPoint;
        % Screen-scaled distance distinguishes points with the same rounded angle.
        scale = max([diff(profileAxes.XLim),diff(profileAxes.YLim)],eps);
        distance = ((points.Angle(rows)-location(1))/scale(1)).^2 + ...
            ((points.LocalWidthPx(rows)-location(2))/scale(2)).^2;
        [~,nearest] = min(distance);
        selectedPoint = rows(nearest); selectedPointEye = k;
        qcAngle.Value = points.Angle(selectedPoint);
        refresh();
    end

    function result = summarize()
        indices = find(~cellfun(@isempty,cache));
        names = strings(numel(indices),1); values = nan(numel(indices),5);
        for j = 1:numel(indices)
            k = indices(j); points = cache{k}; valid = usable(points);
            names(j) = string(data.IMGname{k});
            values(j,:) = [height(points),nnz(valid),median(points.LocalWidthPx(valid),'omitnan'), ...
                nnz(points.LocalWindowShortened & valid),windowValue];
        end
        result = array2table(values,'VariableNames',{'TotalPoints','IncludedPoints', ...
            'LocalMedianPx','ShortWindowPoints','LocalWindowTotalPx'});
        result = addvars(result,names,'Before',1,'NewVariableNames','Eye');
    end

    function drawPlots(imageAx,profileAx,k)
        points = cache{k}; xy = data.ROIxy{k}; xy = [xy;xy(1,:)];
        q = inspectedPoint(points,k);
        img = data.IMG{k}; if ismatrix(img), img = repmat(double(img)/255,1,1,3); end
        cla(imageAx,'reset'); imagesc(imageAx,img,'HandleVisibility','off'); hold(imageAx,'on');
        plot(imageAx,xy(:,1),xy(:,2),'Color',[0.65 0.15 0.55],'LineWidth',1,'DisplayName','ROI');
        [path,order] = sort(points.LocalPathDistancePx); ordered = [points.X(order),points.Y(order)];
        plot(imageAx,ordered(:,1),ordered(:,2),'Color',[0.1 0.65 0.45],'DisplayName','Centerline');
        lo = points.LocalPathDistancePx(q)-points.LocalWindowBeforePx(q);
        hi = points.LocalPathDistancePx(q)+points.LocalWindowAfterPx(q);
        support = [interp1(path,ordered,lo);ordered(path>lo & path<hi,:);interp1(path,ordered,hi)];
        plot(imageAx,support(:,1),support(:,2),'Color',[.85 .6 .05],'LineWidth',2,'DisplayName','Fit window','Tag','WidthFitWindow');
        if points.LocalValid(q)
            plot(imageAx,[points.LocalSectionX1(q),points.LocalSectionX2(q)],[points.LocalSectionY1(q),points.LocalSectionY2(q)], ...
                'Color',[.05 .35 .8],'LineWidth',2.4,'DisplayName','Local-normal section','Tag','WidthLocalSection');
        end
        scatter(imageAx,points.X(q),points.Y(q),36,'w','filled','MarkerEdgeColor',[.1 .1 .1], ...
            'HandleVisibility','off','Tag','WidthSelectedLocation','UserData',q);
        hold(imageAx,'off'); axis(imageAx,'image'); imageAx.YDir = 'reverse';
        xlim(imageAx,[0.5,size(data.IMG{k},2)+0.5]);
        ylim(imageAx,[0.5,size(data.IMG{k},1)+0.5]);
        imageAx.XTick = []; imageAx.YTick = [];
        title(imageAx,sprintf('Point %d | %.1f deg | %.2f px',points.Point(q),points.Angle(q),points.LocalWidthPx(q)),'FontSize',11);
        legend(imageAx,'Location','southoutside','NumColumns',2);
        bins = layerwidth_bins(points,bin.Value,excludeEnds.Value,'local');
        cla(profileAx,'reset'); hold(profileAx,'on');
        if iqrToggle.Value
            valid = isfinite(bins.LocalQ25Px) & isfinite(bins.LocalQ75Px);
            left = bins.Angle(valid)-bin.Value/2; right = bins.Angle(valid)+bin.Value/2;
            lower = bins.LocalQ25Px(valid); upper = bins.LocalQ75Px(valid);
            if any(valid)
                patch(profileAx,'XData',[left left right right]', ...
                    'YData',[lower upper upper lower]','FaceColor',[.05 .35 .8], ...
                    'FaceAlpha',0.14,'EdgeColor','none','DisplayName','Within-bin IQR', ...
                    'Tag','WidthIQRBand','ButtonDownFcn',@selectProfilePoint);
            end
        end
        [angles,order] = sort(points.Angle);
        raw = points.LocalWidthPx; raw(~usable(points)) = NaN;
        plot(profileAx,angles,raw(order),'.-','Color',[.48 .56 .62],'LineWidth',0.65,'MarkerSize',5, ...
            'DisplayName','Individual measurements','Tag','WidthRawProfile','ButtonDownFcn',@selectProfilePoint);
        edges = [bins.Angle-bin.Value/2;bins.Angle(end)+bin.Value/2];
        stairs(profileAx,edges,[bins.LocalMedianPx;bins.LocalMedianPx(end)], ...
            'Color',[.05 .35 .8],'LineWidth',1.8, ...
            'DisplayName',sprintf('%d-degree median',bin.Value),'Tag','WidthLocalProfile','ButtonDownFcn',@selectProfilePoint);
        xline(profileAx,points.Angle(q),':','HandleVisibility','off','HitTest','off','PickableParts','none');
        if points.LocalValid(q)
            scatter(profileAx,points.Angle(q),points.LocalWidthPx(q),48,[.85 .3 .08],'filled', ...
                'DisplayName','Selected measurement','Tag','WidthSelectedPoint','UserData',q, ...
                'ButtonDownFcn',@selectProfilePoint);
        end
        hold(profileAx,'off'); xlim(profileAx,[0 180]); grid(profileAx,'on');
        visibleWidths = raw(isfinite(raw));
        if points.LocalValid(q), visibleWidths(end+1) = points.LocalWidthPx(q); end
        if isempty(visibleWidths)
            ylim(profileAx,[0 1]);
        else
            bounds = [min(visibleWidths),max(visibleWidths)];
            margin = max(1,0.05*diff(bounds));
            ylim(profileAx,[max(0,bounds(1)-margin),bounds(2)+margin]);
        end
        ylabel(profileAx,'Width (pixels)'); xlabel(profileAx,'Angular distance (degrees)');
        title(profileAx,sprintf('Local-normal width | %g px window',windowValue),'FontSize',11);
        legend(profileAx,'Location','southoutside','FontSize',9);
        if profileAx==profileAxes
            disableDefaultInteractivity(profileAx);
            profileAx.ButtonDownFcn = @selectProfilePoint;
        end
        imageAx.Tag = 'WidthImageAxes'; profileAx.Tag = 'WidthProfileAxes';
        imageAx.UserData = k;
        profileAx.UserData = [k bin.Value windowValue excludeEnds.Value];
    end

    function exportClicked(~,~)
        [name,folder] = uiputfile({'*.csv','CSV';'*.mat','MAT file'},'Export all-eye width measurements',fullfile(root,'width_comparison.csv'));
        if isequal(name,0), return; end
        try
            writeResults(fullfile(folder,name));
        catch problem
            showError(problem);
        end
    end

    function writeResults(file)
        measureAll();
        measurements = table; profiles = table;
        for k = 1:numel(cache)
            eye = cache{k}; eye.IncludedInProfile = usable(eye);
            eye.Eye = repmat(string(data.IMGname{k}),height(eye),1);
            eye.SourceFile = repmat(string(source),height(eye),1);
            eye.DistanceMetric = repmat("quasi-euclidean",height(eye),1);
            eye.LocalDistanceMetric = repmat("euclidean",height(eye),1);
            eye.LocalWindowUnits = repmat("pixel-distance",height(eye),1);
            measurements = [measurements;eye]; %#ok<AGROW>
            profile = layerwidth_bins(cache{k},bin.Value,excludeEnds.Value,'local');
            profile.Eye = repmat(string(data.IMGname{k}),height(profile),1);
            profile.SourceFile = repmat(string(source),height(profile),1);
            profile.BinWidthDegrees = repmat(bin.Value,height(profile),1);
            profiles = [profiles;profile]; %#ok<AGROW>
        end
        metadata = struct('SourceFile',source,'EyeDetails',{details},'ProfileBinDegrees',bin.Value, ...
            'ExcludeEndRegions',excludeEnds.Value,'Units','pixels', ...
            'LocalWindowTotalPx',windowValue,'LocalWindowHalfPx',windowValue/2, ...
            'LocalWindowUnits','pixel-distance','LocalDistanceMetric','euclidean', ...
            'PrimaryMethod','local-normal','ProfileValidity','LocalValid and finite LocalWidthPx; optional EndpointRisk exclusion', ...
            'IQRPercentiles',[25 75],'IQRMinPoints',2,'IQRVisible',iqrToggle.Value, ...
            'ReferenceColumns','Distance and angle-fixed columns retained for compatibility; not used for profile inclusion');
        summary = summarize();
        [~,~,extension] = fileparts(file);
        if strcmpi(extension,'.csv')
            writetable(measurements,file);
        elseif strcmpi(extension,'.mat')
            save(file,'measurements','profiles','metadata','summary');
        else
            error('EyeLayerWidth:Widths','Choose CSV or MAT format.');
        end
    end

    function figureClicked(~,~)
        if running || blocked, return; end
        parent = ancestor(tab,'figure');
        choice = uiconfirm(parent,'Export the current eye or every eye in the selected group?', ...
            'Export Width Figures','Options',{'Current Eye','All Eyes','Cancel'}, ...
            'DefaultOption',1,'CancelOption',3);
        if strcmp(choice,'Cancel'), return; end
        try
            if strcmp(choice,'All Eyes')
                folder = uigetdir(fileparts(source),'Export all-eye width PDFs');
                if isequal(folder,0), return; end
                files = figureFiles(folder);
                if any(isfile(files))
                    replace = uiconfirm(parent,'Replace existing width PDFs in this folder?', ...
                        'Existing Width PDFs','Options',{'Replace','Cancel'},'DefaultOption',2,'CancelOption',2);
                    if ~strcmp(replace,'Replace'), return; end
                end
                writeAllFigures(folder);
            else
                [name,folder] = uiputfile({'*.pdf','Vector PDF'},'Export width profile',fullfile(root,'width_profile.pdf'));
                if isequal(name,0), return; end
                writeFigure(fullfile(folder,name));
            end
        catch problem
            showError(problem);
        end
    end

    function files = figureFiles(folder)
        [~,groupName] = fileparts(source);
        files = cell(numel(cache),1);
        for k = 1:numel(cache)
            files{k} = fullfile(folder,sprintf('%s_eye_%03d_widths.pdf',groupName,k));
        end
    end

    function files = writeAllFigures(folder)
        assert(isfolder(folder),'EyeLayerWidth:Widths','Select an existing output folder.');
        measureAll();
        files = figureFiles(folder);
        running = true; onBusy(true); updateControls();
        cleanup = onCleanup(@finish);
        for k = 1:numel(files)
            status.Text = sprintf('Exporting width PDF %d / %d: %s',k,numel(files),data.IMGname{k});
            drawnow;
            writeFigure(files{k},k);
        end
        clear cleanup;
        status.Text = sprintf('Exported %d width PDFs to %s',numel(files),folder);
    end

    function writeFigure(file,k)
        if nargin<2, k = selectedEye(); end
        assert(k>0 && ~isempty(cache{k}),'EyeLayerWidth:Widths','Measure an eye first.');
        fig = figure('Visible','off','Color','w','Position',[100 100 1200 600]);
        cleanup = onCleanup(@() close(fig));
        grid = tiledlayout(fig,1,2,'TileSpacing','compact');
        drawPlots(nexttile(grid),nexttile(grid),k);
        title(grid,data.IMGname{k},'Interpreter','none','FontSize',11);
        note = 'IQR hidden.';
        if iqrToggle.Value, note = 'IQR: within-bin 25th-75th percentiles, not a confidence interval.'; end
        xlabel(grid,{sprintf('Local-normal total window: %g pixel-distance units (+/- %g). End-region exclusion: %d. Widths in pixels.', ...
            windowValue,windowValue/2,excludeEnds.Value);note},'FontSize',9);
        layerwidth_export_figure(fig,file);
    end

    function [results,metadata,summary] = getResults()
        results = cache; metadata = details; summary = summarize();
    end

    function showError(problem)
        status.Text = ['Failed: ' problem.message]; updateControls();
        uialert(ancestor(tab,'figure'),problem.message,'Width Comparison');
    end
end
