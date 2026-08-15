function output = predictNewSpectra(modelFile,newDetectorFile)
%PREDICTNEWSPECTRA Use a saved experiment model on new detector readings.
%
% Guided use:
%   output = predictNewSpectra;
%
% The new detector table may put samples in rows or columns. You will be
% asked to identify the sample/channel columns. Extra channels are ignored;
% every channel required by the model must be present.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot,'functions'));
settings = defaultSpectralSettings();
settings.projectRoot = string(projectRoot);
settings.guidedDialogs = true;

if nargin < 1 || strlength(string(modelFile)) == 0
    selected = selectFrameworkFiles({'*.mat','MATLAB model files'}, ...
        'Select Best_Trained_Model.mat',false,settings);
    if isempty(selected), error('No model file was selected.'); end
    modelFile = selected(1);
end
loaded = load(modelFile,'modelPackage');
if ~isfield(loaded,'modelPackage')
    error('The selected MAT file does not contain modelPackage.');
end
package = loaded.modelPackage;

settings.realDataLayout = "interactive";
if nargin >= 2 && strlength(string(newDetectorFile)) > 0
    settings.realSensorFile = string(newDetectorFile);
end
[rawData,importNotes] = importRealSensorDataFlexible(settings,"preserve");

required = string(package.featureNamesUsed(:));
available = string(rawData.featureNames(:));
[requiredIndex,availableIndex,shared,missingRequired,extraAvailable] = ...
    matchChannelSets(required,available);
if ~isempty(missingRequired)
    error('The new detector table is missing required channel(s): %s', ...
        strjoin(missingRequired,', '));
end

% matchChannelSets preserves the order of the first argument, so availableIndex
% reorders the new data into the exact feature order expected by the model.
ordered.rawX = rawData.rawX(:,availableIndex);
ordered.X = ordered.rawX;
ordered.sampleNames = rawData.sampleNames;
ordered.featureNames = shared;
ordered.mode = "prediction";
normalization = package.sensorNormalizationInfo;
[ordered,normNotes] = applySensorNormalization(ordered, ...
    normalization.mode,normalization.referenceChannelName);

prediction = predictSpectralModel(package.model,ordered.X);
T = array2table(prediction,'VariableNames',wavelengthVariableNames(package.wavelength));
T = addvars(T,ordered.sampleNames,'Before',1,'NewVariableNames','Sample');

sourceFolder = string(fileparts(rawData.sourceFile));
if strlength(sourceFolder) == 0, sourceFolder = string(pwd); end
stamp = string(datetime('now','Format','yyyyMMdd_HHmmss'));
outFile = fullfile(sourceFolder,"Predicted_Spectra_"+stamp+".csv");
writetable(T,outFile);

notes = [importNotes(:); normNotes(:)];
if ~isempty(extraAvailable)
    notes(end+1,1) = "Extra detector channels were ignored: " + strjoin(extraAvailable,', ');
end
notes(end+1,1) = "Predicted spectra use target normalization: " + string(package.targetNormalization) + ".";

output.prediction = prediction;
output.wavelength = package.wavelength;
output.sampleNames = ordered.sampleNames;
output.outputFile = outFile;
output.modelName = package.bestModelName;
output.notes = notes;

fprintf('Predicted %d spectrum/spectra using %s.\n',size(prediction,1),char(package.bestModelName));
fprintf('Saved to:\n%s\n',char(outFile));
for i = 1:numel(notes), fprintf('NOTE: %s\n',char(notes(i))); end
end

function names = wavelengthVariableNames(wavelength)
labels = "WL_" + compose('%.6f',wavelength(:)');
labels = replace(labels,'.','p');
names = matlab.lang.makeValidName(cellstr(labels));
names = matlab.lang.makeUniqueStrings(names);
end
