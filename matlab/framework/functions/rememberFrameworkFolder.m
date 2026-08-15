function rememberFrameworkFolder(folder,settings)
%REMEMBERFRAMEWORKFOLDER Persist the most recently used data folder.

if nargin < 1 || strlength(string(folder)) == 0 || ~isfolder(string(folder))
    return;
end
if isfield(settings,'rememberLastDataFolder') && ~settings.rememberLastDataFolder
    return;
end
if isfield(settings,'projectRoot') && strlength(string(settings.projectRoot)) > 0
    root = string(settings.projectRoot);
else
    root = string(fileparts(fileparts(mfilename('fullpath'))));
end
lastDataFolder = char(string(folder)); %#ok<NASGU>
try
    save(fullfile(root,'Framework_User_State.mat'),'lastDataFolder');
catch ME
    warning('Could not remember the last-used folder: %s',ME.message);
end
end
