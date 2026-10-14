function test_layerwidth_group_profile
root = fileparts(fileparts(mfilename('fullpath'))); addpath(root);
eyes = cell(3,1);
for k = 1:3
    width = (1:k*7)'/7 + k*3.125;
    values = [width;width+2.25;30+k/8];
    angles = [repmat(2,numel(width),1);repmat(42,numel(width),1);180];
    eyes{k} = table(angles,values,true(size(values)),false(size(values)), ...
        'VariableNames',{'Angle','LocalWidthPx','LocalValid','EndpointRisk'});
end
eyes{1}.LocalValid(1) = false; eyes{2}.EndpointRisk(2) = true;
before = rng; iterations = 500; seed = 271;
for exclude = [false true]
    [profile,metadata] = layerwidth_group_profile(eyes,5,exclude,iterations,seed);
    stream = RandStream('mt19937ar','Seed',seed); draws = randi(stream,3,3,iterations);
    for b = [1 9 36]
        values = cell(3,1);
        for k = 1:3
            p = eyes{k}; valid = p.LocalValid & (~exclude | ~p.EndpointRisk);
            valid = valid & p.Angle>=(b-1)*5 & (p.Angle<b*5 | (b==36 & p.Angle==180));
            values{k} = p.LocalWidthPx(valid);
        end
        pooled = sort(vertcat(values{:}));
        assert(profile.MedianWidthPx(b)==median(pooled) && profile.Points(b)==numel(pooled));
        estimates = zeros(iterations,1);
        for j = 1:iterations, estimates(j) = median(vertcat(values{draws(:,j)})); end
        limits = prctile(estimates,[2.5 97.5]);
        assert(max(abs([profile.BootstrapCI95L(b),profile.BootstrapCI95U(b)]-limits))<1e-12);
        n = numel(pooled); lo = round(n/2-1.96*sqrt(n/4)); hi = round(n/2+1.96*sqrt(n/4));
        if lo>=1 && hi<=n
            assert(isequal([profile.PointCI95L(b),profile.PointCI95U(b)],[pooled(lo),pooled(hi)]));
        else
            assert(isnan(profile.PointCI95L(b)) && isnan(profile.PointCI95U(b)));
        end
    end
    assert(all(isnan(profile.MedianWidthPx(setdiff(1:36,[1 9 36])))));
    assert(metadata.FinalBinIncludes180 && metadata.EyeCount==3 && strcmp(metadata.Units,'pixels'));
end
assert(isequal(before,rng));
one = layerwidth_group_profile(eyes(1),5,false,100,seed);
assert(all(isnan(one.BootstrapCI95L)) && any(isfinite(one.MedianWidthPx)));
empty = eyes; empty{2}.LocalValid(:) = false; empty{3}.LocalValid(:) = false;
empty = layerwidth_group_profile(empty,5,false,iterations,seed);
assert(empty.EmptyBootstrapDraws(1)>0 && isnan(empty.BootstrapCI95L(1)));
for width = [1 10]
    p = layerwidth_group_profile(eyes,width,false,100,seed);
    assert(height(p)==180/width && p.Points(end)==3);
end
disp('Group width statistics match literal whole-eye resampling of continuous widths; rank CIs, missing bins, endpoints, exclusions, and RNG passed.');
end
