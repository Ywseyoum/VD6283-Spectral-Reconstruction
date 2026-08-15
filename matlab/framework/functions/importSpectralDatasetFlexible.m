function [raw,notes] = importSpectralDatasetFlexible(settings)
%IMPORTSPECTRALDATASETFLEXIBLE Import individual or combined spectra.
%
% Supported combined layouts:
%   long:        Sample | Wavelength | Intensity
%   widecolumns: Wavelength | Sample1 | Sample2 | ...
%   widerows:    Sample | 400 | 401 | 402 | ...

notes = strings(0,1);
mode = lower(string(settings.spectralInputMode));
files = normalizeConfiguredFileList(settings.spectralFiles);

if mode == "interactive"
    choice = menu('How is the reference spectral dataset stored?', ...
        'Multiple files, one spectrum per file', ...
        'One combined spectral dataset file');
    if choice == 0, error('Spectral input selection was canceled.'); end
    if choice == 1, mode = "individual"; else, mode = "combined"; end
end

if mode == "individual"
    if isempty(files)
        files = selectFrameworkFiles( ...
            {'*.csv;*.txt;*.xlsx;*.xls','Supported spectral files'}, ...
            'Select all individual spectrum files',true,settings);
        if isempty(files), error('No spectral files were selected.'); end
    end
    [raw,moreNotes] = readIndividualSpectra(files,settings);
elseif mode == "combined"
    if isempty(files)
        files = selectFrameworkFiles( ...
            {'*.csv;*.txt;*.xlsx;*.xls','Supported spectral files'}, ...
            'Select the combined spectral dataset',false,settings);
        if isempty(files), error('No spectral dataset was selected.'); end
    end
    [raw,moreNotes] = readCombinedSpectra(files(1),settings);
else
    error('spectralInputMode must be interactive, individual, or combined.');
end
notes = [notes; moreNotes(:)];
raw.sourceFiles = files;
raw.kind = "spectrum";
if isempty(raw.names)
    error('No usable spectra were imported.');
end
end

function [raw,notes] = readIndividualSpectra(files,settings)
notes = strings(0,1);
n = numel(files);
names = strings(n,1);
wavelengths = cell(n,1);
values = cell(n,1);
replicateCounts = ones(n,1);

configuredWavelength = settings.spectralColumnMap.wavelength;
configuredIntensity = settings.spectralColumnMap.intensity;
rememberWavelengthName = "";
rememberIntensityName = "";

for i = 1:n
    [T,fileNotes] = readTableFlexible(files(i));
    notes = [notes; fileNotes(:)]; %#ok<AGROW>
    numeric = numericCandidateColumns(T,2);
    if numel(numeric) < 2
        error('Spectrum file "%s" needs at least two numeric columns.',files(i));
    end

    wlSpec = configuredWavelength;
    intSpec = configuredIntensity;
    tableNames = string(T.Properties.VariableNames);
    if isempty(wlSpec) && strlength(rememberWavelengthName) > 0 && ...
            any(strcmpi(tableNames,rememberWavelengthName))
        wlSpec = rememberWavelengthName;
    end
    if isempty(intSpec) && strlength(rememberIntensityName) > 0 && ...
            any(strcmpi(tableNames,rememberIntensityName))
        intSpec = rememberIntensityName;
    end

    if numel(numeric) == 2 && isempty(wlSpec) && isempty(intSpec)
        wlIndex = numeric(1);
        intensityIndex = numeric(2);
    else
        wlIndex = selectTableColumn(T, ...
            sprintf('Select the wavelength column for %s',char(files(i))), ...
            wlSpec,numeric);
        intensityIndex = selectTableColumn(T, ...
            sprintf('Select the intensity column for %s',char(files(i))), ...
            intSpec,setdiff(numeric,wlIndex,'stable'));
    end
    rememberWavelengthName = tableNames(wlIndex);
    rememberIntensityName = tableNames(intensityIndex);

    wl = tableColumnToNumeric(T,wlIndex);
    intensity = tableColumnToNumeric(T,intensityIndex);
    [wl,intensity,duplicateCount] = cleanOneSeries(wl,intensity);
    if numel(wl) < 2
        error('Spectrum file "%s" has fewer than two valid wavelength points.',files(i));
    end
    wavelengths{i} = wl;
    values{i} = intensity;
    replicateCounts(i) = duplicateCount;
    [~,base] = fileparts(files(i));
    names(i) = string(base);
    if any(intensity < 0)
        notes(end+1,1) = "Negative spectral intensities found in " + files(i) + "."; %#ok<AGROW>
    end
end

raw.names = names;
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = replicateCounts;
raw.layout = "individual";
raw.sourceFolder = string(fileparts(files(1)));
end

function [raw,notes] = readCombinedSpectra(filePath,settings)
[T,notes] = readTableFlexible(filePath);
layout = lower(string(settings.spectralCombinedLayout));
if layout == "interactive"
    choice = menu('Choose the combined spectral dataset layout', ...
        'Long: Sample | Wavelength | Intensity (recommended)', ...
        'Wide: wavelength rows and sample columns', ...
        'Wide: sample rows and wavelength columns');
    if choice == 0, error('Spectral layout selection was canceled.'); end
    options = ["long","widecolumns","widerows"];
    layout = options(choice);
