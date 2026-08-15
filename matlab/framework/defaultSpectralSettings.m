function settings = defaultSpectralSettings()
%DEFAULTSPECTRALSETTINGS Defaults for the adaptable reconstruction framework.
%
% Normal users can run:
%   results = runSpectralReconstruction;
%
% Advanced users can override any field:
%   s = defaultSpectralSettings;
%   s.pathwayMode = "both";
%   s.spectralFiles = ["file1.csv"; "file2.csv"];
%   results = runSpectralReconstruction(s);

settings.randomSeed = 1;
settings.guidedDialogs = true;
settings.projectRoot = ""; % set automatically by runSpectralReconstruction
settings.rememberLastDataFolder = true;
settings.defaultStartFolder = ""; % optional advanced override

% Main pathway: interactive | synthetic | real | both
settings.pathwayMode = "interactive";

% Spectral dataset input.
settings.spectralInputMode = "interactive"; % interactive | individual | combined
settings.spectralFiles = strings(0,1);
settings.spectralCombinedLayout = "interactive"; % long | widecolumns | widerows
settings.spectralColumnMap = struct('sample',[],'wavelength',[],'intensity',[], ...
    'sampleColumns',[],'wavelengthColumns',[]);

% Channel-response input.
settings.channelInputMode = "interactive"; % interactive | individual | combined
settings.channelFiles = strings(0,1);
settings.channelCombinedLayout = "interactive"; % long | widecolumns | widerows
settings.channelColumnMap = struct('channel',[],'wavelength',[],'response',[], ...
    'channelColumns',[],'wavelengthColumns',[]);

% Real detector data input.
settings.realSensorFile = "";
settings.realDataLayout = "interactive"; % samplesinrows | samplesincolumns
settings.realColumnMap = struct('sample',[],'channel',[], ...
    'channelColumns',[],'sampleColumns',[]);

% Wavelength handling.
settings.wavelengthCoverageMode = "interactive"; % overlap | spectralrange | unionzero | custom
settings.wavelengthRange = [];      % [minimum maximum], empty = prompted/automatic
settings.wavelengthSpacing = [];    % scalar nm, empty = prompted/automatic
settings.maximumWavelengthPoints = 20000;

% Negative values: interactive | preserve | clip
settings.negativeHandling = "interactive";

% Sensor-input normalization. Each can be interactive | none | max | reference.
settings.syntheticNormalization = "interactive";
settings.syntheticReferenceChannel = "";
settings.realNormalization = "interactive";
settings.realReferenceChannel = "";
settings.sharedNormalization = "interactive";
settings.sharedReferenceChannel = "";

% Reference spectra used as ML targets: peak | area | none.
settings.targetNormalization = "peak";

% Matching and repetition handling.
settings.averageRepeatedSamples = true;
settings.offerManualSampleMatching = true;
settings.dropConstantFeatures = true;
settings.constantFeatureTolerance = 1e-12;

% Validation and model settings.
settings.numFolds = 5;
settings.smallSampleWarningThreshold = 8;
settings.recommendedSampleThreshold = 20;
settings.modelNames = [ ...
    "Mean Spectrum Baseline", ...
    "Ridge Regression", ...
    "PLS Regression", ...
    "PCA + Linear", ...
    "PCA + Ridge", ...
    "PCA + Ensemble", ...
    "PCA + Neural Network", ...
    "PLS + Neural Network"];
settings.ridgeLambda = 1e-3;
settings.maxPLSComponents = 6;
settings.pcaComponents = 10;
settings.pcaRidgeLambda = 1;
settings.ensembleLearningCycles = 100;
settings.pcaNNHiddenLayers = [20 10];
settings.pcaNNEpochs = 500;
settings.plsNNMaxComponents = 5;
settings.plsNNHiddenLayer = 15;
settings.plsNNEpochs = 300;
settings.minimumNeuralNetworkTrainRows = 2;

% Output and plotting.
settings.outputRoot = "";  % empty = ask in guided mode, otherwise beside spectral input
settings.askOutputFolder = true;
settings.figureVisible = false; % figures are always saved; set true to display every figure
settings.showCompletionDialog = true;
settings.examplePlots = 3;
settings.smoothMeanPredictionForDisplay = true;
settings.smoothingWindow = 11;
settings.saveAllModelPredictions = true;
settings.saveStandardizedInputs = true;
settings.createSharedPathwayPlots = true;
settings.createOverallSummaryPlots = true;
end
