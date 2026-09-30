function importParameters_function(filename, sliders, val_labels, ...
    rAreaBox, maxrAreaBox, gAreaBox, maxgAreaBox, bAreaBox, maxbAreaBox, overlapThreshBox)

    paramTable = readtable(filename);
    if height(paramTable) < 3
        error('PARAM:IncompleteFile', 'Parameter file is incomplete.');
    end

    % Contrast / Brightness
    for c = 1:3
        sliders(c,1).Value = paramTable.Contrast(c);
        set(val_labels(c,1), 'String', num2str(paramTable.Contrast(c), '%.2f'));
        sliders(c,2).Value = paramTable.Brightness(c);
        set(val_labels(c,2), 'String', num2str(paramTable.Brightness(c), '%.2f'));
    end

    % Threshold block
    [~, ~, raw] = xlsread(filename);
    for k = 4:size(raw,1)
        param = string(raw{k,1});
        value = raw{k,2};
        switch param
            case "R_Min",      rAreaBox.String = num2str(value);
            case "R_Max",      maxrAreaBox.String = num2str(value);
            case "G_Min",      gAreaBox.String = num2str(value);
            case "G_Max",      maxgAreaBox.String = num2str(value);
            case "B_Min",      bAreaBox.String = num2str(value);
            case "B_Max",      maxbAreaBox.String = num2str(value);
            case "Overlap_Max", overlapThreshBox.String = num2str(value);
        end
    end
end
