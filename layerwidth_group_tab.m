function api = layerwidth_group_tab(tab,root,onBusy)
% Cross-group local-width profiles, independent of the inspected eye.
groups = struct('File',{},'Name',{},'Show',{},'Stamp',{},'Eyes',{},'Names',{}, ...
    'Details',{},'Window',{},'Profile',{},'Metadata',{});
settings = struct('Window',25,'Bin',5,'ExcludeEnds',false);
running = false; blocked = false;
layout = uigridlayout(tab,[5 1],'RowHeight',{32,120,28,'1x',36});
actions = uigridlayout(layout,[1 4],'ColumnWidth',{135,130,150,'1x'},'Padding',[0 0 0 0]);
calculateButton = uibutton(actions,'Text','Plot Groups','Tag','WidthGroupCalculate','ButtonPushedFcn',@calculateClicked);
pdfButton = uibutton(actions,'Text','Export PDF...','Tag','WidthGroupExportFigure','ButtonPushedFcn',@exportFigureClicked);
resultsButton = uibutton(actions,'Text','Export Results...','Tag','WidthGroupExportResults','ButtonPushedFcn',@exportResultsClicked);
groupTable = uitable(layout,'Data',cell(0,4),'ColumnName',{'Show','Group','Eyes measured','File'}, ...
    'ColumnEditable',[true true false false],'ColumnFormat',{'logical','char','char','char'}, ...
    'ColumnWidth',{55,180,120,'auto'},'CellEditCallback',@editGroup,'Tag','WidthProfileGroups', ...
    'Tooltip','Loaded treatment groups. Show selects curves and exports. Measurements are cached per group and fitting window.');
toggles = uigridlayout(layout,[1 3],'ColumnWidth',{290,265,'1x'},'Padding',[0 0 0 0]);
pointToggle = uicheckbox(toggles,'Text','Point-based median CI (nominal 95%)','Value',true, ...
    'Tag','WidthGroupPointCI','ValueChangedFcn',@displayChanged, ...
    'Tooltip','How precisely is the pooled median defined IF centerline points are independent? Not the spread of widths. See ? for an example.');
bootstrapToggle = uicheckbox(toggles,'Text','Whole-eye bootstrap CI (95%)','Value',true, ...
    'Tag','WidthGroupBootstrapCI','ValueChangedFcn',@displayChanged, ...
    'Tooltip','How could the same pooled median change with a different sample of eyes? Resamples whole eyes, not separate points. See ? for an example.');
