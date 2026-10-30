function region = regionInBox(maskImg, intensityImg, boxPos, darkObjects)
% regionInBox  Find the largest object inside a box (the "Add" label tool).
%
%   region = regionInBox(maskImg, intensityImg, boxPos, darkObjects)
%   Otsu-thresholds each channel of maskImg (H x W x C) inside the box
%   boxPos = [x y w h] (axes data units = image pixels) and keeps pixels
%   that are foreground in every channel. darkObjects = true treats dark
%   pixels as foreground (grayscale dark cells), false bright ones
%   (fluorescence channels). The largest connected object is returned as
%   a struct, in full-image pixels:
%     centroid  [x y]
%     area      pixel count
%     meanI     mean of intensityImg (H x W) over the object
%     boundary  [x y] outer contour (zeros(0,2) if none)
%   region is [] if the box is empty, outside the image, or has no object.
%
%   The threshold comes from the box only, so the same cell can get a
%   slightly different outline than auto-labeling (which thresholds the
%   whole crop).

    region = [];
    if numel(boxPos) < 4 || any(boxPos(3:4) <= 0), return; end
    % nCh is the number of channels in the mask image (e.g., 3 for RGB)
    [imgH, imgW, nCh] = size(maskImg);

    % Pixels whose centers fall inside the box
    x1 = max(1, ceil(boxPos(1)));
    y1 = max(1, ceil(boxPos(2)));
    x2 = min(imgW, floor(boxPos(1) + boxPos(3)));
    y2 = min(imgH, floor(boxPos(2) + boxPos(4)));
    if x2 < x1 || y2 < y1, return; end

    bw = true(y2 - y1 + 1, x2 - x1 + 1);

    % And together all the channels
    for c = 1:nCh
        fg = imbinarize(maskImg(y1:y2, x1:x2, c));
        if darkObjects, fg = ~fg; end
        bw = bw & fg;
    end

    [L, num] = bwlabel(bw);
    if num == 0, return; end
    S = regionprops(L, 'Area', 'Centroid');
    [~, k] = max([S.Area]);
    mk = (L == k);

    sub = intensityImg(y1:y2, x1:x2);
    region.centroid = S(k).Centroid + [x1 y1] - 1;
    region.area = S(k).Area;
    region.meanI = mean(sub(mk));

    B = bwboundaries(mk, 'noholes');
    if isempty(B)
        region.boundary = zeros(0, 2);
    else
        region.boundary = [B{1}(:,2), B{1}(:,1)] + [x1 y1] - 1;   % [row col] -> [x y]
    end
end
