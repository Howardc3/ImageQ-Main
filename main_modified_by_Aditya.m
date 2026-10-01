function main_modified_by_Aditya(openDir, animal_name)
    % Add src folder to MATLAB path
    addpath(fullfile(fileparts(mfilename('fullpath')), 'src'));
    
    adjustedCopy = [];  % this will store the latest unfiltered adjusted image
    filteredCopy = []; 
    channelActive = [true true true];  % [R, G, B] initially all ON
    removeMode = false;  % Initially OFF
    rectHandle = [];
    modeButtons = struct();  % 🛠 now officially exists
    currentShape ='rectangle'; % Add shape state variable
    roi = []; % ROI object
    rulerLine = [];
    rulerPoints = [];

    % Handle missing animal_name argument
    if nargin < 2 || isempty(animal_name)
        animal_name = 'sample';  % Default animal name
    end

    % Optional directory to start in kk
    if nargin < 1 || ~isfolder(openDir)
        [file, path] = uigetfile({'*.tif;*.png;*.jpg'}, 'Select Or iginal Image');
    else
        [file, path] = uigetfile({'*.tif;*.png;*.jpg'}, 'Select Original Image', openDir);
    end
    if isequal(file, 0), return; end
    original_img = imread(fullfile(path, file));
    if ndims(original_img) == 2 || size(original_img,3) == 1
        % Grayscale path
        original_gray = im2double(original_img);
        greyscale_case(original_gray, animal_name);   % >>> NEW <<<
        return;
    else
        original_rgb = im2double(original_img);
    end

    answer = inputdlg({'Crop Width (pixels):','Crop Height (pixels):'}, ...
                      'Crop Window Size', [1 40], {'1061','1061'});
    if isempty(answer), return; end
    cropSize = [str2double(answer{1}), str2double(answer{2})];

    [imgH, imgW, ~] = size(original_rgb);
    defaultRectPos = [round((imgW-cropSize(1))/2), round((imgH-cropSize(2))/2), cropSize];
    rectPos = defaultRectPos;


    fig = figure('Name','Interactive Crop Adjuster','NumberTitle','off', ...
        'Units','normalized','WindowState', 'maximized');
    
    % Default uicontrol font: normalized, i.e. a fraction of each control's
    % height, so text scales with the window. fitUicontrolText (called at
    % the end of setup) shrinks any text too wide for its control. Pass a
    % smaller normalized 'FontSize' to cap one control's size, or
    % 'FontUnits','points' before 'FontSize' to opt it out of fitting.
    set(fig, 'DefaultUicontrolFontUnits', 'normalized', ...
        'DefaultUicontrolFontSize', 0.6);
    
    % uicontrol(fig,'Style','pushbutton','String','Convert to Gray','Units','normalized', ...
    % 'Position',[0.025 0.8 0.08 0.05], ...   % slightly bigger
    % 'FontWeight','bold', ...
    % 'FontSize',12, ...
    % 'ForegroundColor',[0 0 0], ...          % black text
    % 'BackgroundColor',[0.7 0.7 0.7], ...      
    % 'Callback',@(src,evt) convertToGray());

    uicontrol(fig,'Style','pushbutton','String','Convert to Gray','Units','normalized', ...
        'Position',[0.025 0.8 0.08 0.05], ...   % slightly bigger
        'FontWeight','bold', ...
        'ForegroundColor',[0 0 0], ...          % black text
        'BackgroundColor',[0.7 0.7 0.7], ...      
        'Callback',@(src,evt) convertToGray());

    


    %% Add shape selection buttons
    shapePanel = uipanel(fig, 'Title', 'ROI Shape', 'Position', [0.175 0.55 0.15 0.04]);
    rectButton = uicontrol(shapePanel, 'Style', 'pushbutton', 'String', 'Rectangle', ...
        'Units','normalized', 'Position', [0 0 0.5 1], ...
        'FontWeight', 'bold', 'Callback', @(~,~) setShape('rectangle'));
    polyButton = uicontrol(shapePanel, 'Style', 'pushbutton', 'String', 'Polygon', ...
        'Units','normalized', 'Position', [0.5 0 0.5 1], ...
        'FontWeight', 'normal', 'Callback', @(~,~) setShape('polygon'));



%% Create ROI function
function createROI()
    if ~isempty(roi) && isvalid(roi)
        delete(roi);
    end
    
    switch currentShape
        case 'rectangle'
            roi = drawrectangle(axOriginal, 'Position', rectPos, 'Color', 'r', 'InteractionsAllowed', 'all');
        case 'polygon'
            % Prompt user to click on image to place polygon vertices
            title(axOriginal, 'Click on the image to place the polygon vertices', 'Color', 'r');
            
            % Use drawpolygon to let user freely draw polygon
            roi = drawpolygon(axOriginal, 'Color', 'r', 'InteractionsAllowed', 'all', 'DrawingArea', 'unlimited');
            
            % Remove prompt
            title(axOriginal, '');
    end
    addlistener(roi, 'ROIMoved', @(src, evt) moveROIAction());
end

%% Shape operation functions (simplified)
function moveROIAction()
    updateImage();
    clearAllLabels(); 
end

function setShape(shape)
    currentShape = shape;
    
    % Update button style: selected is bold, unselected is normal
    if strcmp(shape, 'rectangle')
        set(rectButton, 'FontWeight', 'bold');
        set(polyButton, 'FontWeight', 'normal');
    else
        set(rectButton, 'FontWeight', 'normal');
        set(polyButton, 'FontWeight', 'bold');
    end
    
    createROI();
    updateImage();
end

uicontrol(fig, 'Style', 'text', 'String', 'Distance (px):', ...
    'Units', 'normalized', 'Position', [0.46, 0.76, 0.05, 0.025]);

rulerDistanceBox = uicontrol(fig, 'Style', 'edit', ...
    'String', '', 'Enable', 'inactive', ...
    'Units', 'normalized', 'Position', [0.46, 0.72, 0.041, 0.025], ...
    'BackgroundColor', [1 1 1]);

uicontrol(fig, 'Style', 'pushbutton', 'String', 'Ruler', ...
    'Units', 'normalized', 'Position', [0.46, 0.84, 0.041, 0.025], ...
    'BackgroundColor', [0.9 0.9 1], ...
    'Callback', @(~,~) startRulerMode());

uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear Ruler', ...
    'Units', 'normalized', 'Position', [0.46, 0.80, 0.041, 0.025], ...
    'BackgroundColor', [1 0.9 0.9], ...
    'Callback', @(~,~) clearRuler());

    %% Axes
    % Leave axOriginal alone, so ROI dragging works
    axOriginal = axes('Parent', fig, 'Position', [0.05 0.6 0.4 0.35]);
    imshow(original_rgb, 'Parent', axOriginal);
    title('Original Image');
    
    % Enable zoom/pan only in axCropped for navigation and labeling
    axCropped = axes('Parent', fig, 'Position', [0.5 0.6 0.25 0.35]);
    hCroppedRGB = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axCropped, 'InitialMagnification', 'fit');
    title('Adjusted RGB Crop');


    axR = axes('Parent', fig, 'Position', [0.05 0.25 0.25 0.25]);
    hR = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axR, 'InitialMagnification', 'fit'); title(axR, 'Red');
    axis(axR, 'image');
    axG = axes('Parent', fig, 'Position', [0.375 0.25 0.25 0.25]);
    hG = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axG, 'InitialMagnification', 'fit'); title(axG, 'Green');
    axis(axG, 'image');
    axB = axes('Parent', fig, 'Position', [0.7 0.25 0.25 0.25]);
    hB = imshow(zeros(cropSize(2), cropSize(1), 3), 'Parent', axB, 'InitialMagnification', 'fit'); title(axB, 'Blue');
    axis(axB, 'image');

    %% Draggable ROI
    roi = drawrectangle(axOriginal, 'Position', rectPos, 'Color', 'r', 'InteractionsAllowed', 'all');
    addlistener(roi, 'ROIMoved', @(src, evt) moveROIAction());

    %% Sliders and labels
    labels = {'Red','Green','Blue'};
    sliders = gobjects(3,2);
    val_labels = gobjects(3,2);
    initVals = [1, 0; 1, 0; 1, 0];

    for i = 1:3
        baseX = 0.05 + (i-1)*0.325;
        sliders(i,1) = uicontrol(fig, 'Style', 'slider', 'Min', 0.1, 'Max', 3, 'Value', initVals(i,1), ...
            'SliderStep', [0.01 0.1], 'Units','normalized', 'Position', [baseX, 0.18, 0.25, 0.025], 'Callback', @(src,~) updateImage());
        uicontrol(fig, 'Style', 'text', 'String', [labels{i} ' Contrast'], 'Units','normalized', ...
            'Position', [baseX, 0.21, 0.25, 0.02]);
        val_labels(i,1) = uicontrol(fig, 'Style', 'text', 'String', '1.00', 'Units','normalized', ...
            'Position', [baseX+0.25, 0.18, 0.05, 0.025]);

        sliders(i,2) = uicontrol(fig, 'Style', 'slider', 'Min', -0.5, 'Max', 0.5, 'Value', initVals(i,2), ...
            'SliderStep', [0.01 0.1], 'Units','normalized', 'Position', [baseX, 0.13, 0.25, 0.025], 'Callback', @(src,~) updateImage());
        uicontrol(fig, 'Style', 'text', 'String', [labels{i} ' Brightness'], 'Units','normalized', ...
            'Position', [baseX, 0.1, 0.25, 0.02]);
        val_labels(i,2) = uicontrol(fig, 'Style', 'text', 'String', '0.00', 'Units','normalized', ...
            'Position', [baseX+0.25, 0.12, 0.05, 0.025]);
    end

    %% Coordinate display boxes near original image corners
    coord_labels = {'X1','Y1','X2','Y2'};
    coord_boxes = gobjects(1,4);
    % X1, Y1 at bottom-left of original image
    coord_boxes(1) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.01, 0.58, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'X1', 'Units','normalized', 'Position', [0.01, 0.6, 0.05, 0.02]);
    coord_boxes(2) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.06, 0.58, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'Y1', 'Units','normalized', 'Position', [0.06, 0.6, 0.05, 0.02]);
    % X2, Y2 at top-right of original image
    coord_boxes(3) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.4, 0.93, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'X2', 'Units','normalized', 'Position', [0.4, 0.95, 0.05, 0.02]);
    coord_boxes(4) = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
        'Position', [0.45, 0.93, 0.05, 0.02], 'BackgroundColor', [1 1 1], 'Callback', @(src,~) moveROIFromBoxes());
    uicontrol(fig, 'Style', 'text', 'String', 'Y2', 'Units','normalized', 'Position', [0.45, 0.95, 0.05, 0.02]);

    %% Save and Reset buttons
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Reset', ...
        'Units','normalized', 'Position', [0.85, 0.93, 0.12, 0.05], ...
        'BackgroundColor', [1 0.9 0.9], 'Callback', @(src,~) resetAll());

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Save All', ...
        'Units','normalized', 'Position', [0.85, 0.87, 0.12, 0.05], ...
        'BackgroundColor', [0.8 1 0.8], 'Callback', @(src,~) saveAll());

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Clear', ...
        'Units','normalized', 'Position', [0.93, 0.78, 0.05, 0.025], ...
        'BackgroundColor', [1 0.8 0.8], 'Callback', @(~,~) clearAllLabels());

    labelVisible = true;  % initial global state

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Show/Hide', ...
        'Units','normalized', 'Position', [0.90, 0.62, 0.05, 0.025], ...
        'BackgroundColor', [0.9 0.9 1], 'Callback', @(~,~) toggleVisibility());

    traceVisible = true;  % NEW: global state for contour visibility

    uicontrol(fig,'Style','pushbutton','String','Traces On', ...
        'Units','normalized','Position',[0.90, 0.58, 0.05, 0.025], ...
        'BackgroundColor',[0.9 0.9 1], 'Callback', @(~,~) toggleTraces());

    %% Undo button
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Undo Label', 'Units','normalized', ...
        'Position', [0.93, 0.75, 0.05, 0.025], 'BackgroundColor', [1 0.95 0.8], ...
        'Callback', @undoClick);

    removeButton = uicontrol(fig, 'Style', 'pushbutton', 'String', 'Remove Labels (Off)', ...
        'Units','normalized', 'Position', [0.76, 0.55, 0.1, 0.03], ...
        'BackgroundColor', [1 0.9 0.8], 'Callback', @(~,~) toggleRemoveMode());

    %% Add Import parameters button
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Import parameters', ...
        'Units','normalized', 'Position', [0.85, 0.81, 0.12, 0.05], ...
        'BackgroundColor', [0.9 0.9 1], ...
        'Callback', @importParametersCallback);

    %% connected pixel filter
    % Red channel filter (to the right of R plot)
    rAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Units','normalized', 'Position', [0.26, 0.34, 0.03, 0.025]);
    maxrAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units','normalized', 'Position', [0.30, 0.34, 0.03, 0.025]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Filter R', ...
        'Units','normalized', 'Position', [0.28, 0.31, 0.03, 0.025], ...
        'Callback', @(~,~) filterChannel('R'));

    % Green channel filter (to the right of G plot)
    gAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Units','normalized', 'Position', [0.59, 0.34, 0.03, 0.025]);
    maxgAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units','normalized', 'Position', [0.63, 0.34, 0.03, 0.025]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Filter G', ...
        'Units','normalized', 'Position', [0.61, 0.31, 0.03, 0.025], ...
        'Callback', @(~,~) filterChannel('G'));

    % Blue channel filter (to the right of B plot)
    bAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '10', ...
        'Units','normalized', 'Position', [0.91, 0.34, 0.03, 0.025]);
    maxbAreaBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units','normalized', 'Position', [0.95, 0.34, 0.03, 0.025]);
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Filter B', ...
        'Units','normalized', 'Position', [0.93, 0.31, 0.03, 0.025], ...
        'Callback', @(~,~) filterChannel('B'));
    %% auto count cells
    % Below existing filter R/G/B buttons (example positions)
    %% Single channel auto-labeling buttons (keep existing)
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto Label R', ...
        'Units','normalized', 'Position', [0.27, 0.25, 0.06, 0.025], ...
        'Callback', @(~,~) autoLabelChannel('R'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto Label G', ...
        'Units','normalized', 'Position', [0.6, 0.25, 0.06, 0.025], ...
        'Callback', @(~,~) autoLabelChannel('G'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto Label B', ...
        'Units','normalized', 'Position', [0.92, 0.25, 0.06, 0.025], ...
        'Callback', @(~,~) autoLabelChannel('B'));

    %% Add combined channel auto-labeling buttons (placed below single channel buttons)
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto R+G', ...
        'Units','normalized', 'Position', [0.27, 0.22, 0.06, 0.025], ...
        'BackgroundColor', [1 1 0.5], ... % Yellow background
        'Callback', @(~,~) autoLabelChannel('RG'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto G+B', ...
        'Units','normalized', 'Position', [0.6, 0.22, 0.06, 0.025], ...
        'BackgroundColor', [0.5 1 1], ... % Cyan background
        'Callback', @(~,~) autoLabelChannel('GB'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto R+B', ...
        'Units','normalized', 'Position', [0.92, 0.22, 0.06, 0.025], ...
        'BackgroundColor', [1 0.5 1], ... % Magenta background
        'Callback', @(~,~) autoLabelChannel('RB'));

    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Auto R+G+B', ...
        'Units','normalized', 'Position', [0.47, 0.06, 0.06, 0.025], ...
        'BackgroundColor', [1 0.5 1], ... % Magenta background
        'Callback', @(~,~) autoLabelChannel('RGB'));

    %% Overlap Area Threshold input box (set maximum area for extreme overlap)
    uicontrol(fig, 'Style', 'text', 'String', 'Max Overlap Threshold', ...
        'Units', 'normalized', 'Position', [0.55 0.55 0.1 0.025]);
    overlapThreshBox = uicontrol(fig, 'Style', 'edit', 'String', '40', ...
        'Units', 'normalized', 'Position', [0.64 0.55 0.05 0.025], ...
        'BackgroundColor', [1 1 1]);

    %% on/off channel
    rToggle = uicontrol(fig, 'Style', 'pushbutton', 'String', 'On', ...
        'Units','normalized', 'Position', [0.46, 0.68, 0.041, 0.025], 'BackgroundColor', [1 0.5 0.5], ...
        'Callback',@(~,~) toggleChannel(1));

    gToggle = uicontrol(fig, 'Style', 'pushbutton', 'String', 'On', ...
        'Units','normalized', 'Position', [0.46, 0.64, 0.041, 0.025],'BackgroundColor', [0.5 1 0.5], ...
        'Callback',  @(~,~) toggleChannel(2));

    bToggle = uicontrol(fig, 'Style', 'pushbutton', 'String', 'On', ...
        'Units','normalized', 'Position', [0.46, 0.6, 0.041, 0.025], 'BackgroundColor', [0.6 0.6 1], ...
        'Callback',  @(~,~) toggleChannel(3));

    %% Run first update
    updateImage();
    % === Labeling mode and state ===
    currentMode = 'R';  % can be 'R', 'G', or 'B'
    
    rCounter = 0; rHandles = []; rPositions = zeros(0,2);
    gCounter = 0; gHandles = []; gPositions = zeros(0,2);
    bCounter = 0; bHandles = []; bPositions = zeros(0,2);
    rgCounter = 0; rgHandles = []; rgPositions = zeros(0,2);
    gbCounter = 0; gbHandles = []; gbPositions = zeros(0,2);
    rbCounter = 0; rbHandles = []; rbPositions = zeros(0,2);
    rgbCounter = 0; rgbHandles = []; rgbPositions = zeros(0,2);

    counter = 0;
    labelHandles = []; 
    labelPositions = [];

    % >>>PART A<<<
    % === Trace (contour) storage (1:1 with labels) ===
    rTraceH = gobjects(0); gTraceH = gobjects(0); bTraceH = gobjects(0);
    rgTraceH = gobjects(0); gbTraceH = gobjects(0); rbTraceH = gobjects(0); rgbTraceH = gobjects(0);
    
    % Initialize variables for area
    rAreas = []; gAreas = []; bAreas = [];
    rgAreas = []; gbAreas = []; rbAreas = []; rgbAreas = [];

    % Initialize variables for mean intensity
    rMeans = []; gMeans = []; bMeans = [];
    rgMeans = []; gbMeans = []; rbMeans = []; rgbMeans = [];
   
    traceWidth = 1.5;       % slightly thicker looks cleaner

    modeButtons.R = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R', ...
        'Units','normalized', 'Position', [0.76, 0.68, 0.02, 0.025], ...
        'BackgroundColor', [1 0.8 0.8], 'Callback', @(~,~) setMode('R'));

    modeButtons.G = uicontrol(fig, 'Style', 'pushbutton', 'String', 'G', ...
        'Units','normalized', 'Position', [0.76, 0.64, 0.02, 0.025], ...
        'BackgroundColor', [0.8 1 0.8], 'Callback', @(~,~) setMode('G'));

    modeButtons.B = uicontrol(fig, 'Style', 'pushbutton', 'String', 'B', ...
        'Units','normalized', 'Position', [0.76, 0.6, 0.02, 0.025], ...
        'BackgroundColor', [0.8 0.8 1], 'Callback', @(~,~) setMode('B'));

    modeButtons.RG = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R+G', ...
        'Units','normalized', 'Position', [0.82, 0.68, 0.04, 0.025], ...
        'BackgroundColor', [1 1 0.8], 'Callback', @(~,~) setMode('RG'));

    modeButtons.GB = uicontrol(fig, 'Style', 'pushbutton', 'String', 'G+B', ...
        'Units','normalized', 'Position', [0.82, 0.64, 0.04, 0.025], ...
        'BackgroundColor', [0.9 1 1], 'Callback', @(~,~) setMode('GB'));

    modeButtons.RB = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R+B', ...
        'Units','normalized', 'Position', [0.82, 0.6, 0.04, 0.025], ...
        'BackgroundColor', [1 0.9 1], 'Callback', @(~,~) setMode('RB'));

    modeButtons.RGB = uicontrol(fig, 'Style', 'pushbutton', 'String', 'R+G+B', ...
        'Units','normalized', 'Position', [0.90, 0.66, 0.04, 0.025], ...
        'BackgroundColor', [1 0.9 1], 'Callback', @(~,~) setMode('RGB'));



    rCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', 'Position', [0.79, 0.68, 0.02, 0.025]);
    gCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', 'Position', [0.79, 0.64, 0.02, 0.025]);
    bCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', 'Position', [0.79, 0.6, 0.02, 0.025]);

    rgCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.87, 0.68, 0.02, 0.025]);
    gbCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.87, 0.64, 0.02, 0.025]);
    rbCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.87, 0.6, 0.02, 0.025]);
    rgbCountBox = uicontrol(fig, 'Style', 'text', 'String', '0', 'Units','normalized', ...
    'Position', [0.95, 0.66, 0.02, 0.025]);


    % Font size input
    uicontrol(fig, 'Style', 'text', 'String', 'Font Size', 'Units', 'normalized', ...
        'Position', [0.76, 0.75, 0.04, 0.025]);
    fontSizeBox = uicontrol(fig, 'Style', 'edit', 'String', '6', 'Units', 'normalized', ...
        'Position', [0.8, 0.75, 0.02, 0.025], 'Callback', @updateFontSize);

    % Font color dropdown
    uicontrol(fig, 'Style', 'text', 'String', 'Font Color', 'Units', 'normalized', ...
        'Position', [0.83, 0.75, 0.04, 0.025]);
    colorMenu = uicontrol(fig, 'Style', 'popupmenu', ...
    'String', {'red','green','blue','yellow','cyan','magenta','black','white'}, ...
    'Units','normalized', 'Position', [0.87, 0.75, 0.06, 0.025]);

