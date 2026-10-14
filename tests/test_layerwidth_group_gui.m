function test_layerwidth_group_gui
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
folder = fullfile(tempdir,'rpegen_width_groups'); if ~isfolder(folder), mkdir(folder); end
sourceFiles = fullfile(root,'examples',{'DMSO_4dpi.mat','IWR1_4dpi.mat'});
files = cell(1,2); sampleData = cell(1,2);
for k = 1:2
    loaded = load(sourceFiles{k}); fields = fieldnames(loaded); group = loaded.(fields{1});
    for field = {'IMG','IMGname','ROIxy','ROIBW','CLine'}, group.(field{1}) = group.(field{1})(1:2); end
    sampleData{k} = group;
    files{k} = fullfile(folder,sprintf('Example_%d.mat',k)); save(files{k},'group');
end
fig = uifigure('Visible','off','Position',[100 100 1180 780]); cleanup = onCleanup(@() delete(fig));
layout = uigridlayout(fig,[1 1]); tabs = uitabgroup(layout); tab = uitab(tabs,'Title','Widths');
api = layerwidth_workspace(tab,root); api.SetSources(files); api.SetData(sampleData{1},files{1}); api.Activate();
[individual,~,~] = api.GetResults(); sample = findall(fig,'Tag','WidthSample'); sampleName = sample.Value;
views = findall(fig,'Tag','WidthViews'); views.SelectedTab = findall(fig,'Type','uitab','Title','Group Profiles');
feval(views.SelectionChangedFcn,views,[]);
assert(strcmp(sample.Parent.Visible,'off'));
tableUI = findall(fig,'Tag','WidthProfileGroups'); assert(height(tableUI.Data)==2);
assert(strcmp(tableUI.Data{1,3},'1 / 2'));
api.GroupProfiles.Calculate(); assert(api.GroupProfiles.HasResults());
[profiles,metadata] = api.GroupProfiles.GetResults();
assert(height(profiles)==72 && numel(metadata.Groups)==2);
assert(all(profiles.WindowTotalPx==25) && all(profiles.EyesInGroup==2));
expectedEyes = {individual{1};layerwidth_measure_eye(sampleData{1},2,25)};
expected = layerwidth_group_profile(expectedEyes,5,false);
assert(isequaln(profiles.MedianWidthPx(1:36),expected.MedianWidthPx));
assert(isequaln(profiles.BootstrapCI95L(1:36),expected.BootstrapCI95L));
assert(strcmp(sample.Value,sampleName)); [after,~,~] = api.GetResults();
assert(isequaln(after,individual),'Group plotting changed the per-eye inspection cache.');
assert(numel(findall(fig,'Tag','WidthGroupMedian'))==2);
ax = findall(fig,'Tag','WidthGroupAxes'); ax.XLim = [30 90]; ax.YLim = [0 60];
pointCI = findall(fig,'Tag','WidthGroupPointCI'); pointCI.Value = false;
feval(pointCI.ValueChangedFcn,pointCI,[]);
assert(isempty(findall(fig,'Tag','WidthGroupPointBand')) && isequal(ax.XLim,[30 90]) && isequal(ax.YLim,[0 60]));
[unchanged,~] = api.GroupProfiles.GetResults(); assert(isequaln(profiles,unchanged));
pointCI.Value = true; feval(pointCI.ValueChangedFcn,pointCI,[]);
api.GroupProfiles.ExportFigure(fullfile(folder,'group_width_profiles.pdf'));
api.GroupProfiles.ExportResults(fullfile(folder,'group_width_profiles.mat'));
api.GroupProfiles.ExportResults(fullfile(folder,'group_width_profiles.csv'));
saved = load(fullfile(folder,'group_width_profiles.mat')); assert(isequaln(saved.profiles,profiles));
assert(height(readtable(fullfile(folder,'group_width_profiles.csv')))==72);
feval(tableUI.CellEditCallback,tableUI,struct('Indices',[2 1],'NewData',false));
assert(numel(findall(fig,'Tag','WidthGroupMedian'))==1);
feval(tableUI.CellEditCallback,tableUI,struct('Indices',[2 1],'NewData',true));
bin = findall(fig,'Tag','WidthBin'); bin.Value = 10; feval(bin.ValueChangedFcn,bin,[]);
assert(~api.GroupProfiles.HasResults() && isempty(findall(fig,'Tag','WidthGroupMedian')));
assert(strcmp(tableUI.Data{1,3},'2 / 2'),'Changing bins discarded measured geometry.');
api.GroupProfiles.Calculate(); [rebinned,~] = api.GroupProfiles.GetResults(); assert(height(rebinned)==36);
api.SetBusy(true); assert(strcmp(findall(fig,'Tag','WidthGroupCalculate').Enable,'off')); api.SetBusy(false);
fig.Visible = 'on'; drawnow; pause(1); drawnow;
exportapp(fig,fullfile(folder,'group_width_gui.png'));
fig.Position(3:4) = [1000 700]; drawnow; pause(.5); drawnow;
exportapp(fig,fullfile(folder,'group_width_gui_compact.png'));
views.SelectedTab = findall(fig,'Type','uitab','Title','Profiles'); feval(views.SelectionChangedFcn,views,[]);
[reused,~,eyeSummary] = api.GetResults();
assert(height(eyeSummary)==2 && isequaln(reused{1},individual{1}));
assert(strcmp(findall(fig,'Tag','WidthMeasureAll').Text,'All Eyes Measured'));
views.SelectedTab = findall(fig,'Type','uitab','Title','Group Profiles'); feval(views.SelectionChangedFcn,views,[]);
window = findall(fig,'Tag','WidthWindow'); window.Value = 50; feval(window.ValueChangedFcn,window,[]);
assert(~api.GroupProfiles.HasResults() && strcmp(tableUI.Data{1,3},'Not measured'));
assert(strcmp(sample.Value,sampleName));
[~,help] = layerwidth_help('Group Profiles'); assert(any(contains(help,'pooled')));
fprintf('Group width GUI passed: shared geometry, pooled statistics, CI toggles, exports, selection, invalidation, and preserved eye inspection. Outputs: %s\n',folder);
end
