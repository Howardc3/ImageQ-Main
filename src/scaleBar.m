function sb = scaleBar(ax, img, pxPerUm, lengthBox)
% scaleBar  Scale bar in the bottom-right corner of an image.
%
%   sb = scaleBar(ax, img, pxPerUm, lengthBox) draws a line + label on ax
%   (the axes holding image img). The bar's physical length is whatever
%   is typed in the edit box lengthBox (micrometers), so it is
%   (typed um) * pxPerUm pixels long. Returns a struct of function handles:
%     sb.update()   re-place the bar for the image's current size. Call it
%                   after every crop; it also runs when lengthBox is edited.
%                   If pxPerUm is NaN (no conversion factor), the bar stays
%                   hidden and lengthBox shows 'n/a'.
%     sb.handles()  [line text] graphics, e.g. to hide them before export.
%
%   The bar is anchored to the image, not the zoomed view, in pixel (data)
%   coordinates, so it follows every new crop. If the typed length is wider
%   than the crop, the bar is hidden and lengthBox turns pink (its tooltip
%   says the longest length that fits).

    barLine = line(ax, nan, nan, 'Color', 'w', 'LineWidth', 4, ...
        'PickableParts', 'none', 'Clipping', 'on');
    barText = text(ax, nan, nan, '', 'Color', 'w', 'FontWeight', 'bold', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'PickableParts', 'none', 'Clipping', 'on');

    % updateImage_function ends with axis(ax,'image'), which fits the axes
    % around every object in it. Leave the bar out of that, or a bar from
    % a bigger crop makes the axes zoom out and the image shrinks.
    % (XLimInclude/YLimInclude are hidden line properties.)
    try
        set(barLine, 'XLimInclude', 'off', 'YLimInclude', 'off');
    catch
    end

    lastUm = str2double(lengthBox.String);   % last valid length, to fall back on
    lengthBox.Callback = @(~,~) update();

    sb.update = @update;
    sb.handles = @() [barLine barText];

    function update()
        if ~(isfinite(pxPerUm) && pxPerUm > 0)
            set([barLine barText], 'Visible', 'off');
            lengthBox.String = 'n/a';
            lengthBox.Enable = 'inactive';
            return;
        end

        um = str2double(lengthBox.String);
        if ~(isfinite(um) && um > 0)
            % Not a positive number: put the old value back
            um = lastUm;
            lengthBox.String = sprintf('%g', um);
        end
        lastUm = um;

        [h, w, ~] = size(img.CData);
        barPx = um * pxPerUm;                 % the conversion: um -> pixels
        margin = 0.05 * min(w, h);

        % +0.5 is the image's outer pixel edge; y grows downward in images
        x2 = w + 0.5 - margin;
        x1 = x2 - barPx;
        y  = h + 0.5 - margin;

        % Too long for this crop: hide the bar (a clipped bar would show the
        % wrong length) and tint the box so the user types a smaller value
        if barPx > w - 2*margin
            set(barLine, 'XData', nan, 'YData', nan, 'Visible', 'off');
            set(barText, 'Visible', 'off');
            lengthBox.BackgroundColor = [1 0.85 0.85];
            lengthBox.TooltipString = sprintf(['Bar is wider than the crop ' ...
                '(max %g \x3BCm here). Type a smaller length.'], ...
                (w - 2*margin) / pxPerUm);
            return;
        end
        lengthBox.BackgroundColor = [1 1 1];
        lengthBox.TooltipString = '';

        set(barLine, 'XData', [x1 x2], 'YData', [y y], 'Visible', 'on');
        set(barText, 'Position', [(x1 + x2)/2, y - 0.01*h], ...
            'String', sprintf('%g \x3BCm', um), 'Visible', 'on');
    end
end
