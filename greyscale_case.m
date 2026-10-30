function greyscale_case(original_gray, animal_name, pxPerUm)
% Grayscale GUI aligned with your RGB app:
% - ROI tools near Original (left); ROI is on axOriginal only
% - Typed Rectangle Coordinates under the ROI shape buttons
% - Big Cropped (right, centered)
% - X1/Y1 (bottom-left) and X2/Y2 (top-right) readouts
% - Contrast/Brightness + Min/Max/Filter under Cropped
% - Vertical labeling controls (manual/auto/undo/clear/remove/add + font size/color)
% - Live total count
% - Ruler (px + um) and scale bar between Original/Cropped
% - Import Params + Save/Reset (top-right)
%
% pxPerUm: image pixels per micrometer (NaN = unknown: pixels only, no
% scale bar). The RGB GUI's "Convert to Gray" passes it in; when it's
% not given, it is asked for after the crop size.

% Add src folder to MATLAB path (for fitUicontrolText when the grayscale case is launched directly)
addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));

if nargin < 2 || isempty(animal_name), animal_name = 'sample'; end

% ---------- Initial crop size ----------
answer = inputdlg({'Crop Width (pixels):','Crop Height (pixels):'}, ...
                  'Crop Window Size', [1 40], {'1061','1061'});
if isempty(answer), return; end
cropSize = [str2double(answer{1}), str2double(answer{2})];

[imgH, imgW] = size(original_gray);
defaultRectPos = [round((imgW-cropSize(1))/2), round((imgH-cropSize(2))/2), cropSize];
rectPos = defaultRectPos;

% Pixels per micrometer; NaN = unknown (GUI stays in pixels, no scale bar)
if nargin < 3
    pxPerUm = conversionFactorUIGenerator();
end

% ---------- State ----------
currentShape = 'rectangle';           % 'rectangle'|'polygon'
roi = [];
adjustedCopy = [];
filteredCopy = [];
% What a click on the crop does (see refreshButtonDownFcn)
manualOn   = false;   % Manual button: clicks place labels (off = clicks do nothing)
removeMode = false;   % Remove box tool
addMode    = false;   % Add box tool
rulerOn    = false;   % ruler armed or measuring: it gets the clicks until it finishes


% Labels / contours kept 1:1 by index
labelHandles   = gobjects(0);
labelPositions = zeros(0,2);
labelCounter   = 0;
contourHandles = gobjects(0);         % line handles (or placeholder for manual)
labelAreas     = [];                  % numeric area per label (NaN for manual)
contourColor = 'r';     % 'r','g','b','y','w','k'
contourWidth = 1;       % positive scalar
showLabels   = true;
showContours = true;
labelMeans = []; 

rulerTool = [];   % src/ruler.m handles, created once rulerBox exists
scaleBarTool = [];   % src/scaleBar.m handles, created once axCropped exists


% ---------- Figure & layout ----------
fig = figure('Name','Grayscale Cell Counter','NumberTitle','off', ...
    'Units','normalized','Position',[0 0 1 1]);

% Default uicontrol font: normalized, i.e. a fraction of each control's
% height, so text scales with the window. fitUicontrolText (called at
% the end of setup) shrinks any text too wide for its control. Pass a
% smaller normalized 'FontSize' to cap one control's size, or
% 'FontUnits','points' before 'FontSize' to opt it out of fitting.
set(fig, 'DefaultUicontrolFontUnits', 'normalized', ...
    'DefaultUicontrolFontSize', 0.6);

% LEFT: Original (ROI lives here)
axOriginal = axes('Parent', fig, 'Position', [0.05 0.63 0.33 0.34]);
imshow(original_gray, 'Parent', axOriginal); title(axOriginal,'Original');

% RIGHT: Cropped (bigger & centered on right half)
axCropped  = axes('Parent', fig, 'Position', [0.48 0.50 0.40 0.45]);
hCropped   = imshow(zeros(cropSize(2), cropSize(1)), 'Parent', axCropped, 'InitialMagnification','fit');
title(axCropped, 'Adjusted (Gray)');

% -------- Scale bar (top of the column between Original & Cropped) --------
% Below the X2/Y2 readouts (bottom 0.945), above Ruler (top 0.815).
% char(181) is the micro sign
uicontrol(fig,'Style','text','String',['Scale (' char(181) 'm):'], ...
    'Units','normalized','Position',[0.43 0.875 0.05 0.025]);
% Bar length in um; editing it redraws the bar (callback set by scaleBar)
scaleBarBox = uicontrol(fig,'Style','edit','String','1', ...
    'Units','normalized','Position',[0.43 0.85 0.05 0.025], ...
    'BackgroundColor',[1 1 1]);
scaleBarTool = scaleBar(axCropped, hCropped, pxPerUm, scaleBarBox);

% -------- Ruler (between Original & Cropped) --------
uicontrol(fig,'Style','pushbutton','String','Ruler', ...
    'Units','normalized','Position',[0.44 0.78 0.03 0.035], ...
    'BackgroundColor',[0.9 0.9 1], 'Callback',@(~,~) startRulerMode());
uicontrol(fig,'Style','pushbutton','String','Clear', ...
    'Units','normalized','Position',[0.44 0.73 0.03 0.035], ...
    'BackgroundColor',[1 0.9 0.9], 'Callback',@(~,~) clearRuler());
