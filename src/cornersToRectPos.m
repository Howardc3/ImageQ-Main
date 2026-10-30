function pos = cornersToRectPos(x1, y1, x2, y2, imgW, imgH)
% cornersToRectPos  ROI Position for corners typed in Rectangle Coordinates.
%
%   pos = cornersToRectPos(x1, y1, x2, y2, imgW, imgH) converts the
%   bottom-left (x1,y1) and top-right (x2,y2) corners into a rectangle
%   ROI Position [left top width height]. The corners use the same
%   convention as the X1/Y1/X2/Y2 readouts: pixels of the original image
%   (imgW x imgH), y counted up from the bottom.
%
%   Swapped corners are put in order, and the result is clamped to the
%   limits the crop code enforces, so the readouts afterwards match what
%   was typed. pos is [] if a corner isn't a number, or if no area is
%   left inside the image after clamping.

    pos = [];
    if any(isnan([x1, y1, x2, y2])), return; end

    % Ensure x1 < x2 and y1 < y2
    % deal swaps the values if necessary
    if x1 > x2
        [x1, x2] = deal(x2, x1);
    end
    if y1 > y2
        [y1, y2] = deal(y2, y1);
    end

    % Clamp to the image, using the same limits as the crop code
    % (updateImage_function / greyscale_case updateImage)
    x1 = min(max(round(x1), 1), imgW);
    x2 = min(max(round(x2), 1), imgW);
    y1 = min(max(round(y1), 0), imgH - 1);
    y2 = min(max(round(y2), 0), imgH - 1);

    % Entirely outside the image, or no area left after clamping
    if x2 <= x1 || y2 <= y1, return; end

    % Inverse of the readout formulas (X1 = left, Y2 = imgH - top, ...)
    pos = [x1, imgH - y2, x2 - x1, y2 - y1];
end
