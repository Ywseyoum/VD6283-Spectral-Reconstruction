function [indexA,indexB,sharedNames,onlyA,onlyB] = matchChannelSets(namesA,namesB)
%MATCHCHANNELSETS Match channel names without depending on order/case/punctuation.

namesA = string(namesA(:)); namesB = string(namesB(:));
keysA = normalizeEntityKey(namesA,false);
keysB = normalizeEntityKey(namesB,false);
indexA = []; indexB = []; sharedNames = strings(0,1);
usedB = false(numel(namesB),1);
for i = 1:numel(namesA)
    j = find(keysB == keysA(i) & ~usedB,1);
    if ~isempty(j)
        indexA(end+1,1) = i; %#ok<AGROW>
        indexB(end+1,1) = j; %#ok<AGROW>
        sharedNames(end+1,1) = namesA(i); %#ok<AGROW>
        usedB(j) = true;
    end
end
onlyA = namesA(setdiff((1:numel(namesA))',indexA,'stable'));
onlyB = namesB(setdiff((1:numel(namesB))',indexB,'stable'));
end
