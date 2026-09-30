function saveAll_function(animal_name, currentShape, roi, original_rgb, imgW, imgH, hCroppedRGB, ...
    sliders, rAreaBox, gAreaBox, bAreaBox, maxrAreaBox, maxgAreaBox, maxbAreaBox, ...
    coord_boxes, rPositions, gPositions, bPositions, rgPositions, gbPositions, ...
    rbPositions, rgbPositions, overlapThreshBox)

    % Get stored region area data (single channel)
    if isappdata(gcf, 'rAreas')
        rAreas = getappdata(gcf, 'rAreas');
    else
        rAreas = [];
    end
    
    if isappdata(gcf, 'gAreas')
        gAreas = getappdata(gcf, 'gAreas');
    else
        gAreas = [];
    end
    
    if isappdata(gcf, 'bAreas')
        bAreas = getappdata(gcf, 'bAreas');
    else
        bAreas = [];
    end

    % Get stored overlap area data (combined channels)
    if isappdata(gcf, 'rgOverlapAreas')
        rgOverlapAreas = getappdata(gcf, 'rgOverlapAreas');
    else
        rgOverlapAreas = [];
    end
    
    if isappdata(gcf, 'gbOverlapAreas')
        gbOverlapAreas = getappdata(gcf, 'gbOverlapAreas');
    else
        gbOverlapAreas = [];
    end
    
    if isappdata(gcf, 'rbOverlapAreas')
        rbOverlapAreas = getappdata(gcf, 'rbOverlapAreas');
    else
        rbOverlapAreas = [];
    end

    if isappdata(gcf, 'rgbOverlapAreas')
        rgbOverlapAreas = getappdata(gcf, 'rgbOverlapAreas');
    else
        rgbOverlapAreas = [];
    end

    % Get stored mean intensity data
    if isappdata(gcf, 'rMeans'),   rMeans = getappdata(gcf, 'rMeans');   else, rMeans = []; end
    if isappdata(gcf, 'gMeans'),   gMeans = getappdata(gcf, 'gMeans');   else, gMeans = []; end
    if isappdata(gcf, 'bMeans'),   bMeans = getappdata(gcf, 'bMeans');   else, bMeans = []; end
    
    if isappdata(gcf, 'rgMeans'),  rgMeans = getappdata(gcf, 'rgMeans'); else, rgMeans = []; end
    if isappdata(gcf, 'gbMeans'),  gbMeans = getappdata(gcf, 'gbMeans'); else, gbMeans = []; end
    if isappdata(gcf, 'rbMeans'),  rbMeans = getappdata(gcf, 'rbMeans'); else, rbMeans = []; end
    if isappdata(gcf, 'rgbMeans'), rgbMeans = getappdata(gcf, 'rgbMeans'); else, rgbMeans = []; end

    % --- Select save directory ---
    folderPath = uigetdir('', 'Select Save Directory');
    if folderPath == 0, return; end
    
    % --- Get ROI vertex coordinates and area ---
    if strcmp(currentShape, 'rectangle')
        % Rectangle mode [x,y,w,h] → convert to 4 vertices
        pos = roi.Position;
        vertices = [...
            pos(1), pos(2);               % Top-left
            pos(1)+pos(3), pos(2);        % Top-right
            pos(1)+pos(3), pos(2)+pos(4); % Bottom-right
            pos(1), pos(2)+pos(4)];       % Bottom-left
        area_pixels = pos(3) * pos(4);    % Rectangle area
    else
        % Polygon mode - directly get all vertices
        vertices = roi.Position; % N×2 matrix
        area_pixels = polyarea(vertices(:,1), vertices(:,2)); % Polygon area
    end
    % --- Create merged ROI information table (including vertex coordinates) ---
    % Basic information
    roiInfoCell = {
        'ROI_Type', currentShape;
        'Area_pixels', area_pixels;
        'Vertex_Count', size(vertices,1);
        ' ', ' ';
        'Vertex_Coordinates', 'X | Y | X_Norm | Y_Norm'; % Header
        };
    
    % Add vertex data (one vertex per row)
    for i = 1:size(vertices,1)
        roiInfoCell = [roiInfoCell; {
            sprintf('Vertex%d', i), ...
            sprintf('%.1f | %.1f | %.4f | %.4f', ...
                vertices(i,1), vertices(i,2), ...
                vertices(i,1)/imgW, vertices(i,2)/imgH)
            }];
    end
    
    % Convert to table and save
    roiInfoTable = cell2table(roiInfoCell(2:end,:), ...
        'VariableNames', {'Property', 'Value'});
    excelFile = fullfile(folderPath, strcat(animal_name, ' adjustment_parameters.xlsx'));

    % Save adjusted images
    adjusted = hCroppedRGB.CData;
    rgb_out = uint8(adjusted * 255);
    imwrite(rgb_out, fullfile(folderPath, strcat(animal_name,32,'adjusted_RGB.tif')));
    rColor = cat(3, adjusted(:,:,1), zeros(size(adjusted,1), size(adjusted,2), 2));
    gColor = cat(3, zeros(size(adjusted,1), size(adjusted,2)), adjusted(:,:,2), zeros(size(adjusted,1), size(adjusted,2)));
    bColor = cat(3, zeros(size(adjusted,1), size(adjusted,2), 2), adjusted(:,:,3));
    imwrite(uint8(rColor * 255), fullfile(folderPath, strcat(animal_name,32,'adjusted_R.tif')));
    imwrite(uint8(gColor * 255), fullfile(folderPath, strcat(animal_name,32,'adjusted_G.tif')));
    imwrite(uint8(bColor * 255), fullfile(folderPath, strcat(animal_name,32,'adjusted_B.tif')));

    % Save original image with ROI overlay (border only)
    orig = original_rgb;

    % If image is grayscale (1 channel), convert to RGB (3 channels)
    if size(orig,3) == 1
        orig = repmat(orig, [1 1 3]);
    end
    % Create mask
    mask = false(imgH, imgW);
    if strcmp(currentShape, 'rectangle')
        % Rectangle ROI [x, y, width, height]
        pos = roi.Position;

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
        v = roi.Position;
        mask = poly2mask(v(:,1), v(:,2), imgH, imgW);
    end

    overlay = orig;                          
    perim = bwperim(mask, 8);
    
    % Use image size scaled ROI border in saved ROI image
    targetFraction = 0.003;  
    thicknessPx = max(1, round(max(imgH, imgW) * targetFraction));
    perim = imdilate(perim, ones(thicknessPx));  

    % Paint perimeter red by channel editing
    overlay(:,:,1) = max(overlay(:,:,1), perim);
    overlay(:,:,2) = overlay(:,:,2) .* ~perim;
    overlay(:,:,3) = overlay(:,:,3) .* ~perim;

    imwrite(im2uint8(overlay), fullfile(folderPath, strcat(animal_name, ' original_with_ROI.tif')));

    % Get other parameters
    contrast = [sliders(1,1).Value, sliders(2,1).Value, sliders(3,1).Value];
    brightness = [sliders(1,2).Value, sliders(2,2).Value, sliders(3,2).Value];

    % Calculate binary region areas
    areaThreshR = str2double(rAreaBox.String)^2;
    bwR = imbinarize(adjusted(:,:,1));
    cleanR = bwareaopen(bwR, areaThreshR);
    totalR = sum(cleanR(:));
    
    areaThreshG = str2double(gAreaBox.String)^2;
    bwG = imbinarize(adjusted(:,:,2));
    cleanG = bwareaopen(bwG, areaThreshG);
    totalG = sum(cleanG(:));
    
    areaThreshB = str2double(bAreaBox.String)^2;
    bwB = imbinarize(adjusted(:,:,3));
    cleanB = bwareaopen(bwB, areaThreshB);
    totalB = sum(cleanB(:));

    area = [totalR, totalG, totalB];
    filter_size = [str2double(rAreaBox.String), str2double(gAreaBox.String), str2double(bAreaBox.String)];

    % Create corner table (get from coord_boxes)
    x1 = str2double(coord_boxes(1).String);
    y1 = str2double(coord_boxes(2).String);
    x2 = str2double(coord_boxes(3).String);
    y2 = str2double(coord_boxes(4).String);
    T2 = table({'X1';'Y1';'X2';'Y2'}, [x1; y1; x2; y2], ...
              'VariableNames', {'Corner','PixelCoordinate'});

    % Save to Excel file
    excelFile = fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx'));
    
    % Save corner table first
    writetable(T2, excelFile);
    
    % Create and save parameters Excel file
    createParametersFile_helper(folderPath, animal_name, contrast, brightness, ...
        rAreaBox, maxrAreaBox, gAreaBox, maxgAreaBox, bAreaBox, maxbAreaBox, overlapThreshBox);

    % Save R label positions with explanatory note
    if ~isempty(rPositions)
        rNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', '', ''};
        rHeader = {'Label', 'X', 'Y', 'Area', 'MeanIntensity'};
        
        % Ensure rAreas and rPositions have consistent length
        if length(rAreas) ~= size(rPositions, 1)
            rAreas = zeros(size(rPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        if length(rMeans) ~= size(rPositions, 1)
            rMeans = zeros(size(rPositions, 1), 1);
        end
        
        rData = num2cell([(1:size(rPositions,1))', rPositions, rAreas(:), rMeans(:)]);
        rCombined = [rNote; rHeader; rData];
        writecell(rCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'R_Labels');
    end

    % Save G label positions with explanatory note
    if ~isempty(gPositions)
        gNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', '', ''};
        gHeader = {'Label', 'X', 'Y', 'Area', 'MeanIntensity'};
        
        % Ensure gAreas and gPositions have consistent length
        if length(gAreas) ~= size(gPositions, 1)
            gAreas = zeros(size(gPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        gData = num2cell([(1:size(gPositions,1))', gPositions, gAreas(:), gMeans(:)]);
        gCombined = [gNote; gHeader; gData];
        writecell(gCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'G_Labels');
    end

    % Save B label positions with explanatory note
    if ~isempty(bPositions)
        bNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', '', ''};
        bHeader = {'Label', 'X', 'Y', 'Area', 'MeanIntensity'};
        
        % Ensure bAreas and bPositions have consistent length
        if length(bAreas) ~= size(bPositions, 1)
            bAreas = zeros(size(bPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        bData = num2cell([(1:size(bPositions,1))', bPositions, bAreas(:), bMeans(:)]);
        bCombined = [bNote; bHeader; bData];
        writecell(bCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'B_Labels');
    end

    % Save RG overlap label positions with explanatory note
    if ~isempty(rgPositions)
        rgNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', '', ''};
        rgHeader = {'Label', 'X', 'Y', 'Overlap Area', 'MeanIntensity'};
        
        % Ensure rgOverlapAreas and rgPositions have consistent length
        if length(rgOverlapAreas) ~= size(rgPositions, 1)
            rgOverlapAreas = zeros(size(rgPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        rgData = num2cell([(1:size(rgPositions,1))', rgPositions, rgOverlapAreas(:), rgMeans(:)]);
        rgCombined = [rgNote; rgHeader; rgData];
        writecell(rgCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'RG_Labels');
    end

    % Save GB overlap label positions with explanatory note
    if ~isempty(gbPositions)
        gbNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', '', ''};
        gbHeader = {'Label', 'X', 'Y', 'Overlap Area', 'MeanIntensity'};
        
        % Ensure gbOverlapAreas and gbPositions have consistent length
        if length(gbOverlapAreas) ~= size(gbPositions, 1)
            gbOverlapAreas = zeros(size(gbPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        gbData = num2cell([(1:size(gbPositions,1))', gbPositions, gbOverlapAreas(:), gbMeans(:)]);
        gbCombined = [gbNote; gbHeader; gbData];
        writecell(gbCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'GB_Labels');
    end

    % Save RB overlap label positions with explanatory note
    if ~isempty(rbPositions)
        rbNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', '', ''};
        rbHeader = {'Label', 'X', 'Y', 'Overlap Area', 'MeanIntensity'};
        
        % Ensure rbOverlapAreas and rbPositions have consistent length
        if length(rbOverlapAreas) ~= size(rbPositions, 1)
            rbOverlapAreas = zeros(size(rbPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        rbData = num2cell([(1:size(rbPositions,1))', rbPositions, rbOverlapAreas(:), rbMeans(:)]);
        rbCombined = [rbNote; rbHeader; rbData];
        writecell(rbCombined, excelFile, 'Sheet', 'RB_Labels');
    end

    % Save RGB overlap label positions with explanatory note
    if ~isempty(rgbPositions)
        rgbNote = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', '', ''};
        rgbHeader = {'Label', 'X', 'Y', 'Overlap Area', 'MeanIntensity'};
        
        % Ensure rgbOverlapAreas and rgbPositions have consistent length
        if length(rgbOverlapAreas) ~= size(rgbPositions, 1)
            rgbOverlapAreas = zeros(size(rgbPositions, 1), 1); % Fill with 0 if inconsistent
        end
        
        rgbData = num2cell([(1:size(rgbPositions,1))', rgbPositions, rgbOverlapAreas(:), rgbMeans(:)]);
        rgbCombined = [rgbNote; rgbHeader; rgbData];
        writecell(rgbCombined, fullfile(folderPath, strcat(animal_name,32,'adjustment_parameters.xlsx')), 'Sheet', 'RGB_Labels');
    end

    % Save count statistics information
    countsTable = table({'R'; 'G'; 'B'; 'RG'; 'GB'; 'RB'; 'RGB'}, ...
                       [length(rPositions); length(gPositions); length(bPositions); ...
                        length(rgPositions); length(gbPositions); length(rbPositions); length(rgbPositions)], ...
                       'VariableNames', {'Channel', 'Count'});
    writetable(countsTable, excelFile, 'WriteMode', 'Append', 'WriteVariableNames', true);
    writetable(roiInfoTable, excelFile, 'Sheet', 'ROI_Info', 'WriteMode', 'overwritesheet');

    % Display save completion information
    msgbox(sprintf('All data saved successfully to:\n%s', folderPath), 'Save Complete', 'help');
end

% Helper function: Create parameters Excel file
function createParametersFile_helper(folderPath, animal_name, contrast, brightness, ...
    rAreaBox, maxrAreaBox, gAreaBox, maxgAreaBox, bAreaBox, maxbAreaBox, overlapThreshBox)
    try
        % Create parameter file name
        parametersFile = fullfile(folderPath, strcat('saved_parameters.xlsx'));
        
        % Channel labels
        labels = {'Red'; 'Green'; 'Blue'};
        
        % Create Channel-Contrast-Brightness table
        channelTable = table(labels, contrast', brightness', ...
                           'VariableNames', {'Channel', 'Contrast', 'Brightness'});
        
        % Get threshold parameters
        thresholdValues = [
            str2double(rAreaBox.String);      % R_Min
            str2double(maxrAreaBox.String);   % R_Max
            str2double(gAreaBox.String);      % G_Min
            str2double(maxgAreaBox.String);   % G_Max
            str2double(bAreaBox.String);      % B_Min
            str2double(maxbAreaBox.String);   % B_Max
            str2double(overlapThreshBox.String) % Overlap_Max
        ];
        
        thresholdParams = {
            'R_Min'; 'R_Max'; 'G_Min'; 'G_Max'; 
            'B_Min'; 'B_Max'; 'Overlap_Max'
        };
        
        % Create Parameter-Value table
        parameterTable = table(thresholdParams, thresholdValues, ...
                             'VariableNames', {'Parameter', 'Value'});
        
        % Save first table to Sheet1
        writetable(channelTable, parametersFile, 'Sheet', 'Sheet1');
        
        % Append second table to same Sheet (using WriteMode append and explicitly set WriteVariableNames to true)
        writetable(parameterTable, parametersFile, 'Sheet', 'Sheet1', 'WriteMode', 'Append', 'WriteVariableNames', true);
        
    catch ME
        % If parameter file creation fails, show warning but don't interrupt main program
        warning(ME.identifier, '%s', ME.message);
    end
end 
