function data = layerwidth_load_group(file)
% Validate the shared geometry input format before changing the GUI session.
assert(isfile(file),'EyeLayerWidth:Input','Group MAT not found: %s',file);
loaded = load(file); names = fieldnames(loaded); candidates = {};
required = {'IMG','IMGname','ROIxy','CLine'};
for j = 1:numel(names)
    value = loaded.(names{j});
    if isstruct(value) && isscalar(value) && all(isfield(value,required))
        candidates{end+1} = names{j};
    end
end
assert(numel(candidates)==1,'EyeLayerWidth:Input', ...
    'Select a MAT containing exactly one group with IMG, IMGname, ROIxy, and CLine. Width exports and run metadata are not input groups.');
data = loaded.(candidates{1});
n = numel(data.IMGname);
assert(n>0 && (iscellstr(data.IMGname) || isstring(data.IMGname)),'EyeLayerWidth:Input','Group requires nonempty image names.');
data.IMGname = cellstr(string(data.IMGname(:)));
assert(numel(unique(data.IMGname))==n && all(strlength(string(data.IMGname))>0), ...
    'EyeLayerWidth:Input','Each eye must have a unique, nonempty image name.');
for field = {'IMG','ROIxy','CLine'}
    assert(iscell(data.(field{1})) && numel(data.(field{1}))==n, ...
        'EyeLayerWidth:Input','%s must have one cell per eye.',field{1});
end
if isfield(data,'ROIBW')
    assert(iscell(data.ROIBW) && numel(data.ROIBW)==n,'EyeLayerWidth:Input','ROIBW must have one mask per eye.');
end
for k = 1:n
    validateattributes(data.IMG{k},{'uint8'},{'2d','nonempty'},mfilename,'IMG');
    validateattributes(data.ROIxy{k},{'numeric'},{'2d','ncols',2,'finite','real','nonempty'},mfilename,'ROIxy');
    line = data.CLine{k};
    assert(istable(line) && height(line)>=2 && all(ismember({'x','y','distance','angle'},line.Properties.VariableNames)), ...
        'EyeLayerWidth:Input','Eye %d requires a centerline table with x, y, distance, and angle.',k);
    for field = {'x','y','distance','angle'}
        validateattributes(line.(field{1}),{'numeric'},{'column','finite','real'},mfilename,field{1});
    end
    if isfield(data,'ROIBW')
        assert(isequal(size(data.ROIBW{k}),size(data.IMG{k})),'EyeLayerWidth:Input','Eye %d mask and image sizes differ.',k);
    end
end
end
