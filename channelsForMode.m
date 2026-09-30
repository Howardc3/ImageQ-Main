function idx = channelsForMode(mode)
    switch mode
        case 'R'
            idx = 1;
        case 'G'
            idx = 2;
        case 'B'
            idx = 3;
        case 'RG'
            idx = [1 2];
        case 'GB'
            idx = [2 3];
        case 'RB'
            idx = [1 3];
        case 'RGB'
            idx = [1 2 3];
        otherwise
            error('Unknown channel mode: %s', mode);
    end
end
