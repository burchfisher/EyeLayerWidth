function test_layerwidth_batch_exports
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
source = fullfile(root,'examples','DMSO_4dpi.mat'); data = layerwidth_load_group(source);
for field = {'IMG','IMGname','ROIxy','ROIBW','CLine'}, data.(field{1}) = data.(field{1})(1:2); end
fig = uifigure('Visible','off'); cleanup = onCleanup(@() delete(fig));
panel = uipanel(fig); api = layerwidth_workspace(panel,root); api.SetData(data,source); api.Activate();
button = findall(fig,'Tag','WidthMeasureAll'); assert(strcmp(button.Text,'Measure 1 More'));
folder = fullfile(tempdir,'layerwidth_batch'); if ~isfolder(folder), mkdir(folder); end
files = api.ExportFigures(folder); assert(numel(files)==2 && all(isfile(files)));
assert(strcmp(button.Text,'All Eyes Measured'));
api.Export(fullfile(folder,'measurements.mat')); saved = load(fullfile(folder,'measurements.mat'));
assert(height(saved.summary)==2 && numel(unique(saved.measurements.Eye))==2);
disp('EyeLayerWidth all-eye PDF and MAT exports passed.');
end