% Readouts: image px and um, each box shows its own unit
uicontrol(fig,'Style','text','String','Distance:', ...
    'Units','normalized','Position',[0.43 0.69 0.05 0.025]);
rulerBox = uicontrol(fig,'Style','edit','String','','Enable','inactive', ...
    'Units','normalized','Position',[0.43 0.66 0.05 0.03], 'BackgroundColor',[1 1 1]);
rulerUmBox = uicontrol(fig,'Style','edit','String','','Enable','inactive', ...
    'Units','normalized','Position',[0.43 0.625 0.05 0.03], 'BackgroundColor',[1 1 1]);
rulerTool = ruler(fig, axCropped, hCropped, rulerBox, @rulerDone, rulerUmBox, pxPerUm);

% -------- Save / Reset / Import (top-right) --------
uicontrol(fig,'Style','pushbutton','String','Save All', ...
    'Units','normalized','Position',[0.88 0.93 0.10 0.05], ...
    'BackgroundColor',[0.8 1 0.8], 'Callback',@(~,~) saveAllGrey());
uicontrol(fig,'Style','pushbutton','String','Reset', ...
    'Units','normalized','Position',[0.88 0.87 0.10 0.05], ...
    'BackgroundColor',[1 0.9 0.9], 'Callback',@(~,~) resetAll());
uicontrol(fig,'Style','pushbutton','String','Import Params', ...
    'Units','normalized','Position',[0.88 0.81 0.10 0.05], ...
    'BackgroundColor',[0.9 0.9 1], 'Callback',@(~,~) importParams());

% -------- ROI shape tools (NEXT TO ORIGINAL) --------
shapePanel = uipanel(fig,'Title','ROI Shape','Position',[0.1 0.5 0.20 0.06]);
rectButton = uicontrol(shapePanel,'Style','pushbutton','String','Rectangle','Units','normalized', ...
    'Position',[0 0 0.5 1],'FontWeight','bold','Callback',@(~,~) setShape('rectangle'));
polyButton = uicontrol(shapePanel,'Style','pushbutton','String','Polygon','Units','normalized', ...
    'Position',[0.5 0 0.5 1],'Callback',@(~,~) setShape('polygon'));

% Typed rectangle corners X1 / Y1 / X2 / Y2 (same convention as the
% readouts: original-image pixels, y counted up from the bottom). Sits
% under ROI Shape; setShape shows it only while the shape is 'rectangle'
coordPanel = uipanel(fig,'Title','Rectangle Coordinates','Position',[0.1 0.43 0.20 0.06]);
x1Edit = uicontrol(coordPanel,'Style','edit','String','0','Units','normalized', ...
    'Position',[0 0 0.25 1],'Callback',@(~,~) updateRectangle());
y1Edit = uicontrol(coordPanel,'Style','edit','String','0','Units','normalized', ...
    'Position',[0.25 0 0.25 1],'Callback',@(~,~) updateRectangle());
x2Edit = uicontrol(coordPanel,'Style','edit','String','100','Units','normalized', ...
    'Position',[0.5 0 0.25 1],'Callback',@(~,~) updateRectangle());
y2Edit = uicontrol(coordPanel,'Style','edit','String','100','Units','normalized', ...
    'Position',[0.75 0 0.25 1],'Callback',@(~,~) updateRectangle());

% -------- ROI corner readouts (like RGB app) --------
uicontrol(fig,'Style','text','String','X1','Units','normalized','Position',[0.01 0.61 0.03 0.02]);
x1Box = uicontrol(fig,'Style','text','String','0','Units','normalized','Position',[0.01 0.585 0.05 0.025], 'BackgroundColor',[1 1 1]);
uicontrol(fig,'Style','text','String','Y1','Units','normalized','Position',[0.06 0.61 0.03 0.02]);
y1Box = uicontrol(fig,'Style','text','String','0','Units','normalized','Position',[0.06 0.585 0.05 0.025], 'BackgroundColor',[1 1 1]);

uicontrol(fig,'Style','text','String','X2','Units','normalized','Position',[0.38 0.97 0.03 0.02]);
x2Box = uicontrol(fig,'Style','text','String','0','Units','normalized','Position',[0.38 0.945 0.05 0.025], 'BackgroundColor',[1 1 1]);
uicontrol(fig,'Style','text','String','Y2','Units','normalized','Position',[0.43 0.97 0.03 0.02]);
y2Box = uicontrol(fig,'Style','text','String','0','Units','normalized','Position',[0.43 0.945 0.05 0.025], 'BackgroundColor',[1 1 1]);

% -------- Vertical labeling column (right) --------
labelPanel = uipanel(fig,'Title','Labeling', ...
    'Position',[0.90 0.25 0.09 0.55]);   % lowered so top is at 0.80, below Import Params

% Manual: click to select (clicks on the crop place labels), click
% again to deselect (clicks do nothing), like the RGB GUI's mode buttons
manualBtn = uicontrol(labelPanel,'Style','pushbutton','String','Manual (Off)', ...
    'Units','normalized','Position',[0.10 0.88 0.80 0.08], ...
    'Callback',@(~,~) toggleManual());

% Auto
uicontrol(labelPanel,'Style','pushbutton','String','Auto (dark)', ...
    'Units','normalized','Position',[0.10 0.78 0.80 0.08], ...
    'Callback',@(~,~) autoLabelGrey());

