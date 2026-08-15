function results = runSpectralReconstruction(userSettings)
%RUNSPECTRALRECONSTRUCTION Run the adaptable guided reconstruction workflow.
%
% The framework begins at the spectral-reconstruction stage:
%   reference spectra + sensor channel-response curves
%       -> synthetic responses, real detector readings, or both
%       -> model comparison
%       -> reconstructed spectra, metrics, figures, and saved models
%
% It does not require RM or BB calibration files.

projectRoot = fileparts(mfilename('fullpath'));
addpath(fullfile(projectRoot,'functions'));

settings = defaultSpectralSettings();
if nargin >= 1 && ~isempty(userSettings)
    settings = mergeSettings(settings,userSettings);
end
settings.projectRoot = string(projectRoot);
rng(settings.randomSeed);

clc;
fprintf('\n============================================================\n');
fprintf(' ADAPTABLE SPECTRAL RECONSTRUCTION FRAMEWORK\n');
fprintf('============================================================\n');
fprintf('This run starts with reference spectra and channel-response curves.\n\n');

runWarnings = strings(0,1);
pathwayMode = choosePathwayMode(settings);

fprintf('1) Importing reference spectral dataset...\n');
[spectralRaw,notes] = importSpectralDatasetFlexible(settings);
runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
fprintf('   Imported %d raw spectral series.\n',numel(spectralRaw.names));

fprintf('\n2) Importing sensor channel-response curves...\n');
[channelRaw,notes] = importChannelResponsesFlexible(settings);
runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
fprintf('   Imported %d raw channel-response series.\n',numel(channelRaw.names));

[negativeMode,negativeNote] = chooseNegativeHandling(settings);
if strlength(negativeNote) > 0
    runWarnings(end+1,1) = negativeNote; %#ok<AGROW>
end

fprintf('\n3) Configuring the common wavelength grid...\n');
[grid,gridInfo,notes] = buildWavelengthGrid(spectralRaw,channelRaw,settings);
runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
fprintf('   Grid: %.6g to %.6g nm, %.6g nm spacing, %d points.\n', ...
    grid(1),grid(end),gridInfo.spacing,numel(grid));

fprintf('\n4) Standardizing spectra and channel responses...\n');
[spectral,notes] = alignSeriesCollection(spectralRaw,grid,negativeMode, ...
    gridInfo,'spectrum',settings);
runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
[sensorSet,notes] = alignSeriesCollection(channelRaw,grid,negativeMode, ...
    gridInfo,'channel',settings);
runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>

fprintf('   Standardized spectra: %d samples.\n',numel(spectral.names));
fprintf('   Standardized channels: %d channels (%s).\n', ...
    numel(sensorSet.names),char(strjoin(cellstr(sensorSet.names),', ')));

syntheticData = struct();
realData = struct();
experiments = struct('name',{},'pathway',{},'sensorData',{},'description',{});

if pathwayMode == "synthetic" || pathwayMode == "both"
    fprintf('\n5A) Generating synthetic detector responses...\n');
    syntheticRaw = generateSyntheticSensorData(spectral,sensorSet);
    [syntheticData,notes] = configureAndNormalizeSensorData( ...
        syntheticRaw,settings.syntheticNormalization, ...
        settings.syntheticReferenceChannel,'synthetic',settings);
    runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
    experiments(end+1) = makeExperiment('Synthetic_AllChannels','synthetic', ...
        syntheticData,'Synthetic data using every uploaded response curve.'); %#ok<AGROW>
end

if pathwayMode == "real" || pathwayMode == "both"
    fprintf('\n5B) Importing real detector-response data...\n');
    [realRaw,notes] = importRealSensorDataFlexible(settings,negativeMode);
    runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
    [realData,notes] = configureAndNormalizeSensorData( ...
        realRaw,settings.realNormalization,settings.realReferenceChannel, ...
        'real',settings);
    runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
    experiments(end+1) = makeExperiment('Real_AllChannels','real', ...
        realData,'Real detector data using every imported detector channel.'); %#ok<AGROW>
end

sharedInfo = struct('available',false,'channelNames',strings(0,1), ...
    'realOnly',strings(0,1),'syntheticOnly',strings(0,1));
