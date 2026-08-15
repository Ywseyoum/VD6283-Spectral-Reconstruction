function x = tableColumnToNumeric(T,index)
%TABLECOLUMNTONUMERIC Convert one table variable to a numeric column.

v = T{:,index};
if isnumeric(v) || islogical(v)
    x = double(v);
elseif isduration(v)
    x = seconds(v);
elseif isdatetime(v)
    x = datenum(v);
else
    s = string(v);
    s = replace(s,',','');
    x = str2double(s);
end
x = x(:);
end
