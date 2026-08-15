function [dataset,notes] = prepareExperimentDataset(spectral,sensorData,settings,experimentName)
%PREPAREEXPERIMENTDATASET Match samples and construct X/Y matrices.

notes = strings(0,1);
[spectralIndex,sensorIndex,matchReport,matchNotes] = flexibleMatchSamples( ...
    spectral.names,sensorData.sampleNames,settings);
notes = [notes; matchNotes(:)];
if isempty(spectralIndex)
    error(['No detector samples matched the reference spectra. Matching ignores ' ...
        'case, extensions, spaces, underscores, and hyphens, and manual matching ' ...
        'was not completed.']);
end

Xall = double(sensorData.X(sensorIndex,:));
Yall = double(spectral.spectra(:,spectralIndex)');
sampleNames = spectral.names(spectralIndex);

% Scale reference spectra for reconstruction while recording every divisor.
normalization = lower(string(settings.targetNormalization));
switch normalization
    case "peak"
        targetScale = max(abs(Yall),[],2);
    case "area"
        targetScale = trapz(spectral.wavelength,abs(Yall),2);
    case "none"
        targetScale = ones(size(Yall,1),1);
    otherwise
        error('targetNormalization must be peak, area, or none.');
end
zeroScale = ~isfinite(targetScale) | targetScale < eps;
if any(zeroScale)
    targetScale(zeroScale) = 1;
    notes(end+1,1) = sprintf('%d target spectrum/spectra had zero scale and were left unscaled.',nnz(zeroScale));
end
Yall = Yall ./ targetScale;

featureNamesOriginal = string(sensorData.featureNames(:));
keepFeature = true(1,size(Xall,2));
if settings.dropConstantFeatures && size(Xall,2) > 0 && size(Xall,1) > 1
    spread = max(Xall,[],1)-min(Xall,[],1);
    candidate = isfinite(spread) & spread > settings.constantFeatureTolerance;
    if any(candidate)
        keepFeature = candidate;
    else
        notes(end+1,1) = "Every detector channel was constant; channels were retained so the experiment could continue.";
    end
end
X = Xall(:,keepFeature);
featureNames = featureNamesOriginal(keepFeature);
droppedFeatureNames = featureNamesOriginal(~keepFeature);
if ~isempty(droppedFeatureNames)
    notes(end+1,1) = "Constant detector channels removed from ML: " + strjoin(droppedFeatureNames,', ');
end

validRows = all(isfinite(X),2) & all(isfinite(Yall),2);
if any(~validRows)
    notes(end+1,1) = sprintf('%d matched sample(s) with nonfinite values were removed.',nnz(~validRows));
end
X = X(validRows,:); Y = Yall(validRows,:);
sampleNames = sampleNames(validRows);
spectralIndex = spectralIndex(validRows);
sensorIndex = sensorIndex(validRows);
targetScale = targetScale(validRows);
if isempty(X) || isempty(Y)
    error('No finite matched samples remained after data preparation.');
end

n = size(X,1);
if n == 1
    notes(end+1,1) = "Only one matched spectrum is available. Import, preprocessing, fitting, plots, and export will run, but no held-out validation is mathematically possible.";
elseif n < settings.smallSampleWarningThreshold
    notes(end+1,1) = sprintf(['Only %d matched spectra are available. Model fitting will run, but ' ...
        'performance estimates are demonstration-only and highly unstable.'],n);
elseif n < settings.recommendedSampleThreshold
    notes(end+1,1) = sprintf(['%d matched spectra are available. Cross-validation will run, but ' ...
        'this remains a small pilot dataset.'],n);
end

if size(X,2) == 0
    error('No detector channels remained for the experiment.');
end

dataset.experimentName = string(experimentName);
dataset.X = X;
dataset.Y = Y;
dataset.wavelength = spectral.wavelength(:);
dataset.sampleNames = sampleNames(:);
dataset.featureNames = featureNames(:);
dataset.originalFeatureNames = featureNamesOriginal;
dataset.featureKeepMask = keepFeature(:)';
dataset.droppedFeatureNames = droppedFeatureNames(:);
dataset.spectralIndices = spectralIndex(:);
dataset.sensorIndices = sensorIndex(:);
dataset.targetNormalization = normalization;
dataset.targetScale = targetScale;
dataset.sensorNormalizationInfo = sensorData.normalizationInfo;
dataset.matchReport = matchReport;
dataset.preparationWarnings = notes;
end
