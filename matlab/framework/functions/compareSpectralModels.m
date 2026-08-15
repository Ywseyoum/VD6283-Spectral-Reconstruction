function result = compareSpectralModels(dataset,settings)
%COMPARESPECTRALMODELS Evaluate models and rank R2, RMSE, and MAE together.

X = dataset.X; Y = dataset.Y; wavelength = dataset.wavelength;
numSamples = size(X,1);
if numSamples == 1
    validationMode = "Resubstitution only (one sample; not held-out)";
    foldID = 1;
else
    numFolds = min(settings.numFolds,numSamples);
    validationMode = string(numFolds) + "-fold held-out cross-validation";
    rng(settings.randomSeed);
    order = randperm(numSamples);
    foldID = zeros(numSamples,1);
    foldID(order) = mod(0:numSamples-1,numFolds)+1;
end

if ischar(settings.modelNames)
    modelNames = string(settings.modelNames);
else
    modelNames = string(settings.modelNames(:));
end
rows = cell(numel(modelNames),11);
allPredictions = struct();

for m = 1:numel(modelNames)
    name = modelNames(m);
    fprintf('   %-27s ',char(name));
    timer = tic;
    try
        details = determineModelDetails(name,X,Y,foldID,settings,numSamples);
        if numSamples == 1
            model = fitSpectralModel(name,X,Y,settings,details);
            prediction = predictSpectralModel(model,X);
        else
            prediction = crossValidatedPrediction(name,X,Y,foldID,settings,details);
        end
        elapsed = toc(timer);
        metrics = calculateSpectralMetrics(Y,prediction,wavelength);
        status = "Completed";
        detailText = detailsToText(details);
        fprintf('R2 %.5f | RMSE %.6g | MAE %.6g\n',metrics.R2,metrics.RMSE,metrics.MAE);

        safeField = matlab.lang.makeValidName(char(name));
        allPredictions.(safeField).name = name;
        allPredictions.(safeField).prediction = prediction;
        allPredictions.(safeField).metrics = metrics;
        allPredictions.(safeField).details = details;
    catch ME
        elapsed = toc(timer);
        status = "Skipped";
        metrics = blankMetrics();
        detailText = string(ME.message);
        fprintf('SKIPPED: %s\n',ME.message);
    end

    rows(m,:) = {char(name),char(status),char(validationMode),metrics.RMSE, ...
        metrics.R2,metrics.MAE,metrics.MeanSpectralAngle_deg, ...
        metrics.MeanPeakError_nm,metrics.MeanAreaError_percent,elapsed, ...
        char(detailText)};
end

comparison = cell2table(rows,'VariableNames',{'Model','Status','ValidationMode', ...
    'RMSE','R_squared','MAE','MeanSpectralAngle_deg','MeanPeakError_nm', ...
    'MeanAreaError_percent','TrainingTime_seconds','Details'});
completed = strcmp(comparison.Status,'Completed');
comparison.RMSE_Rank = nan(height(comparison),1);
comparison.R2_Rank = nan(height(comparison),1);
comparison.MAE_Rank = nan(height(comparison),1);
comparison.CompositeRankScore = nan(height(comparison),1);
comparison.OverallRank = nan(height(comparison),1);

completedRows = find(completed);
if ~isempty(completedRows)
    rmseRank = ordinalRank(comparison.RMSE(completedRows),"ascend");
    maeRank = ordinalRank(comparison.MAE(completedRows),"ascend");
    r2Values = comparison.R_squared(completedRows);
    if any(isfinite(r2Values))
        r2Rank = ordinalRank(r2Values,"descend");
        composite = mean([rmseRank maeRank r2Rank],2,'omitnan');
    else
        r2Rank = nan(size(r2Values));
        composite = mean([rmseRank maeRank],2,'omitnan');
    end
    comparison.RMSE_Rank(completedRows) = rmseRank;
    comparison.MAE_Rank(completedRows) = maeRank;
    comparison.R2_Rank(completedRows) = r2Rank;
    comparison.CompositeRankScore(completedRows) = composite;

    completedTable = comparison(completedRows,:);
    r2Tie = completedTable.R_squared;
    r2Tie(~isfinite(r2Tie)) = -Inf;
    sortMatrix = [completedTable.CompositeRankScore,completedTable.RMSE, ...
        completedTable.MAE,-r2Tie];
    [~,order] = sortrows(sortMatrix,[1 2 3 4]);
    overall = nan(numel(completedRows),1);
    overall(order) = (1:numel(order))';
    comparison.OverallRank(completedRows) = overall;
end

