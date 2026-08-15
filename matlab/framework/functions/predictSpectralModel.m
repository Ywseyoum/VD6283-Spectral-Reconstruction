function prediction = predictSpectralModel(model,X)
%PREDICTSPECTRALMODEL Reconstruct spectra from detector readings.

X = double(X);
switch string(model.type)
    case "meanBaseline"
        prediction = repmat(model.meanSpectrum,size(X,1),1);
    case "ridge"
        XZ = standardizeWithModel(X,model);
        prediction = [ones(size(XZ,1),1) XZ]*model.beta;
    case "pls"
        XZ = standardizeWithModel(X,model);
        prediction = [ones(size(XZ,1),1) XZ]*model.beta;
    case {"pcaLinear","pcaRidge"}
        XZ = standardizeWithModel(X,model);
        score = [ones(size(XZ,1),1) XZ]*model.mapping;
        prediction = score*model.pca.coeff' + model.pca.mu;
    case "pcaEnsemble"
        XZ = standardizeWithModel(X,model);
        score = zeros(size(XZ,1),numel(model.learners));
        for pc = 1:numel(model.learners)
            score(:,pc) = predict(model.learners{pc},XZ);
        end
        prediction = score*model.pca.coeff' + model.pca.mu;
    case "pcaNN"
        XZ = standardizeWithModel(X,model);
        score = model.net(XZ')';
        prediction = score*model.pca.coeff' + model.pca.mu;
    case "plsNN"
        XZ = standardizeWithModel(X,model);
        score = XZ*model.projection;
        scaled = (score-model.scoreMean)./model.scoreStd;
        predictedScaled = model.net(scaled')';
        prediction = predictedScaled.*model.yStd + model.yMean;
    otherwise
        error('Unknown saved model type: %s',model.type);
end
prediction(~isfinite(prediction)) = 0;
end

function XZ = standardizeWithModel(X,model)
XZ = (X-model.xMean)./model.xStd;
XZ(~isfinite(XZ)) = 0;
end
