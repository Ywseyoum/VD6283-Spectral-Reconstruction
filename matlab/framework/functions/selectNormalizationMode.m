function [mode,reference] = selectNormalizationMode(featureNames,requestedMode,requestedReference,label,settings)
%SELECTNORMALIZATIONMODE Select detector-input normalization.

mode = lower(string(requestedMode));
reference = string(requestedReference);
if mode == "interactive"
    choice = menu(sprintf('How should %s detector values be normalized?',char(label)), ...
        'Keep raw integrated/measured values', ...
        'Divide each sample by its largest absolute channel value', ...
        'Divide each sample by a selected reference channel');
    if choice == 0, error('Normalization selection was canceled.'); end
    options = ["none","max","reference"];
    mode = options(choice);
end
if ~any(mode == ["none","max","reference"])
    error('Normalization mode must be interactive, none, max, or reference.');
end
if mode == "reference"
    index = find(strcmpi(string(featureNames),reference),1);
    if isempty(index)
        if settings.guidedDialogs
            [choice,ok] = listdlg('PromptString', ...
                sprintf('Select the reference channel for %s',char(label)), ...
                'SelectionMode','single','ListString',cellstr(string(featureNames)), ...
                'ListSize',[420 300]);
            if ~ok || isempty(choice), error('Reference-channel selection was canceled.'); end
            reference = string(featureNames(choice));
        else
            error('Configured reference channel "%s" was not found.',reference);
        end
    end
else
    reference = "";
end
end