completedPart = comparison(completed,:);
if ~isempty(completedPart)
    completedPart = sortrows(completedPart,'OverallRank','ascend');
end
comparison = [completedPart; comparison(~completed,:)];
completedSorted = strcmp(comparison.Status,'Completed');
if ~any(completedSorted)
    bestName = ""; bestPrediction = []; bestMetrics = struct();
    bestDetails = struct(); bestPerSample = table(); bestScore = NaN;
else
    bestRow = find(completedSorted,1);
    bestName = string(comparison.Model{bestRow});
    safeField = matlab.lang.makeValidName(char(bestName));
    bestPrediction = allPredictions.(safeField).prediction;
    bestMetrics = allPredictions.(safeField).metrics;
    bestDetails = allPredictions.(safeField).details;
    bestPerSample = bestMetrics.PerSample;
    bestScore = comparison.CompositeRankScore(bestRow);
end

result.comparisonTable = comparison;
result.bestModelName = bestName;
result.bestPrediction = bestPrediction;
result.bestMetrics = bestMetrics;
result.bestDetails = bestDetails;
result.bestPerSampleMetrics = bestPerSample;
result.bestCompositeScore = bestScore;
result.allPredictions = allPredictions;
result.foldID = foldID;
result.validationMode = validationMode;
end

function prediction = crossValidatedPrediction(name,X,Y,foldID,settings,details)
prediction = nan(size(Y));
for fold = 1:max(foldID)
    trainRows = foldID ~= fold;
    testRows = foldID == fold;
    model = fitSpectralModel(name,X(trainRows,:),Y(trainRows,:),settings,details);
    prediction(testRows,:) = predictSpectralModel(model,X(testRows,:));
end
if any(~isfinite(prediction(:)))
    error('The model did not produce finite predictions for every held-out sample.');
end
end

function details = determineModelDetails(name,X,Y,foldID,settings,numSamples)
details = struct();
if numSamples == 1
    minTrain = 1;
else
    minTrain = Inf;
    for f = 1:max(foldID)
        minTrain = min(minTrain,nnz(foldID ~= f));
    end
end
switch string(name)
    case "PLS Regression"
        details.numPLSComponents = min([settings.maxPLSComponents,size(X,2),minTrain-1]);
        if details.numPLSComponents < 1
            error('PLS requires at least two training samples in every fold.');
        end
    case {"PCA + Linear","PCA + Ridge","PCA + Ensemble","PCA + Neural Network"}
        details.numPCAComponents = min([settings.pcaComponents,size(Y,2),minTrain-1]);
        if details.numPCAComponents < 1
            error('Target-spectrum PCA requires at least two training samples in every fold.');
        end
        if name == "PCA + Neural Network" && minTrain < settings.minimumNeuralNetworkTrainRows
            error('Too few training rows for the configured neural-network safety limit.');
        end
    case "PLS + Neural Network"
        details.numPLSComponents = min([settings.plsNNMaxComponents,size(X,2),minTrain-1]);
        if details.numPLSComponents < 1 || minTrain < settings.minimumNeuralNetworkTrainRows
            error('PLS + Neural Network needs at least two training samples in every fold.');
        end
end
end

function ranks = ordinalRank(values,direction)
values = double(values(:));
ranks = nan(size(values));
finite = isfinite(values);
if ~any(finite), return; end
indices = find(finite);
finiteValues = values(finite);
if direction == "ascend"
    [sortedValues,order] = sort(finiteValues,'ascend');
else
    [sortedValues,order] = sort(finiteValues,'descend');
end
position = 1;
while position <= numel(order)
    last = position;
    tolerance = max(1,abs(sortedValues(position)))*1e-12;
    while last < numel(order) && abs(sortedValues(last+1)-sortedValues(position)) <= tolerance
        last = last+1;
    end
    averageRank = mean(position:last);
    ranks(indices(order(position:last))) = averageRank;
    position = last+1;
end
ranks(~finite) = numel(order)+1;
end

function text = detailsToText(details)
parts = strings(0,1);
if isfield(details,'numPLSComponents')
    parts(end+1,1) = "PLS components=" + details.numPLSComponents;
end
if isfield(details,'numPCAComponents')
    parts(end+1,1) = "PCA components=" + details.numPCAComponents;
end
if isempty(parts), text = "automatic defaults"; else, text = strjoin(parts,'; '); end
end

function metrics = blankMetrics()
metrics.RMSE = NaN; metrics.R2 = NaN; metrics.MAE = NaN;
metrics.MeanSpectralAngle_deg = NaN;
metrics.MeanPeakError_nm = NaN;
metrics.MeanAreaError_percent = NaN;
end