function labelClick(~, ~)
    pt = get(axCropped, 'CurrentPoint');
    x = pt(1,1); y = pt(1,2);
    fontSize = str2double(fontSizeBox.String);
    colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
    fontColor = colors{colorMenu.Value};
    
    switch currentMode
    case 'R'
        rCounter = rCounter + 1;
        h = text(axCropped, x, y, num2str(rCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rHandles(end+1) = h;
        if size(rPositions, 2) ~= 2
            rPositions = reshape(rPositions, [], 2);
        end
        rPositions(end+1,:) = [x, y];
    case 'G'
        gCounter = gCounter + 1;
        h = text(axCropped, x, y, num2str(gCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        gHandles(end+1) = h;
        if size(gPositions, 2) ~= 2
            gPositions = reshape(gPositions, [], 2);
        end
        gPositions(end+1,:) = [x, y];
    case 'B'
        bCounter = bCounter + 1;
        h = text(axCropped, x, y, num2str(bCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        bHandles(end+1) = h;
        if size(bPositions, 2) ~= 2
            bPositions = reshape(bPositions, [], 2);
        end
        bPositions(end+1,:) = [x, y];
        
    case 'RG'
        rgCounter = rgCounter + 1;
        h = text(axCropped, x, y, num2str(rgCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rgHandles(end+1) = h;
        if size(rgPositions, 2) ~= 2
            rgPositions = reshape(rgPositions, [], 2);
        end
        rgPositions(end+1,:) = [x, y];
    case 'GB'
        gbCounter = gbCounter + 1;
        h = text(axCropped, x, y, num2str(gbCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        gbHandles(end+1) = h;
        if size(gbPositions, 2) ~= 2
            gbPositions = reshape(gbPositions, [], 2);
        end
        gbPositions(end+1,:) = [x, y];
    case 'RB'
        rbCounter = rbCounter + 1;
        h = text(axCropped, x, y, num2str(rbCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rbHandles(end+1) = h;
        if size(rbPositions, 2) ~= 2
            rbPositions = reshape(rbPositions, [], 2);
        end
        rbPositions(end+1,:) = [x, y];
    case 'RGB'
        rgbCounter = rgbCounter + 1;
        h = text(axCropped, x, y, num2str(rgbCounter), 'Color', fontColor, ...
            'FontSize', fontSize, 'FontWeight', 'bold', 'HorizontalAlignment', 'center','Clipping', 'on');
        rgbHandles(end+1) = h;
        if size(rgbPositions, 2) ~= 2
            rgbPositions = reshape(rgbPositions, [], 2);
        end
        rgbPositions(end+1,:) = [x, y];
    end
        
        updateCountDisplay();
end

function filterChannel(channel)
    switch channel
        case 'R', cIndex = 1; areaThresh = str2double(rAreaBox.String); maxareaThresh = str2double(maxrAreaBox.String);
        case 'G', cIndex = 2; areaThresh = str2double(gAreaBox.String); maxareaThresh = str2double(maxgAreaBox.String);
        case 'B', cIndex = 3; areaThresh = str2double(bAreaBox.String); maxareaThresh = str2double(maxbAreaBox.String);
    end

    bw = imbinarize(adjustedCopy(:,:,cIndex));  % use current filtered image
    
    % Get bounding box areas of all connected regions
    stats = regionprops(bw, 'BoundingBox', 'PixelIdxList');
    validCells = false(size(bw));

    for k = 1:numel(stats)
        bb = stats(k).BoundingBox;
        width = bb(3);
        height = bb(4);
        
        % Check if both width and height are within min and max threshold range
        % Keep cells with width and height >= min threshold and <= max threshold
        if (width >= areaThresh && height >= areaThresh) && ...
           (width <= maxareaThresh && height <= maxareaThresh)
            validCells(stats(k).PixelIdxList) = true;
        end
    end

    % Apply filtering
    filteredChannel = adjustedCopy(:,:,cIndex);
    filteredChannel(~validCells) = 0;
    filteredCopy(:,:,cIndex) = filteredChannel;

    % Update display
    hCroppedRGB.CData = filteredCopy;
    updateSplitChannels();  % Update single channel display (need to customize this function, see below)
end

function updateSplitChannels()
    hR.CData = cat(3, filteredCopy(:,:,1), zeros(size(filteredCopy,1), size(filteredCopy,2), 2));
    hG.CData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2)), filteredCopy(:,:,2), zeros(size(filteredCopy,1), size(filteredCopy,2)));
    hB.CData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2)), zeros(size(filteredCopy,1), size(filteredCopy,2)), filteredCopy(:,:,3));
end

%>>>PART B<<<
function col = modeToRGB(mode)
    switch mode
        case 'R',   col = [0 1 1];
        case 'G',   col = [1 0 1];  % magenta vs green
        case 'B',   col = [1 1 0];  % yellow vs blue
        case 'RG',  col = [0 0 1];  % blue vs yellow (R+G)
        case 'GB',  col = [1 0 0];  % red vs cyan (G+B)
        case 'RB',  col = [0 1 0];  % green vs magenta (R+B)
        case 'RGB', col = [0 0 0];  % black vs white (R+G+B)
    end
end

function [amin, amax] = limitsFor(mode)
    switch mode
        case 'R',   amin = str2double(rAreaBox.String);  amax = str2double(maxrAreaBox.String);
        case 'G',   amin = str2double(gAreaBox.String);  amax = str2double(maxgAreaBox.String);
        case 'B',   amin = str2double(bAreaBox.String);  amax = str2double(maxbAreaBox.String);
        case 'RG',  amin = max(str2double(rAreaBox.String), str2double(gAreaBox.String));
                    amax = min(str2double(maxrAreaBox.String), str2double(maxgAreaBox.String));
        case 'GB',  amin = max(str2double(gAreaBox.String), str2double(bAreaBox.String));
                    amax = min(str2double(maxgAreaBox.String), str2double(maxbAreaBox.String));
        case 'RB',  amin = max(str2double(rAreaBox.String), str2double(bAreaBox.String));
                    amax = min(str2double(maxrAreaBox.String), str2double(maxbAreaBox.String));
        case 'RGB', amin = max([str2double(rAreaBox.String), str2double(gAreaBox.String), str2double(bAreaBox.String)]);
                    amax = min([str2double(maxrAreaBox.String), str2double(maxgAreaBox.String), str2double(maxbAreaBox.String)]);
    end
end

function plane = pickPlane(img, idx)
    % prefer filteredCopy if it has been created; else adjustedCopy
    if ~isempty(img)
        plane = img(:,:,idx);
    else
        plane = adjustedCopy(:,:,idx);
    end
end

function bw = makeMaskFor(mode)
    % Otsu threshold selected channels; combined modes require overlap across channels.
    use = filteredCopy;   % uses filtered result if you ran "Filter R/G/B"
    if isempty(use); use = adjustedCopy; end

    idx = channelsForMode(mode);
    bwStack = false(size(use,1), size(use,2), numel(idx));
    
    for i = 1:numel(idx)
       bwStack(:,:,i) = imbinarize(use(:,:,idx(i)));
    end 
    bw = all(bwStack, 3);
end

%>>>END PART B<<<
%>>>PART C<<<
function [Hout, Pout, Cout, Aout, Mout, counterOut] = ...
         traceAndLabel(mode, Hin, Pin, Cin, Ain, Min, counterIn)

    [amin, amax] = limitsFor(mode);
    fs = max(6, str2double(fontSizeBox.String));
    colors = {'red','green','blue','yellow','cyan','magenta','black','white'};
    textCol = colors{colorMenu.Value};
    lineCol = modeToRGB(mode);

    [Hout, Pout, Cout, Aout, Mout, counterOut] = traceAndLabel_function( ...
        mode, Hin, Pin, Cin, Ain, Min, counterIn, ...
        adjustedCopy, filteredCopy, amin, amax, fs, textCol, lineCol, axCropped, traceWidth);
end

function toggleVisibility()
    labelVisible = ~labelVisible;
    switch currentMode
        case 'R', toggleSet(rHandles);
        case 'G', toggleSet(gHandles);
        case 'B', toggleSet(bHandles);
        case 'RG', toggleSet(rgHandles);
        case 'GB', toggleSet(gbHandles);
        case 'RB', toggleSet(rbHandles);
        case 'RGB', toggleSet(rgbHandles);
    end
end

function toggleSet(handles)
    for i = 1:numel(handles)
        if isgraphics(handles(i))
            if labelVisible
                set(handles(i), 'Visible', 'on');
            else
                set(handles(i), 'Visible', 'off');
            end
        end
    end
end

function toggleTraces()
    traceVisible = ~traceVisible;
    % flip button text
    if traceVisible, set(gcbo,'String','Traces On'); else, set(gcbo,'String','Traces Off'); end

    switch currentMode
        case 'R',  toggleTraceSet(rTraceH);
        case 'G',  toggleTraceSet(gTraceH);
        case 'B',  toggleTraceSet(bTraceH);
        case 'RG', toggleTraceSet(rgTraceH);
        case 'GB', toggleTraceSet(gbTraceH);
        case 'RB', toggleTraceSet(rbTraceH);
        case 'RGB',toggleTraceSet(rgbTraceH);
    end
end

function toggleTraceSet(handles)
    for i = 1:numel(handles)
        if isgraphics(handles(i))
            if traceVisible
                set(handles(i), 'Visible', 'on');
            else
                set(handles(i), 'Visible', 'off');
            end
        end
    end
end

function toggleRemoveMode()
    removeMode = ~removeMode;
    if removeMode
        removeButton.String = 'Remove (On)';
        set(fig, 'Pointer', 'crosshair');
        enableRectangleDrawing();
    else
        removeButton.String = 'Remove (Off)';
        set(fig, 'Pointer', 'arrow');
        set(hCroppedRGB, 'ButtonDownFcn', @labelClick);

        % 🔥 Cancel any unfinished rectangle
        if exist('rectHandle', 'var') && isgraphics(rectHandle)
            delete(rectHandle);
        end
    end
end

function enableRectangleDrawing()
    rectHandle = drawrectangle(axCropped, 'Color', 'm', 'LineWidth', 1.5);
    rectangleDone(rectHandle);
end

function rectangleDone(rect)
    % After rectangle is drawn, delete labels inside
    boxPos = rect.Position;
    delete(rect);  % 🔥 delete the rectangle right after finishing drawing

    % Get box corners
    boxX1 = boxPos(1); boxY1 = boxPos(2);
    boxX2 = boxX1 + boxPos(3);
    boxY2 = boxY1 + boxPos(4);

    % Remove based on current mode
    switch currentMode
        case 'R'
            [rHandles, rPositions, rTraceH, rAreas, rMeans, rCounter] = ...
            removeInRegion(rHandles, rPositions, rTraceH, rAreas, rMeans, boxX1, boxY1, boxX2, boxY2);        
        case 'G'
            [gHandles, gPositions, gTraceH, gAreas, gMeans, gCounter] = ...
            removeInRegion(gHandles, gPositions, gTraceH, gAreas, gMeans, boxX1, boxY1, boxX2, boxY2);
        case 'B'
            [bHandles, bPositions, bTraceH, bAreas, bMeans, bCounter] = ...
            removeInRegion(bHandles, bPositions, bTraceH, bAreas, bMeans, boxX1, boxY1, boxX2, boxY2);
        case 'RG'
            [rgHandles, rgPositions, rgTraceH, rgAreas, rgMeans, rgCounter] = ...
            removeInRegion(rgHandles, rgPositions, rgTraceH, rgAreas, rgMeans, boxX1, boxY1, boxX2, boxY2);
        case 'GB'
            [gbHandles, gbPositions, gbTraceH, gbAreas, gbMeans, gbCounter] = ...
            removeInRegion(gbHandles, gbPositions, gbTraceH, gbAreas, gbMeans, boxX1, boxY1, boxX2, boxY2);
        case 'RB'
            [rbHandles, rbPositions, rbTraceH, rbAreas, rbMeans, rbCounter] = ...
            removeInRegion(rbHandles, rbPositions, rbTraceH, rbAreas, rbMeans, boxX1, boxY1, boxX2, boxY2);
        case 'RGB'
            [rgbHandles, rgbPositions, rgbTraceH, rgbAreas, rgbMeans, rgbCounter] = ...
            removeInRegion(rgbHandles, rgbPositions, rgbTraceH, rgbAreas, rgbMeans, boxX1, boxY1, boxX2, boxY2);
    end

    updateCountDisplay();

    if removeMode  % double-check it again AFTER drawing
        enableRectangleDrawing();  
    else
        set(fig, 'Pointer', 'arrow');  % Reset pointer too when finished
        set(hCroppedRGB, 'ButtonDownFcn', @labelClick);  % Restore click for manual labeling
    end

end

function [H, P, T, A, M, counter] = removeInRegion(H, P, T, A, M, boxX1, boxY1, boxX2, boxY2)
    if isempty(H) || isempty(P)
        H = []; P = zeros(0,2); A = []; M = []; counter = 0;
        return;
    end

    toKeep = true(size(P,1),1);
    for i = 1:size(P,1)
        x = P(i,1); y = P(i,2);
        if x >= boxX1 && x <= boxX2 && y >= boxY1 && y <= boxY2
            if isgraphics(H(i)), delete(H(i)); end
            if i <= numel(T) && isgraphics(T(i)), delete(T(i)); end
            toKeep(i) = false;
        end
    end
    H = H(toKeep);
    P = P(toKeep,:);
    if ~isempty(T), T = T(toKeep); else, T = gobjects(0); end
    if ~isempty(A), A = A(toKeep); else, A = []; end
    if ~isempty(M), M = M(toKeep); else, M = []; end
    if isempty(P), P = zeros(0,2); end
    
    % Renumber labels
    for i = 1:numel(H)
        if isgraphics(H(i)), set(H(i), 'String', num2str(i)); end
    end
    counter = numel(H);
end

function toggleChannel(channelIdx)
    channelActive(channelIdx) = ~channelActive(channelIdx);
    
    % Update button label correctly
    switch channelIdx
        case 1
            if channelActive(1)
                rToggle.String = 'On';
            else
                rToggle.String = 'Off';
            end
        case 2
            if channelActive(2)
                gToggle.String = 'On';
            else
                gToggle.String = 'Off';
            end
        case 3
            if channelActive(3)
                bToggle.String = 'On';
            else
                bToggle.String = 'Off';
            end
    end
    
    % Update displayed Adjusted RGB image
    newDisplay = filteredCopy;
    for c = 1:3
        if ~channelActive(c)
            newDisplay(:,:,c) = 0;
        end
    end
    hCroppedRGB.CData = newDisplay;
    
    % ALSO update the split R, G, B images
    if channelActive(1)
        rData = cat(3, filteredCopy(:,:,1), zeros(size(filteredCopy,1), size(filteredCopy,2), 2));
    else
        rData = zeros(size(filteredCopy,1), size(filteredCopy,2), 3);
    end
    hR.CData = rData;
    
    if channelActive(2)
        gData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2)), filteredCopy(:,:,2), zeros(size(filteredCopy,1), size(filteredCopy,2)));
    else
        gData = zeros(size(filteredCopy,1), size(filteredCopy,2), 3);
    end
    hG.CData = gData;
    
    if channelActive(3)
        bData = cat(3, zeros(size(filteredCopy,1), size(filteredCopy,2), 2), filteredCopy(:,:,3));
    else
        bData = zeros(size(filteredCopy,1), size(filteredCopy,2), 3);
    end
    hB.CData = bData;
end

function undoClick(~,~)
    switch currentMode
        case 'R'
            if rCounter > 0
                delete(rHandles(end)); rHandles(end) = [];
                if ~isempty(rTraceH) && isgraphics(rTraceH(end)), delete(rTraceH(end)); end
                if ~isempty(rTraceH), rTraceH(end) = []; end
                if ~isempty(rAreas),  rAreas(end)  = []; end
                if ~isempty(rMeans),  rMeans(end)  = []; end
                rPositions(end, :) = [];
                rCounter = rCounter - 1;
            end
        case 'G'
            if gCounter > 0
                delete(gHandles(end)); gHandles(end) = [];
                if ~isempty(gTraceH) && isgraphics(gTraceH(end)), delete(gTraceH(end)); end
                if ~isempty(gTraceH), gTraceH(end) = []; end
                if ~isempty(gAreas),  gAreas(end)  = []; end
                if ~isempty(gMeans),  gMeans(end)  = []; end
                gPositions(end, :) = [];
                gCounter = gCounter - 1;
            end
       case 'B'
            if bCounter > 0
                delete(bHandles(end)); bHandles(end) = [];
                if ~isempty(bTraceH) && isgraphics(bTraceH(end)), delete(bTraceH(end)); end
                if ~isempty(bTraceH), bTraceH(end) = []; end
                if ~isempty(bAreas),  bAreas(end)  = []; end
                if ~isempty(bMeans),  bMeans(end)  = []; end
                bPositions(end, :) = [];
                bCounter = bCounter - 1;
            end
        case 'RG'
            if rgCounter > 0
                delete(rgHandles(end)); rgHandles(end) = [];
                if ~isempty(rgTraceH) && isgraphics(rgTraceH(end)), delete(rgTraceH(end)); end
                if ~isempty(rgTraceH), rgTraceH(end) = []; end
                if ~isempty(rgAreas),  rgAreas(end)  = []; end
                if ~isempty(rgMeans), rgMeans(end) = []; end
                rgPositions(end, :) = [];
                rgCounter = rgCounter - 1;
            end
        case 'GB'
            if gbCounter > 0
                delete(gbHandles(end)); gbHandles(end) = [];
                if ~isempty(gbTraceH) && isgraphics(gbTraceH(end)), delete(gbTraceH(end)); end
                if ~isempty(gbTraceH), gbTraceH(end) = []; end
                if ~isempty(gbAreas),  gbAreas(end)  = []; end
                if ~isempty(gbMeans), gbMeans(end) = []; end
                gbPositions(end, :) = [];
                gbCounter = gbCounter - 1;
            end
        case 'RB'
            if rbCounter > 0
                delete(rbHandles(end)); rbHandles(end) = [];
                if ~isempty(rbTraceH) && isgraphics(rbTraceH(end)), delete(rbTraceH(end)); end
                if ~isempty(rbTraceH), rbTraceH(end) = []; end
                if ~isempty(rbAreas),  rbAreas(end)  = []; end
                if ~isempty(rbMeans), rbMeans(end) = []; end
                rbPositions(end, :) = [];
                rbCounter = rbCounter - 1;
            end
        case 'RGB'
            if rgbCounter > 0
                delete(rgbHandles(end)); rgbHandles(end) = [];
                if ~isempty(rgbTraceH) && isgraphics(rgbTraceH(end)), delete(rgbTraceH(end)); end
                if ~isempty(rgbTraceH), rgbTraceH(end) = []; end
                if ~isempty(rgbAreas),  rgbAreas(end)  = []; end
                if ~isempty(rgbMeans), rgbMeans(end) = []; end
                rgbPositions(end, :) = [];
                rgbCounter = rgbCounter - 1;
            end
    end

    updateCountDisplay();  % <- Ensure this stays to refresh UI
end

function updateImage()
    updateImage_function(axCropped, currentShape, roi, original_rgb, imgW, imgH, ...
        coord_boxes, sliders, val_labels, hCroppedRGB, hR, hG, hB);
    
    % Update local variables from workspace
    adjustedCopy = evalin('base', 'adjustedCopy');
    filteredCopy = evalin('base', 'filteredCopy');
    
    % --- Keep ButtonDownFcn for manual labeling ---
    set(hCroppedRGB, 'ButtonDownFcn', @labelClick);
end

function saveAll()
    % Make measured areas available to saveAll_function
    setappdata(gcf,'rAreas',rAreas);
    setappdata(gcf,'gAreas',gAreas);
    setappdata(gcf,'bAreas',bAreas);

    % saveAll_function expects 'Overlap' names
    setappdata(gcf,'rgOverlapAreas',rgAreas);
    setappdata(gcf,'gbOverlapAreas',gbAreas);
    setappdata(gcf,'rbOverlapAreas',rbAreas);
    setappdata(gcf,'rgbOverlapAreas',rgbAreas);

    setappdata(gcf,'rMeans',rMeans);
    setappdata(gcf,'gMeans',gMeans);
    setappdata(gcf,'bMeans',bMeans);
    
    setappdata(gcf,'rgMeans',rgMeans);
    setappdata(gcf,'gbMeans',gbMeans);
    setappdata(gcf,'rbMeans',rbMeans);
    setappdata(gcf,'rgbMeans',rgbMeans);
    
    saveAll_function(animal_name, currentShape, roi, original_rgb, imgW, imgH, hCroppedRGB, ...
        sliders, rAreaBox, gAreaBox, bAreaBox, maxrAreaBox, maxgAreaBox, maxbAreaBox, ...
        coord_boxes, rPositions, gPositions, bPositions, rgPositions, gbPositions, ...
        rbPositions, rgbPositions, overlapThreshBox);
end

% Helper function: Create parameters Excel file
function createParametersFile(folderPath, animal_name, contrast, brightness)
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

function saveLabelData(excelFile, prefix, positions, areas)
    if ~isempty(positions)
        note = {'NOTE: Coordinates are relative to the CROPPED image with (0,0) at the TOP-LEFT corner', '', '', ''};
        header = {'Label', 'X', 'Y', 'Area'};
        
        % Ensure areas and positions have consistent length
        if length(areas) ~= size(positions, 1)
            areas = zeros(size(positions, 1), 1);
        end
        
        data = num2cell([(1:size(positions,1))', positions, areas(:)]);
        combined = [note; header; data];
        writecell(combined, excelFile, 'Sheet', [prefix '_Labels']);
    end
end

function resetAll()
    % Reset contrast and brightness sliders
    for i = 1:3
        sliders(i,1).Value = initVals(i,1); % Contrast
        sliders(i,2).Value = initVals(i,2); % Brightness
    end

    % Reset crop window to default position (adapted for rectangle/polygon)
    if strcmp(currentShape, 'rectangle')
        % Rectangle mode uses [x,y,w,h] format
        roi.Position = defaultRectPos;
    else
        % Polygon mode: convert default rectangle to vertex coordinates
        x = defaultRectPos(1);
        y = defaultRectPos(2);
        w = defaultRectPos(3);
        h = defaultRectPos(4);
        % Generate rectangle vertices (clockwise order)
        roi.Position = [x, y; x+w, y; x+w, y+h; x, y+h]; 
        % Note: For more complex default polygons, custom vertices can be defined here
    end

    % Reset filter size boxes
    rAreaBox.String = '10';
    gAreaBox.String = '10';
    bAreaBox.String = '10';
    maxrAreaBox.String = '40';
    maxgAreaBox.String = '40';
    maxbAreaBox.String = '40';

    % Reset display settings
    fontSizeBox.String = '6';
    colorMenu.Value = 1;  % Reset to red

    % Clear ALL labels (optimized deletion logic)
    labelGroups = {'rHandles', 'gHandles', 'bHandles', ...
                   'rgHandles', 'gbHandles', 'rbHandles', 'rgbHandles'};
    for k = 1:numel(labelGroups)
        handles = eval(labelGroups{k});
        validHandles = isgraphics(handles); % Batch check validity
        delete(handles(validHandles));
        eval([labelGroups{k} ' = [];']);    % Clear handle arrays
    end

    traceGroups = {'rTraceH','gTraceH','bTraceH','rgTraceH','gbTraceH','rbTraceH','rgbTraceH'};
    for k = 1:numel(traceGroups)
        th = eval(traceGroups{k});
        delete(th(isgraphics(th)));
        eval([traceGroups{k} ' = gobjects(0);']);
    end
    areaVars = {'rAreas','gAreas','bAreas','rgAreas','gbAreas','rbAreas','rgbAreas'};
    for k = 1:numel(areaVars)
        eval([areaVars{k} ' = [];']);
    end
    meanVars = {'rMeans','gMeans','bMeans','rgMeans','gbMeans','rbMeans','rgbMeans'};
    for k = 1:numel(meanVars)
        eval([meanVars{k} ' = [];']);
    end
    
    % Reset counters and positions (merged into single line code)
    vars = {'r', 'g', 'b', 'rg', 'gb', 'rb', 'rgb'};
    for m = 1:numel(vars)
        eval([vars{m} 'Positions = zeros(0,2);']);
        eval([vars{m} 'Counter = 0;']);
    end

    % Update display and image
    updateCountDisplay();
    updateImage(); % Will automatically handle ROI normalized coordinate updates

    % Display operation completion prompt (optional)
    disp('All parameters and labels have been reset.');
end

function importParametersCallback(~, ~)
    [file, path] = uigetfile({'*.xlsx'}, 'Please select parameter Excel file');
    if isequal(file, 0), return; end
    filename = fullfile(path, file);

    try
        importParameters_function(filename, sliders, val_labels, ...
            rAreaBox, maxrAreaBox, gAreaBox, maxgAreaBox, bAreaBox, maxbAreaBox, overlapThreshBox);
        msgbox('Parameters are imported and auto-populated successfully!', 'Success');
        updateImage();  % Refresh interface after importing parameters
    catch ME
        warning(ME.identifier, '%s', ME.message);
        msgbox('Failed to import parameters, please check the file format!', 'Error', 'error');
    end
end



function setMode(mode)
    currentMode = mode;

    allFields = fieldnames(modeButtons);
    for i = 1:length(allFields)
        btn = modeButtons.(allFields{i});
        set(btn, 'FontWeight', 'normal');  % reset normal
    end

    % Highlight selected one
    activeBtn = modeButtons.(mode);
    set(activeBtn, 'FontWeight', 'bold');  % bold (fitUicontrolText refits the size)

    % Optional: Change background color darker too
    switch mode
        case 'R'
            set(activeBtn, 'BackgroundColor', [1 0.5 0.5]);
        case 'G'
            set(activeBtn, 'BackgroundColor', [0.5 1 0.5]);
        case 'B'
            set(activeBtn, 'BackgroundColor', [0.5 0.5 1]);
        case 'RG'
            set(activeBtn, 'BackgroundColor', [1 1 0.5]);
        case 'GB'
            set(activeBtn, 'BackgroundColor', [0.5 1 1]);
        case 'RB'
            set(activeBtn, 'BackgroundColor', [1 0.5 1]);
        case 'RGB'
            set(activeBtn, 'BackgroundColor', [1 0.5 1]);
    end

    % Reset others to their normal background color
    for i = 1:length(allFields)
        if ~strcmp(allFields{i}, mode)
            btn = modeButtons.(allFields{i});
            % set their color back to original
            switch allFields{i}
                case 'R'
                    set(btn, 'BackgroundColor', [1 0.8 0.8]);
                case 'G'
                    set(btn, 'BackgroundColor', [0.8 1 0.8]);
                case 'B'
                    set(btn, 'BackgroundColor', [0.8 0.8 1]);
                case 'RG'
                    set(btn, 'BackgroundColor', [1 1 0.8]);
                case 'GB'
                    set(btn, 'BackgroundColor', [0.9 1 1]);
                case 'RB'
                    set(btn, 'BackgroundColor', [1 0.9 1]);
                case 'RGB'
                    set(btn, 'BackgroundColor', [1 0.9 1]);
            end
        end
    end

end


function updateCountDisplay()
    rCountBox.String = num2str(rCounter);
    gCountBox.String = num2str(gCounter);
    bCountBox.String = num2str(bCounter);
    rgCountBox.String = num2str(rgCounter);
    gbCountBox.String = num2str(gbCounter);
    rbCountBox.String = num2str(rbCounter);
    rgbCountBox.String = num2str(rgbCounter);

end

function updateFontSize(~, ~)
    % Get new font size
    newFontSize = str2double(fontSizeBox.String);
    
    % Verify if input is valid
    if isnan(newFontSize) || newFontSize <= 0
        fontSizeBox.String = '6'; % Restore default value
        newFontSize = 6;
    end
    
    % Update font size for all existing labels
    allHandles = [rHandles, gHandles, bHandles, rgHandles, gbHandles, rbHandles, rgbHandles];
    
    for i = 1:length(allHandles)
        if isgraphics(allHandles(i))
            set(allHandles(i), 'FontSize', newFontSize);
        end
    end
end
%>>>PART D<<<
function autoLabelChannel(channel)
    setMode(channel);

    switch channel
        case 'R'
            [rHandles, rPositions, rTraceH, rAreas, rMeans, rCounter] = ...
                traceAndLabel('R', rHandles, rPositions, rTraceH, rAreas, rMeans, rCounter);
        case 'G'
            [gHandles, gPositions, gTraceH, gAreas, gMeans, gCounter] = ...
                traceAndLabel('G', gHandles, gPositions, gTraceH, gAreas, gMeans, gCounter);
        case 'B'
            [bHandles, bPositions, bTraceH, bAreas, bMeans, bCounter] = ...
                traceAndLabel('B', bHandles, bPositions, bTraceH, bAreas, bMeans, bCounter);
        case 'RG'
            [rgHandles, rgPositions, rgTraceH, rgAreas, rgMeans, rgCounter] = ...
                traceAndLabel('RG', rgHandles, rgPositions, rgTraceH, rgAreas, rgMeans, rgCounter);
        case 'GB'
            [gbHandles, gbPositions, gbTraceH, gbAreas, gbMeans, gbCounter] = ...
                traceAndLabel('GB', gbHandles, gbPositions, gbTraceH, gbAreas, gbMeans, gbCounter);
        case 'RB'
            [rbHandles, rbPositions, rbTraceH, rbAreas, rbMeans, rbCounter] = ...
                traceAndLabel('RB', rbHandles, rbPositions, rbTraceH, rbAreas, rbMeans, rbCounter);
        case 'RGB'
            [rgbHandles, rgbPositions, rgbTraceH, rgbAreas, rgbMeans, rgbCounter] = ...
                traceAndLabel('RGB', rgbHandles, rgbPositions, rgbTraceH, rgbAreas, rgbMeans, rgbCounter);
    end

    updateCountDisplay();
end
%>>>END PART D<<<
    
function clearAllLabels()
    switch currentMode
        case 'R'
            delete(rHandles(isgraphics(rHandles))); rHandles = [];
            delete(rTraceH(isgraphics(rTraceH)));   rTraceH = gobjects(0);
            rPositions = zeros(0,2); rAreas = []; rMeans = []; rCounter = 0;
        case 'G'
            delete(gHandles(isgraphics(gHandles))); gHandles = [];
            delete(gTraceH(isgraphics(gTraceH)));   gTraceH = gobjects(0);
            gPositions = zeros(0,2); gAreas = []; gMeans = []; gCounter = 0;
        case 'B'
            delete(bHandles(isgraphics(bHandles))); bHandles = [];
            delete(bTraceH(isgraphics(bTraceH)));   bTraceH = gobjects(0);
            bPositions = zeros(0,2); bAreas = []; bMeans = []; bCounter = 0;
        case 'RG'
            delete(rgHandles(isgraphics(rgHandles))); rgHandles = [];
            delete(rgTraceH(isgraphics(rgTraceH)));   rgTraceH = gobjects(0);
            rgPositions = zeros(0,2); rgAreas = []; rgMeans = []; rgCounter = 0;
        case 'GB'
            delete(gbHandles(isgraphics(gbHandles))); gbHandles = [];
            delete(gbTraceH(isgraphics(gbTraceH)));   gbTraceH = gobjects(0);
            gbPositions = zeros(0,2); gbAreas = []; gbMeans = []; gbCounter = 0;
        case 'RB'
            delete(rbHandles(isgraphics(rbHandles))); rbHandles = [];
            delete(rbTraceH(isgraphics(rbTraceH)));   rbTraceH = gobjects(0);
            rbPositions = zeros(0,2); rbAreas = []; rbMeans = []; rbCounter = 0;
        case 'RGB'
            delete(rgbHandles(isgraphics(rgbHandles))); rgbHandles = [];
            delete(rgbTraceH(isgraphics(rgbTraceH)));   rgbTraceH = gobjects(0);
            rgbPositions = zeros(0,2); rgbAreas = []; rgbMeans = []; rgbCounter = 0;
    end
    updateCountDisplay();
end

function startRulerMode()
    % rulerPoints = [];  % 清空上一次
    clearRuler();
    title(axCropped, 'Click two points to measure distance', 'Color', 'b');
    set(hCroppedRGB, 'ButtonDownFcn', @rulerClick);
end

function rulerClick(~,~)
    pt = get(axCropped, 'CurrentPoint');
    pt = pt(1, 1:2);  % [x, y]
    rulerPoints(end+1, :) = pt;
    % if size(rulerPoints, 1) == 2
        % 画线
        % Draw line that follows mouse
        % if isgraphics(rulerLine), delete(rulerLine); end
        % rulerLine = line(axCropped, rulerPoints(:,1), rulerPoints(:,2), ...
        %     'Color', 'yellow', 'LineWidth', 2);
        % 
        % % 计算距离
        % d = sqrt(sum(diff(rulerPoints).^2));
        % 
        % % 显示在 GUI 框中
        % rulerDistanceBox.String = sprintf('%.2f', d);
        % 
        % % 恢复点击逻辑
        % set(hCroppedRGB, 'ButtonDownFcn', @labelClick);
        % title(axCropped, 'Adjusted RGB Crop');
    if size(rulerPoints, 1) == 1
        % First click: start a line that follows the mouse
        rulerLine = line(axCropped, [pt(1) pt(1)], [pt(2) pt(2)], ...
            'Color', 'yellow', 'LineWidth', 2, 'PickableParts', 'none');

        % WindowButtonMotionFcn is a property that holds a callback.
        % Whenever the mouse moves, rulerMove is called
        set(fig, 'WindowButtonMotionFcn', @rulerMove);
    else
        % Second click: lock the line in place
        set(fig, 'WindowButtonMotionFcn', '');
        set(rulerLine, 'XData', rulerPoints(:,1), 'YData', rulerPoints(:,2));
        d = hypot(diff(rulerPoints(:,1)), diff(rulerPoints(:,2)));
        rulerDistanceBox.String = sprintf('%.2f', d);

        set(hCroppedRGB, 'ButtonDownFcn', @labelClick);
        title(axCropped, 'Adjusted RGB Crop');
    end
end

% Callback function used by a figure to show the ruler line
    function rulerMove(~,~)
        % Runs every time the mouse moves between the two clicks
        if ~isgraphics(rulerLine), return; end
        cp = get(axCropped, 'CurrentPoint');
        p2 = cp(1, 1:2);

        % Keep the end of the line inside the image, so the axes never zooms out
        [h, w, ~] = size(hCroppedRGB.CData);
        p2(1) = min(max(p2(1), 0.5), w + 0.5);
        p2(2) = min(max(p2(2), 0.5), h + 0.5);

        set(rulerLine, 'XData', [rulerPoints(1,1) p2(1)], ...
            'YData', [rulerPoints(1,2) p2(2)]);
        d = hypot(p2(1) - rulerPoints(1,1), p2(2) - rulerPoints(1,2));
        rulerDistanceBox.String = sprintf('%.2f', d);
    end


function clearRuler()
    % if isgraphics(rulerLine), delete(rulerLine); end
    % rulerLine = [];
    % rulerPoints = [];
    % rulerDistanceBox.String = '';
    set(fig, 'WindowButtonMotionFcn', '');   % stop following the mouse
    if isgraphics(rulerLine), delete(rulerLine); end
    rulerLine = [];
    rulerPoints = [];
    rulerDistanceBox.String = '';
    set(hCroppedRGB, 'ButtonDownFcn', @labelClick);
    title(axCropped, 'Adjusted RGB Crop');
end

    function convertToGray()
        % Convert current RGB to grayscale
        gray_img = rgb2gray(original_rgb);
        gray_img = im2double(gray_img);

        % Close current figure and launch grayscale GUI
        close(fig);
        greyscale_case(gray_img, animal_name);
    end


    % Shrink any control text that is too wide; refits on resize
    fitUicontrolText(fig);

    createROI();
    updateImage();
end
