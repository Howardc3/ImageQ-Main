function overlay = roiOverlay(original, shape, roiPosition)
% roiOverlay  The original image with the ROI border painted red.
%
%   overlay = roiOverlay(original, shape, roiPosition) returns an RGB copy
%   of original (H x W x 3, or H x W grayscale) with the ROI's outline in
%   red, for saving as "original_with_ROI". shape is 'rectangle' (then
%   roiPosition = [x y w h]) or 'polygon' (roiPosition = N x 2 vertices),
%   i.e. the ROI object's Position, in image pixels. The border thickness
%   scales with the image size so it stays visible on large scans.

    [imgH, imgW, ~] = size(original);

    % If image is grayscale (1 channel), convert to RGB (3 channels)
    if size(original,3) == 1
        original = repmat(original, [1 1 3]);
    end
    % Create mask
    mask = false(imgH, imgW);
    if strcmp(shape, 'rectangle')
        % Rectangle ROI [x, y, width, height]
        pos = roiPosition;

        % Edges are converted to integer pixels
        x1 = max(1, floor(pos(1)));
        y1 = max(1, floor(pos(2)));
        x2 = min(imgW, ceil(pos(1) + pos(3)));
        y2 = min(imgH, ceil(pos(2) + pos(4)));

        % Fill rectangle area
        if x2 >= x1 && y2 >= y1
            mask(y1:y2, x1:x2) = true;
        end
    else
        % Polygon ROI
        v = roiPosition;
        mask = poly2mask(v(:,1), v(:,2), imgH, imgW);
    end

    overlay = original;
    perim = bwperim(mask, 8);

    % Use image size scaled ROI border in saved ROI image
    targetFraction = 0.003;
    thicknessPx = max(1, round(max(imgH, imgW) * targetFraction));
    perim = imdilate(perim, ones(thicknessPx));

    % Paint perimeter red by channel editing
    overlay(:,:,1) = max(overlay(:,:,1), perim);
    overlay(:,:,2) = overlay(:,:,2) .* ~perim;
    overlay(:,:,3) = overlay(:,:,3) .* ~perim;
end
