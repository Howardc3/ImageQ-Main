function r = ruler(fig, ax, img, distanceBox, onDone)
% ruler  Two-click distance tool for an image, shared by both GUIs.
%
%   r = ruler(fig, ax, img, distanceBox, onDone) returns a struct of
%   function handles:
%     r.start()  arm the tool: clears any old line, then the next click on
%                img starts a line that follows the mouse, and the click
%                after that locks it. The distance (px) shows live in
%                distanceBox.
%     r.clear()  delete the line, empty distanceBox, stop following the mouse.
%     r.click    the image's ButtonDownFcn while armed; a GUI that resets
%                img.ButtonDownFcn itself (e.g. greyscale_case's
%                refreshButtonDownFcn) should set it back to r.click.
%
%   onDone() is called when a measurement finishes or is cleared while
%   armed, so the GUI can restore its own click handler. The axes title is
%   saved by r.start() and restored before onDone runs.
%
%   The ruler's state lives in the nested functions below, so the GUI only
%   needs to keep r.

    rulerLine = [];
    rulerPoints = zeros(0,2);
    active = false;
    savedTitle = '';
    savedTitleColor = [0 0 0];
    clickFcn = @click;

    r.start = @start;
    r.clear = @clearRuler;
    r.click = clickFcn;

    function start()
        % drop any previous line / half-finished measurement
        clearRuler();
        savedTitle = ax.Title.String;
        savedTitleColor = ax.Title.Color;
        title(ax, 'Click two points to measure distance', 'Color', 'b');
        active = true;
        img.ButtonDownFcn = clickFcn;
    end

    function click(~,~)
        cp = get(ax, 'CurrentPoint');
        pt = cp(1, 1:2);  % [x, y]
        if any(isnan(pt)), return; end
        rulerPoints(end+1, :) = pt;
        if size(rulerPoints, 1) == 1
            % First click: start a line that follows the mouse
            rulerLine = line(ax, [pt(1) pt(1)], [pt(2) pt(2)], ...
                'Color', 'yellow', 'LineWidth', 2, 'PickableParts', 'none');

            % WindowButtonMotionFcn is a property that holds a callback.
            % Whenever the mouse moves, move is called
            set(fig, 'WindowButtonMotionFcn', @move);
        else
            % Second click: lock the line in place
            set(fig, 'WindowButtonMotionFcn', '');
            set(rulerLine, 'XData', rulerPoints(:,1), 'YData', rulerPoints(:,2));
            d = hypot(diff(rulerPoints(:,1)), diff(rulerPoints(:,2)));
            distanceBox.String = sprintf('%.2f', d);
            finish();
        end
    end

    function move(~,~)
        % Runs every time the mouse moves between the two clicks.
        % Stop following if the GUI switched to another tool meanwhile.
        if ~isgraphics(rulerLine) || ~isequal(img.ButtonDownFcn, clickFcn)
            return;
        end
        cp = get(ax, 'CurrentPoint');
        p2 = cp(1, 1:2);

        % Keep the end of the line inside the image, so when the mouse moves out of the image, the axes never zooms out
        % we chose 0.5 because we want it strictly inside the image, not on the edge
        [h, w, ~] = size(img.CData);
        p2(1) = min(max(p2(1), 0.5), w + 0.5);
        p2(2) = min(max(p2(2), 0.5), h + 0.5);

        set(rulerLine, 'XData', [rulerPoints(1,1) p2(1)], ...
            'YData', [rulerPoints(1,2) p2(2)]);
        d = hypot(p2(1) - rulerPoints(1,1), p2(2) - rulerPoints(1,2));
        distanceBox.String = sprintf('%.2f', d);
    end

    function clearRuler()
        if size(rulerPoints, 1) == 1
            set(fig, 'WindowButtonMotionFcn', '');   % stop following the mouse
        end
        if isgraphics(rulerLine), delete(rulerLine); end
        rulerLine = [];
        rulerPoints = zeros(0,2);
        distanceBox.String = '';
        if active, finish(); end
    end

    function finish()
        active = false;
        title(ax, savedTitle, 'Color', savedTitleColor);
        onDone();
    end
end
