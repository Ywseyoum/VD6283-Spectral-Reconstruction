function metrics = calculateSpectralMetrics(reference,prediction,wavelength)
%CALCULATESPECTRALMETRICS Global and per-spectrum diagnostics.

reference = double(reference); prediction = double(prediction);
errorMatrix = reference-prediction;
absoluteError = abs(errorMatrix);
metrics.RMSE = sqrt(mean(errorMatrix(:).^2,'omitnan'));
metrics.MAE = mean(absoluteError(:),'omitnan');
metrics.MedianAE = median(absoluteError(:),'omitnan');
metrics.MaximumAE = max(absoluteError(:),[],'omitnan');

ssResidual = sum(errorMatrix(:).^2,'omitnan');
grandMean = mean(reference(:),'omitnan');
ssTotal = sum((reference(:)-grandMean).^2,'omitnan');
if ssTotal > eps
    metrics.R2 = 1-ssResidual/ssTotal;
else
    metrics.R2 = NaN;
end

n = size(reference,1);
rmse = nan(n,1); r2 = nan(n,1); angle = nan(n,1);
peakError = nan(n,1); areaError = nan(n,1);
for i = 1:n
    ref = reference(i,:); pred = prediction(i,:);
    rmse(i) = sqrt(mean((ref-pred).^2,'omitnan'));
    ssr = sum((ref-pred).^2,'omitnan');
    sst = sum((ref-mean(ref,'omitnan')).^2,'omitnan');
    if sst > eps, r2(i) = 1-ssr/sst; end
    denominator = norm(ref)*norm(pred);
    if denominator > eps
        cosine = max(-1,min(1,dot(ref,pred)/denominator));
        angle(i) = acosd(cosine);
    end
    [~,refPeak] = max(ref); [~,predPeak] = max(pred);
    peakError(i) = abs(wavelength(refPeak)-wavelength(predPeak));
    refArea = trapz(wavelength,abs(ref));
    predArea = trapz(wavelength,abs(pred));
    if refArea > eps, areaError(i) = abs(predArea-refArea)/refArea*100; end
end

metrics.MeanSpectralAngle_deg = mean(angle,'omitnan');
metrics.MedianSpectralAngle_deg = median(angle,'omitnan');
metrics.MeanPeakError_nm = mean(peakError,'omitnan');
metrics.MedianPeakError_nm = median(peakError,'omitnan');
metrics.MeanAreaError_percent = mean(areaError,'omitnan');
metrics.MedianAreaError_percent = median(areaError,'omitnan');
validR2 = r2(isfinite(r2));
if isempty(validR2)
    metrics.PercentAbove090R2 = NaN;
    metrics.PercentAbove080R2 = NaN;
else
    metrics.PercentAbove090R2 = mean(validR2 >= .90)*100;
    metrics.PercentAbove080R2 = mean(validR2 >= .80)*100;
end
metrics.PerSample = table(rmse,r2,angle,peakError,areaError, ...
    'VariableNames',{'RMSE','R_squared','SpectralAngle_deg', ...
    'PeakError_nm','AreaError_percent'});
end
