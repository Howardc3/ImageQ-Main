function [rHandles, gHandles, bHandles, rgHandles, gbHandles, rbHandles, rgbHandles, ...
          rPositions, gPositions, bPositions, rgPositions, gbPositions, rbPositions, rgbPositions, ...
          rCounter, gCounter, bCounter, rgCounter, gbCounter, rbCounter, rgbCounter] = ...
          autoLabelChannel_function(channel, adjustedCopy, fontSizeBox, colorMenu, axCropped, ...
          rHandles, gHandles, bHandles, rgHandles, gbHandles, rbHandles, rgbHandles, ...
          rPositions, gPositions, bPositions, rgPositions, gbPositions, rbPositions, rgbPositions, ...
          rCounter, gCounter, bCounter, rgCounter, gbCounter, rbCounter, rgbCounter, ...
          rAreaBox, gAreaBox, bAreaBox, maxrAreaBox, maxgAreaBox, maxbAreaBox, overlapThreshBox)

    % Get parameters
    adjusted = adjustedCopy;
    fontSize = str2double(fontSizeBox.String);
    colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
    fontColor = colors{colorMenu.Value};
    
    % Clear existing markers for current channel
    switch channel
        case 'R'
            arrayfun(@delete, rHandles);
            rHandles = []; rPositions = zeros(0,2); rCounter = 0;
            % Clear region information
            rAreas = [];
        case 'G'
            arrayfun(@delete, gHandles);
            gHandles = []; gPositions = zeros(0,2); gCounter = 0;
            % Clear region information
            gAreas = [];
        case 'B'
            arrayfun(@delete, bHandles);
            bHandles = []; bPositions = zeros(0,2); bCounter = 0;
            % Clear region information
            bAreas = [];
        case 'RG'
            arrayfun(@delete, rgHandles);
            rgHandles = []; rgPositions = zeros(0,2); rgCounter = 0;
            % Clear overlap region information
            rgOverlapAreas = [];
        case 'GB'
            arrayfun(@delete, gbHandles);
            gbHandles = []; gbPositions = zeros(0,2); gbCounter = 0;
            % Clear overlap region information
            gbOverlapAreas = [];
        case 'RB'
            arrayfun(@delete, rbHandles);
            rbHandles = []; rbPositions = zeros(0,2); rbCounter = 0;
            % Clear overlap region information
            rbOverlapAreas = [];
        case 'RGB'
            arrayfun(@delete, rgbHandles);
            rgbHandles = []; rgbPositions = zeros(0,2); rgbCounter = 0;
            % Clear overlap region information
            rgbOverlapAreas = [];
    end

    % Get edge length thresholds
    switch channel
        case 'R'
            areaThresh = str2double(rAreaBox.String);
            maxareaThresh = str2double(maxrAreaBox.String);
        case 'G'
            areaThresh = str2double(gAreaBox.String);
            maxareaThresh = str2double(maxgAreaBox.String);
        case 'B'
            areaThresh = str2double(bAreaBox.String);
            maxareaThresh = str2double(maxbAreaBox.String);
        case 'RG'
            areaThresh = min(str2double(rAreaBox.String), str2double(gAreaBox.String));
            maxareaThresh = max(str2double(maxrAreaBox.String), str2double(maxgAreaBox.String));
        case 'GB'
            areaThresh = min(str2double(gAreaBox.String), str2double(bAreaBox.String));
            maxareaThresh = max(str2double(maxgAreaBox.String), str2double(maxbAreaBox.String));
        case 'RB'
            areaThresh = min(str2double(rAreaBox.String), str2double(bAreaBox.String));
            maxareaThresh = max(str2double(maxrAreaBox.String), str2double(maxbAreaBox.String));
        case 'RGB'
            areaThresh = min([str2double(rAreaBox.String), str2double(gAreaBox.String), str2double(bAreaBox.String)]);
            maxareaThresh = max([str2double(maxrAreaBox.String), str2double(maxgAreaBox.String), str2double(maxbAreaBox.String)]);
    end

    %% Single channel processing (based on Bounding Box edge length)
    if length(channel) == 1
        cIndex = find('RGB' == channel);
        bw = imbinarize(adjusted(:,:,cIndex));
        stats = regionprops(bw, 'BoundingBox', 'Centroid', 'Area');
        
        % Mark regions that meet the conditions
        for k = 1:numel(stats)
            bb = stats(k).BoundingBox; % [x, y, width, height]
            width = bb(3);
            height = bb(4);
            area = stats(k).Area; % Get region area
            
            % Modified judgment condition: check if both width and height are within min and max threshold range
            if (width >= areaThresh && height >= areaThresh) && ...
               (width <= maxareaThresh && height <= maxareaThresh)
                pos = stats(k).Centroid;
                switch channel
                    case 'R'
                        rCounter = rCounter + 1;
                        h = text(axCropped, pos(1), pos(2), num2str(rCounter), ...
                            'Color', fontColor, 'FontSize', fontSize, ...
                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                        rHandles(end+1) = h;
                        rPositions(end+1,:) = pos;
                        rAreas(end+1) = area;
                    case 'G'
                        gCounter = gCounter + 1;
                        h = text(axCropped, pos(1), pos(2), num2str(gCounter), ...
                            'Color', fontColor, 'FontSize', fontSize, ...
                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                        gHandles(end+1) = h;
                        gPositions(end+1,:) = pos;
                        gAreas(end+1) = area;
                    case 'B'
                        bCounter = bCounter + 1;
                        h = text(axCropped, pos(1), pos(2), num2str(bCounter), ...
                            'Color', fontColor, 'FontSize', fontSize, ...
                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                        bHandles(end+1) = h;
                        bPositions(end+1,:) = pos;
                        bAreas(end+1) = area;
                end
            end
        end

    %% Combined channel processing (synchronized modification to edge length filtering)
    else
        % Determine channel combination
        switch channel
            case 'RG', ch1 = 1; ch2 = 2;
            case 'GB', ch1 = 2; ch2 = 3;
            case 'RB', ch1 = 1; ch2 = 3;
            case 'RGB', ch1 = 1; ch2 = 2; ch3 = 3;
        end
    
        % Binarize and filter (based on edge length)
        bw1 = imbinarize(adjusted(:,:,ch1));
        stats1 = regionprops(bw1, 'BoundingBox', 'Centroid');
        % Modified to correct array access method
        widths1 = arrayfun(@(x) x.BoundingBox(3), stats1);
        heights1 = arrayfun(@(x) x.BoundingBox(4), stats1);
        validIdx1 = (widths1 >= areaThresh & heights1 >= areaThresh) & ...
                (widths1 <= maxareaThresh & heights1 <= maxareaThresh);
        stats1 = stats1(validIdx1);
    
        bw2 = imbinarize(adjusted(:,:,ch2));
        stats2 = regionprops(bw2, 'BoundingBox', 'Centroid');
        widths2 = arrayfun(@(x) x.BoundingBox(3), stats2);
        heights2 = arrayfun(@(x) x.BoundingBox(4), stats2);
        validIdx2 = (widths2 >= areaThresh & heights2 >= areaThresh) & ...
                (widths2 <= maxareaThresh & heights2 <= maxareaThresh);
        stats2 = stats2(validIdx2);
    
        if strcmp(channel, 'RGB')
            bw3 = imbinarize(adjusted(:,:,ch3));
            stats3 = regionprops(bw3, 'BoundingBox', 'Centroid');
            widths3 = arrayfun(@(x) x.BoundingBox(3), stats3);
            heights3 = arrayfun(@(x) x.BoundingBox(4), stats3);
            validIdx3 = (widths3 >= areaThresh & heights3 >= areaThresh) & ...
                    (widths3 <= maxareaThresh & heights3 <= maxareaThresh);
            stats3 = stats3(validIdx3);
        end
        
        % Detect overlap (rest of logic remains unchanged)
        maxOverlapArea = str2double(overlapThreshBox.String)^2;    
    
        if strcmp(channel, 'RGB')
            % Initialize overlap region array
            rgbOverlapAreas = [];
            
            % Three-channel overlap detection
            for i = 1:numel(stats1)
                bb1 = stats1(i).BoundingBox;
                r1 = [bb1(1), bb1(2), bb1(1)+bb1(3), bb1(2)+bb1(4)];
                c1 = stats1(i).Centroid;
                for j = 1:numel(stats2)
                    bb2 = stats2(j).BoundingBox;
                    r2 = [bb2(1), bb2(2), bb2(1)+bb2(3), bb2(2)+bb2(4)];
                    c2 = stats2(j).Centroid;
                
                    % Check R and G overlap
                    in1 = c1(1)>=r2(1) && c1(1)<=r2(3) && c1(2)>=r2(2) && c1(2)<=r2(4);
                    in2 = c2(1)>=r1(1) && c2(1)<=r1(3) && c2(2)>=r1(2) && c2(2)<=r1(4);
                
                    if (in1 || in2)
                        xL = max(r1(1), r2(1));
                        yT = max(r1(2), r2(2));
                        xR = min(r1(3), r2(3));
                        yB = min(r1(4), r2(4));
                    
                        if (xR > xL) && (yB > yT)
                            ovAreaRG = (xR - xL) * (yB - yT);
                            area1 = bb1(3)*bb1(4);
                            area2 = bb2(3)*bb2(4);
                            ratio1 = ovAreaRG / area1;
                            ratio2 = ovAreaRG / area2;
                        
                            % Apply maxOverlapArea filtering
                            if (ratio1 >= 0.5 || ratio2 >= 0.5) && ovAreaRG <= maxOverlapArea
                                % Check R+G and B overlap
                                for k = 1:numel(stats3)
                                    bb3 = stats3(k).BoundingBox;
                                    r3 = [bb3(1), bb3(2), bb3(1)+bb3(3), bb3(2)+bb3(4)];
                                    c3 = stats3(k).Centroid;
                                    area3 = bb3(3)*bb3(4);
                                
                                    % Check R+G and B overlap
                                    inRG_B = (c3(1)>=xL && c3(1)<=xR && c3(2)>=yT && c3(2)<=yB) || ...
                                            ((c1(1)+c2(1))/2 >= r3(1) && (c1(1)+c2(1))/2 <= r3(3) && ...
                                            (c1(2)+c2(2))/2 >= r3(2) && (c1(2)+c2(2))/2 <= r3(4));
                                
                                    if inRG_B
                                        xL_final = max(xL, r3(1));
                                        yT_final = max(yT, r3(2));
                                        xR_final = min(xR, r3(3));
                                        yB_final = min(yB, r3(4));
                                    
                                        if (xR_final > xL_final) && (yB_final > yT_final)
                                            ovAreaRGB = (xR_final - xL_final) * (yB_final - yT_final);
                                            ratio3 = ovAreaRGB / area3;
                                        
                                            % Apply maxOverlapArea filtering again
                                            if ratio3 >= 0.5 && ovAreaRGB <= maxOverlapArea
                                                cx = (xL_final + xR_final)/2;
                                                cy = (yT_final + yB_final)/2;
                                            
                                                rgbCounter = rgbCounter + 1;
                                                h = text(axCropped, cx, cy, num2str(rgbCounter), ...
                                                    'Color', fontColor, 'FontSize', fontSize, ...
                                                    'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                                rgbHandles(end+1) = h;
                                                rgbPositions(end+1,:) = [cx, cy];
                                                rgbOverlapAreas(end+1) = ovAreaRGB;
                                            end
                                        end
                                    end
                                end
                            end
                        end
                    end
                end
            end
            
            % Save RGB overlap region data to figure application data
            setappdata(gcf, 'rgbOverlapAreas', rgbOverlapAreas);

        else
            % Initialize corresponding channel overlap region arrays
            if strcmp(channel, 'RG')
                rgOverlapAreas = [];
            elseif strcmp(channel, 'GB')
                gbOverlapAreas = [];
            elseif strcmp(channel, 'RB')
                rbOverlapAreas = [];
            end
            
            % Two-channel overlap detection
            for i = 1:numel(stats1)
                bb1 = stats1(i).BoundingBox;
                r1 = [bb1(1), bb1(2), bb1(1)+bb1(3), bb1(2)+bb1(4)];
                c1 = stats1(i).Centroid;
                area1 = bb1(3)*bb1(4);
                
                for j = 1:numel(stats2)
                    bb2 = stats2(j).BoundingBox;
                    r2 = [bb2(1), bb2(2), bb2(1)+bb2(3), bb2(2)+bb2(4)];
                    c2 = stats2(j).Centroid;
                    area2 = bb2(3)*bb2(4);
                
                    % Overlap detection
                    in1 = c1(1)>=r2(1) && c1(1)<=r2(3) && c1(2)>=r2(2) && c1(2)<=r2(4);
                    in2 = c2(1)>=r1(1) && c2(1)<=r1(3) && c2(2)>=r1(2) && c2(2)<=r1(4);
                
                    if (in1 || in2)
                        xL = max(r1(1), r2(1));
                        yT = max(r1(2), r2(2));
                        xR = min(r1(3), r2(3));
                        yB = min(r1(4), r2(4));
                    
                        if (xR > xL) && (yB > yT)
                            ovArea = (xR - xL) * (yB - yT);
                            ratio1 = ovArea / area1;
                            ratio2 = ovArea / area2;
                        
                            % Apply maxOverlapArea filtering
                            if (ratio1 >= 0.5 || ratio2 >= 0.5) && ovArea <= maxOverlapArea
                                cx = (xL + xR)/2;
                                cy = (yT + yB)/2;
                            
                                switch channel
                                    case 'RG'
                                        rgCounter = rgCounter + 1;
                                        h = text(axCropped, cx, cy, num2str(rgCounter), ...
                                            'Color', fontColor, 'FontSize', fontSize, ...
                                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                        rgHandles(end+1) = h;
                                        rgPositions(end+1,:) = [cx, cy];
                                        rgOverlapAreas(end+1) = ovArea;
                                    case 'GB'
                                        gbCounter = gbCounter + 1;
                                        h = text(axCropped, cx, cy, num2str(gbCounter), ...
                                            'Color', fontColor, 'FontSize', fontSize, ...
                                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                        gbHandles(end+1) = h;
                                        gbPositions(end+1,:) = [cx, cy];
                                        gbOverlapAreas(end+1) = ovArea;
                                    case 'RB'
                                        rbCounter = rbCounter + 1;
                                        h = text(axCropped, cx, cy, num2str(rbCounter), ...
                                            'Color', fontColor, 'FontSize', fontSize, ...
                                            'FontWeight', 'bold', 'HorizontalAlignment', 'center', 'Clipping', 'on');
                                        rbHandles(end+1) = h;
                                        rbPositions(end+1,:) = [cx, cy];
                                        rbOverlapAreas(end+1) = ovArea;
                                end
                            end
                        end
                    end
                end
            end
            
            % Save overlap region data to figure application data
            if strcmp(channel, 'RG')
                setappdata(gcf, 'rgOverlapAreas', rgOverlapAreas);
            elseif strcmp(channel, 'GB')
                setappdata(gcf, 'gbOverlapAreas', gbOverlapAreas);
            elseif strcmp(channel, 'RB')
                setappdata(gcf, 'rbOverlapAreas', rbOverlapAreas);
            end
        end
    end
    
    % Save single channel region area data
    if strcmp(channel, 'R')
        setappdata(gcf, 'rAreas', rAreas);
    elseif strcmp(channel, 'G')
        setappdata(gcf, 'gAreas', gAreas); 
    elseif strcmp(channel, 'B')
        setappdata(gcf, 'bAreas', bAreas);
    end
end 