% Undo
uicontrol(labelPanel,'Style','pushbutton','String','Undo', ...
    'Units','normalized','Position',[0.10 0.68 0.35 0.08], ...
    'Callback',@(~,~) undoLabel());

% Clear
uicontrol(labelPanel,'Style','pushbutton','String','Clear', ...
    'Units','normalized','Position',[0.55 0.68 0.35 0.08], ...
    'BackgroundColor',[1 0.9 0.9], 'Callback',@(~,~) clearLabels());

% Remove
removeBtn = uicontrol(labelPanel,'Style','pushbutton','String','Remove (Off)', ...
    'Units','normalized','Position',[0.10 0.58 0.80 0.08], ...
    'BackgroundColor',[1 0.95 0.8], 'Callback',@(~,~) toggleRemoveMode());

% Add
addBtn = uicontrol(labelPanel,'Style','pushbutton','String','Add (Off)', ...
    'Units','normalized','Position',[0.10 0.48 0.80 0.08], ...
    'BackgroundColor',[0.9 1 0.9], 'Callback',@(~,~) toggleAddMode());

% ---- Total Count (moved inside panel) ----
uicontrol(labelPanel,'Style','text','String','Total count:', ...
    'Units','normalized','Position',[0.10 0.40 0.45 0.06], ...
    'HorizontalAlignment','left');
countBox = uicontrol(labelPanel,'Style','text','String','0', ...
    'Units','normalized','Position',[0.55 0.40 0.35 0.06], ...
    'BackgroundColor',[1 1 1]);


uicontrol(labelPanel,'Style','text','String','Contour Color:', ...
    'Units','normalized','Position',[0.10 0.24 0.45 0.06], ...
    'HorizontalAlignment','left');
popupContourColor = uicontrol(labelPanel,'Style','popupmenu', ...
    'String',{'red','green','blue','yellow','white','black'}, ...
    'Units','normalized','Position',[0.55 0.24 0.35 0.06], ...
    'Callback',@(src,~) setContourColor(src));
uicontrol(labelPanel,'Style','text','String','Contour Width:', ...
    'Units','normalized','Position',[0.10 0.16 0.45 0.06], ...
    'HorizontalAlignment','left');
editContourWidth = uicontrol(labelPanel,'Style','edit','String','1', ...
    'Units','normalized','Position',[0.55 0.16 0.35 0.06], ...
    'Callback',@(src,~) setContourWidth(src));



% Font Size
uicontrol(labelPanel,'Style','text','String','Font Size:', ...
    'Units','normalized','Position',[0.10 0.08 0.45 0.06], ...
    'HorizontalAlignment','left');
fontSizeBox = uicontrol(labelPanel,'Style','edit','String','8', ...
    'Units','normalized','Position',[0.55 0.08 0.35 0.06], ...
    'Callback',@(~,~) applyFontSize());

% Font Color
uicontrol(labelPanel,'Style','text','String','Font Color:', ...
    'Units','normalized','Position',[0.10 0.00 0.45 0.06], ...
    'HorizontalAlignment','left');
colorMenu = uicontrol(labelPanel,'Style','popupmenu', ...
    'String',{'red','green','blue','yellow','cyan','magenta','black','white'}, ...
    'Units','normalized','Position',[0.55 0.00 0.35 0.06]);


% Labels visibility toggle
labelsToggleBtn = uicontrol(fig,'Style','pushbutton','String','Labels: On', ...
    'Units','normalized','Position',[0.6 0.40 0.08 0.06], ...
    'Callback',@(src,~) toggleLabelVisibility());

% Contours visibility toggle
contoursToggleBtn = uicontrol(fig,'Style','pushbutton','String','Contours: On', ...
    'Units','normalized','Position',[0.6 0.32 0.08 0.06], ...
    'Callback',@(src,~) toggleContourVisibility());

% -------- Contrast/Brightness + Min/Max/Filter (under Cropped) --------
% Contrast
uicontrol(fig,'Style','text','String','Contrast','Units','normalized', ...
    'Position',[0.48 0.25 0.06 0.03],'HorizontalAlignment','left');
sContrast = uicontrol(fig,'Style','slider','Min',0.1,'Max',3,'Value',1, ...
    'Units','normalized','Position',[0.54 0.255 0.22 0.025], 'Callback',@(~,~) updateImage());
tContrast = uicontrol(fig,'Style','text','String','1.00','Units','normalized', ...
    'Position',[0.77 0.25 0.05 0.03]);

% Brightness
uicontrol(fig,'Style','text','String','Brightness','Units','normalized', ...
    'Position',[0.48 0.21 0.06 0.03],'HorizontalAlignment','left');
sBright = uicontrol(fig,'Style','slider','Min',-0.5,'Max',0.5,'Value',0, ...
    'Units','normalized','Position',[0.54 0.215 0.22 0.025], 'Callback',@(~,~) updateImage());
tBright = uicontrol(fig,'Style','text','String','0.00','Units','normalized', ...
    'Position',[0.77 0.21 0.05 0.03]);

% Min/Max/Filter aligned with sliders
uicontrol(fig,'Style','text','String','Min','Units','normalized', ...
    'Position',[0.83 0.25 0.03 0.03]);
minBox = uicontrol(fig,'Style','edit','String','10','Units','normalized', ...
    'Position',[0.86 0.25 0.04 0.03]);

uicontrol(fig,'Style','text','String','Max','Units','normalized', ...
    'Position',[0.83 0.21 0.03 0.03]);
