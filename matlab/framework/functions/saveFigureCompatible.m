function saveFigureCompatible(fig,folder,name)
%SAVEFIGURECOMPATIBLE Save PNG and editable FIG with a fallback.
pngPath = fullfile(folder,[name '.png']);
if exist('exportgraphics','file') == 2
    exportgraphics(fig,pngPath,'Resolution',300);
else
    print(fig,pngPath,'-dpng','-r300');
end
savefig(fig,fullfile(folder,[name '.fig']));
close(fig);
end
