function test_layerwidth_navigation
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
[fig,api] = EyeLayerWidth_GUI('Visible','off','ResultsFile',fullfile(root,'examples','DMSO_4dpi.mat'));
cleanup = onCleanup(@() delete(fig));
sample = findall(fig,'Tag','WidthSample');
next = findall(fig,'Tag','WidthNext');
views = findall(fig,'Tag','WidthViews');
for title = {'Profiles','Measurements','Eye Summary'}
    views.SelectedTab = findall(fig,'Type','uitab','Title',title{1});
    key('rightarrow',{}); assert(strcmp(sample.Value,sample.Items{2}));
    key('leftarrow',{}); assert(strcmp(sample.Value,sample.Items{1}));
end
key('leftarrow',{}); assert(strcmp(sample.Value,sample.Items{1}));
key('rightarrow',{'shift'}); assert(strcmp(sample.Value,sample.Items{1}));
fig.CurrentObject = sample;
key('rightarrow',{}); assert(strcmp(sample.Value,sample.Items{1}));
fig.CurrentObject = findall(fig,'Tag','WidthMeasurements');
key('rightarrow',{}); assert(strcmp(sample.Value,sample.Items{1}));
fig.CurrentObject = next;
key('pagedown',{}); assert(strcmp(sample.Value,sample.Items{2}));
key('pageup',{}); assert(strcmp(sample.Value,sample.Items{1}));
api.Widths.SetBusy(true);
key('rightarrow',{}); assert(strcmp(sample.Value,sample.Items{1}));
api.Widths.SetBusy(false);
views.SelectedTab = findall(fig,'Type','uitab','Title','Group Profiles');
key('rightarrow',{}); assert(strcmp(sample.Value,sample.Items{1}));
views.SelectedTab = findall(fig,'Type','uitab','Title','Profiles');
sample.Value = sample.Items{end};
key('rightarrow',{}); assert(strcmp(sample.Value,sample.Items{end}));
disp('EyeLayerWidth navigation passed: arrows, aliases, boundaries, modifiers, input controls, busy state, and views.');

    function key(name,modifiers)
        feval(fig.WindowKeyPressFcn,fig,struct('Key',name,'Modifier',{modifiers}));
    end
end
