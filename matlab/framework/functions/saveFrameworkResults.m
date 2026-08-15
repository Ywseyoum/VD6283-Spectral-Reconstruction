function output = saveFrameworkResults(projectRoot,spectral,sensorSet,syntheticData, ...
    realData,experimentResults,sharedInfo,gridInfo,negativeMode,warnings,settings,pathwayMode)
%SAVEFRAMEWORKRESULTS Save standardized inputs and every experiment.

root = string(settings.outputRoot);
if strlength(root) == 0
    defaultRoot = string(spectral.sourceFolder);
    if strlength(defaultRoot) == 0, defaultRoot = string(pwd); end
    if settings.guidedDialogs && settings.askOutputFolder
        outputSettings = settings;
        outputSettings.defaultStartFolder = defaultRoot;
        outputSettings.rememberLastDataFolder = false;
        selected = selectFrameworkFolder('Select the parent folder for reconstruction results',outputSettings);
        if strlength(selected) == 0, root = defaultRoot; else, root = selected; end
    else
        root = defaultRoot;
    end
end
stamp = string(datetime('now','Format','yyyyMMdd_HHmmss'));
outputFolder = fullfile(root,"Spectral_Reconstruction_Results_"+stamp);
inputFolder = fullfile(outputFolder,'Standardized_Inputs');
experimentRoot = fullfile(outputFolder,'Experiments');
overallFigureFolder = fullfile(outputFolder,'Figures');
reportFolder = fullfile(outputFolder,'Report');
mkdir(outputFolder); mkdir(inputFolder); mkdir(experimentRoot);
mkdir(overallFigureFolder); mkdir(reportFolder);

% Standardized reference spectra, both wide and long.
spectralWide = array2table(spectral.spectra, ...
    'VariableNames',safeVariableNames(spectral.names));
spectralWide = addvars(spectralWide,spectral.wavelength,'Before',1, ...
    'NewVariableNames','Wavelength_nm');
writetable(spectralWide,fullfile(inputFolder,'Standardized_Spectra_Wide.csv'));
spectralLong = matrixToLongTable(spectral.wavelength,spectral.spectra, ...
    spectral.names,'Sample','Intensity');
writetable(spectralLong,fullfile(inputFolder,'Standardized_Spectra_Long.csv'));
writetable(spectral.repeatTable,fullfile(inputFolder,'Spectral_Repeat_Report.csv'));
writetable(spectral.coverageTable,fullfile(inputFolder,'Spectral_Coverage_Report.csv'));

% Standardized channel responses, both wide and long.
channelWide = array2table(sensorSet.responses, ...
    'VariableNames',safeVariableNames(sensorSet.names));
channelWide = addvars(channelWide,sensorSet.wavelength,'Before',1, ...
    'NewVariableNames','Wavelength_nm');
writetable(channelWide,fullfile(inputFolder,'Standardized_Channel_Responses_Wide.csv'));
channelLong = matrixToLongTable(sensorSet.wavelength,sensorSet.responses, ...
    sensorSet.names,'Channel','Response');
writetable(channelLong,fullfile(inputFolder,'Standardized_Channel_Responses_Long.csv'));
writetable(sensorSet.repeatTable,fullfile(inputFolder,'Channel_Repeat_Report.csv'));
writetable(sensorSet.coverageTable,fullfile(inputFolder,'Channel_Coverage_Report.csv'));

if isfield(syntheticData,'rawX')
    writeSensorData(syntheticData,inputFolder,'Synthetic');
end
if isfield(realData,'rawX')
    writeSensorData(realData,inputFolder,'Real');
    if isfield(realData,'repeatTable') && ~isempty(realData.repeatTable)
        writetable(realData.repeatTable,fullfile(inputFolder,'Real_Sample_Repeat_Report.csv'));
    end
    if isfield(realData,'channelRepeatTable') && ~isempty(realData.channelRepeatTable)
        writetable(realData.channelRepeatTable,fullfile(inputFolder,'Real_Channel_Repeat_Report.csv'));
    end
