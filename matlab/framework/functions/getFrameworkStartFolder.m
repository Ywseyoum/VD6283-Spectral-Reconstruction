function folder = getFrameworkStartFolder(settings)
%GETFRAMEWORKSTARTFOLDER Resolve the best starting folder for file dialogs.

folder = "";
if isfield(settings,'defaultStartFolder') && strlength(string(settings.defaultStartFolder)) > 0
    candidate = string(settings.defaultStartFolder);
    if isfolder(candidate), folder = candidate; end
end

if strlength(folder) == 0 && shouldRemember(settings)
    stateFile = frameworkStateFile(settings);
    if isfile(stateFile)
        try
            state = load(stateFile,'lastDataFolder');
            if isfield(state,'lastDataFolder') && isfolder(string(state.lastDataFolder))
                folder = string(state.lastDataFolder);
            end
        catch
        end
    end
end

if strlength(folder) == 0
    try
        up = string(userpath);
        candidates = split(up,pathsep);
        candidates = candidates(strlength(candidates) > 0);
        for i = 1:numel(candidates)
            if isfolder(candidates(i))
                folder = candidates(i);
                break;
            end
        end
    catch
    end
end

if strlength(folder) == 0 || ~isfolder(folder)
    folder = string(pwd);
end
end

function tf = shouldRemember(settings)
tf = true;
if isfield(settings,'rememberLastDataFolder')
    tf = logical(settings.rememberLastDataFolder);
end
end

function stateFile = frameworkStateFile(settings)
if isfield(settings,'projectRoot') && strlength(string(settings.projectRoot)) > 0
    root = string(settings.projectRoot);
else
    root = string(fileparts(fileparts(mfilename('fullpath'))));
end
stateFile = fullfile(root,'Framework_User_State.mat');
end
