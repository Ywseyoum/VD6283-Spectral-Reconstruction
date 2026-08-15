function [sensorData,notes] = applySensorNormalization(sensorData,mode,reference)
%APPLYSENSORNORMALIZATION Apply a selected detector normalization.

notes = strings(0,1);
X = double(sensorData.rawX);
featureNames = string(sensorData.featureNames(:));
mode = lower(string(mode));
reference = string(reference);
referenceIndex = [];

switch mode
    case "none"
        denominator = ones(size(X,1),1);
        normalized = X;
    case "max"
        denominator = max(abs(X),[],2);
        zeroRows = ~isfinite(denominator) | denominator < eps;
        denominator(zeroRows) = 1;
        normalized = X ./ denominator;
        if any(zeroRows)
            notes(end+1,1) = sprintf('%d sample(s) had zero maximum magnitude and were left unchanged during max normalization.',nnz(zeroRows));
        end
    case "reference"
        referenceIndex = find(strcmpi(featureNames,reference),1);
        if isempty(referenceIndex)
            error('Reference channel "%s" was not found.',reference);
        end
        reference = featureNames(referenceIndex);
        denominator = X(:,referenceIndex);
        zeroRows = ~isfinite(denominator) | abs(denominator) < eps;
        denominator(zeroRows) = 1;
        normalized = X ./ denominator;
        if any(zeroRows)
            notes(end+1,1) = sprintf('%d sample(s) had a zero/missing reference value and were left unscaled for that row.',nnz(zeroRows));
        end
    otherwise
        error('Unknown normalization mode: %s',mode);
end
normalized(~isfinite(normalized)) = 0;
sensorData.X = normalized;
sensorData.normalizationInfo = struct('mode',mode, ...
    'referenceChannelName',reference,'referenceIndex',referenceIndex, ...
    'denominator',denominator);
end
