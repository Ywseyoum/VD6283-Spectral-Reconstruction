function [grid,info,notes] = buildWavelengthGrid(spectralRaw,channelRaw,settings)
%BUILDWAVELENGTHGRID Ask how coverage differences should be handled.

notes = strings(0,1);
[sMin,sMax,sSpacing] = summarizeRanges(spectralRaw.wavelengths);
[cMin,cMax,cSpacing] = summarizeRanges(channelRaw.wavelengths);
allMin = [sMin; cMin]; allMax = [sMax; cMax];

mode = lower(string(settings.wavelengthCoverageMode));
if mode == "interactive"
    choice = menu('How should different wavelength coverages be handled?', ...
        'Use only the range shared by every spectrum and channel', ...
        'Use the spectral dataset range; set unavailable channel regions to zero', ...
        'Use the full union; set every unavailable region to zero', ...
        'Enter a custom wavelength range');
    if choice == 0, error('Wavelength coverage selection was canceled.'); end
    options = ["overlap","spectralrange","unionzero","custom"];
    mode = options(choice);
end

switch mode
    case "overlap"
        defaultMin = max(allMin);
        defaultMax = min(allMax);
        if defaultMax <= defaultMin
            error(['The uploaded files have no wavelength interval shared by every ' ...
                'spectrum and channel. Choose a zero-padding or custom option.']);
        end
    case "spectralrange"
        defaultMin = min(sMin);
        defaultMax = max(sMax);
        notes(end+1,1) = "Channel-response regions outside their measured ranges will be set to zero.";
    case "unionzero"
        defaultMin = min(allMin);
        defaultMax = max(allMax);
        notes(end+1,1) = "Unavailable regions outside each uploaded series will be set to zero.";
    case "custom"
        defaultMin = max(allMin);
        defaultMax = min(allMax);
        if defaultMax <= defaultMin
            defaultMin = min(sMin);
            defaultMax = max(sMax);
        end
    otherwise
        error('Unsupported wavelengthCoverageMode: %s',mode);
end

allSpectralSpacing = sSpacing(isfinite(sSpacing) & sSpacing > 0);
if isempty(allSpectralSpacing)
    allSpacing = [sSpacing; cSpacing];
    allSpacing = allSpacing(isfinite(allSpacing) & allSpacing > 0);
    if isempty(allSpacing), defaultSpacing = 1; else, defaultSpacing = min(allSpacing); end
else
    defaultSpacing = min(allSpectralSpacing);
end

if ~isempty(settings.wavelengthRange)
    range = double(settings.wavelengthRange(:)');
    if numel(range) ~= 2, error('settings.wavelengthRange must contain [minimum maximum].'); end
    minimum = range(1); maximum = range(2);
else
    minimum = defaultMin; maximum = defaultMax;
end
if ~isempty(settings.wavelengthSpacing)
    spacing = double(settings.wavelengthSpacing(1));
else
    spacing = defaultSpacing;
end

if settings.guidedDialogs && (isempty(settings.wavelengthRange) || isempty(settings.wavelengthSpacing))
    answer = inputdlg({ ...
        'Starting wavelength (nm):', ...
        'Ending wavelength (nm):', ...
        'Wavelength spacing (nm):'}, ...
        'Review or override the wavelength grid',[1 50], ...
        {num2str(minimum,'%.10g'),num2str(maximum,'%.10g'),num2str(spacing,'%.10g')});
    if isempty(answer), error('Wavelength-grid configuration was canceled.'); end
    minimum = str2double(answer{1});
    maximum = str2double(answer{2});
    spacing = str2double(answer{3});
end

if ~isfinite(minimum) || ~isfinite(maximum) || maximum <= minimum
    error('The wavelength minimum and maximum are invalid.');
end
if ~isfinite(spacing) || spacing <= 0
    error('The wavelength spacing must be a positive number.');
end
numberPoints = floor((maximum-minimum)/spacing)+1;
if numberPoints < 2, error('The chosen wavelength grid contains fewer than two points.'); end
if numberPoints > settings.maximumWavelengthPoints
    error(['The chosen grid would contain %d points, exceeding the configured ' ...
        'limit of %d. Increase the spacing or the configured limit.'], ...
        numberPoints,settings.maximumWavelengthPoints);
end

grid = (minimum:spacing:maximum)';
if grid(end) < maximum-spacing*1e-8
    grid(end+1,1) = maximum;
end

info.mode = mode;
info.minimum = minimum;
info.maximum = maximum;
info.spacing = spacing;
info.numberPoints = numel(grid);
info.defaultMinimum = defaultMin;
info.defaultMaximum = defaultMax;
info.defaultSpacing = defaultSpacing;
info.spectralMinimums = sMin;
info.spectralMaximums = sMax;
info.channelMinimums = cMin;
info.channelMaximums = cMax;

if minimum < min(sMin) || maximum > max(sMax)
    notes(end+1,1) = "The selected grid extends beyond at least part of the spectral dataset; unavailable spectral regions will be zero-filled.";
end
if minimum < min(cMin) || maximum > max(cMax)
    notes(end+1,1) = "The selected grid extends beyond at least part of the channel-response data; unavailable response regions will be zero-filled.";
end
end

function [minimums,maximums,spacings] = summarizeRanges(series)
n = numel(series);
minimums = nan(n,1); maximums = nan(n,1); spacings = nan(n,1);
for i = 1:n
    x = double(series{i}(:));
    x = sort(x(isfinite(x)));
    if isempty(x), continue; end
    minimums(i) = x(1); maximums(i) = x(end);
    d = diff(unique(x)); d = d(d > 0 & isfinite(d));
    if ~isempty(d), spacings(i) = median(d); end
end
valid = isfinite(minimums) & isfinite(maximums);
minimums = minimums(valid); maximums = maximums(valid); spacings = spacings(valid);
if isempty(minimums), error('No valid wavelength ranges were found.'); end
end