maxBox = uicontrol(fig,'Style','edit','String','40','Units','normalized', ...
    'Position',[0.86 0.21 0.04 0.03]);

uicontrol(fig,'Style','pushbutton','String','Filter','Units','normalized', ...
    'Position',[0.91 0.2 0.07 0.04], 'Callback',@(~,~) filterGrey());


% Shrink any control text that is too wide; refits on resize
fitUicontrolText(fig);

% ---------- Build ROI and first draw ----------
createROI();
updateImage();

% ==================== Nested helpers ====================

    function setShape(shp)
        currentShape = shp;

        % Selected shape is bold; typed corners only apply to rectangles
        if strcmp(shp, 'rectangle')
            set(rectButton, 'FontWeight', 'bold');
            set(polyButton, 'FontWeight', 'normal');
            set(coordPanel, 'Visible', 'on');
        else
            set(rectButton, 'FontWeight', 'normal');
            set(polyButton, 'FontWeight', 'bold');
            set(coordPanel, 'Visible', 'off');
        end

        createROI();
        moveROIAction();   % new crop
    end

    % The crop changed (ROI dragged, corners typed, shape switched):
    % refresh (which also clears the labels) and drop the ruler's line,
    % which was measured on the old crop
    function moveROIAction()
        updateImage();
        rulerTool.clear();
    end

    function createROI()
        if ~isempty(roi) && isvalid(roi)
            delete(roi);
            % If that was a polygon still being drawn, its draw() is waiting
            % on the figure; deleting the ROI alone doesn't end the wait
            uiresume(fig);
        end
        % ROI is ALWAYS on the ORIGINAL axis (left)
        switch currentShape
            case 'rectangle'
                roi = drawrectangle(axOriginal,'Position',rectPos,'Color','r','InteractionsAllowed','all');
            case 'polygon'
                title(axOriginal,'Click to draw polygon (double-click to finish)','Color','r');
                % Store the ROI in roi BEFORE the blocking draw(), so picking
                % another shape mid-draw can delete it and stop drawing
                poly = images.roi.Polygon(axOriginal,'Color','r','InteractionsAllowed','all','DrawingArea','unlimited');
                roi = poly;
                draw(poly);
                title(axOriginal,'Original','Color','k');
                % Cancelled: the newer createROI already made the ROI + listener
                if ~isvalid(poly), return; end
        end
        addlistener(roi,'ROIMoved',@(~,~) moveROIAction());
    end

    function updateImage()
        if ~isempty(labelHandles) || ~isempty(contourHandles)
            clearLabels();  % clears labels + contours + areas + count
        end
        % Crop by ROI; clamp for indexing but never move ROI itself
        switch currentShape
            case 'rectangle'
                pos = round(roi.Position);
                pos(1:2) = max(pos(1:2), [1,1]);
                pos(3:4) = min(pos(3:4), [imgW, imgH] - pos(1:2));
                cropped = imcrop(original_gray, pos);

                % Readouts: X1/Y1 (bottom-left), X2/Y2 (top-right)
                X1 = pos(1);
                Y2 = imgH - pos(2);
                X2 = pos(1) + pos(3);
                Y1 = imgH - (pos(2) + pos(4));
                x1Box.String = num2str(X1); y1Box.String = num2str(Y1);
                x2Box.String = num2str(X2); y2Box.String = num2str(Y2);

            case 'polygon'
                vertices = roi.Position;
                mask = poly2mask(vertices(:,1), vertices(:,2), imgH, imgW);
                minX = floor(min(vertices(:,1))); maxX = ceil(max(vertices(:,1)));
                minY = floor(min(vertices(:,2))); maxY = ceil(max(vertices(:,2)));
                bbox = [minX, minY, maxX-minX, maxY-minY];
                bbox = max(bbox, [1 1 1 1]);
                bbox(3) = min(bbox(3), imgW - bbox(1));
                bbox(4) = min(bbox(4), imgH - bbox(2));
                sub = original_gray(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3));
                subMask = mask(bbox(2):bbox(2)+bbox(4), bbox(1):bbox(1)+bbox(3));
                cropped = sub; cropped(~subMask) = 0;

                % Show bbox corners (consistent with your readouts)
                X1 = bbox(1);
                Y2 = imgH - bbox(2);
                X2 = bbox(1) + bbox(3);
                Y1 = imgH - (bbox(2) + bbox(4));
                x1Box.String = num2str(X1); y1Box.String = num2str(Y1);
                x2Box.String = num2str(X2); y2Box.String = num2str(Y2);
        end

        % Contrast / Brightness
        c = sContrast.Value; b = sBright.Value;
        tContrast.String = sprintf('%.2f', c);
        tBright.String   = sprintf('%.2f', b);
        adjusted = c * cropped + b;
        adjusted = min(max(adjusted,0),1);

        adjustedCopy = adjusted;
        filteredCopy = adjusted;
        hCropped.CData = adjustedCopy;
        axis image; axis tight;
        refreshButtonDownFcn();
        countBox.String = num2str(numel(labelHandles)); % live count

        % Keep the Rectangle Coordinates boxes showing the ROI's real corners
        syncBoxesToROI();

        % Re-place the scale bar for the new crop size
        if ~isempty(scaleBarTool), scaleBarTool.update(); end
    end

    % Callback for the Rectangle Coordinates boxes: read all four and apply
    function updateRectangle()
        if ~strcmp(currentShape, 'rectangle'), return; end
        v = str2double({x1Edit.String, y1Edit.String, x2Edit.String, y2Edit.String});
        drawRectangleFromCoords(v(1), v(2), v(3), v(4));
    end

    % Move the ROI to the given bottom-left (x1,y1) and top-right (x2,y2)
    % corners. Same convention as the X1/Y1/X2/Y2 readouts: pixels of the
    % original image, y counted up from the bottom.
    function drawRectangleFromCoords(x1, y1, x2, y2)
        % Not a number (e.g. empty or text): put the boxes back
        if any(isnan([x1, y1, x2, y2]))
            syncBoxesToROI();
            return;
        end

        % Order, clamp and convert to [left top width height]
        % (src/cornersToRectPos.m, shared with main_modified_by_Aditya.m)
        pos = cornersToRectPos(x1, y1, x2, y2, imgW, imgH);
        if isempty(pos)
            % Entirely outside the image, or no area left after clamping
            warndlg('The rectangle is outside the image or has zero size.', 'Invalid Rectangle');
            syncBoxesToROI();
            return;
        end
        roi.Position = pos;
        rectPos = pos;   % keep it if the shape is switched away and back

        % Setting Position in code doesn't fire ROIMoved, so refresh by hand
        % (this also writes the clamped values back into the boxes)
        moveROIAction();
    end

    % Show the ROI's current corners in the Rectangle Coordinates boxes
    function syncBoxesToROI()
        x1Edit.String = x1Box.String;
        y1Edit.String = y1Box.String;
        x2Edit.String = x2Box.String;
        y2Edit.String = y2Box.String;
    end

