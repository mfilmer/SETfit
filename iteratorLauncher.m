function [finalZ, finalParams] = iteratorLauncher(measuredZ, simFile, limits, startingParams)
    fig = dialog('Position', [500,200,100,250]);
    fig.MenuBar = 'none';
    
    
    
    tCheckbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [30,220,50,20], 'String', 'T');
    cgCheckbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [30,190,50,20], 'String', 'Cg', 'Callback', @toggleCg);
    offsetCheckbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [30,160,50,20], 'String', 'Offset', 'Callback', @toggleOffset);
    csCheckbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [30,130,50,20], 'String', 'Cs');
    cdCheckbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [30,100,50,20], 'String', 'Cd');
    gsCheckbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [30,70,50,20], 'String', 'Gs', 'Callback', @toggleG);
    gdCheckbox = uicontrol(fig, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [30,40,50,20], 'String', 'Gd', 'Callback', @toggleG);
    
    uicontrol(fig, 'Style', 'pushbutton', 'Units', 'pixels', ...
        'Position', [10,10,100,20], 'String', 'Start', 'Callback', @runCB);
    
    % Wait for user input
    uiwait(fig);
    
    function toggleCg(src,~)
        if src.Value
            offsetCheckbox.Value = 1;
        end
    end
    
    function toggleOffset(src,~)
        if ~src.Value
            cgCheckbox.Value = 0;
        end
    end
    
    function toggleG(src,~)
        value = src.Value;
        gsCheckbox.Value = value;
        gdCheckbox.Value = value;
    end
    
    function runCB(src,~)
        startingParams.fitT = tCheckbox.Value;
        startingParams.fitCg = cgCheckbox.Value;
        startingParams.fitOffset = offsetCheckbox.Value;
        startingParams.fitCs = csCheckbox.Value;
        startingParams.fitCd = cdCheckbox.Value;
        startingParams.fitG = gsCheckbox.Value;
        
        simZ = load(simFile);
        
        delete(src.Parent);
        
        [finalZ, finalParams] = iterationSolver(measuredZ, simZ, limits, startingParams);
    end
end