panel = uipanel(layout,'BorderType','none'); tiles = tiledlayout(panel,1,1,'TileSpacing','compact','Padding','compact');
ax = nexttile(tiles); ax.Tag = 'WidthGroupAxes';
status = uilabel(layout,'Text','No groups loaded.','WordWrap','on','Tag','WidthGroupStatus');
api.SetSources = @setSources; api.SetSettings = @setSettings; api.SetBusy = @setBusy;
api.SeedMeasurements = @seedMeasurements; api.Calculate = @calculate;
api.GetMeasurements = @getMeasurements;
api.InvalidateSource = @invalidateSource;
api.GetResults = @getResults; api.HasResults = @ready;
api.ExportFigure = @writeFigure; api.ExportResults = @writeResults;
updateTable(); render(false);

    function stamp = fileStamp(file)
        entry = dir(file);
        if isempty(entry), stamp = []; else, stamp = [entry.bytes entry.datenum]; end
    end

    function invalidateSource(file)
        file = char(java.io.File(file).getCanonicalPath()); k = find(strcmp({groups.File},file),1);
        if isempty(k), return; end
        groups(k).Eyes = {}; groups(k).Details = {}; groups(k).Names = {}; groups(k).Window = NaN;
        groups(k).Profile = table; groups(k).Metadata = struct;
        updateTable(); render(false);
    end

    function setSources(files)
        files = cellstr(string(files)); pending = groups([]);
        for k = 1:numel(files)
            file = char(java.io.File(files{k}).getCanonicalPath());
            if any(strcmp({pending.File},file)), continue; end
            old = find(strcmp({groups.File},file),1); stamp = fileStamp(file);
            if ~isempty(old) && isequal(groups(old).Stamp,stamp)
                pending(end+1) = groups(old); %#ok<AGROW>
            else
                [~,name] = fileparts(file);
                pending(end+1) = struct('File',file,'Name',name,'Show',true,'Stamp',stamp, ...
                    'Eyes',{{}},'Names',{{}},'Details',{{}},'Window',NaN,'Profile',table,'Metadata',struct); %#ok<AGROW>
                if ~isempty(old), pending(end).Name = groups(old).Name; pending(end).Show = groups(old).Show; end
            end
        end
        if isequaln(pending,groups), return; end
        groups = pending; updateTable(); render(false);
    end

    function setSettings(value)
        if isequal(settings,value), return; end
        changedWindow = settings.Window~=value.Window; settings = value;
        for k = 1:numel(groups)
            groups(k).Profile = table; groups(k).Metadata = struct;
            if changedWindow, groups(k).Eyes = {}; groups(k).Details = {}; groups(k).Names = {}; groups(k).Window = NaN; end
        end
        updateTable(); render(false);
    end

    function seedMeasurements(file,eyes,details,names,window,stamp)
        if isempty(file) || window~=settings.Window || all(cellfun(@isempty,eyes)), return; end
        file = char(java.io.File(file).getCanonicalPath());
        k = find(strcmp({groups.File},file),1); if isempty(k), return; end
        if ~isequal(groups(k).Stamp,stamp), return; end
        if isempty(groups(k).Eyes)
            groups(k).Eyes = cell(size(eyes)); groups(k).Details = cell(size(eyes)); groups(k).Names = names; groups(k).Window = window;
        end
        if numel(groups(k).Eyes)~=numel(eyes) || groups(k).Window~=window, return; end
        for j = 1:numel(eyes)
            if isempty(groups(k).Eyes{j}) && ~isempty(eyes{j})
                groups(k).Eyes{j} = eyes{j}; groups(k).Details{j} = details{j};
            end
        end
        updateTable();
    end

    function [eyes,details] = getMeasurements(file,window,stamp)
        eyes = {}; details = {};
        if isempty(file), return; end
        file = char(java.io.File(file).getCanonicalPath()); k = find(strcmp({groups.File},file),1);
        if isempty(k) || groups(k).Window~=window || ~isequal(groups(k).Stamp,stamp), return; end
        eyes = groups(k).Eyes; details = groups(k).Details;
    end

    function setBusy(value)
        blocked = value; updateControls();
    end

    function selected = selectedGroups()
        selected = find([groups.Show]);
    end

    function value = ready()
        selected = selectedGroups();
        value = ~isempty(selected) && all(arrayfun(@(g) ~isempty(g.Profile),groups(selected)));
    end

    function updateControls()
        enabled = ~running && ~blocked;
        calculateButton.Enable = matlab.lang.OnOffSwitchState(enabled && ~isempty(selectedGroups()));
        pdfButton.Enable = matlab.lang.OnOffSwitchState(enabled && ready());
        resultsButton.Enable = pdfButton.Enable;
        if enabled, groupTable.Enable = 'on'; else, groupTable.Enable = 'off'; end
        pointToggle.Enable = groupTable.Enable; bootstrapToggle.Enable = groupTable.Enable;
    end

    function updateTable()
        rows = cell(numel(groups),4);
        for k = 1:numel(groups)
            progress = 'Not measured';
            if ~isempty(groups(k).Eyes)
                progress = sprintf('%d / %d',nnz(~cellfun(@isempty,groups(k).Eyes)),numel(groups(k).Eyes));
            end
            rows(k,:) = {groups(k).Show,groups(k).Name,progress,groups(k).File};
        end
        groupTable.Data = rows; updateControls();
    end

    function editGroup(~,event)
        if running || blocked, return; end
        k = event.Indices(1);
        if event.Indices(2)==1
            groups(k).Show = logical(event.NewData);
        else
            name = strtrim(char(string(event.NewData)));
            if ~isempty(name), groups(k).Name = name; end
        end
        updateTable(); render(false);
    end

    function calculateClicked(~,~)
        try, calculate(); catch problem, showError(problem); end
    end

    function calculate()
        assert(~running && ~blocked,'EyeLayerWidth:WidthGroups','Another calculation is running.');
        assert(~isempty(selectedGroups()),'EyeLayerWidth:WidthGroups','Select at least one group.');
        % Recheck disk identities before reusing measurements from a previous run.
        setSources({groups.File});
        running = true; onBusy(true); updateControls();
        cleanup = onCleanup(@finish);
        for k = selectedGroups()
            if ~isempty(groups(k).Profile), continue; end
            if isempty(groups(k).Eyes) || any(cellfun(@isempty,groups(k).Eyes))
                data = layerwidth_load_group(groups(k).File);
                if isempty(groups(k).Eyes)
                    groups(k).Eyes = cell(numel(data.IMGname),1); groups(k).Details = groups(k).Eyes;
                end
                groups(k).Names = data.IMGname; groups(k).Window = settings.Window;
                assert(numel(groups(k).Eyes)==numel(data.IMGname),'EyeLayerWidth:WidthGroups','Eye list changed; reload the group.');
                for eye = 1:numel(data.IMGname)
                    if ~isempty(groups(k).Eyes{eye}), continue; end
                    status.Text = sprintf('%s: measuring eye %d / %d',groups(k).Name,eye,numel(data.IMGname)); drawnow;
                    [groups(k).Eyes{eye},groups(k).Details{eye}] = layerwidth_measure_eye(data,eye,settings.Window);
                    updateTable();
                end
                clear data;
            end
            status.Text = sprintf('%s: calculating pooled medians and whole-eye bootstrap CIs',groups(k).Name); drawnow;
            [groups(k).Profile,groups(k).Metadata] = layerwidth_group_profile( ...
                groups(k).Eyes,settings.Bin,settings.ExcludeEnds);
        end
        clear cleanup;
        render(false);
    end

    function finish()
        running = false; onBusy(false); updateTable();
    end

    function displayChanged(~,~)
        render(true);
    end

    function render(preserveView)
        limits = [ax.XLim;ax.YLim]; drawPlot(ax);
        if preserveView && ready(), ax.XLim = limits(1,:); ax.YLim = limits(2,:); end
        if ready()
            selected = selectedGroups(); missing = 0;
            for k = selected, missing = missing+nnz(~isfinite(groups(k).Profile.BootstrapCI95L)); end
            status.Text = sprintf('%d groups | pooled point medians | 5,000 whole-eye resamples | pointwise CIs | %d group-bins without a bootstrap CI',numel(selected),missing);
        elseif isempty(groups)
            status.Text = 'No groups loaded.';
        else
            status.Text = 'Selected groups or changed settings have not been calculated.';
        end
        status.Tooltip = status.Text; updateControls();
    end

    function drawPlot(target)
        cla(target,'reset'); target.Tag = 'WidthGroupAxes'; hold(target,'on');
        if ready()
            selected = selectedGroups(); colors = lines(numel(groups));
            for k = selected
                p = groups(k).Profile;
                if bootstrapToggle.Value, drawBand(target,p.Angle,p.BootstrapCI95L,p.BootstrapCI95U,colors(k,:),.14,'WidthGroupBootstrapBand'); end
                if pointToggle.Value, drawBand(target,p.Angle,p.PointCI95L,p.PointCI95U,colors(k,:),.35,'WidthGroupPointBand'); end
            end
            for k = selected
                p = groups(k).Profile; edges = [p.Angle-settings.Bin/2;180];
                stairs(target,edges,[p.MedianWidthPx;p.MedianWidthPx(end)],'Color',colors(k,:),'LineWidth',1.7, ...
                    'DisplayName',sprintf('%s (n = %d eyes)',groups(k).Name,numel(groups(k).Eyes)), ...
                    'Tag','WidthGroupMedian','UserData',groups(k).File);
            end
            legend(target,'Location','southoutside','Interpreter','none');
        else
            legend(target,'off');
        end
        hold(target,'off'); grid(target,'on'); xlim(target,[0 180]);
        xlabel(target,'Angular distance (degrees)'); ylabel(target,'Median width (pixels)');
        title(target,sprintf('Pooled local-normal width | %d-degree bins | %g px window',settings.Bin,settings.Window));
    end

    function drawBand(target,angles,lo,hi,color,alpha,tag)
        valid = isfinite(lo) & isfinite(hi);
        if ~any(valid), return; end
        left = angles(valid)-settings.Bin/2; right = angles(valid)+settings.Bin/2;
        patch(target,'XData',[left,left,right,right]','YData',[lo(valid),hi(valid),hi(valid),lo(valid)]', ...
            'FaceColor',color,'FaceAlpha',alpha,'EdgeColor','none','HandleVisibility','off','Tag',tag);
    end

    function [profiles,metadata] = getResults()
        assert(ready(),'EyeLayerWidth:WidthGroups','Calculate all selected groups first.');
        profiles = table; selected = selectedGroups(); entries = cell(numel(selected),1);
        for j = 1:numel(selected)
            k = selected(j); p = groups(k).Profile;
            p.Group = repmat(string(groups(k).Name),height(p),1);
            p.SourceFile = repmat(string(groups(k).File),height(p),1);
            p.EyesInGroup = repmat(numel(groups(k).Eyes),height(p),1);
            p.WindowTotalPx = repmat(settings.Window,height(p),1);
            p.BinWidthDegrees = repmat(settings.Bin,height(p),1);
            p.ExcludeEndRegions = repmat(settings.ExcludeEnds,height(p),1);
            p.BootstrapIterations = repmat(5000,height(p),1); p.BootstrapSeed = repmat(20261012,height(p),1);
            profiles = [profiles;p]; %#ok<AGROW>
            entries{j} = struct('Name',groups(k).Name,'File',groups(k).File,'EyeNames',{groups(k).Names}, ...
                'FileStamp',groups(k).Stamp,'Calculation',groups(k).Metadata);
        end
        metadata = struct('Settings',settings,'Groups',{entries}, ...
            'PointCIVisible',pointToggle.Value,'BootstrapCIVisible',bootstrapToggle.Value, ...
            'Units','pixels','Estimator','pooled-centerline-point median', ...
            'CalibrationNote','Compare only images with matching pixel size; no micrometer calibration is applied');
    end

    function exportFigureClicked(~,~)
        [name,folder] = uiputfile({'*.pdf','Vector PDF'},'Export group width profiles',fullfile(root,'group_width_profiles.pdf'));
        if isequal(name,0), return; end
        try, writeFigure(fullfile(folder,name)); catch problem, showError(problem); end
    end

    function writeFigure(file)
        assert(ready() && ~running && ~blocked,'EyeLayerWidth:WidthGroups','Calculate all selected groups first.');
        fig = figure('Visible','off','Color','w','Position',[100 100 1100 650]); cleanup = onCleanup(@() close(fig));
        grid = tiledlayout(fig,1,1,'TileSpacing','compact'); drawPlot(nexttile(grid));
        note = {};
        if pointToggle.Value, note{end+1} = 'Point-based median CI (nominal 95%, dark)'; end
        if bootstrapToggle.Value, note{end+1} = 'Whole-eye bootstrap CI (95%, light)'; end
        if isempty(note), note = {'Confidence intervals hidden'}; end
        xlabel(grid,{strjoin(note,'; ');sprintf('Pooled centerline widths; pointwise intervals. End-region exclusion: %d. Compare matching pixel sizes.',settings.ExcludeEnds)},'FontSize',9);
        layerwidth_export_figure(fig,file);
    end

    function exportResultsClicked(~,~)
        [name,folder] = uiputfile({'*.csv','CSV';'*.mat','MAT file'},'Export group width summaries',fullfile(root,'group_width_profiles.csv'));
        if isequal(name,0), return; end
        try, writeResults(fullfile(folder,name)); catch problem, showError(problem); end
    end

    function writeResults(file)
        assert(~running && ~blocked,'EyeLayerWidth:WidthGroups','A calculation is running.');
        [profiles,metadata] = getResults(); [~,~,ext] = fileparts(file);
        if strcmpi(ext,'.csv'), writetable(profiles,file);
        elseif strcmpi(ext,'.mat'), save(file,'profiles','metadata');
        else, error('EyeLayerWidth:WidthGroups','Choose CSV or MAT.'); end
    end

    function showError(problem)
        status.Text = ['Failed: ' problem.message]; updateControls();
        uialert(ancestor(tab,'figure'),problem.message,'Group Width Profiles');
    end
end
