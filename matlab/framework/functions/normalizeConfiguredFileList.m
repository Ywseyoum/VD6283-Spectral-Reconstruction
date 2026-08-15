function files = normalizeConfiguredFileList(value)
%NORMALIZECONFIGUREDFILELIST Convert file setting values to a string column.
%
% A character vector must be treated as one path. Applying (: ) before
% converting it to string would incorrectly split the path into characters.

if nargin == 0 || isempty(value)
    files = strings(0,1);
elseif ischar(value)
    files = string(value);
elseif isstring(value)
    files = value(:);
elseif iscell(value)
    files = string(value(:));
else
    files = string(value);
    files = files(:);
end
files = strtrim(files);
files(files == "") = [];
end
