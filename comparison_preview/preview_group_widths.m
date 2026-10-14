function preview_group_widths
% Full example-data verification and publication export for the new group view.
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
files = fullfile(root,'examples',{'DMSO_4dpi.mat','IWR1_4dpi.mat','DMSO_9dpf.mat','IWR1_9dpf.mat'});
fig = uifigure('Visible','off','Position',[100 100 1180 780]); cleanup = onCleanup(@() delete(fig));
grid = uigridlayout(fig,[1 1]); tabs = uitabgroup(grid); tab = uitab(tabs,'Title','Widths');
api = layerwidth_workspace(tab,root); api.SetSources(files); api.Activate();
views = findall(fig,'Tag','WidthViews'); views.SelectedTab = findall(fig,'Type','uitab','Title','Group Profiles');
feval(views.SelectionChangedFcn,views,[]);
before = rng; timer = tic; api.GroupProfiles.Calculate(); elapsed = toc(timer);
[profiles,metadata] = api.GroupProfiles.GetResults();
assert(height(profiles)==144 && isequal(before,rng));
assert(isequal(cellfun(@(g) numel(g.EyeNames),metadata.Groups),[11;12;11;10]));
assert(numel(findall(fig,'Tag','WidthGroupMedian'))==4);
folder = fullfile(root,'output','pdf'); if ~isfolder(folder), mkdir(folder); end
api.GroupProfiles.ExportFigure(fullfile(folder,'group_width_profiles_example.pdf'));
api.GroupProfiles.ExportResults(fullfile(root,'comparison_preview','group_width_profiles_example.mat'));
api.GroupProfiles.ExportResults(fullfile(root,'comparison_preview','group_width_profiles_example.csv'));
fig.Visible = 'on'; drawnow; pause(1); drawnow;
exportapp(fig,fullfile(root,'comparison_preview','group_width_profiles_gui.png'));
fprintf('All 44 example eyes plotted in %.1f seconds; four groups, 144 bins, unchanged RNG, and PDF/MAT/CSV exports verified.\n',elapsed);
end
