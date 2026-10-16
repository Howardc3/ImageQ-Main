function pxPerUm = conversionFactorUIGenerator()
% conversionFactorUIGenerator  Ask how many pixels make one micrometer.
%
%   pxPerUm = conversionFactorUIGenerator() returns the typed value, or NaN
%   if the user cancels, leaves it blank, or types something that isn't a
%   positive number. NaN means "unknown": the GUI stays pixel-based and no
%   scale bar is drawn.

    answer = inputdlg({'Pixels per micrometer (leave blank if unknown):'}, ...
        'Conversion Factor', [1 50], {''});
    pxPerUm = NaN;
    if isempty(answer), return; end
    v = str2double(answer{1});
    if isfinite(v) && v > 0
        pxPerUm = v;
    end
end
