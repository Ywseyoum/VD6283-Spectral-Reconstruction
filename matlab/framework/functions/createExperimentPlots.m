function notes = createExperimentPlots(dataset,models,folder,settings,experimentName)
%CREATEEXPERIMENTPLOTS Generate and save diagnostic figures for one experiment.
%
% A failure in one plot is recorded and does not prevent the remaining plots
% or model files from being saved.

notes = strings(0,1);
visibility = 'off';
if settings.figureVisible, visibility = 'on'; end

notes = savePlotSafely(@() detectorHeatmap(dataset,experimentName,visibility), ...
    folder,'01_Detector_Input_Heatmap',notes);

completed = strcmp(models.comparisonTable.Status,'Completed');
T = models.comparisonTable(completed,:);
if ~isempty(T)
    notes = savePlotSafely(@() metricBar(T,'CompositeRankScore', ...
        'Composite rank score (lower is better)', ...
        'Combined R^2, RMSE, and MAE Model Ranking',visibility), ...
        folder,'02_Composite_Model_Ranking',notes);
    notes = savePlotSafely(@() metricBar(T,'RMSE','RMSE', ...
        'Model RMSE Comparison',visibility),folder,'03_Model_RMSE',notes);
    notes = savePlotSafely(@() metricBar(T,'MAE','MAE', ...
        'Model MAE Comparison',visibility),folder,'04_Model_MAE',notes);
    if any(isfinite(T.R_squared))
        notes = savePlotSafely(@() metricBar(T,'R_squared','R^2', ...
            'Model R^2 Comparison',visibility),folder,'05_Model_R2',notes);
    end
end

reference = dataset.Y;
prediction = models.bestPrediction;
notes = savePlotSafely(@() predictionScatter(reference,prediction,visibility), ...
    folder,'06_Reference_vs_Predicted',notes);
notes = savePlotSafely(@() meanSpectrumPlot(dataset,models,settings,visibility), ...
    folder,'07_Overall_Mean_Spectrum',notes);

numExamples = min(settings.examplePlots,size(reference,1));
exampleIndices = unique(round(linspace(1,size(reference,1),numExamples)));
for k = 1:numel(exampleIndices)
    i = exampleIndices(k);
    safe = matlab.lang.makeValidName(char(dataset.sampleNames(i)));
    notes = savePlotSafely(@() reconstructionPlot(dataset,models,i,visibility), ...
        folder,sprintf('08_Reconstruction_%02d_%s',k,safe),notes);
end

if ~isempty(models.bestPerSampleMetrics) && ...
        any(isfinite(models.bestPerSampleMetrics.R_squared))
    notes = savePlotSafely(@() perSampleR2Plot(models,visibility), ...
        folder,'09_Per_Sample_R2',notes);
end

notes = savePlotSafely(@() meanResidualPlot(dataset,models,visibility), ...
    folder,'10_Mean_Residual_vs_Wavelength',notes);
notes = savePlotSafely(@() residualHeatmap(dataset,models,visibility), ...
    folder,'11_Residual_Heatmap',notes);

if ~isempty(notes)
    writePlotNotes(fullfile(folder,'Plot_Warnings.txt'),notes);
end
end

function notes = savePlotSafely(builder,folder,name,notes)
fig = [];
try
    fig = builder();
    saveFigureCompatible(fig,folder,name);
catch ME
    if ~isempty(fig)
        try, close(fig); catch, end
    end
    notes(end+1,1) = string(name) + ": " + string(ME.message); %#ok<AGROW>
    warning('Plot %s was skipped: %s',name,ME.message);
end
end

function fig = detectorHeatmap(dataset,experimentName,visibility)
fig = figure('Visible',visibility);
imagesc(dataset.X); colorbar;
xlabel('Detector channel'); ylabel('Matched sample');
title(sprintf('%s: Detector Inputs Used for ML',char(experimentName)),'Interpreter','none');
set(gca,'XTick',1:numel(dataset.featureNames), ...
    'XTickLabel',dataset.featureNames,'XTickLabelRotation',45);
