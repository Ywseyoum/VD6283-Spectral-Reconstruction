function createInputPlots(spectral,sensorSet,folder,settings)
%CREATEINPUTPLOTS Plot standardized spectra and response curves.
visibility = 'off'; if settings.figureVisible, visibility = 'on'; end

fig = figure('Visible',visibility);
plot(spectral.wavelength,spectral.spectra,'LineWidth',1.2);
xlabel('Wavelength (nm)'); ylabel('Spectral intensity');
title('Standardized Reference Spectra'); grid on;
if numel(spectral.names) <= 15
    legend(spectral.names,'Interpreter','none','Location','best');
end
saveFigureCompatible(fig,folder,'01_Standardized_Reference_Spectra');

fig = figure('Visible',visibility);
plot(sensorSet.wavelength,sensorSet.responses,'LineWidth',1.5);
xlabel('Wavelength (nm)'); ylabel('Channel response');
title('Standardized Sensor Channel-Response Curves'); grid on;
if numel(sensorSet.names) <= 20
    legend(sensorSet.names,'Interpreter','none','Location','best');
end
saveFigureCompatible(fig,folder,'02_Standardized_Channel_Responses');
end
