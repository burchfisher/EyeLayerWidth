function file = layerwidth_export_figure(fig,file)
% Keep publication exports vector-based; embedded image data remain raster.
file = char(file);
[~,~,extension] = fileparts(file);
if isempty(extension)
    file = [file '.pdf'];
elseif ~strcmpi(extension,'.pdf')
    error('EyeLayerWidth:FigureFormat','Choose a .pdf filename for an editable figure export.');
end
exportgraphics(fig,file,'ContentType','vector','BackgroundColor','white');
end
