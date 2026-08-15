function model = fitSpectralModel(name,X,Y,settings,details)
%FITSPECTRALMODEL Fit one spectral reconstruction model.

if nargin < 5, details = struct(); end
name = string(name);
X = double(X); Y = double(Y);
model.name = name;
model.targetPointCount = size(Y,2);

switch name
    case "Mean Spectrum Baseline"
        model.type = "meanBaseline";
        model.meanSpectrum = mean(Y,1,'omitnan');

    case "Ridge Regression"
        [XZ,xMean,xStd] = standardizePredictors(X);
        Xaug = [ones(size(XZ,1),1) XZ];
        penalty = eye(size(Xaug,2)); penalty(1,1) = 0;
        beta = (Xaug'*Xaug + settings.ridgeLambda*penalty) \ (Xaug'*Y);
        model.type = "ridge";
        model.beta = beta;
        model.xMean = xMean;
        model.xStd = xStd;
        model.lambda = settings.ridgeLambda;

    case "PLS Regression"
        requireFunction('plsregress');
        nComp = getDetail(details,'numPLSComponents', ...
            min([settings.maxPLSComponents,size(X,2),size(X,1)-1]));
        if nComp < 1, error('Not enough training samples for PLS regression.'); end
        [XZ,xMean,xStd] = standardizePredictors(X);
        [~,~,~,~,beta] = plsregress(XZ,Y,nComp);
        model.type = "pls";
        model.beta = beta;
        model.xMean = xMean;
        model.xStd = xStd;
        model.numComponents = nComp;

    case "PCA + Linear"
        nPC = choosePCCount(Y,settings,details);
        pcaModel = computeTargetPCA(Y,nPC);
        [XZ,xMean,xStd] = standardizePredictors(X);
        mapping = [ones(size(XZ,1),1) XZ] \ pcaModel.score;
        model.type = "pcaLinear";
        model.pca = pcaModel;
        model.mapping = mapping;
        model.xMean = xMean;
        model.xStd = xStd;

    case "PCA + Ridge"
        nPC = choosePCCount(Y,settings,details);
        pcaModel = computeTargetPCA(Y,nPC);
        [XZ,xMean,xStd] = standardizePredictors(X);
        Xaug = [ones(size(XZ,1),1) XZ];
        penalty = eye(size(Xaug,2)); penalty(1,1) = 0;
        mapping = (Xaug'*Xaug + settings.pcaRidgeLambda*penalty) \ ...
            (Xaug'*pcaModel.score);
        model.type = "pcaRidge";
        model.pca = pcaModel;
        model.mapping = mapping;
        model.xMean = xMean;
        model.xStd = xStd;
        model.lambda = settings.pcaRidgeLambda;

    case "PCA + Ensemble"
        requireFunction('fitrensemble');
        nPC = choosePCCount(Y,settings,details);
        pcaModel = computeTargetPCA(Y,nPC);
        [XZ,xMean,xStd] = standardizePredictors(X);
        learners = cell(nPC,1);
        for pc = 1:nPC
            learners{pc} = fitrensemble(XZ,pcaModel.score(:,pc), ...
                'Method','LSBoost','NumLearningCycles', ...
                settings.ensembleLearningCycles,'Learners','tree');
        end
        model.type = "pcaEnsemble";
        model.pca = pcaModel;
        model.learners = learners;
        model.xMean = xMean;
        model.xStd = xStd;

    case "PCA + Neural Network"
        requireFunction('fitnet');
        nPC = choosePCCount(Y,settings,details);
        if size(X,1) < settings.minimumNeuralNetworkTrainRows
            error('Too few rows for PCA + Neural Network.');
        end
        pcaModel = computeTargetPCA(Y,nPC);
        [XZ,xMean,xStd] = standardizePredictors(X);
        net = fitnet(settings.pcaNNHiddenLayers,'trainscg');
        net.divideFcn = 'dividetrain';
        net.trainParam.epochs = settings.pcaNNEpochs;
        net.trainParam.min_grad = 1e-7;
        net.trainParam.showWindow = false;
        net.trainParam.showCommandLine = false;
        net = train(net,XZ',pcaModel.score');
        model.type = "pcaNN";
        model.pca = pcaModel;
        model.net = net;
        model.xMean = xMean;
        model.xStd = xStd;

    case "PLS + Neural Network"
        requireFunction('plsregress');
        requireFunction('fitnet');
        nComp = getDetail(details,'numPLSComponents', ...
            min([settings.plsNNMaxComponents,size(X,2),size(X,1)-1]));
        if nComp < 1 || size(X,1) < settings.minimumNeuralNetworkTrainRows
            error('Not enough samples for PLS + Neural Network.');
        end
        [XZ,xMean,xStd] = standardizePredictors(X);
        [XL,~,XScore,~,~,~,~,stats] = plsregress(XZ,Y,nComp);
        projection = stats.W / (XL'*stats.W);
        scoreMean = mean(XScore,1);
        scoreStd = std(XScore,0,1); scoreStd(scoreStd < eps) = 1;
        scoreScaled = (XScore-scoreMean)./scoreStd;
        yMean = mean(Y,1);
        yStd = std(Y,0,1); yStd(yStd < eps) = 1;
        yScaled = (Y-yMean)./yStd;
        net = fitnet(settings.plsNNHiddenLayer,'trainscg');
        net.divideFcn = 'dividetrain';
        net.trainParam.epochs = settings.plsNNEpochs;
        net.trainParam.min_grad = 1e-7;
        net.trainParam.showWindow = false;
        net.trainParam.showCommandLine = false;
        net = train(net,scoreScaled',yScaled');
        model.type = "plsNN";
        model.numComponents = nComp;
        model.xMean = xMean;
        model.xStd = xStd;
        model.projection = projection;
        model.scoreMean = scoreMean;
        model.scoreStd = scoreStd;
        model.yMean = yMean;
        model.yStd = yStd;
        model.net = net;

    otherwise
        error('Unknown model: %s',name);
end
end

function value = getDetail(details,fieldName,defaultValue)
if isfield(details,fieldName)
    value = details.(fieldName);
else
    value = defaultValue;
end
end

function count = choosePCCount(Y,settings,details)
count = getDetail(details,'numPCAComponents', ...
    min([settings.pcaComponents,size(Y,1)-1,size(Y,2)]));
if count < 1, error('Not enough samples for target-spectrum PCA.'); end
end

function pcaModel = computeTargetPCA(Y,nPC)
mu = mean(Y,1);
centered = Y-mu;
[U,S,V] = svd(centered,'econ');
scoreAll = U*S;
latent = diag(S).^2;
if sum(latent) > eps
    explained = latent/sum(latent)*100;
else
    explained = zeros(size(latent));
end
pcaModel.mu = mu;
pcaModel.coeff = V(:,1:nPC);
pcaModel.score = scoreAll(:,1:nPC);
pcaModel.explained = explained(1:nPC);
pcaModel.variancePreserved = sum(explained(1:nPC));
pcaModel.numComponents = nPC;
end

function [XZ,mu,sigma] = standardizePredictors(X)
mu = mean(X,1,'omitnan');
sigma = std(X,0,1,'omitnan');
sigma(~isfinite(sigma) | sigma < eps) = 1;
XZ = (X-mu)./sigma;
XZ(~isfinite(XZ)) = 0;
end

function requireFunction(functionName)
if exist(functionName,'file') ~= 2
    error('Required MATLAB function "%s" is unavailable.',functionName);
end
end
