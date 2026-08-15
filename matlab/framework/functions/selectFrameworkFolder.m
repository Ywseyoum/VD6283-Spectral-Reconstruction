function folder = selectFrameworkFolder(titleText,settings)
%SELECTFRAMEWORKFOLDER Select a folder, starting from the recent data folder.

startFolder = getFrameworkStartFolder(settings);
selected = uigetdir(char(startFolder),titleText);
if isequal(selected,0)
    folder = "";
else
    folder = string(selected);
    rememberFrameworkFolder(folder,settings);
end
end
