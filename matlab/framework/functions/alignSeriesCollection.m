function [aligned,notes] = alignSeriesCollection(raw,grid,negativeMode,gridInfo,kind,settings)
%ALIGNSERIESCOLLECTION Interpolate, average repeats, and standardize names.

notes = strings(0,1);
n = numel(raw.names);
alignedRaw = nan(numel(grid),n);
minimums = nan(n,1); maximums = nan(n,1); points = zeros(n,1);
negativeCounts = zeros(n,1); zeroFilledCounts = zeros(n,1);

for i = 1:n
    wl = double(raw.wavelengths{i}(:));
    value = double(raw.values{i}(:));
    valid = isfinite(wl) & isfinite(value);
    wl = wl(valid); value = value(valid);
    [wl,order] = sort(wl); value = value(order);
    [wl,uniqueIndex] = unique(wl,'stable'); value = value(uniqueIndex);
    if numel(wl) < 2
        error('%s "%s" has fewer than two valid wavelength points.',kind,raw.names(i));
    end
    minimums(i) = min(wl); maximums(i) = max(wl); points(i) = numel(wl);
    negativeCounts(i) = nnz(value < 0);
    if negativeMode == "clip", value(value < 0) = 0; end
    interpolated = interp1(wl,value,grid,'linear',NaN);
    zeroFilledCounts(i) = nnz(~isfinite(interpolated));
    alignedRaw(:,i) = interpolated;
end

% Repeated names are grouped flexibly and averaged. NaN regions are omitted
% before zero-filling so that a shorter replicate does not depress a longer one.
keys = normalizeEntityKey(raw.names,true);
[uniqueKeys,firstIndex,group] = unique(keys,'stable');
numGroups = numel(uniqueKeys);
matrix = nan(numel(grid),numGroups);
names = strings(numGroups,1);
measurements = zeros(numGroups,1);
sourceSeries = strings(numGroups,1);
for g = 1:numGroups
    cols = find(group == g);
    matrix(:,g) = mean(alignedRaw(:,cols),2,'omitnan');
    names(g) = cleanDisplayName(raw.names(firstIndex(g)));
    baseCounts = ones(numel(cols),1);
    if isfield(raw,'replicateCounts') && numel(raw.replicateCounts) >= max(cols)
        baseCounts = max(1,double(raw.replicateCounts(cols)));
    end
    measurements(g) = sum(baseCounts);
    sourceSeries(g) = strjoin(raw.names(cols)," | ");
end
matrix(~isfinite(matrix)) = 0;
if negativeMode == "clip", matrix(matrix < 0) = 0; end

% Make display names unique without changing their matching keys unnecessarily.
names = string(matlab.lang.makeUniqueStrings(cellstr(names)));
repeatTable = table(names,uniqueKeys,measurements,sourceSeries, ...
    'VariableNames',{'Name','NormalizedKey','MeasurementsAveraged','SourceSeries'});
repeated = measurements > 1;
if any(repeated)
    note = sprintf('%d repeated %s group(s) were averaged. See the repeat report.',nnz(repeated),kind);
    notes(end+1,1) = string(note);
end
if sum(negativeCounts) > 0
    if negativeMode == "clip"
        notes(end+1,1) = sprintf('%d negative %s values were clipped to zero.',sum(negativeCounts),kind);
    else
        notes(end+1,1) = sprintf('%d negative %s values were preserved.',sum(negativeCounts),kind);
    end
end
if sum(zeroFilledCounts) > 0
    notes(end+1,1) = sprintf('%d aligned %s values outside measured coverage were set to zero.',sum(zeroFilledCounts),kind);
end

coverageTable = table(string(raw.names(:)),minimums,maximums,points, ...
    negativeCounts,zeroFilledCounts, ...
    'VariableNames',{'OriginalName','OriginalMinimum_nm','OriginalMaximum_nm', ...
    'OriginalPointCount','NegativeValueCount','ZeroFilledGridPointCount'});

aligned.names = names;
aligned.wavelength = grid(:);
aligned.matrix = matrix;
aligned.repeatTable = repeatTable;
aligned.coverageTable = coverageTable;
aligned.sourceFiles = raw.sourceFiles;
aligned.sourceFolder = raw.sourceFolder;
aligned.inputLayout = raw.layout;
aligned.gridInfo = gridInfo;
aligned.negativeHandling = negativeMode;
if kind == "spectrum"
    aligned.spectra = matrix;
    aligned.sampleNames = names;
elseif kind == "channel"
    aligned.responses = matrix;
else
    error('Unknown series kind: %s',kind);
end

if settings.averageRepeatedSamples == false && any(repeated)
    notes(end+1,1) = "Repeated-series averaging is required by this version and was applied despite the advanced setting.";
end
end

function name = cleanDisplayName(name)
name = string(name);
name = regexprep(name,'\.[a-z0-9]{1,8}$','', 'ignorecase');
name = regexprep(name,'\s*\(\d+\)$','');
name = regexprep(name,'(?:[_\-\s]*(?:rep(?:licate)?|repeat|trial|run|measurement|meas)\s*\d+)$','', 'ignorecase');
name = strtrim(name);
if strlength(name) == 0, name = "Unnamed"; end
end