if pathwayMode == "both"
    fprintf('\n5C) Building the fair shared-channel comparison...\n');
    [realIndex,syntheticIndex,sharedNames,realOnly,syntheticOnly] = ...
        matchChannelSets(realData.featureNames,syntheticData.featureNames);
    sharedInfo.available = ~isempty(sharedNames);
    sharedInfo.channelNames = sharedNames;
    sharedInfo.realOnly = realOnly;
    sharedInfo.syntheticOnly = syntheticOnly;

    if ~isempty(realOnly)
        note = "Real-only channels retained in Real_AllChannels but unavailable for synthetic generation: " + ...
            strjoin(realOnly,', ');
        runWarnings(end+1,1) = note; %#ok<AGROW>
        fprintf('   %s\n',char(note));
    end
    if ~isempty(syntheticOnly)
        note = "Response-curve-only channels retained in Synthetic_AllChannels but omitted from real modeling: " + ...
            strjoin(syntheticOnly,', ');
        runWarnings(end+1,1) = note; %#ok<AGROW>
        fprintf('   %s\n',char(note));
    end

    if isempty(sharedNames)
        note = "No real and synthetic channel names matched, so the shared-channel comparison was skipped.";
        runWarnings(end+1,1) = note; %#ok<AGROW>
        warning('%s',note);
    else
        realSharedRaw = subsetSensorData(realData,realIndex,sharedNames,'real-shared');
        syntheticSharedRaw = subsetSensorData(syntheticData,syntheticIndex,sharedNames,'synthetic-shared');

        [sharedMode,sharedReference] = chooseSharedNormalization( ...
            sharedNames,settings.sharedNormalization, ...
            settings.sharedReferenceChannel,settings);
        [realShared,notes] = applySensorNormalization( ...
            realSharedRaw,sharedMode,sharedReference);
        runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
        [syntheticShared,notes] = applySensorNormalization( ...
            syntheticSharedRaw,sharedMode,sharedReference);
        runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>

        experiments(end+1) = makeExperiment('Real_SharedChannels','real-shared', ...
            realShared,'Real detector data restricted to channels shared with synthetic data.'); %#ok<AGROW>
        experiments(end+1) = makeExperiment('Synthetic_SharedChannels','synthetic-shared', ...
            syntheticShared,'Synthetic data restricted to channels shared with real data.'); %#ok<AGROW>
        fprintf('   Shared channels: %s\n',char(strjoin(cellstr(sharedNames),', ')));
    end
end

fprintf('\n6) Matching samples and running model experiments...\n');
experimentResults = repmat(emptyExperimentResult(),numel(experiments),1);
for i = 1:numel(experiments)
    fprintf('\n------------------------------------------------------------\n');
    fprintf(' EXPERIMENT: %s\n',experiments(i).name);
    fprintf('------------------------------------------------------------\n');
    expResult = emptyExperimentResult();
    expResult.name = string(experiments(i).name);
    expResult.pathway = string(experiments(i).pathway);
    expResult.description = string(experiments(i).description);
    try
        [dataset,notes] = prepareExperimentDataset( ...
            spectral,experiments(i).sensorData,settings,experiments(i).name);
        runWarnings = [runWarnings; notes(:)]; %#ok<AGROW>
        completed = runReconstructionExperiment(dataset,settings,experiments(i));
        expResult.dataset = completed.dataset;
        expResult.modelResults = completed.modelResults;
        expResult.finalModel = completed.finalModel;
        expResult.errorMessage = "";
        expResult.status = "Completed";
    catch ME
        expResult.errorMessage = string(ME.message);
        expResult.status = "Skipped";
        runWarnings(end+1,1) = "Experiment " + expResult.name + " was skipped: " + string(ME.message); %#ok<AGROW>
        warning('Experiment %s was skipped: %s',experiments(i).name,ME.message);
    end
    experimentResults(i,1) = expResult;
end

fprintf('\n7) Saving standardized inputs, diagnostics, figures, and models...\n');
runWarnings = runWarnings(strlength(strtrim(runWarnings)) > 0);
runWarnings = unique(runWarnings,'stable');
output = saveFrameworkResults(projectRoot,spectral,sensorSet,syntheticData, ...
    realData,experimentResults,sharedInfo,gridInfo,negativeMode, ...
    runWarnings,settings,pathwayMode);

results.status = "Complete";
results.pathwayMode = pathwayMode;
results.outputFolder = output.outputFolder;
results.spectral = spectral;
results.sensorSet = sensorSet;
results.syntheticData = syntheticData;
results.realData = realData;
results.experiments = experimentResults;
results.sharedInfo = sharedInfo;
results.warnings = unique(runWarnings,'stable');

