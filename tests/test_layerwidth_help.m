function test_layerwidth_help
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
topics = {'Profiles','Measurements','Eye Summary','Group Profiles'};
phrases = {{'middle 50%','IQR of 8 pixels','IQR shows spread','uncertainty in the group median'}, ...
    {'Near 1','near 0.5','Smaller values mean a closer fit','measurement is unavailable'}, ...
    {'one eye','median is 20 pixels','Each point has equal weight'}, ...
    {'1,000 independent observations','10 independent eyes','CI means confidence interval', ...
     '5,000 draws','original angles','point-based band can look overly precise', ...
     'no width significance test','ContributingEyes'}};
fig = EyeLayerWidth_GUI('Visible','on'); cleanup = onCleanup(@() delete(fig));
views = findall(fig,'Tag','WidthViews'); button = findall(fig,'Tag','ContextHelp');
for k = 1:numel(topics)
    views.SelectedTab = findall(fig,'Type','uitab','Title',topics{k});
    feval(button.ButtonPushedFcn,button,[]);
    help = findall(groot,'Tag','EyeLayerWidthHelp');
    control = findall(help,'Tag','EyeLayerWidthHelpText');
    [heading,body] = layerwidth_help(topics{k});
    assert(strcmp(help.Name,heading) && isequal(control.Value,body));
    for phrase = phrases{k}, assert(any(contains(body,phrase{1}))); end
    if ismember(k,[1 4])
        drawnow; pause(3); drawnow;
        exportapp(help,fullfile(tempdir,sprintf('eyelayerwidth_statistics_help_%d.png',k)));
    end
end
assert(mean([10 20 90])==40 && median([10 20 90])==20);
assert(isequal(prctile([18 18 26 26],[25 75]),[18 26]));
delete(fig); assert(~isvalid(help)); clear cleanup;
disp('EyeLayerWidth statistical help passed: all views, worked examples, independence, IQR versus CI, fit diagnostics, and group comparison limitations.');
end