end

try
    createInputPlots(spectral,sensorSet,overallFigureFolder,settings);
catch ME
    writeText(fullfile(overallFigureFolder,'Input_Plot_Error.txt'),string(ME.message));
    warning('Input plots could not be completed: %s',ME.message);
end

summaryRows = cell(numel(experimentResults),10);
for i = 1:numel(experimentResults)
    current = experimentResults(i);
    safeName = matlab.lang.makeValidName(char(current.name));
    expFolder = fullfile(experimentRoot,safeName);
    mkdir(expFolder);
    if current.status == "Completed"
        try
            plotNotes = saveOneExperiment(current,expFolder,settings);
            if ~isempty(plotNotes)
                writeStringList(fullfile(expFolder,'Report','Plot_Warnings.txt'),plotNotes);
            end
            metrics = current.modelResults.bestMetrics;
            summaryRows(i,:) = {char(current.name),char(current.pathway),char(current.status), ...
                char(current.modelResults.validationMode),char(current.modelResults.bestModelName), ...
                metrics.R2,metrics.RMSE,metrics.MAE, ...
                current.modelResults.bestCompositeScore,size(current.dataset.X,1)};
        catch ME
            writeText(fullfile(expFolder,'SAVE_ERROR.txt'),string(ME.message));
            warning('Experiment %s completed, but some outputs could not be saved: %s', ...
                char(current.name),ME.message);
            metrics = current.modelResults.bestMetrics;
            summaryRows(i,:) = {char(current.name),char(current.pathway),'CompletedWithSaveWarning', ...
                char(current.modelResults.validationMode),char(current.modelResults.bestModelName), ...
                metrics.R2,metrics.RMSE,metrics.MAE, ...
                current.modelResults.bestCompositeScore,size(current.dataset.X,1)};
        end
    else
        writeText(fullfile(expFolder,'SKIPPED.txt'),current.errorMessage);
        summaryRows(i,:) = {char(current.name),char(current.pathway),char(current.status), ...
            '', '',NaN,NaN,NaN,NaN,0};
    end
end
experimentSummary = cell2table(summaryRows,'VariableNames', ...
    {'Experiment','Pathway','Status','ValidationMode','BestModel','R_squared', ...
    'RMSE','MAE','CompositeRankScore','MatchedSamples'});
writetable(experimentSummary,fullfile(reportFolder,'Experiment_Summary.csv'));
sharedRows = strcmp(experimentSummary.Experiment,'Real_SharedChannels') | ...
    strcmp(experimentSummary.Experiment,'Synthetic_SharedChannels');
if any(sharedRows)
    sharedPerformance = experimentSummary(sharedRows,:);
    writetable(sharedPerformance,fullfile(reportFolder,'Shared_Pathway_Performance_Comparison.csv'));
end

if isfield(settings,'createOverallSummaryPlots') && settings.createOverallSummaryPlots
    summaryPlotNotes = createOverallSummaryPlots(experimentSummary,overallFigureFolder,settings);
    if ~isempty(summaryPlotNotes)
        writeStringList(fullfile(overallFigureFolder,'Overall_Plot_Warnings.txt'),summaryPlotNotes);
    end
end
if isfield(settings,'createSharedPathwayPlots') && settings.createSharedPathwayPlots
    sharedPlotNotes = createSharedPathwayPlots(experimentResults,overallFigureFolder,settings);
    if ~isempty(sharedPlotNotes)
        writeStringList(fullfile(overallFigureFolder,'Shared_Plot_Warnings.txt'),sharedPlotNotes);
    end
end

writeRunSummary(reportFolder,pathwayMode,gridInfo,negativeMode,warnings, ...
    spectral,sensorSet,syntheticData,realData,sharedInfo,experimentSummary);
writeWarnings(reportFolder,warnings);
writeSharedChannelReport(reportFolder,sharedInfo);

