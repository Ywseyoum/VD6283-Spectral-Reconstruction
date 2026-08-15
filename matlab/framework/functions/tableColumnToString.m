function s = tableColumnToString(T,index)
%TABLECOLUMNOTOSTRING Convert one table variable to strings.

v = T{:,index};
if iscell(v)
    s = string(v);
else
    s = string(v);
end
s = strtrim(s(:));
end
