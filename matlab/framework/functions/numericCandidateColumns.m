function indices = numericCandidateColumns(T,minimumFinite)
%NUMERICCANDIDATECOLUMNS Find columns containing enough numeric values.
if nargin < 2, minimumFinite = 2; end
indices = [];
for j = 1:width(T)
    x = tableColumnToNumeric(T,j);
    if nnz(isfinite(x)) >= minimumFinite
        indices(end+1) = j; %#ok<AGROW>
    end
end
end