runMetadata.pathwayMode = pathwayMode;
runMetadata.gridInfo = gridInfo;
runMetadata.negativeHandling = negativeMode;
runMetadata.settings = settings;
runMetadata.sharedInfo = sharedInfo;
runMetadata.warnings = warnings;
runMetadata.experimentSummary = experimentSummary;
save(fullfile(outputFolder,'Run_Metadata.mat'),'runMetadata');

% Include a copy of prediction helper and README beside the output.
try
    copyfile(fullfile(projectRoot,'predictNewSpectra.m'),outputFolder);
catch
end

output.outputFolder = outputFolder;
output.inputFolder = inputFolder;
output.experimentFolder = experimentRoot;
output.reportFolder = reportFolder;
end

function plotNotes = saveOneExperiment(current,expFolder,settings)
dataFolder = fullfile(expFolder,'Data');
figureFolder = fullfile(expFolder,'Figures');
modelFolder = fullfile(expFolder,'Models');
reportFolder = fullfile(expFolder,'Report');
mkdir(dataFolder); mkdir(figureFolder); mkdir(modelFolder); mkdir(reportFolder);

dataset = current.dataset;
models = current.modelResults;
inputTable = array2table(dataset.X,'VariableNames',safeVariableNames(dataset.featureNames));
inputTable = addvars(inputTable,dataset.sampleNames,'Before',1,'NewVariableNames','Sample');
writetable(inputTable,fullfile(dataFolder,'ML_Input_Matrix.csv'));
targetTable = array2table(dataset.Y,'VariableNames',wavelengthVariableNames(dataset.wavelength));
targetTable = addvars(targetTable,dataset.sampleNames,'Before',1,'NewVariableNames','Sample');
writetable(targetTable,fullfile(dataFolder,'ML_Target_Spectra.csv'));
writetable(dataset.matchReport,fullfile(dataFolder,'Sample_Matching_Report.csv'));
writetable(models.comparisonTable,fullfile(dataFolder,'Model_Comparison_and_Ranking.csv'));

foldTable = table(dataset.sampleNames,models.foldID(:), ...
    'VariableNames',{'Sample','ValidationFold'});
writetable(foldTable,fullfile(dataFolder,'Validation_Folds.csv'));

predictionTable = array2table(models.bestPrediction, ...
    'VariableNames',wavelengthVariableNames(dataset.wavelength));
predictionTable = addvars(predictionTable,dataset.sampleNames,'Before',1, ...
    'NewVariableNames','Sample');
writetable(predictionTable,fullfile(dataFolder,'Best_Model_Validation_Predictions.csv'));
perSample = models.bestPerSampleMetrics;
perSample = addvars(perSample,dataset.sampleNames,'Before',1,'NewVariableNames','Sample');
writetable(perSample,fullfile(dataFolder,'Best_Model_Per_Sample_Metrics.csv'));

modelPackage.experimentName = current.name;
modelPackage.pathway = current.pathway;
modelPackage.bestModelName = models.bestModelName;
modelPackage.model = current.finalModel;
modelPackage.wavelength = dataset.wavelength;
modelPackage.featureNamesUsed = dataset.featureNames;
modelPackage.sensorNormalizationInfo = dataset.sensorNormalizationInfo;
modelPackage.targetNormalization = dataset.targetNormalization;
modelPackage.settings = settings;
modelPackage.validationMode = models.validationMode;
modelPackage.validationMetrics = models.bestMetrics;
modelPackage.compositeRankScore = models.bestCompositeScore;
save(fullfile(modelFolder,'Best_Trained_Model.mat'),'modelPackage','-v7.3');

if settings.saveAllModelPredictions
    allPredictions = models.allPredictions; %#ok<NASGU>
    save(fullfile(modelFolder,'All_Validation_Predictions.mat'),'allPredictions','-v7.3');
end

plotNotes = createExperimentPlots(dataset,models,figureFolder,settings,current.name);
writeExperimentSummary(reportFolder,current);
end

