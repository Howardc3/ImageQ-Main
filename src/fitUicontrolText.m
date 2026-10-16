function fitUicontrolText(parent)
% fitUicontrolText  Shrink uicontrol text so it fits the width of its control.
%
%   fitUicontrolText(fig) fits every uicontrol inside fig (sliders excluded).
%   Each control's current normalized FontSize is treated as its maximum;
%   if the text is wider than the control at that size, the font is scaled
%   down until it fits. Controls are re-fitted when the window is resized
%   and whenever their String or FontWeight changes.
%
%   Controls whose FontUnits are not 'normalized' (e.g. 'points') are left
%   alone, so a control can opt out by passing 'FontUnits','points'.
%
%   Call this once, after all uicontrols have been created.


    controls = findobj(parent, 'Type', 'uicontrol', '-not', 'Style', 'slider');
    controls = controls(strcmp(get(controls, 'FontUnits'), 'normalized'));

    for k = 1:numel(controls)
        h = controls(k);
        maxSize = h.FontSize;
        % can't be bigger than 1 bro
        if maxSize > 1
            maxSize = 0.6;  % a leftover point size; fall back to the default
        end
        setappdata(h, 'fitMaxFontSize', maxSize);

        % Like in Java except MATLAB always passes in the src and event and
        % we already have the control, h
        addlistener(h, 'String', 'PostSet', @(~,~) fitOne(h));
        addlistener(h, 'FontWeight', 'PostSet', @(~,~) fitOne(h));
        fitOne(h);
    end

    % if the size of the entire window changed, all ui elements should also
    % change
    fig = ancestor(parent, 'figure');
    fig.SizeChangedFcn = @(~,~) fitAll(controls);
end

% Callback for changing all elements
function fitAll(controls)
    for k = 1:numel(controls)
        fitOne(controls(k));
    end
end

% Change the size of the font/text width in a control
function fitOne(h)
    if ~isgraphics(h)
        return;
    end
    maxSize = getappdata(h, 'fitMaxFontSize');
    h.FontSize = maxSize;

    textWidth = measureTextWidth(h);
    availWidth = h.Position(3) * usableWidthFraction(h.Style);
    if textWidth > availWidth
        % Text width scales linearly with font size
        h.FontSize = maxSize * availWidth / textWidth;
    end
end

% Declare function so it returns text width
function w = measureTextWidth(h)
    if strcmp(h.Style, 'popupmenu')
        % A popupmenu's Extent only covers the selected item, so measure
        % every item with a hidden text control and take the widest.
        items = cellstr(h.String);
        probe = uicontrol(h.Parent, 'Style', 'text', 'Visible', 'off', ...
            'Units', h.Units, 'Position', h.Position, ...
            'FontUnits', 'normalized', 'FontSize', h.FontSize, ...
            'FontName', h.FontName, 'FontWeight', h.FontWeight);
        w = 0;
        for k = 1:numel(items)
            probe.String = items{k};
            w = max(w, probe.Extent(3));
        end
        delete(probe);
    else
        w = h.Extent(3);
    end
end


function f = usableWidthFraction(style)
    % Leave room for button bevels, the popupmenu arrow, checkbox squares
    switch style
        case {'pushbutton', 'togglebutton'}
            f = 0.85;
        case {'popupmenu', 'checkbox', 'radiobutton'}
            f = 0.7;
        otherwise
            f = 0.9;
    end
end
