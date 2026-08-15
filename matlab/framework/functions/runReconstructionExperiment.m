function result = runReconstructionExperiment(dataset,settings,experiment)
%RUNRECONSTRUCTIONEXPERIMENT Compare models and fit the selected final model.

fprintf('Matched samples: %d | channels used: %d | wavelength targets: %d\n', ...
    size(dataset.X,1),size(dataset.X,2),size(dataset.Y,2));
for i = 1:numel(dataset.preparationWarnings)
    fprintf('WARNING: %s\n',char(dataset.preparationWarnings(i)));
end

modelResults = compareSpectralModels(dataset,settings);
if strlength(modelResults.bestModelName) == 0
    error('No reconstruction model completed successfully.');
end

fprintf('\nModel ranking (R2, RMSE, and MAE combined):\n');
disp(modelResults.comparisonTable);
fprintf('Selected model: %s\n',char(modelResults.bestModelName));

finalModel = fitSpectralModel(modelResults.bestModelName, ...
    dataset.X,dataset.Y,settings,modelResults.bestDetails);

result.name = string(experiment.name);
result.pathway = string(experiment.pathway);
result.description = string(experiment.description);
result.dataset = dataset;
result.modelResults = modelResults;
result.finalModel = finalModel;
result.errorMessage = "";
end
