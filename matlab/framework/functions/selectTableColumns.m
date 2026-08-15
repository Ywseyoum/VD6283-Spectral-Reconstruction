function indices = selectTableColumns(T,prompt,configuredSpec,suggestedIndices,excluded)
%SELECTTABLECOLUMNS Select one or more columns.

indices = resolveColumnSpec(T,configuredSpec);
if nargin < 5, excluded = []; end
indices = setdiff(indices,excluded,'stable');
if ~isempty(indices), return; end

names = string(T.Properties.VariableNames);
if nargin < 4 || isempty(suggestedIndices)
    suggestedIndices = setdiff(1:width(T),excluded,'stable');
else
    suggestedIndices = setdiff(suggestedIndices,excluded,'stable');
end
if isempty(suggestedIndices)
    error('No candidate columns are available for selection.');
end

[choice,ok] = listdlg('PromptString',prompt, ...
    'SelectionMode','multiple','ListString',cellstr(names), ...
    'InitialValue',suggestedIndices,'ListSize',[460 330]);
if ~ok || isempty(choice), error('Column selection was canceled.'); end
indices = setdiff(choice,excluded,'stable');
if isempty(indices), error('At least one column must be selected.'); end
end
