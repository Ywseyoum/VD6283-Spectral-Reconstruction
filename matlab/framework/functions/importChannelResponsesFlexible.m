function [raw,notes] = importChannelResponsesFlexible(settings)
%IMPORTCHANNELRESPONSESFLEXIBLE Import any number of response curves.
%
% Supported combined layouts:
%   long:        Channel | Wavelength | Response
%   widecolumns: Wavelength | Channel1 | Channel2 | ...
%   widerows:    Channel | 400 | 401 | 402 | ...

notes = strings(0,1);
mode = lower(string(settings.channelInputMode));
files = normalizeConfiguredFileList(settings.channelFiles);

if mode == "interactive"
    choice = menu('How are the channel-response curves stored?', ...
        'Multiple files, one channel per file', ...
        'One combined channel-response file');
    if choice == 0, error('Channel-response input selection was canceled.'); end
    if choice == 1, mode = "individual"; else, mode = "combined"; end
end

if mode == "individual"
    if isempty(files)
        files = selectFrameworkFiles( ...
            {'*.csv;*.txt;*.xlsx;*.xls','Supported response files'}, ...
            'Select all channel-response files',true,settings);
        if isempty(files), error('No channel-response files were selected.'); end
    end
    [raw,moreNotes] = readIndividualChannels(files,settings);
elseif mode == "combined"
    if isempty(files)
        files = selectFrameworkFiles( ...
            {'*.csv;*.txt;*.xlsx;*.xls','Supported response files'}, ...
            'Select the combined channel-response file',false,settings);
        if isempty(files), error('No channel-response file was selected.'); end
    end
    [raw,moreNotes] = readCombinedChannels(files(1),settings);
else
    error('channelInputMode must be interactive, individual, or combined.');
end
notes = [notes; moreNotes(:)];
raw.sourceFiles = files;
raw.kind = "channel";
if isempty(raw.names)
    error('No usable channel-response curves were imported.');
end
end

function [raw,notes] = readIndividualChannels(files,settings)
notes = strings(0,1);
n = numel(files);
names = strings(n,1);
wavelengths = cell(n,1);
values = cell(n,1);
replicateCounts = ones(n,1);

configuredWavelength = settings.channelColumnMap.wavelength;
configuredResponse = settings.channelColumnMap.response;
rememberWavelengthName = "";
rememberResponseName = "";

for i = 1:n
    [T,fileNotes] = readTableFlexible(files(i));
    notes = [notes; fileNotes(:)]; %#ok<AGROW>
    numeric = numericCandidateColumns(T,2);
    if numel(numeric) < 2
        error('Channel file "%s" needs at least two numeric columns.',files(i));
    end

    wlSpec = configuredWavelength;
    responseSpec = configuredResponse;
    tableNames = string(T.Properties.VariableNames);
    if isempty(wlSpec) && strlength(rememberWavelengthName) > 0 && ...
            any(strcmpi(tableNames,rememberWavelengthName))
        wlSpec = rememberWavelengthName;
    end
    if isempty(responseSpec) && strlength(rememberResponseName) > 0 && ...
            any(strcmpi(tableNames,rememberResponseName))
        responseSpec = rememberResponseName;
    end

    if numel(numeric) == 2 && isempty(wlSpec) && isempty(responseSpec)
        wlIndex = numeric(1);
        responseIndex = numeric(2);
    else
        wlIndex = selectTableColumn(T, ...
            sprintf('Select the wavelength column for %s',char(files(i))), ...
            wlSpec,numeric);
        responseIndex = selectTableColumn(T, ...
            sprintf('Select the response column for %s',char(files(i))), ...
            responseSpec,setdiff(numeric,wlIndex,'stable'));
    end
    rememberWavelengthName = tableNames(wlIndex);
    rememberResponseName = tableNames(responseIndex);

    wl = tableColumnToNumeric(T,wlIndex);
    response = tableColumnToNumeric(T,responseIndex);
    [wl,response,duplicateCount] = cleanOneSeries(wl,response);
    if numel(wl) < 2
        error('Channel file "%s" has fewer than two valid wavelength points.',files(i));
    end
    wavelengths{i} = wl;
    values{i} = response;
    replicateCounts(i) = duplicateCount;
    [~,base] = fileparts(files(i));
    names(i) = cleanChannelName(base);
    if any(response < 0)
        notes(end+1,1) = "Negative channel responses found in " + files(i) + "."; %#ok<AGROW>
    end
end

raw.names = names;
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = replicateCounts;
raw.layout = "individual";
raw.sourceFolder = string(fileparts(files(1)));
end

function [raw,notes] = readCombinedChannels(filePath,settings)
[T,notes] = readTableFlexible(filePath);
layout = lower(string(settings.channelCombinedLayout));
if layout == "interactive"
    choice = menu('Choose the combined channel-response layout', ...
        'Long: Channel | Wavelength | Response', ...
        'Wide: wavelength rows and channel columns', ...
        'Wide: channel rows and wavelength columns');
    if choice == 0, error('Channel layout selection was canceled.'); end
    options = ["long","widecolumns","widerows"];
    layout = options(choice);
end
switch layout
    case "long"
        [raw,moreNotes] = readLongChannels(T,settings);
    case "widecolumns"
        [raw,moreNotes] = readWideColumnChannels(T,settings);
    case "widerows"
        [raw,moreNotes] = readWideRowChannels(T,settings);
    otherwise
        error('Unsupported channelCombinedLayout: %s',layout);
end
notes = [notes; moreNotes(:)];
raw.layout = layout;
raw.sourceFolder = string(fileparts(filePath));
end

