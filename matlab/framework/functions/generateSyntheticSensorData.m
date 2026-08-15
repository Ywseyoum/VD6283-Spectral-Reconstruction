function sensorData = generateSyntheticSensorData(spectral,sensorSet)
%GENERATESYNTHETICSENSORDATA Integrate spectrum x channel response.

numSamples = size(spectral.spectra,2);
numChannels = size(sensorSet.responses,2);
rawX = zeros(numSamples,numChannels);
for i = 1:numSamples
    spectrum = spectral.spectra(:,i);
    for j = 1:numChannels
        rawX(i,j) = trapz(spectral.wavelength, ...
            spectrum .* sensorSet.responses(:,j));
    end
end
sensorData.mode = "synthetic";
sensorData.sampleNames = spectral.names(:);
sensorData.featureNames = sensorSet.names(:);
sensorData.rawX = rawX;
sensorData.X = rawX;
sensorData.normalizationInfo = struct('mode',"none", ...
    'referenceChannelName',"",'referenceIndex',[], ...
    'denominator',ones(numSamples,1));
sensorData.sourceFile = "Generated from reference spectra and channel-response curves";
sensorData.repeatTable = spectral.repeatTable;
end
