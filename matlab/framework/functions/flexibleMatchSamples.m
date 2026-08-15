function [spectralIndex,sensorIndex,report,notes] = flexibleMatchSamples(spectralNames,sensorNames,settings)
%FLEXIBLEMATCHSAMPLES Match sample IDs independent of order and punctuation.

spectralNames = string(spectralNames(:));
sensorNames = string(sensorNames(:));
keysA = normalizeEntityKey(spectralNames,false);
keysB = normalizeEntityKey(sensorNames,false);
usedA = false(numel(spectralNames),1);
usedB = false(numel(sensorNames),1);
spectralIndex = [];
sensorIndex = [];
method = strings(0,1);

for b = 1:numel(sensorNames)
    a = find(keysA == keysB(b) & ~usedA,1);
    if ~isempty(a)
        spectralIndex(end+1,1) = a; %#ok<AGROW>
        sensorIndex(end+1,1) = b; %#ok<AGROW>
        method(end+1,1) = "Flexible automatic match"; %#ok<AGROW>
        usedA(a) = true; usedB(b) = true;
    end
end

notes = strings(0,1);
if settings.offerManualSampleMatching && settings.guidedDialogs && ...
        any(~usedB) && any(~usedA)
    answer = questdlg(sprintf(['%d detector sample(s) did not automatically match. ' ...
        'Would you like to manually pair them?'],nnz(~usedB)), ...
        'Unmatched sample names','Yes','No','Yes');
    if strcmp(answer,'Yes')
        remainingB = find(~usedB);
        for k = 1:numel(remainingB)
            b = remainingB(k);
            availableA = find(~usedA);
            if isempty(availableA), break; end
            options = [spectralNames(availableA); "<Leave this detector sample unmatched>"];
            [choice,ok] = listdlg('PromptString', ...
                sprintf('Match detector sample "%s" to a reference spectrum',char(sensorNames(b))), ...
                'SelectionMode','single','ListString',cellstr(options), ...
                'ListSize',[520 340]);
            if ~ok || isempty(choice), continue; end
            if choice <= numel(availableA)
                a = availableA(choice);
                spectralIndex(end+1,1) = a; %#ok<AGROW>
                sensorIndex(end+1,1) = b; %#ok<AGROW>
                method(end+1,1) = "Manual user match"; %#ok<AGROW>
                usedA(a) = true; usedB(b) = true;
            end
        end
    end
end

if isempty(spectralIndex)
    report = table();
    notes(end+1,1) = "No sample names matched between the detector data and reference spectra.";
    return
end

% Keep output in spectral dataset order for stable plotting and exports.
[spectralIndex,order] = sort(spectralIndex);
sensorIndex = sensorIndex(order);
method = method(order);
report = table(spectralNames(spectralIndex),sensorNames(sensorIndex),method, ...
    'VariableNames',{'ReferenceSpectrum','DetectorSample','MatchMethod'});

unmatchedSpectral = spectralNames(~usedA);
unmatchedSensor = sensorNames(~usedB);
if ~isempty(unmatchedSpectral)
    notes(end+1,1) = "Reference spectra not used in this experiment: " + strjoin(unmatchedSpectral,', ');
end
if ~isempty(unmatchedSensor)
    notes(end+1,1) = "Detector samples not used in this experiment: " + strjoin(unmatchedSensor,', ');
end
end
