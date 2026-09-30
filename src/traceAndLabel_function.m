function [Hout, Pout, Cout, Aout, Mout, counterOut] = ...
    traceAndLabel_function(mode, Hin, Pin, Cin, Ain, Min, counterIn, ...
    adjustedCopy, filteredCopy, amin, amax, fontSize, textCol, lineCol, axCropped, traceWidth)

    use = filteredCopy;
    if isempty(use), use = adjustedCopy; end

    idx = channelsForMode(mode);

    % Combined binary mask
    bwStack = false(size(use,1), size(use,2), numel(idx));
    for i = 1:numel(idx)
        bwStack(:,:,i) = imbinarize(use(:,:,idx(i)));
    end
    bw = all(bwStack, 3);

    [L, num] = bwlabel(bw);
    S = regionprops(L, 'BoundingBox', 'Centroid', 'Area');

    hold(axCropped, 'on');
    for k = 1:num
        bb = S(k).BoundingBox; w = bb(3); h = bb(4);
        if (w >= amin && h >= amin) && (w <= amax && h <= amax)
            c = S(k).Centroid;
            counterIn = counterIn + 1;

            t = text(axCropped, c(1), c(2), num2str(counterIn), ...
                'Color', textCol, 'FontSize', fontSize, 'FontWeight', 'bold', ...
                'HorizontalAlignment', 'center', 'Clipping', 'on');
            Hin(end+1) = t;
            Pin(end+1,:) = c;
            
            % Create binary mask for current object
            mk = (L == k);

            plane = mean(adjustedCopy(:,:,idx), 3);
            meanI = mean(plane(mk));
            Min(end+1) = meanI;

            B = bwboundaries(mk, 'noholes');
            if ~isempty(B)
                xy = B{1};
                hC = plot(axCropped, xy(:,2), xy(:,1), 'Color', lineCol, 'LineWidth', traceWidth);
            else
                hC = gobjects(1);
            end

            Cin(end+1) = hC;
            Ain(end+1) = S(k).Area;
        end
    end
    hold(axCropped, 'off');

    Hout = Hin; Pout = Pin; Cout = Cin; Aout = Ain; Mout = Min; counterOut = counterIn;
end