%% What a click on the crop does: one place decides
% Priority: ruler (until its measurement finishes) > Remove/Add box >
% manual labelling. manualLabel itself does nothing while Manual is
% off, so the image always has a click handler.
function refreshButtonDownFcn()
    if rulerOn
        set(hCropped, 'ButtonDownFcn', rulerTool.click);
    elseif removeMode || addMode
        set(hCropped, 'ButtonDownFcn', @boxClick);
    else
        set(hCropped, 'ButtonDownFcn', @manualLabel);
    end
end

% Remove/Add box: the press starts a rubber band, the release ends it.
% Nothing is left waiting between boxes, so turning the tool off or
% switching tools just changes what the next press does.
function boxClick(~, ~)
    p1 = get(axCropped, 'CurrentPoint');   % where the button went down
    rbbox;                                 % rubber band until the button is released
    p2 = get(axCropped, 'CurrentPoint');   % where it was released
    p1 = p1(1,1:2); p2 = p2(1,1:2);
    boxPos = [min(p1, p2), abs(p2 - p1)];  % [x y w h] in crop (image) pixels
    if any(boxPos(3:4) < 1), return; end   % a click, not a drag

    if removeMode
        rectangleDone(boxPos);
    elseif addMode
        addRectangleDone(boxPos);
    end
end

% Delete the labels inside a Remove box (boxPos = [x y w h])
function rectangleDone(boxPos)
    % Inclusive bounds
    imgHc = size(adjustedCopy,1);
    imgWc = size(adjustedCopy,2);
    x1 = max(1, floor(boxPos(1))); 
    y1 = max(1, floor(boxPos(2)));
    x2 = min(imgWc, floor(boxPos(1)+boxPos(3)-1));
    y2 = min(imgHc, floor(boxPos(2)+boxPos(4)-1));
    if x2 < x1 || y2 < y1, return; end

    % Find labels inside the box by their positions
    inBox = false(1, numel(labelHandles));
    for i = 1:numel(labelHandles)
        p = labelPositions(i,:);
        if ~isempty(p) && all(isfinite(p))
            inBox(i) = (p(1) >= x1 && p(1) <= x2 && p(2) >= y1 && p(2) <= y2);
        end
    end

    % Delete those labels + their contours/areas
    deleteByIndices(find(inBox));
end


    function manualLabel(~,~)
        if ~manualOn, return; end   % Manual not selected: clicks don't label
        pt = get(axCropped,'CurrentPoint'); pt = pt(1,1:2);
        if any(isnan(pt)), return; end
        labelCounter = labelCounter + 1;
        fs = str2double(fontSizeBox.String);
        if isnan(fs) || fs <= 0, fs = 8; fontSizeBox.String = '8'; end
        colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
        col = colors{colorMenu.Value};

        h = text(axCropped, pt(1), pt(2), num2str(labelCounter), ...
            'Color', col, 'FontSize', fs, 'FontWeight','bold', ...
            'HorizontalAlignment','center','Clipping','on', ...
            'PickableParts','none');   % clicks pass through to the image
        labelHandles(end+1) = h;
        labelPositions(end+1,:) = pt;
        contourHandles(end+1) = gobjects(1);   % placeholder (no contour for manual label)
        labelAreas(end+1)     = NaN;           % unknown area for manual label
        labelMeans(end+1) = NaN;

        countBox.String = num2str(numel(labelHandles));
    end

    function applyFontSize()
        newSize = str2double(fontSizeBox.String);
        if isnan(newSize) || newSize <= 0
            newSize = 8; fontSizeBox.String = '8';
        end
        for i = 1:numel(labelHandles)
            if isgraphics(labelHandles(i))
                set(labelHandles(i),'FontSize', newSize);
            end
        end
    end

    function undoLabel()
    if ~isempty(labelHandles)
        deleteByIndices(numel(labelHandles));
    end
    end