function [raw,notes] = readLongChannels(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,2);
nonNumeric = setdiff(1:width(T),numeric,'stable');
if isempty(nonNumeric), nonNumeric = 1:width(T); end
channelIndex = selectTableColumn(T,'Select the channel-name column', ...
    settings.channelColumnMap.channel,nonNumeric);
wlIndex = selectTableColumn(T,'Select the wavelength column', ...
    settings.channelColumnMap.wavelength,setdiff(numeric,channelIndex,'stable'));
responseIndex = selectTableColumn(T,'Select the channel-response column', ...
    settings.channelColumnMap.response,setdiff(numeric,[channelIndex wlIndex],'stable'));

channel = tableColumnToString(T,channelIndex);
wl = tableColumnToNumeric(T,wlIndex);
response = tableColumnToNumeric(T,responseIndex);
valid = strlength(channel) > 0 & isfinite(wl) & isfinite(response);
channel = channel(valid); wl = wl(valid); response = response(valid);
if isempty(channel), error('No valid long-format channel rows were found.'); end

uniqueNames = unique(channel,'stable');
n = numel(uniqueNames);
wavelengths = cell(n,1); values = cell(n,1); counts = ones(n,1);
for i = 1:n
    rows = channel == uniqueNames(i);
    [wavelengths{i},values{i},counts(i)] = cleanOneSeries(wl(rows),response(rows));
    if any(values{i} < 0)
        notes(end+1,1) = "Negative responses found for channel " + uniqueNames(i) + "."; %#ok<AGROW>
    end
end
raw.names = uniqueNames;
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = counts;
end

function [raw,notes] = readWideColumnChannels(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,2);
wlIndex = selectTableColumn(T,'Select the wavelength column', ...
    settings.channelColumnMap.wavelength,numeric);
channelIndices = selectTableColumns(T,'Select every channel-response column', ...
    settings.channelColumnMap.channelColumns,setdiff(numeric,wlIndex,'stable'),wlIndex);
wlAll = tableColumnToNumeric(T,wlIndex);

names = string(T.Properties.VariableNames(channelIndices));
n = numel(channelIndices);
wavelengths = cell(n,1); values = cell(n,1); counts = ones(n,1);
for i = 1:n
    response = tableColumnToNumeric(T,channelIndices(i));
    [wavelengths{i},values{i},counts(i)] = cleanOneSeries(wlAll,response);
    if any(values{i} < 0)
        notes(end+1,1) = "Negative responses found for channel " + names(i) + "."; %#ok<AGROW>
    end
end
raw.names = names(:);
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = counts;
end

function [raw,notes] = readWideRowChannels(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,1);
nonNumeric = setdiff(1:width(T),numeric,'stable');
if isempty(nonNumeric), nonNumeric = 1:width(T); end
channelIndex = selectTableColumn(T,'Select the channel-name column', ...
    settings.channelColumnMap.channel,nonNumeric);
wlColumns = selectTableColumns(T,'Select every wavelength-response column', ...
    settings.channelColumnMap.wavelengthColumns,setdiff(1:width(T),channelIndex,'stable'),channelIndex);
wl = parseWavelengthHeaders(string(T.Properties.VariableNames(wlColumns)));
if any(~isfinite(wl))
    bad = string(T.Properties.VariableNames(wlColumns(~isfinite(wl))));
    error('Could not extract wavelength numbers from these column names: %s',strjoin(bad,', '));
end

names = tableColumnToString(T,channelIndex);
n = height(T);
wavelengths = cell(n,1); values = cell(n,1); counts = ones(n,1);
for i = 1:n
    response = nan(numel(wlColumns),1);
    for j = 1:numel(wlColumns)
        x = tableColumnToNumeric(T(:,wlColumns(j)),1);
        response(j) = x(i);
    end
    [wavelengths{i},values{i},counts(i)] = cleanOneSeries(wl,response);
    if any(values{i} < 0)
        notes(end+1,1) = "Negative responses found for channel " + names(i) + "."; %#ok<AGROW>
    end
end
raw.names = names(:);
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = counts;
end

function name = cleanChannelName(base)
name = string(base);
name = regexprep(name,'\s*\(\d+\)$','');
name = regexprep(name,'[_\-\s]*(response|sensitivity|channel)$','', 'ignorecase');
name = strtrim(name);
if strlength(name) == 0, name = "Channel"; end
end

function wl = parseWavelengthHeaders(headers)
headers = string(headers(:));
if all(~cellfun('isempty',regexp(cellstr(headers),'^Var\d+$','once')))
    error(['The selected columns have generic names such as Var1 and Var2, ' ...
        'so their actual wavelengths cannot be determined. Use a long-format ' ...
        'table or add wavelength values to the column headers.']);
end
headers = replace(headers,'p','.');
wl = nan(numel(headers),1);
for i = 1:numel(headers)
    token = regexp(char(headers(i)),'-?\d+(?:\.\d+)?','match','once');
    if ~isempty(token), wl(i) = str2double(token); end
end
end

function [wl,value,repeatCount] = cleanOneSeries(wl,value)
wl = double(wl(:)); value = double(value(:));
valid = isfinite(wl) & isfinite(value);
wl = wl(valid); value = value(valid);
[wl,order] = sort(wl); value = value(order);
if isempty(wl), repeatCount = 0; return; end
[uniqueWL,~,group] = unique(wl,'stable');
averaged = accumarray(group,value,[],@mean);
counts = accumarray(group,1);
repeatCount = max(counts);
wl = uniqueWL;
value = averaged;
end
