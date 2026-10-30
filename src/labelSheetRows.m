function rows = labelSheetRows(positions, areas, means, areaName, pxPerUm)
% labelSheetRows  Cell rows for a *_Labels sheet: note, header, one row per label.
%
%   rows = labelSheetRows(positions, areas, means, areaName, pxPerUm)
%   positions is N x 2 [x y] in crop pixels; areas and means hold one value
%   per label (NaN for manual labels). areaName names the area column
%   ('Area' or 'Overlap Area'). Write the result with writecell.
%
%   If pxPerUm (image pixels per micrometer) is a positive number, a
%   square-micrometer area goes right after the pixel area, and both area
%   headers get their unit so they're distinct: "Area (px)", "Area (um^2)".
%   Otherwise (NaN = unknown scale) the sheet keeps its single "Area" column.

    hasScale = isscalar(pxPerUm) && isfinite(pxPerUm) && pxPerUm > 0;
    n = size(positions, 1);
    areas = reshape(areas, [], 1);
    means = reshape(means, [], 1);

    if hasScale
        um2 = [char(181) 'm' char(178)];   % micro sign, m, superscript 2
        header = {'Label', 'X', 'Y', [areaName ' (px)'], [areaName ' (' um2 ')'], 'MeanIntensity'};
        % 1 px = 1/pxPerUm um, so 1 px^2 = 1/pxPerUm^2 um^2
        data = [(1:n)', positions, areas, areas / pxPerUm^2, means];
    else
        header = {'Label', 'X', 'Y', areaName, 'MeanIntensity'};
        data = [(1:n)', positions, areas, means];
    end

    % Note row padded to the header's width, so the rows stack
    note = [{'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner'}, ...
            repmat({''}, 1, numel(header) - 1)];
    rows = [note; header; num2cell(data)];
end
