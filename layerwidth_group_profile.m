function [profile,metadata] = layerwidth_group_profile(eyes,binWidth,excludeEnds,iterations,seed)
% Pooled continuous widths with point-rank and whole-eye bootstrap intervals.
if nargin<4, iterations = 5000; end
if nargin<5, seed = 20261012; end
assert(iscell(eyes) && ~isempty(eyes),'EyeLayerWidth:WidthGroups','Provide measured eyes.');
assert(ismember(binWidth,[1 5 10]),'EyeLayerWidth:WidthGroups','Use 1, 5, or 10 degree bins.');
validateattributes(iterations,{'numeric'},{'scalar','integer','>=',100});
validateattributes(seed,{'numeric'},{'scalar','integer','nonnegative','<=',2^32-1});
n = numel(eyes); values = []; angles = []; ids = [];
for k = 1:n
    points = eyes{k};
    required = {'Angle','LocalWidthPx','LocalValid','EndpointRisk'};
    assert(istable(points) && all(ismember(required,points.Properties.VariableNames)), ...
        'EyeLayerWidth:WidthGroups','Each eye needs local widths, angles, and validity flags.');
    valid = points.LocalValid & isfinite(points.LocalWidthPx) & points.LocalWidthPx>0 & ...
        isfinite(points.Angle) & points.Angle>=0 & points.Angle<=180;
    if excludeEnds, valid = valid & ~points.EndpointRisk; end
    values = [values;double(points.LocalWidthPx(valid))]; %#ok<AGROW>
    angles = [angles;double(points.Angle(valid))]; %#ok<AGROW>
    ids = [ids;repmat(k,nnz(valid),1)]; %#ok<AGROW>
end
stream = RandStream('mt19937ar','Seed',seed);
draws = randi(stream,n,n,iterations);
drawIndex = repmat(1:iterations,n,1);
weights = accumarray([draws(:),drawIndex(:)],1,[n iterations]);
count = 180/binWidth;
medianWidth = nan(count,1); pointL = medianWidth; pointU = medianWidth;
bootL = medianWidth; bootU = medianWidth;
pointsPerBin = zeros(count,1); contributing = pointsPerBin; emptyDraws = pointsPerBin;
for b = 1:count
    inBin = angles>=(b-1)*binWidth & (angles<b*binWidth | (b==count & angles==180));
    [sorted,order] = sort(values(inBin)); eyeIDs = ids(inBin); eyeIDs = eyeIDs(order);
    m = numel(sorted); pointsPerBin(b) = m; contributing(b) = numel(unique(eyeIDs));
    if m==0, emptyDraws(b) = iterations; continue; end
    medianWidth(b) = median(sorted);
    lo = round(m/2-1.96*sqrt(m/4)); hi = round(m/2+1.96*sqrt(m/4));
    if lo>=1 && hi<=m, pointL(b) = sorted(lo); pointU(b) = sorted(hi); end
    estimates = nan(1,iterations);
    % Bound the temporary point-by-draw arrays without discretizing widths.
    batch = max(1,min(128,floor(2e6/m)));
    for first = 1:batch:iterations
        last = min(iterations,first+batch-1);
        cumulative = cumsum(weights(eyeIDs,first:last),1);
        total = cumulative(end,:);
        left = min(m,1+sum(cumulative<ceil(total/2),1));
        right = min(m,1+sum(cumulative<floor(total/2)+1,1));
        sampleMedians = (reshape(sorted(left),1,[])+reshape(sorted(right),1,[]))/2;
        sampleMedians(total==0) = NaN;
        estimates(first:last) = sampleMedians;
    end
    emptyDraws(b) = nnz(~isfinite(estimates));
    if contributing(b)>=2 && emptyDraws(b)==0
        limits = prctile(estimates,[2.5 97.5]); bootL(b) = limits(1); bootU(b) = limits(2);
    end
end
profile = table(((binWidth/2):binWidth:180)',pointsPerBin,contributing,medianWidth, ...
    pointL,pointU,bootL,bootU,emptyDraws,'VariableNames', ...
    {'Angle','Points','ContributingEyes','MedianWidthPx','PointCI95L','PointCI95U', ...
    'BootstrapCI95L','BootstrapCI95U','EmptyBootstrapDraws'});
metadata = struct('Estimator','pooled-centerline-point median','Units','pixels', ...
    'EyeCount',n,'BinWidthDegrees',binWidth,'ExcludeEndRegions',logical(excludeEnds), ...
    'Iterations',iterations,'Seed',seed,'ResamplingUnit','whole eye', ...
    'IntervalCoverage','pointwise','FinalBinIncludes180',true, ...
    'PointCIMethod','Original normal-approximation median ranks; undefined ranks omitted', ...
    'BootstrapMethod','Percentile 2.5-97.5; same eye draw at every angle; no band with fewer than two contributing eyes or empty draws');
end