% Add box: label the largest dark object inside it (boxPos = [x y w h] in
% CROPPED coords). The object finding is src/regionInBox.m, shared with
% the RGB GUI's Add tool (which looks for bright objects instead).
function addRectangleDone(boxPos)
    region = regionInBox(adjustedCopy, adjustedCopy, boxPos, true);
    if isempty(region), return; end   % box outside the crop, or no object in it

    % Style
    fs = str2double(fontSizeBox.String);
    if isnan(fs) || fs <= 0, fs = 8; fontSizeBox.String = '8'; end
    colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
    col = colors{colorMenu.Value};

    % PickableParts none: clicks and box drags that start on a label still
    % reach the image
    hold(axCropped,'on');

    % Draw the actual contour of the binarized object
    hC = gobjects(1); % Initialize
    if ~isempty(region.boundary)
        hC = plot(axCropped, region.boundary(:,1), region.boundary(:,2), ...
            'LineWidth', contourWidth, 'Color', contourColor, 'PickableParts', 'none');
    end

    % Place label at the centroid
    labelCounter = labelCounter + 1;
    hT = text(axCropped, region.centroid(1), region.centroid(2), num2str(labelCounter), ...
        'Color', col, 'FontSize', fs, 'FontWeight','bold', ...
        'HorizontalAlignment','center','Clipping','on', 'PickableParts','none');

    hold(axCropped,'off');
    drawnow;   % ensure immediate render

    % Track 1:1
    labelHandles(end+1)     = hT;
    labelPositions(end+1,:) = region.centroid;
    contourHandles(end+1)   = hC;
    labelAreas(end+1) = region.area;
    labelMeans(end+1) = region.meanI;

    % UI
    countBox.String = num2str(numel(labelHandles));
end

    function clearLabels()
        % Delete label texts
        if ~isempty(labelHandles)
            delete(labelHandles(isgraphics(labelHandles)));
        end
        labelHandles   = gobjects(0);
        labelPositions = zeros(0,2);
        labelCounter   = 0;
    
        % Delete contours
        if ~isempty(contourHandles)
            delete(contourHandles(isgraphics(contourHandles)));
        end
        contourHandles = gobjects(0);
        labelAreas     = [];
        labelMeans = [];

        % Update UI
        countBox.String = '0';
    end


    % Manual button: select / deselect click-to-label. manualLabel checks
    % manualOn itself, so the click handler doesn't need to change
    function toggleManual()
        manualOn = ~manualOn;
        if manualOn
            manualBtn.String = 'Manual (On)';
            manualBtn.FontWeight = 'bold';
        else
            manualBtn.String = 'Manual (Off)';
            manualBtn.FontWeight = 'normal';
        end
    end

    % Remove / Add box tools: only one at a time. While one is on, a drag
    % on the crop draws its box (boxClick); Manual stays as selected
    function toggleRemoveMode()
        removeMode = ~removeMode;
        if removeMode
            if addMode, toggleAddMode(); end  % only one box tool at a time
            removeBtn.String = 'Remove (On)';
            set(fig,'Pointer','crosshair');
        else
            removeBtn.String = 'Remove (Off)';
            set(fig,'Pointer','arrow');
        end
        refreshButtonDownFcn();
    end

    function toggleAddMode()
        addMode = ~addMode;
        if addMode
            if removeMode, toggleRemoveMode(); end  % only one box tool at a time
            addBtn.String = 'Add (On)';
            set(fig,'Pointer','crosshair');
        else
            addBtn.String = 'Add (Off)';
            set(fig,'Pointer','arrow');
        end
        refreshButtonDownFcn();
    end

    % Ruler logic lives in src/ruler.m (shared with main_modified_by_Aditya.m)
    function startRulerMode()
        rulerTool.start();   % sets the image's click to the ruler
        % Set the flag AFTER start(): start() clears a ruler that's already
        % armed, which runs rulerDone and would reset it
        rulerOn = true;
    end

    function clearRuler()
        rulerTool.clear();
    end

    % Called by the ruler when a measurement finishes or is cleared: give
    % the clicks back to Remove/Add or manual labelling
    function rulerDone()
        rulerOn = false;
        refreshButtonDownFcn();
    end

    function filterGrey()
        % Use the SAME min/max side-length thresholds you already have
        amin = str2double(minBox.String);
        amax = str2double(maxBox.String);
        if isnan(amin), amin = 10; minBox.String = '10'; end
        if isnan(amax), amax = 40; maxBox.String = '40'; end

        % --- ORIGINAL ALGO, single-channel version ---
        % Global Otsu threshold (like your RGB code) + INVERT so dark cells -> 1
        bw = ~imbinarize(adjustedCopy);

        % Gate on bounding-box width & height within [amin, amax]
        stats = regionprops(bw, 'BoundingBox', 'PixelIdxList');
        valid = false(size(bw));
        for k = 1:numel(stats)
            bb = stats(k).BoundingBox;  % [x y w h]
            w = bb(3); h = bb(4);
            if (w >= amin && h >= amin) && (w <= amax && h <= amax)
                valid(stats(k).PixelIdxList) = true;
            end
        end

        % Mask intensity image like you do per-channel in RGB
        filteredCopy = adjustedCopy;
        filteredCopy(~valid) = 1;

        % Update display
        hCropped.CData = filteredCopy;
    end


