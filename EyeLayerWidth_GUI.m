function [fig,api] = EyeLayerWidth_GUI(varargin)
% Launch the independent polygon and centerline width application.
root = fileparts(mfilename('fullpath'));
options = inputParser;
addParameter(options,'Visible','on');
addParameter(options,'ResultsFile','');
parse(options,varargin{:});
addpath(root);
files = {}; busy = false; helpWindow = [];
fig = uifigure('Name','Eye Layer Width','Tag','EyeLayerWidthGUI', ...
    'Position',[100 100 1180 780],'Visible',options.Results.Visible, ...
    'CloseRequestFcn',@closeApp,'DeleteFcn',@(~,~) closeHelp(), ...
    'WindowKeyPressFcn',@sampleKey);
layout = uigridlayout(fig,[3 1],'RowHeight',{44,34,'1x'},'Padding',[16 12 16 12]);
header = uigridlayout(layout,[1 3],'ColumnWidth',{'1x',240,40},'Padding',[0 0 0 0]);
uilabel(header,'Text','Eye Layer Width','FontSize',24,'FontWeight','bold');
uilabel(header,'Text',['MATLAB ' version('-release')],'HorizontalAlignment','right');
uibutton(header,'Text','?','FontSize',20,'Tag','ContextHelp', ...
    'Tooltip','Help for the selected view, measurements, confidence bands, and exports', ...
    'ButtonPushedFcn',@showHelp);
actions = uigridlayout(layout,[1 4],'ColumnWidth',{130,140,120,'1x'},'Padding',[0 0 0 0]);
addButton = uibutton(actions,'Text','Add Groups...','Tag','EyeLayerWidthAddGroups', ...
    'Tooltip','Load one or more geometry MAT files, one independent treatment group per file', ...
    'ButtonPushedFcn',@chooseFiles);
exampleButton = uibutton(actions,'Text','Example Groups','Tag','ExampleGroups', ...
    'Tooltip','Load the four bundled groups; no RpEGEN installation or analysis rerun is needed', ...
    'ButtonPushedFcn',@examplesClicked);
clearButton = uibutton(actions,'Text','Clear Groups','Tag','EyeLayerWidthClearGroups', ...
    'Tooltip','Clear loaded groups and cached measurements without changing source files', ...
    'ButtonPushedFcn',@clearClicked,'Enable','off');
status = uilabel(actions,'Text','No groups loaded','Tag','EyeLayerWidthStatus');
panel = uipanel(layout,'BorderType','none');
widths = layerwidth_workspace(panel,root,@setBusy);
api.AddFiles = @addFiles;
api.GetFiles = @getFiles;
api.Clear = @clearGroups;
api.Widths = widths;
if ~isempty(options.Results.ResultsFile)
    try, addFiles(cellstr(string(options.Results.ResultsFile)));
    catch problem, delete(fig); rethrow(problem); end
end

    function addFiles(incoming)
        assert(~busy,'EyeLayerWidth:Busy','A calculation is running.');
        incoming = cellstr(string(incoming)); pending = files;
        setBusy(true); cleanup = onCleanup(@() setBusy(false));
        for k = 1:numel(incoming)
            file = char(java.io.File(incoming{k}).getCanonicalPath());
            if ismember(file,pending), continue; end
            status.Text = sprintf('Checking group %d / %d',k,numel(incoming)); drawnow;
            layerwidth_load_group(file);
            pending{end+1} = file;
        end
        files = pending;
        widths.SetSources(files);
        clear cleanup;
        widths.Activate();
    end

    function value = getFiles()
        value = files;
    end

    function chooseFiles(~,~)
        if busy, return; end
        [names,folder] = uigetfile('*.mat','Select EyeLayerWidth or full RpEGEN group MATs',root,'MultiSelect','on');
        if isequal(names,0), return; end
        try, addFiles(fullfile(folder,cellstr(string(names))));
        catch problem, showError(problem); end
    end

    function examplesClicked(~,~)
        try
            addFiles(fullfile(root,'examples',{'DMSO_4dpi.mat','IWR1_4dpi.mat','DMSO_9dpf.mat','IWR1_9dpf.mat'}));
        catch problem, showError(problem); end
    end

    function clearClicked(~,~)
        if busy, return; end
        answer = uiconfirm(fig,'Clear all groups and unsaved measurements? Source files will not change.', ...
            'Clear Groups','Options',{'Clear','Cancel'},'DefaultOption',2,'CancelOption',2);
        if strcmp(answer,'Clear'), clearGroups(); end
    end

    function clearGroups()
        assert(~busy,'EyeLayerWidth:Busy','A calculation is running.');
        files = {}; widths.Clear(); setBusy(false);
    end

    function setBusy(value)
        busy = value; widths.SetBusy(value);
        addButton.Enable = matlab.lang.OnOffSwitchState(~value);
        exampleButton.Enable = addButton.Enable;
        clearButton.Enable = matlab.lang.OnOffSwitchState(~value && ~isempty(files));
        if ~value, status.Text = sprintf('%d groups loaded',numel(files)); end
    end

    function showHelp(~,~)
        views = findall(fig,'Tag','WidthViews');
        [heading,body] = layerwidth_help(views.SelectedTab.Title);
        if isempty(helpWindow) || ~isvalid(helpWindow)
            helpWindow = uifigure('Name',heading,'Position',[180 140 660 570], ...
                'Tag','EyeLayerWidthHelp','Visible',fig.Visible);
            grid = uigridlayout(helpWindow,[1 1]);
            uitextarea(grid,'Editable','off','FontSize',14,'Tag','EyeLayerWidthHelpText');
        end
        helpWindow.Name = heading;
        control = findall(helpWindow,'Tag','EyeLayerWidthHelpText'); control.Value = body;
        if strcmp(fig.Visible,'on'), figure(helpWindow); end
    end

    function closeHelp()
        if ~isempty(helpWindow) && isvalid(helpWindow), delete(helpWindow); end
    end

    function closeApp(~,~)
        if busy, uialert(fig,'Wait for the current calculation or export to finish.','Eye Layer Width'); return; end
        delete(fig);
    end

    function sampleKey(~,event)
        if busy || ~isempty(event.Modifier), return; end
        % Leave native arrow-key editing and selection to input controls.
        active = fig.CurrentObject;
        if ismember(event.Key,{'leftarrow','rightarrow'}) && ~isempty(active) && ...
                (isprop(active,'Value') || isa(active,'matlab.ui.control.Table') || ...
                isa(active,'matlab.ui.container.TabGroup'))
            return;
        end
        if ismember(event.Key,{'leftarrow','pageup'}), widths.Step(-1);
        elseif ismember(event.Key,{'rightarrow','pagedown'}), widths.Step(1); end
    end

    function showError(problem)
        status.Text = problem.message;
        uialert(fig,problem.message,'Eye Layer Width');
    end
end
