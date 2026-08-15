function [T,notes] = readTableFlexible(filePath)
%READTABLEFLEXIBLE Read CSV, text, or spreadsheet data with tolerant fallbacks.

filePath = string(filePath);
notes = strings(0,1);
candidates = cell(0,1);
scores = [];

try
    opts = detectImportOptions(filePath,'VariableNamingRule','preserve');
    T1 = readtable(filePath,opts);
    candidates{end+1,1} = T1; %#ok<AGROW>
    scores(end+1,1) = tableNumericScore(T1); %#ok<AGROW>
catch
end

try
    T2 = readtable(filePath,'VariableNamingRule','preserve');
    candidates{end+1,1} = T2; %#ok<AGROW>
    scores(end+1,1) = tableNumericScore(T2); %#ok<AGROW>
catch
    try
        T2 = readtable(filePath);
        candidates{end+1,1} = T2; %#ok<AGROW>
        scores(end+1,1) = tableNumericScore(T2); %#ok<AGROW>
    catch
    end
end

try
    M = readmatrix(filePath);
    if ~isempty(M)
        keep = any(isfinite(M),1);
        M = M(:,keep);
        if ~isempty(M)
            names = cellstr("Var" + string(1:size(M,2)));
            T3 = array2table(M,'VariableNames',names);
            candidates{end+1,1} = T3; %#ok<AGROW>
            scores(end+1,1) = tableNumericScore(T3); %#ok<AGROW>
        end
    end
catch
end

if isempty(candidates)
    error('Could not read file "%s" as a supported table.',filePath);
end
[~,best] = max(scores);
T = candidates{best};
if width(T) == 0 || height(T) == 0
    error('File "%s" did not contain a usable table.',filePath);
end

% Remove completely empty columns and rows.
emptyCol = false(1,width(T));
for j = 1:width(T)
    v = T{:,j};
    if isnumeric(v)
        emptyCol(j) = all(~isfinite(v));
    else
        s = string(v);
        emptyCol(j) = all(ismissing(s) | strlength(strtrim(s)) == 0);
    end
end
T(:,emptyCol) = [];

emptyRow = true(height(T),1);
for j = 1:width(T)
    v = T{:,j};
    if isnumeric(v)
        emptyRow = emptyRow & ~isfinite(v);
    else
        s = string(v);
        emptyRow = emptyRow & (ismissing(s) | strlength(strtrim(s)) == 0);
    end
end
T(emptyRow,:) = [];

if any(emptyCol)
    notes(end+1,1) = "Removed completely empty columns from " + filePath + ".";
end
if any(emptyRow)
    notes(end+1,1) = "Removed completely empty rows from " + filePath + ".";
end
end

function score = tableNumericScore(T)
score = 0;
for j = 1:width(T)
    x = tableColumnToNumeric(T,j);
    score = score + nnz(isfinite(x));
end
score = score + 0.001*height(T);
end