function autoLabelGrey()
    % SAME thresholds as your original min/max “edge-length” boxes
    amin = str2double(minBox.String);
    amax = str2double(maxBox.String);
    if isnan(amin), amin = 10; minBox.String = '10'; end
    if isnan(amax), amax = 40; maxBox.String = '40'; end

    % Clear existing overlays first
    clearLabels();

    % --- Segment dark cells ---
    % Global Otsu + INVERT so dark cells are foreground
    bw = ~imbinarize(adjustedCopy);

    % Label components
    [L, num] = bwlabel(bw);
    stats = regionprops(L, 'BoundingBox','Centroid','Area','PixelIdxList');

    % Label style
    fs = str2double(fontSizeBox.String);
    if isnan(fs) || fs <= 0, fs = 8; fontSizeBox.String = '8'; end
    colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
    col = colors{colorMenu.Value};

    hold(axCropped,'on');  % we’ll add text + contours

    for k = 1:num
        bb = stats(k).BoundingBox; w = bb(3); h = bb(4);
        % Gate by bbox width/height (your existing logic)
        if (w >= amin && h >= amin) && (w <= amax && h <= amax)
            % Centroid for label position
            c = stats(k).Centroid;

            % ---- TRUE AREA ----
            A = stats(k).Area;  % connected-component pixel count
            mask_k = (L == k);  % component mask (same size as adjustedCopy)
            meanI  = mean(adjustedCopy(mask_k));

            % ---- BOUNDARY (contour) for this CC ----
            % Extract binary mask of just this component
            mask_k = (L == k);
            % Get boundary as a cell array of coordinates
            B = bwboundaries(mask_k, 'noholes');
            if ~isempty(B)
                xy = B{1};    % Nx2 [row, col]
                % Draw as a line in axes coordinate (x=columns, y=rows);
                % PickableParts none so clicks pass through to the image
                hC = plot(axCropped, xy(:,2), xy(:,1), 'LineWidth', contourWidth, 'Color',contourColor, ...
                    'PickableParts','none');
              
            else
                hC = gobjects(1); % fallback
            end

            % ---- Place the label text ----
            labelCounter = labelCounter + 1;
            hT = text(axCropped, c(1), c(2), num2str(labelCounter), ...
                'Color', col, 'FontSize', fs, 'FontWeight', 'bold', ...
                'HorizontalAlignment','center','Clipping','on', 'PickableParts','none');

            % ---- Keep everything aligned ----
            labelHandles(end+1)    = hT;                %#ok<AGROW>
            contourHandles(end+1)  = hC;                %#ok<AGROW>
            labelPositions(end+1,:)= c;                 %#ok<AGROW>
            
            labelAreas(end+1) = A;            %#ok<AGROW>
            labelMeans(end+1) = meanI;        %#ok<AGROW>

        end
    end

    hold(axCropped,'off');

    % Update total count
    countBox.String = num2str(numel(labelHandles));
