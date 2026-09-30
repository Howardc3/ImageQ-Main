function updateImage_function(axCropped, currentShape, roi, original_rgb, imgW, imgH, ...
    coord_boxes, sliders, val_labels, hCroppedRGB, hR, hG, hB)

    % --- Save current view (zoom/pan position) ---
    xlimCurrent = xlim(axCropped);
    ylimCurrent = ylim(axCropped);

    % Get cropping region based on shape type
    switch currentShape
        case 'rectangle'
            pos = round(roi.Position);
            pos(1:2) = max(pos(1:2), [1,1]);
            pos(3:4) = min(pos(3:4), [imgW, imgH] - pos(1:2));
            cropped = imcrop(original_rgb, pos);
            
            % Update coordinate display
            x1 = pos(1); y2 = imgH - pos(2);
            x2 = pos(1) + pos(3); y1 = imgH - (pos(2) + pos(4));
            coord_vals = [x1, y1, x2, y2];
            
        case 'polygon'  % Modified for arbitrary polygon
            % Get polygon vertices
            vertices = roi.Position;
            
            % Create polygon mask
            mask = poly2mask(vertices(:,1), vertices(:,2), size(original_rgb,1), size(original_rgb,2));
            
            % Calculate bounding box (for cropping)
            minX = min(vertices(:,1));
            maxX = max(vertices(:,1));
            minY = min(vertices(:,2));
            maxY = max(vertices(:,2));
            width = maxX - minX;
            height = maxY - minY;
            
            % Crop bounding box region
            bbox = [minX, minY, width, height];
            bbox = round(bbox);
            bbox(1:2) = max(bbox(1:2), [1,1]);
            bbox(3:4) = min(bbox(3:4), [imgW, imgH] - bbox(1:2));
            
            % Apply mask to bounding box region
            cropped = zeros(bbox(4), bbox(3), 3);
            for c = 1:3
                channel = original_rgb(bbox(2):bbox(2)+bbox(4)-1, bbox(1):bbox(1)+bbox(3)-1, c);
                mask_roi = mask(bbox(2):bbox(2)+bbox(4)-1, bbox(1):bbox(1)+bbox(3)-1);
                channel(~mask_roi) = 0;
                cropped(:,:,c) = channel;
            end
            
            % Update coordinate display (display bounding box coordinates)
            x1 = bbox(1); y2 = imgH - bbox(2);
            x2 = bbox(1) + bbox(3); y1 = imgH - (bbox(2) + bbox(4));
            coord_vals = [x1, y1, x2, y2];
    end

    % Update coordinate boxes
    for i = 1:4
        coord_boxes(i).String = num2str(coord_vals(i));
    end

    % Adjust image brightness and contrast
    adjusted = zeros(size(cropped));
    for c = 1:3
        contrast = sliders(c,1).Value;
        brightness = sliders(c,2).Value;
        val_labels(c,1).String = sprintf('%.2f', contrast);
        val_labels(c,2).String = sprintf('%.2f', brightness);
        adjusted(:,:,c) = contrast * cropped(:,:,c) + brightness;
    end
    adjusted = min(max(adjusted, 0), 1);

    % --- Update the image display ---
    hCroppedRGB.CData = adjusted;
   
    % --- Restore previous zoom and pan ---
    xlim(axCropped, xlimCurrent);
    ylim(axCropped, ylimCurrent);

    % --- Update split RGB channels ---
    hR.CData = cat(3, adjusted(:,:,1), zeros(size(adjusted,1), size(adjusted,2), 2));
    hG.CData = cat(3, zeros(size(adjusted,1), size(adjusted,2)), adjusted(:,:,2), zeros(size(adjusted,1), size(adjusted,2)));
    hB.CData = cat(3, zeros(size(adjusted,1), size(adjusted,2), 2), adjusted(:,:,3));
    
    axis(axCropped, 'image');

    % Return the adjusted image for other functions to use
    assignin('base', 'adjustedCopy', adjusted);
    assignin('base', 'filteredCopy', adjusted);
end 