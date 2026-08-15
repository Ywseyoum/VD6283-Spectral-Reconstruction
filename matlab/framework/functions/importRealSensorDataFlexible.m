function [sensorData,notes] = importRealSensorDataFlexible(settings,negativeMode)
%IMPORTREALSENSORDATAFLEXIBLE Import real detector readings in either orientation.
%
% Samples-in-rows example:
%   Sample | Blue | Green | Red
%
% Samples-in-columns example:
%   Channel | Sample1 | Sample2 | Sample3

notes = strings(0,1);
filePath = string(settings.realSensorFile);
if strlength(filePath) == 0
    selected = selectFrameworkFiles( ...
        {'*.csv;*.txt;*.xlsx;*.xls','Supported real detector-data files'}, ...
        'Select the real detector-response table',false,settings);
    if isempty(selected), error('No real detector dataset was selected.'); end
    filePath = selected(1);
end
[T,fileNotes] = readTableFlexible(filePath);
notes = [notes; fileNotes(:)];

layout = lower(string(settings.realDataLayout));
if layout == "interactive"
    choice = menu('How is the real detector table oriented?', ...
        'Samples are rows; detector channels are columns', ...
        'Detector channels are rows; samples are columns');
    if choice == 0, error('Real-data layout selection was canceled.'); end
    if choice == 1, layout = "samplesinrows"; else, layout = "samplesincolumns"; end
end

switch layout
    case "samplesinrows"
        [sampleNames,featureNames,X,moreNotes] = readSamplesInRows(T,settings);
    case "samplesincolumns"
        [sampleNames,featureNames,X,moreNotes] = readSamplesInColumns(T,settings);
    otherwise
        error('realDataLayout must be interactive, samplesinrows, or samplesincolumns.');
end
notes = [notes; moreNotes(:)];

[sampleNames,X,sampleRepeatTable,moreNotes] = averageRepeatedRows(sampleNames,X);
notes = [notes; moreNotes(:)];
[featureNames,X,channelRepeatTable,moreNotes] = averageRepeatedColumns(featureNames,X);
notes = [notes; moreNotes(:)];

negativeCount = nnz(X < 0 & isfinite(X));
if negativeCount > 0
    if negativeMode == "clip"
        X(X < 0) = 0;
        notes(end+1,1) = sprintf('%d negative real detector values were clipped to zero.',negativeCount);
    else
        notes(end+1,1) = sprintf('%d negative real detector values were preserved.',negativeCount);
    end
end

% Impute only after repeats are averaged. Every imputation is reported.
missingCount = nnz(~isfinite(X));
if missingCount > 0
    for j = 1:size(X,2)
        missing = ~isfinite(X(:,j));
        finiteValues = X(~missing,j);
        if isempty(finiteValues)
            replacement = 0;
            notes(end+1,1) = "Channel " + featureNames(j) + ...
                " contained no finite values and was filled with zero.";
        else
            replacement = median(finiteValues);
        end
        X(missing,j) = replacement;
    end
    notes(end+1,1) = sprintf('%d missing real detector values were filled with the channel median and recorded.',missingCount);
end

sensorData.mode = "real";
sensorData.sampleNames = sampleNames(:);
sensorData.featureNames = featureNames(:);
sensorData.rawX = double(X);
sensorData.X = double(X);
sensorData.normalizationInfo = struct('mode',"none", ...
    'referenceChannelName',"",'referenceIndex',[], ...
    'denominator',ones(size(X,1),1));
sensorData.sourceFile = filePath;
sensorData.inputLayout = layout;
sensorData.repeatTable = sampleRepeatTable;
sensorData.channelRepeatTable = channelRepeatTable;
end

function [sampleNames,featureNames,X,notes] = readSamplesInRows(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,1);
nonNumeric = setdiff(1:width(T),numeric,'stable');
if isempty(nonNumeric), nonNumeric = 1:width(T); end
sampleIndex = selectTableColumn(T,'Select the sample-name/ID column', ...
    settings.realColumnMap.sample,nonNumeric);