end


   function saveAllGrey()

    folderPath = uigetdir('', 'Select Save Directory'); 
    if folderPath==0, return; end
    pngOverlay = fullfile(folderPath, sprintf('%s_overlay.png', animal_name));
        
        % Preferred: high-quality export of the current axis
        try
            exportgraphics(axCropped, pngOverlay, 'Resolution', 300);
        catch
            % Fallback for older MATLAB: use getframe
            fr = getframe(axCropped);
            imwrite(fr.cdata, pngOverlay);
        end
    % Images
    % Why export two and not just one?
    imwrite(uint8(adjustedCopy*255), fullfile(folderPath, sprintf('%s_adjusted_gray.tif', animal_name)));
    imwrite(uint8(filteredCopy*255), fullfile(folderPath, sprintf('%s_filtered_gray.tif', animal_name)));

    % Original with the ROI outlined in red (src/roiOverlay.m, shared with
    % the RGB GUI's "original_with_ROI")
    overlay = roiOverlay(original_gray, currentShape, roi.Position);
    imwrite(im2uint8(overlay), fullfile(folderPath, sprintf('%s_original_with_ROI.tif', animal_name)));
    
    % Labels: note, header (Label, X, Y, Area, MeanIntensity) and one row
    % per label. With a scale, an um^2 column goes next to the pixel area
    % (src/labelSheetRows.m, shared with the RGB save)
    if ~isempty(labelPositions)
        out = labelSheetRows(labelPositions, labelAreas, labelMeans, 'Area', pxPerUm);
        writecell(out, fullfile(folderPath, sprintf('%s_adjustment_parameters.xlsx', animal_name)), ...
                  'Sheet','Gray_Labels');
    end
    % Params
    T = table(sContrast.Value, sBright.Value, ...
              str2double(minBox.String), str2double(maxBox.String), ...
              'VariableNames', {'Contrast','Brightness','MinBBox','MaxBBox'});
    writetable(T, fullfile(folderPath, sprintf('%s_adjustment_parameters.xlsx', animal_name)), ...
        'Sheet','Gray_Params','WriteMode','overwritesheet');

    % ROI info
    if strcmp(currentShape,'rectangle')
        pos = roi.Position;
        verts = [pos(1),pos(2); pos(1)+pos(3),pos(2); pos(1)+pos(3),pos(2)+pos(4); pos(1),pos(2)+pos(4)];
    else
        verts = roi.Position;
    end
    roiCell = {'ROI_Type', currentShape};
    % With a scale, record it: the label sheet's um^2 areas were made with it
    if isscalar(pxPerUm) && isfinite(pxPerUm) && pxPerUm > 0
        roiCell = [roiCell; {'Pixels_per_um', pxPerUm}];
    end
    roiCell = [roiCell;
               {'Vertex_Count', size(verts,1)};
               {' ',' '};
               {'Vertex_Coordinates','X | Y | X_Norm | Y_Norm'}];
    for i = 1:size(verts,1)
        roiCell(end+1,:) = {sprintf('Vertex%d',i), ...
            sprintf('%.1f | %.1f | %.4f | %.4f', verts(i,1),verts(i,2), verts(i,1)/imgW, verts(i,2)/imgH)}; %#ok<AGROW>
    end
    writecell(roiCell, fullfile(folderPath, sprintf('%s_adjustment_parameters.xlsx', animal_name)), 'Sheet','ROI_Info');

    msgbox(['Saved to:' char(10) folderPath], 'Save Complete','help');
end


    function resetAll()
        sContrast.Value = 1; tContrast.String = '1.00';
        sBright.Value   = 0; tBright.String   = '0.00';
        minBox.String = '10'; maxBox.String = '40';
        fontSizeBox.String = '8'; colorMenu.Value = 4; % yellow
        clearLabels();
        if strcmp(currentShape,'rectangle')
            roi.Position = defaultRectPos;
        else
            x = defaultRectPos(1); y = defaultRectPos(2);
            w = defaultRectPos(3); h = defaultRectPos(4);
            roi.Position = [x,y; x+w,y; x+w,y+h; x,y+h];
        end
        % Box tools off (Manual stays as selected)
        if removeMode, toggleRemoveMode(); end
        if addMode, toggleAddMode(); end
        updateImage();
        rulerTool.clear();   % the crop moved back to the default
    end

    function importParams()
        [file, path] = uigetfile({'*.xlsx'}, 'Select grayscale parameter file');
        if isequal(file,0), return; end
        fname = fullfile(path,file);
        try
            T = readtable(fname, 'Sheet', 'Gray_Params');
            if all(ismember({'Contrast','Brightness','MinBBox','MaxBBox'}, T.Properties.VariableNames))
                sContrast.Value = T.Contrast(1);  tContrast.String = sprintf('%.2f', sContrast.Value);
                sBright.Value   = T.Brightness(1); tBright.String = sprintf('%.2f', sBright.Value);
                minBox.String = num2str(T.MinBBox(1)); maxBox.String = num2str(T.MaxBBox(1));
                updateImage();
                msgbox('Parameters imported.', 'Success');
            else
                msgbox('Gray_Params sheet missing required columns.','Error','error');
            end
        catch ME
            warning(ME.identifier, '%s', ME.message);
            msgbox('Failed to import parameters.','Error','error');
        end
    end

    function deleteByIndices(idx)
        if isempty(idx), return; end
        idx = idx(idx>=1 & idx<=numel(labelHandles));   % clamp
    
        % delete graphics if they exist
        for k = idx(:).'
            if k <= numel(labelHandles) && isgraphics(labelHandles(k)), delete(labelHandles(k)); end
            if k <= numel(contourHandles) && isgraphics(contourHandles(k)), delete(contourHandles(k)); end
        end
    
        % remove entries from arrays (same indices)
        keep = true(1, numel(labelHandles));
        keep(idx) = false;
    
        labelHandles   = labelHandles(keep);
        labelPositions = labelPositions(keep,:);
        if ~isempty(contourHandles), contourHandles = contourHandles(keep); end
        if ~isempty(labelAreas),     labelAreas     = labelAreas(keep);     end
        if ~isempty(labelMeans),   labelMeans   = labelMeans(keep);   end

    
        % renumber remaining labels
        for i = 1:numel(labelHandles)
            if isgraphics(labelHandles(i))
                set(labelHandles(i), 'String', num2str(i));
            end
        end
        labelCounter = numel(labelHandles);
        countBox.String = num2str(labelCounter);
    end
   
    
    function setContourColor(src)
        colors = {'r','g','b','y','w','k'};
        contourColor = colors{get(src,'Value')}; % get(...) is fine too
    end
    
    function setContourWidth(src)
        w = str2double(get(src,'String'));
        if isnan(w) || w <= 0, w = 1; end
        contourWidth = w;
    end
    function toggleLabelVisibility()
        showLabels = ~showLabels;
        if showLabels
            set(labelsToggleBtn,'String','Labels: On');
            if ~isempty(labelHandles)
                set(labelHandles(isgraphics(labelHandles)),'Visible','on');
            end
        else
            set(labelsToggleBtn,'String','Labels: Off');
            if ~isempty(labelHandles)
                set(labelHandles(isgraphics(labelHandles)),'Visible','off');
            end
        end
    end
    
    function toggleContourVisibility()
        showContours = ~showContours;
        if showContours
            set(contoursToggleBtn,'String','Contours: On');
            if ~isempty(contourHandles)
                set(contourHandles(isgraphics(contourHandles)),'Visible','on');
            end
        else
            set(contoursToggleBtn,'String','Contours: Off');
            if ~isempty(contourHandles)
                set(contourHandles(isgraphics(contourHandles)),'Visible','off');
            end
        end
    end


end