function writeSensorData(data,folder,prefix)
raw = array2table(data.rawX,'VariableNames',safeVariableNames(data.featureNames));
raw = addvars(raw,data.sampleNames,'Before',1,'NewVariableNames','Sample');
writetable(raw,fullfile(folder,[prefix '_Sensor_Data_Raw.csv']));
used = array2table(data.X,'VariableNames',safeVariableNames(data.featureNames));
used = addvars(used,data.sampleNames,'Before',1,'NewVariableNames','Sample');
writetable(used,fullfile(folder,[prefix '_Sensor_Data_Normalized.csv']));
end

function T = matrixToLongTable(wavelength,matrix,names,nameVariable,valueVariable)
numPoints = numel(wavelength); numSeries = size(matrix,2);
nameColumn = repelem(string(names(:)),numPoints,1);
wlColumn = repmat(wavelength(:),numSeries,1);
valueColumn = matrix(:);
T = table(nameColumn,wlColumn,valueColumn,'VariableNames', ...
    {nameVariable,'Wavelength_nm',valueVariable});
end

function writeRunSummary(folder,pathwayMode,gridInfo,negativeMode,warnings, ...
    spectral,sensorSet,syntheticData,realData,sharedInfo,experimentSummary)
fid = fopen(fullfile(folder,'Run_Summary.txt'),'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'ADAPTABLE SPECTRAL RECONSTRUCTION RUN SUMMARY\n');
fprintf(fid,'============================================\n\n');
fprintf(fid,'Pathway selection: %s\n',char(pathwayMode));
fprintf(fid,'Reference spectra after repeat averaging: %d\n',numel(spectral.names));
fprintf(fid,'Channel response curves after repeat averaging: %d\n',numel(sensorSet.names));
fprintf(fid,'Channels: %s\n',strjoin(cellstr(sensorSet.names),', '));
fprintf(fid,'Wavelength grid: %.8g to %.8g nm at %.8g nm spacing (%d points)\n', ...
    gridInfo.minimum,gridInfo.maximum,gridInfo.spacing,gridInfo.numberPoints);
fprintf(fid,'Coverage rule: %s\n',char(gridInfo.mode));
fprintf(fid,'Negative-value handling: %s\n',char(negativeMode));
if isfield(syntheticData,'normalizationInfo')
    fprintf(fid,'Synthetic normalization: %s',char(syntheticData.normalizationInfo.mode));
    if syntheticData.normalizationInfo.mode == "reference"
        fprintf(fid,' (%s)',char(syntheticData.normalizationInfo.referenceChannelName));
    end
    fprintf(fid,'\n');
end
if isfield(realData,'normalizationInfo')
    fprintf(fid,'Real normalization: %s',char(realData.normalizationInfo.mode));
    if realData.normalizationInfo.mode == "reference"
        fprintf(fid,' (%s)',char(realData.normalizationInfo.referenceChannelName));
    end
    fprintf(fid,'\n');
end
fprintf(fid,'Shared-channel comparison available: %s\n',mat2str(sharedInfo.available));
if sharedInfo.available
    fprintf(fid,'Shared channels: %s\n',strjoin(cellstr(sharedInfo.channelNames),', '));
end
fprintf(fid,'\nEXPERIMENT RESULTS\n------------------\n');
for i = 1:height(experimentSummary)
    fprintf(fid,'%s | %s | %s',experimentSummary.Experiment{i}, ...
        experimentSummary.Status{i},experimentSummary.ValidationMode{i});
    if strcmp(experimentSummary.Status{i},'Completed')
        fprintf(fid,' | Best: %s | R2 %.7g | RMSE %.7g | MAE %.7g | Composite %.4g', ...
            experimentSummary.BestModel{i},experimentSummary.R_squared(i), ...
            experimentSummary.RMSE(i),experimentSummary.MAE(i), ...
            experimentSummary.CompositeRankScore(i));
    end
    fprintf(fid,'\n');
end
fprintf(fid,'\nWARNINGS AND DISCLOSURES\n------------------------\n');
if isempty(warnings)
    fprintf(fid,'None.\n');
else
    for i = 1:numel(warnings), fprintf(fid,'- %s\n',char(warnings(i))); end
end
end

function writeExperimentSummary(folder,current)
fid = fopen(fullfile(folder,'Experiment_Summary.txt'),'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
d = current.dataset; m = current.modelResults; met = m.bestMetrics;
fprintf(fid,'EXPERIMENT: %s\n',char(current.name));
fprintf(fid,'Pathway: %s\n',char(current.pathway));
fprintf(fid,'Description: %s\n\n',char(current.description));
fprintf(fid,'Matched samples: %d\n',size(d.X,1));
fprintf(fid,'Channels used: %s\n',strjoin(cellstr(d.featureNames),', '));
fprintf(fid,'Sensor normalization: %s\n',char(d.sensorNormalizationInfo.mode));
fprintf(fid,'Target normalization: %s\n',char(d.targetNormalization));
fprintf(fid,'Validation: %s\n\n',char(m.validationMode));
fprintf(fid,'Best model: %s\n',char(m.bestModelName));
fprintf(fid,'Composite metric-rank score: %.6g (lower is better)\n',m.bestCompositeScore);
fprintf(fid,'R squared: %.9g\n',met.R2);
fprintf(fid,'RMSE: %.9g\n',met.RMSE);
fprintf(fid,'MAE: %.9g\n',met.MAE);
fprintf(fid,'Mean spectral angle: %.9g degrees\n',met.MeanSpectralAngle_deg);
fprintf(fid,'Mean peak error: %.9g nm\n',met.MeanPeakError_nm);
fprintf(fid,'Mean area error: %.9g percent\n',met.MeanAreaError_percent);
fprintf(fid,'\nModel selection rule: ordinal ranks for higher R2, lower RMSE, and lower MAE are averaged. The lowest composite score wins; ties use RMSE, then MAE, then R2.\n');
if size(d.X,1) == 1
    fprintf(fid,'\nIMPORTANT: These are resubstitution/training-fit metrics, not held-out validation.\n');
elseif size(d.X,1) < 8
    fprintf(fid,'\nIMPORTANT: This is a very small dataset. Performance estimates are demonstration-only.\n');
end
end

function writeWarnings(folder,warnings)
fid = fopen(fullfile(folder,'Warnings_and_Transformations.txt'),'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'WARNINGS AND RECORDED TRANSFORMATIONS\n====================================\n\n');
if isempty(warnings)
    fprintf(fid,'None.\n');
else
    for i = 1:numel(warnings), fprintf(fid,'%d. %s\n',i,char(warnings(i))); end
end
end

function writeSharedChannelReport(folder,sharedInfo)
fid = fopen(fullfile(folder,'Shared_Channel_Report.txt'),'w');
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'SHARED-CHANNEL COMPARISON REPORT\n================================\n\n');
fprintf(fid,'Available: %s\n',mat2str(sharedInfo.available));
fprintf(fid,'Shared channels: %s\n',strjoin(cellstr(sharedInfo.channelNames),', '));
fprintf(fid,'Real-only channels: %s\n',strjoin(cellstr(sharedInfo.realOnly),', '));
fprintf(fid,'Synthetic-only channels: %s\n',strjoin(cellstr(sharedInfo.syntheticOnly),', '));
end

function writeStringList(path,items)
fid = fopen(path,'w');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
for i = 1:numel(items), fprintf(fid,'- %s\n',char(items(i))); end
end

function writeText(path,text)
fid = fopen(path,'w'); cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'%s\n',char(text));
end

function names = safeVariableNames(names)
names = matlab.lang.makeValidName(cellstr(string(names(:)')));
names = matlab.lang.makeUniqueStrings(names);
end

function names = wavelengthVariableNames(wavelength)
labels = "WL_" + compose('%.6f',wavelength(:)');
labels = replace(labels,'.','p');
names = safeVariableNames(labels);
end