fprintf('\n============================================================\n');
fprintf(' RUN COMPLETE\n');
fprintf('============================================================\n');
fprintf('Results saved to:\n%s\n',char(output.outputFolder));
printBestExperimentSummary(experimentResults);
if settings.guidedDialogs && isfield(settings,'showCompletionDialog') && settings.showCompletionDialog
    message = sprintf(['Run complete.\n\nResults, graphs, reports, and trained models were saved to:\n%s'], ...
        char(output.outputFolder));
    try
        msgbox(message,'Spectral reconstruction complete','help');
    catch
    end
end
end

function merged = mergeSettings(defaults,overrides)
merged = defaults;
fields = fieldnames(overrides);
for i = 1:numel(fields)
    if isstruct(overrides.(fields{i})) && isfield(defaults,fields{i}) && ...
            isstruct(defaults.(fields{i}))
        merged.(fields{i}) = mergeSettings(defaults.(fields{i}),overrides.(fields{i}));
    else
        merged.(fields{i}) = overrides.(fields{i});
    end
end
end

function mode = choosePathwayMode(settings)
mode = lower(string(settings.pathwayMode));
if mode == "interactive"
    choice = menu('Which pathway should this run use?', ...
        'Synthetic only','Real only','Both real and synthetic');
    if choice == 0, error('No pathway was selected.'); end
    options = ["synthetic","real","both"];
    mode = options(choice);
end
if ~any(mode == ["synthetic","real","both"])
    error('pathwayMode must be interactive, synthetic, real, or both.');
end
end

function [mode,note] = chooseNegativeHandling(settings)
mode = lower(string(settings.negativeHandling));
note = "";
if mode == "interactive"
    choice = menu('How should negative spectral/response values be handled?', ...
        'Preserve original negative values (recommended)', ...
        'Replace negative values with zero');
    if choice == 0, error('Negative-value handling was not selected.'); end
    if choice == 1, mode = "preserve"; else, mode = "clip"; end
end
if mode == "preserve"
    note = "Negative values were preserved. The import report identifies any files containing them.";
elseif mode == "clip"
    note = "Negative values were replaced with zero after import, as selected by the user.";
else
    error('negativeHandling must be interactive, preserve, or clip.');
end
end

function experiment = makeExperiment(name,pathway,sensorData,description)
experiment.name = char(name);
experiment.pathway = char(pathway);
experiment.sensorData = sensorData;
experiment.description = char(description);
end

function subset = subsetSensorData(source,index,names,mode)
subset = source;
subset.mode = string(mode);
subset.featureNames = names(:);
subset.rawX = source.rawX(:,index);
subset.X = subset.rawX;
subset.normalizationInfo = struct('mode',"none",'referenceChannelName',"", ...
    'referenceIndex',[],'denominator',ones(size(subset.rawX,1),1));
end

function [mode,reference] = chooseSharedNormalization(names,requestedMode,requestedReference,settings)
[mode,reference] = selectNormalizationMode(names,requestedMode, ...
    requestedReference,'shared-channel comparison',settings);
end

function printBestExperimentSummary(results)
for i = 1:numel(results)
    if isfield(results(i),'modelResults') && ...
            strlength(results(i).modelResults.bestModelName) > 0
        m = results(i).modelResults.bestMetrics;
        fprintf('%s -> %s | R2 %.5f | RMSE %.6g | MAE %.6g | composite rank %.3f\n', ...
            char(results(i).name),char(results(i).modelResults.bestModelName), ...
            m.R2,m.RMSE,m.MAE,results(i).modelResults.bestCompositeScore);
    elseif isfield(results(i),'errorMessage')
        fprintf('%s -> skipped: %s\n',char(results(i).name),char(results(i).errorMessage));
    end
end
end

function result = emptyExperimentResult()
result.name = "";
result.pathway = "";
result.description = "";
result.dataset = struct();
result.modelResults = emptyModelResults();
result.finalModel = struct();
result.errorMessage = "";
result.status = "Pending";
end

function result = emptyModelResults()
result.comparisonTable = table();
result.bestModelName = "";
result.bestPrediction = [];
result.bestMetrics = struct();
result.bestDetails = struct();
result.bestPerSampleMetrics = table();
result.bestCompositeScore = NaN;
result.allPredictions = struct();
result.validationMode = "";
end
