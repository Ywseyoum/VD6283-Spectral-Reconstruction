function [sensorData,notes] = configureAndNormalizeSensorData(sensorData,requestedMode,requestedReference,label,settings)
%CONFIGUREANDNORMALIZESENSORDATA Ask for raw, max, or reference normalization.

[mode,reference] = selectNormalizationMode(sensorData.featureNames, ...
    requestedMode,requestedReference,label,settings);
[sensorData,notes] = applySensorNormalization(sensorData,mode,reference);
end