channelIndices = selectTableColumns(T,'Select every real detector channel column', ...
    settings.realColumnMap.channelColumns,setdiff(numeric,sampleIndex,'stable'),sampleIndex);

sampleNames = tableColumnToString(T,sampleIndex);
featureNames = string(T.Properties.VariableNames(channelIndices))';
X = nan(height(T),numel(channelIndices));
for j = 1:numel(channelIndices)
    X(:,j) = tableColumnToNumeric(T,channelIndices(j));
end
valid = strlength(strtrim(sampleNames)) > 0;
if nnz(~valid) > 0
    notes(end+1,1) = sprintf('%d real-data rows with empty sample names were removed.',nnz(~valid));
end
sampleNames = sampleNames(valid);
X = X(valid,:);
end

function [sampleNames,featureNames,X,notes] = readSamplesInColumns(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,1);
nonNumeric = setdiff(1:width(T),numeric,'stable');
if isempty(nonNumeric), nonNumeric = 1:width(T); end
channelIndex = selectTableColumn(T,'Select the channel-name column', ...
    settings.realColumnMap.channel,nonNumeric);
sampleIndices = selectTableColumns(T,'Select every sample-reading column', ...
    settings.realColumnMap.sampleColumns,setdiff(numeric,channelIndex,'stable'),channelIndex);

featureNames = tableColumnToString(T,channelIndex);
sampleNames = string(T.Properties.VariableNames(sampleIndices))';
M = nan(height(T),numel(sampleIndices));
for j = 1:numel(sampleIndices)
    M(:,j) = tableColumnToNumeric(T,sampleIndices(j));
end
validFeature = strlength(strtrim(featureNames)) > 0;
if nnz(~validFeature) > 0
    notes(end+1,1) = sprintf('%d rows with empty channel names were removed.',nnz(~validFeature));
end
featureNames = featureNames(validFeature);
M = M(validFeature,:);
X = M';
end

function [names,X,report,notes] = averageRepeatedRows(names,X)
notes = strings(0,1);
keys = normalizeEntityKey(names,true);
[uniqueKeys,firstIndex,group] = unique(keys,'stable');
newX = nan(numel(uniqueKeys),size(X,2));
counts = zeros(numel(uniqueKeys),1);
sources = strings(numel(uniqueKeys),1);
newNames = strings(numel(uniqueKeys),1);
for i = 1:numel(uniqueKeys)
    rows = find(group == i);
    newX(i,:) = mean(X(rows,:),1,'omitnan');
    counts(i) = numel(rows);
    newNames(i) = cleanDisplayName(names(firstIndex(i)));
    sources(i) = strjoin(names(rows)," | ");
end
names = string(matlab.lang.makeUniqueStrings(cellstr(newNames)));
X = newX;
report = table(names,uniqueKeys,counts,sources, ...
    'VariableNames',{'Sample','NormalizedKey','MeasurementsAveraged','SourceRows'});
if any(counts > 1)
    notes(end+1,1) = sprintf('%d repeated real sample group(s) were averaged.',nnz(counts > 1));
end
end

function [names,X,report,notes] = averageRepeatedColumns(names,X)
notes = strings(0,1);
keys = normalizeEntityKey(names,true);
[uniqueKeys,firstIndex,group] = unique(keys,'stable');
newX = nan(size(X,1),numel(uniqueKeys));
counts = zeros(numel(uniqueKeys),1);
sources = strings(numel(uniqueKeys),1);
newNames = strings(numel(uniqueKeys),1);
for i = 1:numel(uniqueKeys)
    cols = find(group == i);
    newX(:,i) = mean(X(:,cols),2,'omitnan');
    counts(i) = numel(cols);
    newNames(i) = cleanDisplayName(names(firstIndex(i)));
    sources(i) = strjoin(names(cols)," | ");
end
names = string(matlab.lang.makeUniqueStrings(cellstr(newNames)));
X = newX;
report = table(names,uniqueKeys,counts,sources, ...
    'VariableNames',{'Channel','NormalizedKey','MeasurementsAveraged','SourceColumns'});
if any(counts > 1)
    notes(end+1,1) = sprintf('%d repeated real channel group(s) were averaged.',nnz(counts > 1));
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
