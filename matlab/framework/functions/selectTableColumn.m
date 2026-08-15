function index = selectTableColumn(T,prompt,configuredSpec,suggestedIndices)
%SELECTTABLECOLUMN Select exactly one column, using config when supplied.

index = resolveColumnSpec(T,configuredSpec);
if numel(index) == 1, return; end

names = string(T.Properties.VariableNames);
if nargin < 4, suggestedIndices = []; end
if isempty(suggestedIndices), suggestedIndices = 1:width(T); end
if numel(suggestedIndices) == 1
    index = suggestedIndices;
    return
end

[choice,ok] = listdlg('PromptString',prompt, ...
    'SelectionMode','single','ListString',cellstr(names), ...
    'InitialValue',suggestedIndices(1),'ListSize',[420 300]);
if ~ok || isempty(choice), error('Column selection was canceled.'); end
index = choice;
end
