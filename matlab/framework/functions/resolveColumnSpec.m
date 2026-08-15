function index = resolveColumnSpec(T,spec)
%RESOLVECOLUMNSPEC Resolve a configured column index or column name.

index = [];
if isempty(spec), return; end
if isnumeric(spec)
    index = spec(:)';
    index = index(index >= 1 & index <= width(T));
    return
end
names = string(T.Properties.VariableNames);
requested = string(spec(:));
for i = 1:numel(requested)
    hit = find(strcmpi(names,requested(i)),1);
    if ~isempty(hit), index(end+1) = hit; end %#ok<AGROW>
end
end
