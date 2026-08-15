function keys = normalizeEntityKey(names,removeRepeatSuffix)
%NORMALIZEENTITYKEY Normalize names for flexible matching and repeat grouping.
%
% Ignores case, file extensions, spaces, underscores, hyphens, and copy
% suffixes. When removeRepeatSuffix is true, trailing replicate labels such
% as rep2, repeat3, trial1, run4, and measurement2 are also removed.

if nargin < 2, removeRepeatSuffix = false; end
text = lower(strtrim(string(names(:))));
text = regexprep(text,'\.[a-z0-9]{1,8}$','');
text = regexprep(text,'\s*\(\d+\)$','');
text = regexprep(text,'(?:[_\-\s]*(?:copy)\s*\d*)$','');
if removeRepeatSuffix
    text = regexprep(text, ...
        '(?:[_\-\s]*(?:rep(?:licate)?|repeat|trial|run|measurement|meas)\s*\d+)$','');
end
keys = regexprep(text,'[^a-z0-9]+','');
for i = 1:numel(keys)
    if strlength(keys(i)) == 0
        keys(i) = "unnamed" + i;
    end
end
end
