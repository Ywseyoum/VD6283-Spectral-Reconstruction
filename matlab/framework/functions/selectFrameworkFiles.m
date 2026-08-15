function files = selectFrameworkFiles(filterSpec,titleText,multiSelect,settings)
%SELECTFRAMEWORKFILES Open a file dialog in the most recently used folder.

if nargin < 3 || isempty(multiSelect), multiSelect = false; end
startFolder = getFrameworkStartFolder(settings);
mode = 'off';
if multiSelect, mode = 'on'; end

try
    [names,path] = uigetfile(filterSpec,titleText,char(startFolder), ...
        'MultiSelect',mode);
catch
    % Older releases can be more restrictive about the third argument.
    [names,path] = uigetfile(filterSpec,titleText,'MultiSelect',mode);
end
if isequal(names,0)
    files = strings(0,1);
    return;
end
if ischar(names) || isstring(names)
    names = cellstr(names);
end
files = string(fullfile(path,names(:)));
rememberFrameworkFolder(path,settings);
end
