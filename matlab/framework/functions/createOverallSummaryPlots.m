function notes = createOverallSummaryPlots(experimentSummary,folder,settings)
%CREATEOVERALLSUMMARYPLOTS Compare the best result from each experiment.

notes = strings(0,1);
completed = startsWith(string(experimentSummary.Status),'Completed');
T = experimentSummary(completed,:);
if isempty(T), return; end
visibility = 'off'; if settings.figureVisible, visibility = 'on'; end

notes = safeBar(T.Experiment,T.RMSE,'RMSE', ...
    'Best-Model RMSE Across Experiments',folder,'03_Experiment_RMSE',visibility,notes);
notes = safeBar(T.Experiment,T.MAE,'MAE', ...
    'Best-Model MAE Across Experiments',folder,'04_Experiment_MAE',visibility,notes);
if any(isfinite(T.R_squared))
    notes = safeBar(T.Experiment,T.R_squared,'R^2', ...
        'Best-Model R^2 Across Experiments',folder,'05_Experiment_R2',visibility,notes);
end
end

function notes = safeBar(labels,values,yText,titleText,folder,name,visibility,notes)
fig = [];
try
    fig = figure('Visible',visibility);
    bar(1:numel(values),values);
    set(gca,'XTick',1:numel(values),'XTickLabel',labels,'XTickLabelRotation',30);
    ylabel(yText); title(titleText); grid on;
    saveFigureCompatible(fig,folder,name);
catch ME
    if ~isempty(fig), try, close(fig); catch, end, end
    notes(end+1,1) = string(name) + ": " + string(ME.message); %#ok<AGROW>
end
end