end

switch layout
    case "long"
        [raw,moreNotes] = readLongSpectra(T,settings);
    case "widecolumns"
        [raw,moreNotes] = readWideColumnSpectra(T,settings);
    case "widerows"
        [raw,moreNotes] = readWideRowSpectra(T,settings);
    otherwise
        error('Unsupported spectralCombinedLayout: %s',layout);
end
notes = [notes; moreNotes(:)];
raw.layout = layout;
raw.sourceFolder = string(fileparts(filePath));
end

function [raw,notes] = readLongSpectra(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,2);
nonNumeric = setdiff(1:width(T),numeric,'stable');
if isempty(nonNumeric), nonNumeric = 1:width(T); end
sampleIndex = selectTableColumn(T,'Select the sample-name/ID column', ...
    settings.spectralColumnMap.sample,nonNumeric);
wlIndex = selectTableColumn(T,'Select the wavelength column', ...
    settings.spectralColumnMap.wavelength,setdiff(numeric,sampleIndex,'stable'));
intensityIndex = selectTableColumn(T,'Select the spectral-intensity column', ...
    settings.spectralColumnMap.intensity,setdiff(numeric,[sampleIndex wlIndex],'stable'));

sample = tableColumnToString(T,sampleIndex);
wl = tableColumnToNumeric(T,wlIndex);
intensity = tableColumnToNumeric(T,intensityIndex);
valid = strlength(sample) > 0 & isfinite(wl) & isfinite(intensity);
sample = sample(valid); wl = wl(valid); intensity = intensity(valid);
if isempty(sample), error('No valid long-format spectral rows were found.'); end

uniqueNames = unique(sample,'stable');
n = numel(uniqueNames);
wavelengths = cell(n,1); values = cell(n,1); counts = ones(n,1);
for i = 1:n
    rows = sample == uniqueNames(i);
    [wavelengths{i},values{i},counts(i)] = cleanOneSeries(wl(rows),intensity(rows));
    if any(values{i} < 0)
        notes(end+1,1) = "Negative spectral intensities found for sample " + uniqueNames(i) + "."; %#ok<AGROW>
    end
end
raw.names = uniqueNames;
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = counts;
end

function [raw,notes] = readWideColumnSpectra(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,2);
wlIndex = selectTableColumn(T,'Select the wavelength column', ...
    settings.spectralColumnMap.wavelength,numeric);
sampleIndices = selectTableColumns(T,'Select every spectrum/sample column', ...
    settings.spectralColumnMap.sampleColumns,setdiff(numeric,wlIndex,'stable'),wlIndex);
wlAll = tableColumnToNumeric(T,wlIndex);

names = string(T.Properties.VariableNames(sampleIndices));
n = numel(sampleIndices);
wavelengths = cell(n,1); values = cell(n,1); counts = ones(n,1);
for i = 1:n
    intensity = tableColumnToNumeric(T,sampleIndices(i));
    [wavelengths{i},values{i},counts(i)] = cleanOneSeries(wlAll,intensity);
    if any(values{i} < 0)
        notes(end+1,1) = "Negative spectral intensities found for sample " + names(i) + "."; %#ok<AGROW>
    end
end
raw.names = names(:);
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = counts;
end

function [raw,notes] = readWideRowSpectra(T,settings)
notes = strings(0,1);
numeric = numericCandidateColumns(T,1);
nonNumeric = setdiff(1:width(T),numeric,'stable');
if isempty(nonNumeric), nonNumeric = 1:width(T); end
sampleIndex = selectTableColumn(T,'Select the sample-name/ID column', ...
    settings.spectralColumnMap.sample,nonNumeric);
wlColumns = selectTableColumns(T,'Select every wavelength-intensity column', ...
    settings.spectralColumnMap.wavelengthColumns,setdiff(1:width(T),sampleIndex,'stable'),sampleIndex);
wl = parseWavelengthHeaders(string(T.Properties.VariableNames(wlColumns)));
if any(~isfinite(wl))
    bad = string(T.Properties.VariableNames(wlColumns(~isfinite(wl))));
    error('Could not extract wavelength numbers from these column names: %s',strjoin(bad,', '));
end

names = tableColumnToString(T,sampleIndex);
n = height(T);
wavelengths = cell(n,1); values = cell(n,1); counts = ones(n,1);
for i = 1:n
    intensity = nan(numel(wlColumns),1);
    for j = 1:numel(wlColumns)
        x = tableColumnToNumeric(T(:,wlColumns(j)),1);
        intensity(j) = x(i);
    end
    [wavelengths{i},values{i},counts(i)] = cleanOneSeries(wl,intensity);
    if any(values{i} < 0)
        notes(end+1,1) = "Negative spectral intensities found for sample " + names(i) + "."; %#ok<AGROW>
    end
end
raw.names = names(:);
raw.wavelengths = wavelengths;
raw.values = values;
raw.replicateCounts = counts;
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
if isempty(wl)
    repeatCount = 0; return
end
[uniqueWL,~,group] = unique(wl,'stable');
averaged = accumarray(group,value,[],@mean);
counts = accumarray(group,1);
repeatCount = max(counts);
wl = uniqueWL;
value = averaged;
end