end

function fig = metricBar(T,fieldName,yText,titleText,visibility)
fig = figure('Visible',visibility);
values = T.(fieldName);
bar(1:height(T),values);
set(gca,'XTick',1:height(T),'XTickLabel',T.Model,'XTickLabelRotation',35);
ylabel(yText); title(titleText); grid on;
end

function fig = predictionScatter(reference,prediction,visibility)
indices = 1:max(1,ceil(numel(reference)/15000)):numel(reference);
fig = figure('Visible',visibility);
scatter(reference(indices),prediction(indices),10,'filled'); hold on;
limits = [min([reference(:);prediction(:)]) max([reference(:);prediction(:)])];
if limits(2) <= limits(1)
    limits = limits + [-1 1]*max(1,abs(limits(1))*0.1);
end
plot(limits,limits,'--','LineWidth',1.5);
xlabel('Reference intensity'); ylabel('Predicted intensity');
title('Overall Validation Reference vs Predicted Intensities');
axis equal; xlim(limits); ylim(limits); grid on;
end

function fig = meanSpectrumPlot(dataset,models,settings,visibility)
meanReference = mean(dataset.Y,1);
meanPrediction = mean(models.bestPrediction,1);
if settings.smoothMeanPredictionForDisplay && exist('smoothdata','file') == 2 && ...
        numel(meanPrediction) >= settings.smoothingWindow
    meanPrediction = smoothdata(meanPrediction,'sgolay',settings.smoothingWindow);
end
fig = figure('Visible',visibility);
plot(dataset.wavelength,meanReference,'LineWidth',2.2); hold on;
plot(dataset.wavelength,meanPrediction,'--','LineWidth',2.2);
xlabel('Wavelength (nm)'); ylabel('Target-scaled intensity');
title(sprintf('Mean Spectrum: Reference vs %s',char(models.bestModelName)),'Interpreter','none');
legend('Reference','Prediction','Location','best'); grid on;
end

function fig = reconstructionPlot(dataset,models,index,visibility)
fig = figure('Visible',visibility);
plot(dataset.wavelength,dataset.Y(index,:),'LineWidth',2); hold on;
plot(dataset.wavelength,models.bestPrediction(index,:),'--','LineWidth',2);
xlabel('Wavelength (nm)'); ylabel('Target-scaled intensity');
title(sprintf('Validation Reconstruction: %s',char(dataset.sampleNames(index))), ...
    'Interpreter','none');
legend('Reference spectrum','Predicted spectrum','Location','best'); grid on;
end

function fig = perSampleR2Plot(models,visibility)
fig = figure('Visible',visibility);
scatter(1:height(models.bestPerSampleMetrics), ...
    models.bestPerSampleMetrics.R_squared,35,'filled'); hold on;
yline(.90,'--','R^2 = 0.90'); yline(.80,':','R^2 = 0.80');
xlabel('Sample number'); ylabel('Individual validation R^2');
title('Best-Model Accuracy Across Samples'); grid on;
end

function fig = meanResidualPlot(dataset,models,visibility)
residual = models.bestPrediction-dataset.Y;
fig = figure('Visible',visibility);
plot(dataset.wavelength,mean(residual,1),'LineWidth',1.8); hold on;
yline(0,'--');
xlabel('Wavelength (nm)'); ylabel('Mean prediction minus reference');
title('Mean Reconstruction Residual Across Wavelength'); grid on;
end

function fig = residualHeatmap(dataset,models,visibility)
residual = models.bestPrediction-dataset.Y;
fig = figure('Visible',visibility);
imagesc(dataset.wavelength,1:size(residual,1),residual); colorbar;
xlabel('Wavelength (nm)'); ylabel('Matched sample');
title('Best-Model Residual Heatmap (Prediction - Reference)');
end

function writePlotNotes(path,notes)
fid = fopen(path,'w');
if fid < 0, return; end
cleanup = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid,'PLOT WARNINGS\n=============\n\n');
for i = 1:numel(notes), fprintf(fid,'- %s\n',char(notes(i))); end
end
