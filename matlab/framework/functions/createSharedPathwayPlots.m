function notes = createSharedPathwayPlots(experimentResults,folder,settings)
%CREATESHAREDPATHWAYPLOTS Compare real and synthetic shared-channel inputs.

notes = strings(0,1);
realIndex = find(arrayfun(@(x) x.name == "Real_SharedChannels" && x.status == "Completed", ...
    experimentResults),1);
synIndex = find(arrayfun(@(x) x.name == "Synthetic_SharedChannels" && x.status == "Completed", ...
    experimentResults),1);
if isempty(realIndex) || isempty(synIndex), return; end

realData = experimentResults(realIndex).dataset;
synData = experimentResults(synIndex).dataset;
[realRows,synRows,sampleNames] = matchNames(realData.sampleNames,synData.sampleNames,true);
[realCols,synCols,channelNames] = matchNames(realData.featureNames,synData.featureNames,false);
if isempty(realRows) || isempty(realCols)
    notes(end+1,1) = "Shared-pathway plots were skipped because matched samples or channels were unavailable.";
    return;
end

realX = realData.X(realRows,realCols);
synX = synData.X(synRows,synCols);
comparison = table();
comparison.Sample = repelem(sampleNames(:),numel(channelNames));
comparison.Channel = repmat(channelNames(:),numel(sampleNames),1);
comparison.RealValue = reshape(realX',[],1);
comparison.SyntheticValue = reshape(synX',[],1);
writetable(comparison,fullfile(folder,'Shared_Real_vs_Synthetic_Detector_Values.csv'));

visibility = 'off'; if settings.figureVisible, visibility = 'on'; end
fig = [];
try
    fig = figure('Visible',visibility);
    scatter(comparison.RealValue,comparison.SyntheticValue,40,'filled'); hold on;
    limits = [min([comparison.RealValue;comparison.SyntheticValue]) ...
        max([comparison.RealValue;comparison.SyntheticValue])];
    if limits(2) <= limits(1), limits = limits + [-1 1]; end
    plot(limits,limits,'--','LineWidth',1.5);
    xlim(limits); ylim(limits); axis equal; grid on;
    xlabel('Real detector value'); ylabel('Synthetic detector value');
    title('Shared-Channel Real vs Synthetic Detector Responses');
    saveFigureCompatible(fig,folder,'06_Shared_Real_vs_Synthetic_Scatter');
catch ME
    if ~isempty(fig), try, close(fig); catch, end, end
    notes(end+1,1) = "Shared scatter: " + string(ME.message); %#ok<AGROW>
end

fig = [];
try
    fig = figure('Visible',visibility);
    channelMean = [mean(realX,1,'omitnan')' mean(synX,1,'omitnan')'];
    bar(channelMean);
    set(gca,'XTick',1:numel(channelNames),'XTickLabel',channelNames, ...
        'XTickLabelRotation',35);
    ylabel('Mean normalized detector value');
    title('Mean Real and Synthetic Responses by Shared Channel');
    legend('Real','Synthetic','Location','best'); grid on;
    saveFigureCompatible(fig,folder,'07_Shared_Channel_Mean_Comparison');
catch ME
    if ~isempty(fig), try, close(fig); catch, end, end
    notes(end+1,1) = "Shared channel means: " + string(ME.message); %#ok<AGROW>
end
end

function [aIndex,bIndex,names] = matchNames(aNames,bNames,isSample)
aNames = string(aNames(:)); bNames = string(bNames(:));
aKey = normalizeEntityKey(aNames,isSample);
bKey = normalizeEntityKey(bNames,isSample);
[~,aIndex,bIndex] = intersect(aKey,bKey,'stable');
names = aNames(aIndex);
end
