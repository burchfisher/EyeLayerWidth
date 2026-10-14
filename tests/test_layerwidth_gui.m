function test_layerwidth_gui
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
assert(isempty(which('RpEGEN_GUI')),'Run this test with only EyeLayerWidth on the project path.');
initialRng = rng;
[fig,api] = EyeLayerWidth_GUI('Visible','off'); cleanup = onCleanup(@() delete(fig));
example = findall(fig,'Tag','ExampleGroups'); feval(example.ButtonPushedFcn,example,[]);
assert(numel(api.GetFiles())==4);
feval(example.ButtonPushedFcn,example,[]); assert(numel(api.GetFiles())==4);
assert(~isempty(findall(fig,'Tag','WidthLocalProfile')));
assert(findall(fig,'Tag','WidthWindow').Value==25);
views = findall(fig,'Tag','WidthViews');
helpButton = findall(fig,'Tag','ContextHelp');
for topic = {'Profiles','Measurements','Eye Summary','Group Profiles'}
    views.SelectedTab = findall(fig,'Type','uitab','Title',topic{1});
    feval(views.SelectionChangedFcn,views,[]);
    feval(helpButton.ButtonPushedFcn,helpButton,[]);
    help = findall(groot,'Tag','EyeLayerWidthHelp'); assert(isscalar(help));
    assert(contains(help.Name,topic{1}));
    body = findall(help,'Tag','EyeLayerWidthHelpText'); assert(numel(body.Value)>10);
end
api.Widths.GroupProfiles.Calculate();
[profiles,metadata] = api.Widths.GroupProfiles.GetResults();
assert(height(profiles)==144 && isequal(cellfun(@(g) numel(g.EyeNames),metadata.Groups),[11;12;11;10]));
assert(numel(findall(fig,'Tag','WidthGroupMedian'))==4);
assert(all(profiles.BootstrapIterations==5000));
bootstrap = findall(fig,'Tag','WidthGroupBootstrapCI'); bootstrap.Value = false;
feval(bootstrap.ValueChangedFcn,bootstrap,[]);
assert(isempty(findall(fig,'Tag','WidthGroupBootstrapBand')));
bootstrap.Value = true; feval(bootstrap.ValueChangedFcn,bootstrap,[]);
assert(~isempty(findall(fig,'Tag','WidthGroupBootstrapBand')));
folder = fullfile(root,'output'); if ~isfolder(folder), mkdir(folder); end
api.Widths.GroupProfiles.ExportResults(fullfile(folder,'group_width_profiles.mat'));
api.Widths.GroupProfiles.ExportResults(fullfile(folder,'group_width_profiles.csv'));
pdfFolder = fullfile(folder,'pdf'); if ~isfolder(pdfFolder), mkdir(pdfFolder); end
api.Widths.GroupProfiles.ExportFigure(fullfile(pdfFolder,'group_width_profiles.pdf'));
fig.Visible = 'on'; drawnow; pause(1); drawnow;
exportapp(fig,fullfile(folder,'layerwidth_groups.png'));
fig.Position(3:4) = [1000 700]; drawnow; pause(.5); drawnow;
exportapp(fig,fullfile(folder,'layerwidth_groups_compact.png'));
views.SelectedTab = findall(fig,'Type','uitab','Title','Profiles');
feval(views.SelectionChangedFcn,views,[]);
iqr = findall(fig,'Tag','WidthIQR'); iqr.Value = true; feval(iqr.ValueChangedFcn,iqr,[]);
api.Widths.ExportFigure(fullfile(pdfFolder,'eye_width_profile.pdf'));
drawnow; pause(.5); drawnow; exportapp(fig,fullfile(folder,'layerwidth_eye.png'));
api.Widths.Export(fullfile(folder,'eye_width_measurements.mat'));
saved = load(fullfile(folder,'eye_width_measurements.mat')); assert(height(saved.summary)==11);
before = api.GetFiles(); invalid = fullfile(tempdir,'layerwidth_invalid.mat'); unrelated = 1; save(invalid,'unrelated');
try, api.AddFiles({invalid}); error('Test:ExpectedError','Invalid group accepted.');
catch problem, assert(strcmp(problem.identifier,'EyeLayerWidth:Input')); end
assert(isequal(api.GetFiles(),before));
assert(strcmp(findall(fig,'Tag','EyeLayerWidthAddGroups').Enable,'on'));
api.Clear(); assert(isempty(api.GetFiles()));
assert(isempty(findall(fig,'Tag','WidthGroupMedian')) && isempty(findall(fig,'Tag','WidthLocalProfile')));
assert(strcmp(findall(fig,'Tag','WidthMeasureAll').Enable,'off'));
api.AddFiles(before(1)); assert(~isempty(findall(fig,'Tag','WidthLocalProfile')));
assert(isequal(initialRng,rng));
delete(fig); assert(~isvalid(help)); clear cleanup;
fprintf('Standalone EyeLayerWidth passed: 44 eyes, four groups, both CIs, help on all views, exports, validation, clear/reload, and no RpEGEN dependency.\n');
end
