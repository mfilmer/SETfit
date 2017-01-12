function SETfit()
    
    %% User Parameters
    % Location of the python.exe executable on your system. It is likely in
    % python_path = 'C:\Python24\python.exe';
    % Or if it is on your system's path you can just use
    % python_path = 'python.exe';
    % I have a nonstandard install location, this should be changed for
    % nearly anyone who wants to use this.
    python_path = 'C:\Python27_32\python.exe';
    
    %% System Parameters
    % Location of the simulator .py file
    simulator_path = 'SETsimulator\guidiamonds.py';
    
    %% Constants
    q = 1.602e-19;          % Coulombs
    G0 = 7.7480917346e-5;   % Conductance quantum in Siemens;
    
    %% Create the GUI
    % Prompt the user for the project path
    project_path = uigetdir('', 'Select Project Directory');
    
    % If the user selected cancel, load the most recent project from the
    % mainsettings.m file. If that doesn't exist, open the defaultProject.
    if project_path == 0
        if isempty(dir('mainsettings.m'))
            mainsettings = struct('project_path', 'defaultProject');
        else
            mainsettings = load('mainsettings.m', '-mat');
        end
        project_path = mainsettings.project_path;
    else
        mainsettings.project_path = project_path;       %#ok we save this later
    end
    
    % Load project settings file. If there is no settings file create a
    % struct that we can save later. (We want a struct either way)
    if isempty(dir(fullfile(project_path, 'settings.m')))
        settings = struct('simData_path', 'simulations');
    else
        settings = load(fullfile(project_path, 'settings.m'), '-mat');
    end
    
    % Load the path to the folder that holds all the simulation files and
    % make it relative to the project directory.
    simData_path = fullfile(project_path, settings.simData_path);
    
    % If the simData_path doesn't exist, we should create it
    if isempty(dir(simData_path))
        mkdir(simData_path);
    end
    
    % Create main figure
    figWidth = 1200;      % Pixels
    figHeight = 670;     % Pixels
    figCenter = figWidth/2;
    fig = figure('Position', [125,20,figWidth,figHeight]);
    fig.MenuBar = 'none';
    fig.CloseRequestFcn = @figureCloseCB;
    
    % Create the main panels
    bottomMargin = 100;         % Pixels
    dataPanel = uipanel(fig, 'Units', 'pixels', ...
        'Position', [0,bottomMargin,figCenter,figHeight - bottomMargin - 30]);
    settingsPanel = uipanel(fig, 'Units', 'pixels', ...
        'Position', [0,0,figCenter,bottomMargin]);
    simTabGroup = uitabgroup('Parent', fig, 'Units', 'pixels', ...
        'Position', [figCenter,0,figCenter,figHeight]);
    
    % Create menu bar buttons
    uicontrol(fig, 'Style', 'pushbutton', 'String', 'Load', ...
        'Units', 'pixels', 'Position', [5, figHeight - 25, 50, 20], ...
        'Callback', @loadDataFileCB);
    dataFileName = uicontrol(fig, 'Style', 'text', 'Units', 'pixels', ...
        'Position', [60, figHeight-25-3, 200, 20], 'HorizontalAlignment', 'left');
    uicontrol(fig, 'Style', 'text', 'String', 'Factor:', 'Units', 'pixels', ...
        'HorizontalAlignment', 'right', 'Position', [figCenter-40-10-40, figHeight-25-3, 40, 20]);
    factorTextBox = uicontrol(fig, 'Style', 'edit', 'Units', 'pixels', ...
        'Position', [figCenter-40-10, figHeight-25, 40, 20], 'HorizontalAlignment', 'left', ...
        'String', '1', 'Callback', @dataFileFactorCB);
    factorTextBox.UserData.value = 1;
    
    % Create the data plot
    dataAxis = axes('Parent', dataPanel, 'Visible', 'on', ...
        'OuterPosition', [0,0,1,1]);
    dataAxis.NextPlot = 'add';
    xlabel('V_G [mV]');
    ylabel('V_D [mV]');
    h = colorbar(dataAxis);
    ylabel(h, 'G [uS]');
    colormap jet;
    
    dataAxis.Units = 'pixels';
    axisPos = dataAxis.Position;
    textWidth = 40;
    textHeight = 20;
    
    xminBox = limitsBox(dataPanel, 'xmin', 0, 'mV', [axisPos(1) - textWidth/2,10,textWidth,textHeight]);
    xmaxBox = limitsBox(dataPanel, 'xmax', 1, 'mV', [axisPos(1) + axisPos(3) - textWidth/2,10,textWidth,textHeight]);
    yminBox = limitsBox(dataPanel, 'ymin', 0, 'mV', [5,axisPos(2)-textHeight/2,textWidth,textHeight]);
    ymaxBox = limitsBox(dataPanel, 'ymax', 1, 'mV', [5,axisPos(2)+axisPos(4)-textHeight/2,textWidth,textHeight]);
    zminBox = limitsBox(dataPanel, 'zmin', 0, 'uS', [figCenter-textWidth-10,axisPos(2)-textHeight/2,textWidth,textHeight]);
    zmaxBox = limitsBox(dataPanel, 'zmax', 1, 'uS', [figCenter-textWidth-10,axisPos(2)+axisPos(4)-textHeight/2,textWidth,textHeight]);
    
    autoscaleButton = uicontrol(dataPanel, 'Style', 'PushButton', 'Units', 'pixels', ...
        'Position', [figCenter-87,10,75,20], 'String', 'Autoscale Z', ...
        'Callback', @autoscaleZCallback, 'Enable', 'off');
    
    % Create data manipulation UI elements in the fitLines panel
    fitLinesPanel = uipanel(settingsPanel, 'Units', 'pixels', ...
        'Position', [340,10,250,bottomMargin-15], 'Title', 'Fitting Lines');
    cgBox = entryBox(fitLinesPanel, 'Cg', 'aF', [100, 44, 35, 20]);
    csBox = entryBox(fitLinesPanel, 'Cs', 'aF', [185, 44, 35, 20]);
    cdBox = entryBox(fitLinesPanel, 'Cd', 'aF', [185, 14, 35, 20]);
    offsetBox = entryBox(fitLinesPanel, '', 'mV', [100,14,35,20]);
    uicontrol(fitLinesPanel, 'Style', 'text', 'HorizontalAlignment', 'right', ...
        'Units', 'pixels', 'Position', [100-40-2, 14-3, 40, 20], ...
        'String', 'Offset:');
    offsetBox.String = '0';
    offsetBox.UserData.value = 0;
    
    fitLineCheckbox = uicontrol(fitLinesPanel, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [10,44,65,20], 'String', 'Draw Fit', ...
        'Callback', @drawFitCB, 'Enable', 'off');
    copyFitLinesButton = uicontrol(fitLinesPanel, 'Style', 'pushbutton', 'Units', 'pixels', ...
        'Position', [10,14,40,20], 'String', 'Copy', 'Callback', @copyFitLinesCB, ...
        'Enable', 'off');
    
    % Panel containing buttons to graphically fit the diamonds
    fittingToolsPanel = uipanel(settingsPanel, 'Units', 'pixels', ...
        'Position', [10,10,130, bottomMargin-15], 'Title', 'Fitting Tools');
    fitCgCheckbox = uicontrol(fittingToolsPanel, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [10,43,50,20], 'String', '<html>Fit C<sub>G</sub></html>', ...
        'Tag', 'cg', 'Callback', @fitCheckboxCB, 'Enable', 'off');
    uicontrol(fittingToolsPanel, 'Style', 'text', 'Units', 'pixels', ...
        'Position', [70,43-3,15,20], 'String', 'n:', 'HorizontalAlignment', 'right');
    cgPeriodBox = uicontrol(fittingToolsPanel, 'Style', 'edit', 'Units', 'pixels', ...
        'Position', [85,43,35,20], 'HorizontalAlignment', 'left', 'Enable', 'off', ...
        'String', '1', 'Callback', @cgPeriodCallback);
    cgPeriodBox.UserData.value = 1;
    fitCsCheckbox = uicontrol(fittingToolsPanel, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [10,13,50,20], 'String', '<html>Fit C<sub>S</sub></html>', ...
        'Tag', 'cs', 'Callback', @fitCheckboxCB, 'Enable', 'off');
    fitCdCheckbox = uicontrol(fittingToolsPanel, 'Style', 'checkbox', 'Units', 'pixels', ...
        'Position', [70,13,50,20], 'String', '<html>Fit C<sub>D</sub></html>', ...
        'Tag', 'cd', 'Callback', @fitCheckboxCB, 'Enable', 'off');
    
    % Create new tab tab. The tab that creates a new tab when it is opened
    newTabTab = uitab('Parent', simTabGroup, 'Title', '+', 'Tag', '+');
    simTabGroup.SelectionChangedFcn = @tabChangedCB;
    
    %% Load measured data file
    if isfield(settings, 'measuredDataFile')
        measuredDataFile = settings.measuredDataFile;
        if ~strcmp(measuredDataFile,'') && ~isempty(dir(fullfile(project_path, measuredDataFile)))
            measuredData = load(fullfile(project_path, measuredDataFile));
            
            % Back up the settings because plotRawMeasuredData() changes them
            settingsBackup = settings;
            
            plotRawMeasuredData(measuredData);
            
            % Reload settings from backup
            settings = settingsBackup;
            
            % Update axis limits from stored data
            setBox(xminBox, settings.xmin);
            setBox(xmaxBox, settings.xmax);
            setBox(yminBox, settings.ymin);
            setBox(ymaxBox, settings.ymax);
            setBox(zminBox, settings.zmin);
            setBox(zmaxBox, settings.zmax);
            
            % Replot now that we have everything in order
            refreshDataPlot()
        end
        
    else        % Set up some default values for some of the parameters
        settings.xmin = 0;
        settings.xmax = 1;
        settings.xfactor = 1e-3;
        settings.ymin = 0;
        settings.ymax = 1;
        settings.yfactor = 1e-3;
        settings.zmin = 0;
        settings.zmax = 1;
        settings.zfactor = 1e-6;
    end
    
    %% Load existing simulations from the folder. If there is none, create an empty tab
    numLoadedSims = 0;
    fileList = dir(fullfile(simData_path, '*.m'));
    for fileIndex = 1:length(fileList)
        file = fileList(fileIndex);
        [pathstr, name, ~] = fileparts(file.name);
        
        % Check for corresponding .dat file
        datFile = dir(fullfile(simData_path, pathstr, [name '.dat']));
        if isempty(datFile)
            continue;       % If we don't have it move on to the next file
        end
        
        % Now we have a pair of .m and a .dat files. Load them.
        simParams = load(fullfile(simData_path, file.name), '-mat');
        loadedSimData = load(fullfile(simData_path, datFile.name));
        
        % Plot the data fill in the simulation parameters
        newTab = newSimTab(simTabGroup);
        newTab.UserData.filename = name;
        newTab.UserData.h.filenameLabel.String = name;
        newTab.Title = simParams.tabname;
        
        h = newTab.UserData.h;
        
        % Plot the new data
        xs = linspace(simParams.xmin/settings.xfactor, simParams.xmax/settings.xfactor, size(loadedSimData,2));
        ys = linspace(simParams.ymin/settings.yfactor, simParams.ymax/settings.yfactor, size(loadedSimData,1));
        [X,Y] = meshgrid(xs,ys);
        
        pcolor(h.axis, X, Y, loadedSimData/zmaxBox.UserData.factor);
        shading(h.axis, 'interp');
        
        xlabel('V_G [mV]');
        ylabel('V_D [mV]');
        
        colormap(h.axis, 'jet');
        cb = colorbar(h.axis);
        ylabel(cb, 'G [uS]');
        caxis(h.axis, [simParams.zmin/settings.zfactor, simParams.zmax/settings.zfactor]);
        h.linkedZCheckbox.Value = 0;
        h.sim_zminBox.Enable = 'on';
        h.sim_zmaxBox.Enable = 'on';
        
        % Update the old simulation labels
        setBox(h.oldSim_cg, simParams.cg);
        setBox(h.oldSim_cs, simParams.cs);
        setBox(h.oldSim_cd, simParams.cd);
        setBox(h.oldSim_gs, simParams.gs);
        setBox(h.oldSim_gd, simParams.gd);
        setBox(h.oldSim_temp, simParams.temp);
        setBox(h.oldSim_offset, simParams.offset);
        setBox(h.sim_zminBox, simParams.zmin);
        setBox(h.sim_zmaxBox, simParams.zmax);
        
        % Calculate sum of residual squares
        if isstruct(dataAxis.UserData)
            zfactor = zmaxBox.UserData.factor;
            squ = calcSquares(dataAxis.UserData.Z/zfactor, Z/zfactor);
            h.oldSim_squ.String = num2str(squ,3);
        else
            h.oldSim_squ.String = '';
        end
        
        % We loaded a simulation. Make sure to count it.
        numLoadedSims = numLoadedSims + 1;
    end
    
    % We went through all this work of counting the number of loaded
    % simulations. Lets check if that number isn't zero and ignore the
    % actual number.
    if numLoadedSims == 0
        % Create empty simulation tab
        newSimTab(simTabGroup);
    end
    
    %% Helper functions
    % Plot a matrix of data on the measured data axis
    % The data is also stored in the axis userdata struct
    function plotRawMeasuredData(Z)
        % Make the plot
        ny = size(Z,1);
        nx = size(Z,2);
        [X,Y] = meshgrid(1:nx,1:ny);
        pcolor(dataAxis,X,Y,Z/settings.zfactor);
        shading(dataAxis,'interp');
        
        % Autoscale the x and y axes
        axis(dataAxis, [-inf, inf, -inf, inf]);
        
        % Bring back colorbar
        h = colorbar(dataAxis);
        ylabel(h, 'G [uS]');
        xlabel(dataAxis,'V_G [mV]');
        ylabel(dataAxis,'V_D [mV]');
        
        % Update textboxes to show correct limits
        setBox(xminBox, 1*settings.yfactor);
        setBox(xmaxBox, nx*settings.xfactor);
        setBox(yminBox, 1*settings.xfactor);
        setBox(ymaxBox, ny*settings.yfactor);
        
        v = caxis(dataAxis);
        setBox(zminBox, v(1)*settings.zfactor);
        setBox(zmaxBox, v(2)*settings.zfactor);
        
        % Store the data
        dataAxis.UserData.Z = Z;
        settings.xmin = 1*settings.xfactor;
        settings.xmax = nx*settings.xfactor;
        dataAxis.UserData.nx = nx;
        settings.ymin = 1*settings.yfactor;
        settings.ymax = ny*settings.yfactor;
        dataAxis.UserData.ny = ny;
        settings.zmin = v(1)*settings.zfactor;
        settings.zmax = v(2)*settings.zfactor;
        
        % Enable ui elements
        xminBox.Enable = 'on';
        xmaxBox.Enable = 'on';
        yminBox.Enable = 'on';
        ymaxBox.Enable = 'on';
        zminBox.Enable = 'on';
        zmaxBox.Enable = 'on';
        
        cgBox.Enable = 'on';
        csBox.Enable = 'on';
        cdBox.Enable = 'on';
        offsetBox.Enable = 'on';
        copyFitLinesButton.Enable = 'on';
        
        fitCgCheckbox.Enable = 'on';
        fitCsCheckbox.Enable = 'on';
        fitCdCheckbox.Enable = 'on';
        cgPeriodBox.Enable = 'on';
        
        autoscaleButton.Enable = 'on';
    end
    
    function refreshDataPlot()
        % Get the data
        Z = dataAxis.UserData.Z;
        
        % Find the limits
        xmin = settings.xmin;
        xmax = settings.xmax;
        ymin = settings.ymin;
        ymax = settings.ymax;
        zmin = settings.zmin;
        zmax = settings.zmax;
        
        nx = dataAxis.UserData.nx;
        ny = dataAxis.UserData.ny;
        
        % Create X and Y
        xs = linspace(xmin/settings.xfactor,xmax/settings.xfactor,nx);
        ys = linspace(ymin/settings.yfactor,ymax/settings.yfactor,ny);
        [X,Y] = meshgrid(xs,ys);
        
        % Delete old plot
        deletePlots(dataAxis);
        
        % Plot data
        pcolor(dataAxis,X,Y,Z/settings.zfactor);
        shading(dataAxis,'interp');
        h = colorbar(dataAxis);
        ylabel(h, 'G [uS]');
        caxis(dataAxis,[zmin/settings.zfactor,zmax/settings.zfactor]);
        xlabel(dataAxis,'V_G [mV]');
        ylabel(dataAxis,'V_D [mV]');
        
        % Scale axes
        axis(dataAxis, [-inf, inf, -inf, inf]);
        
        % Move plot to the back
        sortPlotElements(dataAxis);
        
        % Store the data
        % We have to do this because making a new plot overwrites the
        % existing data
        dataAxis.UserData.Z = Z;
        dataAxis.UserData.nx = nx;
        dataAxis.UserData.ny = ny;
    end
    
    function redrawFittingLines()
        
        % Clear existing lines
        clearLines(dataAxis);
        
        % Don't do anything else unless the box is checked
        if ~fitLineCheckbox.Value
            return
        end
        
        % Draw new lines
        cg = cgBox.UserData.value;
        cs = csBox.UserData.value;
        cd = cdBox.UserData.value;
        offset = offsetBox.UserData.value;
        ms = cg/(cg + cs);
        md = -cg/cd;
        
        % Set up the edges
        xmin = settings.xmin;
        xmax = settings.xmax;
        ymin = settings.ymin;
        ymax = settings.ymax;
        edges = [xmin, xmax, ymin, ymax];
        
        dWidth = q/cg;
        
        % Find node just left of xmin, accounting for user offset
        startingNode = findNodeLeft(xmin, offset, dWidth);
        
        % Find node just right of xmax, accounting for user offset
        endingNode = findNodeRight(xmax, offset, dWidth);
        
        nodes = startingNode:dWidth:endingNode;
        
        for node = nodes
            % Find the source side line
            [X,Y] = findLine([node,0], ms, edges);
            % Convert to display units
            X = X / settings.xfactor;
            Y = Y / settings.yfactor;
            line(dataAxis,X,Y);
            
            % Find the drain side line
            [X,Y] = findLine([node,0], md, edges);
            X = X / settings.xfactor;
            Y = Y / settings.yfactor;
            line(dataAxis,X,Y);
        end
        
        % Sort the plot elements
        sortPlotElements(dataAxis);
    end
    
    function simTab = newSimTab(parent)
        % Create new tab
        allTabs = parent.Children;
        newTabTab = allTabs(end);
        simTab = uitab('Parent', parent, 'Title', 'New Sim');
        simTab.ButtonDownFcn = @tabDoubleClickCB;
        
        % Fill in the standard elements
        simPlotPanel = uipanel(simTab, 'Units', 'Pixels', ...
            'Position', [0,bottomMargin,figCenter,figHeight-bottomMargin-30]);
        simSettingsPanel = uipanel(simTab, 'Units', 'Pixels', ...
            'Position', [0,0,figCenter,bottomMargin]);
        
        ax = axes(simPlotPanel, 'OuterPosition', [0,0,1,1]);
        xlabel('V_G [mV]');
        ylabel('V_D [mV]');
        h = colorbar(ax);
        ylabel(h, 'G [uS]');
        colormap(h, 'jet');
        
        filenameLabel = uicontrol(simTab, 'Style', 'text', 'Units', 'pixels', ...
            'Position', [0, figHeight-60, figWidth/2, 20]);
        
        sim_zminBox = simLimitsBox(simTab, 'zmin', 0, 'uS', [figCenter-textWidth-10,axisPos(2)-textHeight/2+bottomMargin,textWidth,textHeight]);
        sim_zmaxBox = simLimitsBox(simTab, 'zmax', 1, 'uS', [figCenter-textWidth-10,axisPos(2)+axisPos(4)-textHeight/2+bottomMargin,textWidth,textHeight]);
        
        linkedZCheckbox = uicontrol(simTab, 'Style', 'checkbox', 'Units', 'pixels', ...
            'Position', [figCenter-87,10+bottomMargin,75,20], 'String', 'Linked Z', ...
            'Callback', @linkedZCallback, 'Value', 1);
        
        % Create a pannel to hold the previously ran simulation parameters
        oldSimParamsPanel = uipanel(simSettingsPanel, 'Units', 'pixels', ...
            'Position', [10,10,230,bottomMargin-15], 'Title', 'Current Simulation');
        oldSim_temp = simLabelBox(oldSimParamsPanel, 'T', 'K', [55, 49, 35, 20]);
        oldSim_offset = simLabelBox(oldSimParamsPanel, 'Off', 'mV', [55, 29, 35, 20]);
        oldSim_cg = simLabelBox(oldSimParamsPanel, 'Cg', 'aF', [55, 9, 35, 20]);
        oldSim_cs = simLabelBox(oldSimParamsPanel, 'Cs', 'aF', [125, 49, 35, 20]);
        oldSim_cd = simLabelBox(oldSimParamsPanel, 'Cd', 'aF', [125, 29, 35, 20]);
        oldSim_squ = simLabelBox(oldSimParamsPanel, 'Squ', '', [125, 9, 35, 20]);
        oldSim_gs = simLabelBox(oldSimParamsPanel, 'Gs', 'uS', [195, 49, 35, 20]);
        oldSim_gd = simLabelBox(oldSimParamsPanel, 'Gd', 'uS', [195, 29, 35, 20]);
        
        % Create simulation parameter panel and elements
        simParamsPanel = uipanel(simSettingsPanel, 'Units', 'pixels', ...
            'Position', [250,10,335,bottomMargin-15], 'Title', 'Next Simulation');
        sim_cgBox = simEntryBox(simParamsPanel, 'Cg', 'aF', [100, 44, 35, 20]);
        sim_csBox = simEntryBox(simParamsPanel, 'Cs', 'aF', [185, 44, 35, 20]);
        sim_cdBox = simEntryBox(simParamsPanel, 'Cd', 'aF', [185, 14, 35, 20]);
        sim_gsBox = simEntryBox(simParamsPanel, 'Gs', 'uS', [270, 44, 35, 20]);
        sim_gdBox = simEntryBox(simParamsPanel, 'Gd', 'uS', [270, 14, 35, 20]);
        sim_offsetBox = simEntryBox(simParamsPanel, '', 'mV', [100,14,35,20]);
        sim_tempBox = simEntryBox(simParamsPanel, 'T', 'K', [15,44,35,20]);
        sim_tempBox.UserData.value = 0.3;
        sim_tempBox.String = '0.3';
        uicontrol(simParamsPanel, 'Style', 'text', 'HorizontalAlignment', 'right', ...
            'Units', 'pixels', 'Position', [100-40-2, 14-3, 40, 20], ...
            'String', 'Offset:');
        sim_offsetBox.String = '0';
        sim_offsetBox.UserData.value = 0;
        
        runSimButton = uicontrol(simParamsPanel, 'Style', 'pushbutton', 'Units', 'pixels', ...
            'Position', [10,14,40,20], 'String', 'Run', 'Callback', @runSimCB, ...
            'Enable', 'off');
        
        % Store appropriate handles in the tab's UserData
        simTab.UserData.h.axis = ax;
        simTab.UserData.h.filenameLabel = filenameLabel;
        simTab.UserData.h.sim_cgBox = sim_cgBox;
        simTab.UserData.h.sim_csBox = sim_csBox;
        simTab.UserData.h.sim_cdBox = sim_cdBox;
        simTab.UserData.h.sim_gsBox = sim_gsBox;
        simTab.UserData.h.sim_gdBox = sim_gdBox;
        simTab.UserData.h.sim_offsetBox = sim_offsetBox;
        simTab.UserData.h.sim_tempBox = sim_tempBox;
        simTab.UserData.h.runSimButton = runSimButton;
        
        simTab.UserData.h.oldSim_temp = oldSim_temp;
        simTab.UserData.h.oldSim_offset = oldSim_offset;
        simTab.UserData.h.oldSim_cg = oldSim_cg;
        simTab.UserData.h.oldSim_cs = oldSim_cs;
        simTab.UserData.h.oldSim_cd = oldSim_cd;
        simTab.UserData.h.oldSim_squ = oldSim_squ;
        simTab.UserData.h.oldSim_gs = oldSim_gs;
        simTab.UserData.h.oldSim_gd = oldSim_gd;
        
        simTab.UserData.h.sim_zminBox = sim_zminBox;
        simTab.UserData.h.sim_zmaxBox = sim_zmaxBox;
        simTab.UserData.h.linkedZCheckbox = linkedZCheckbox;
        
        % Reorganize tabs
        allTabs(end) = simTab;
        allTabs(end+1) = newTabTab;
        parent.Children = allTabs;
        parent.SelectedTab = simTab;
    end
    
    function renameTab(handle)
        newName = inputdlg('Rename tab:','Rename Tab',1,{handle.Title});
        if ~isempty(newName)
            handle.Title = newName{1};
        end
    end
    
    function handle = limitsBox(parent, tag, value, units, pVec)
        % Determine factor
        factor = unitsToFactor(units);
        
        % Make box
        handle = uicontrol(parent, 'Style', 'edit', 'String', num2str(value), ...
            'Units', 'pixels', 'Callback', @axisLimitsChangedCB,  'Enable', 'off', ...
            'Position', pVec, 'Tag', tag);
        
        % Store data
        handle.UserData.value = value*factor;
        handle.UserData.factor = factor;
    end
    
    function handle = simLimitsBox(parent, tag, value, units, pVec)
        % Determine factor
        factor = unitsToFactor(units);
        
        % Make box
        handle = uicontrol(parent, 'Style', 'edit', 'String', num2str(value), ...
            'Units', 'pixels', 'Callback', @simLimitsChangedCB,  'Enable', 'off', ...
            'Position', pVec, 'Tag', tag);
        
        % Store data
        handle.UserData.value = value*factor;
        handle.UserData.factor = factor;
    end
    
    function handle = entryBox(parent, label, units, pVec)
        % Constants
        lw = 20;
        uw = 20;
        h = 20;
        lo = -3;
        
        % Determine factor
        factor = unitsToFactor(units);
        
        % Make box
        handle = uicontrol(parent, 'Style', 'edit', 'Units', 'pixels', ...
            'Position', pVec, 'HorizontalAlignment', 'right', 'Enable', 'off', ...
            'Callback', @fittingParametersChanged, 'Tag', label);
        
        % Make labels if they aren't empty strings
        if ~strcmp(label, '')
            uicontrol(parent, 'Style', 'text', 'HorizontalAlignment', 'right', ...
            'Units', 'pixels', 'Position', [pVec(1)-lw-2, pVec(2)+lo, lw, h], ...
            'String', [label ':']);
        end
        
        if ~strcmp(units, '')
            uicontrol(parent, 'Style', 'text', 'HorizontalAlignment', 'left', ...
                'Units', 'pixels', 'Position', [pVec(1)+pVec(3)+2, pVec(2)+lo, uw, h], ...
                'String', units);
        end
        
        % Store data
        handle.UserData.value = 0;
        handle.UserData.factor = factor;
    end
    
    function dataHandle = simLabelBox(parent, label, units, pVec)
        % Constants
        lw = 50;
        h = 20;
        lo = -3;
        
        % Determine factor
        factor = unitsToFactor(units);
        
        pVec(2) = pVec(2) + lo;
        
        % Make box
        dataHandle = uicontrol(parent, 'Style', 'text', 'Units', 'pixels', ...
            'Position', pVec, 'HorizontalAlignment', 'left');
        
        % Make label and include units if units isn't an empty string
        if strcmp(units, '')
            uicontrol(parent, 'Style', 'text', 'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [pVec(1)-lw-2, pVec(2), lw, h], ...
                'String', [label ': ']);
        else
            uicontrol(parent, 'Style', 'text', 'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [pVec(1)-lw-2, pVec(2), lw, h], ...
                'String', [label ' [' units ']' ': ']);
        end
        
        % Store data
        dataHandle.UserData.factor = factor;
        dataHandle.UserData.value = 0;
    end
    
    function handle = simEntryBox(parent, label, units, pVec)
        % Constants
        lw = 20;
        uw = 20;
        h = 20;
        lo = -3;
        
        % Determine factor
        factor = unitsToFactor(units);
        
        % Make box
        handle = uicontrol(parent, 'Style', 'edit', 'Units', 'pixels', ...
            'Position', pVec, 'HorizontalAlignment', 'right', ...
            'Callback', @simParametersChanged, 'Tag', label);
        
        % Make labels if they aren't empty strings
        if ~strcmp(label, '')
            uicontrol(parent, 'Style', 'text', 'HorizontalAlignment', 'right', ...
                'Units', 'pixels', 'Position', [pVec(1)-lw-2, pVec(2)+lo, lw, h], ...
                'String', [label ':']);
        end
        
        if ~strcmp(units, '')
            uicontrol(parent, 'Style', 'text', 'HorizontalAlignment', 'left', ...
                'Units', 'pixels', 'Position', [pVec(1)+pVec(3)+2, pVec(2)+lo, uw, h], ...
                'String', units);
        end
        
        % Store data
        handle.UserData.value = 0;
        handle.UserData.factor = factor;
    end
    
    % Handle the new simulation data. This includes deleting some old files if
    % they were overwritten
    function handleNewSimData(Z, tab, filename)
        h = tab.UserData.h;
        
        % Plot the new data
        xs = linspace(settings.xmin/settings.xfactor, settings.xmax/settings.xfactor, 101);
        ys = linspace(settings.ymin/settings.yfactor, settings.ymax/settings.yfactor, 101);
        [X,Y] = meshgrid(xs,ys);
        
        pcolor(h.axis, X, Y, Z/settings.zfactor);
        shading(h.axis, 'interp');
        
        xlabel('V_G [mV]');
        ylabel('V_D [mV]');
        
        colormap(h.axis, 'jet');
        cb = colorbar(h.axis);
        ylabel(cb, 'G [uS]');
        
        zmin = settings.zmin / settings.zfactor;
        zmax = settings.zmax / settings.zfactor;
        caxis(h.axis, [zmin, zmax]);
        
        setBox(h.sim_zminBox, settings.zmin);
        setBox(h.sim_zmaxBox, settings.zmax);
        
        % Delete the old file if one exists
        if isfield(tab.UserData, 'filename')
            oldFilename = tab.UserData.filename;
            mfile = fullfile(simData_path, [oldFilename '.m']);
            datfile = fullfile(simData_path, [oldFilename '.dat']);
            delete(mfile, datfile);
        end
        
        % Store new file information
        tab.UserData.filename = filename;
        mfile = fullfile(simData_path, [filename '.m']);
        
        % Update the old simulation labels
        setBox(h.oldSim_cg, h.sim_cgBox.UserData.value);
        setBox(h.oldSim_cs, h.sim_csBox.UserData.value);
        setBox(h.oldSim_cd, h.sim_cdBox.UserData.value);
        setBox(h.oldSim_gs, h.sim_gsBox.UserData.value);
        setBox(h.oldSim_gd, h.sim_gdBox.UserData.value);
        setBox(h.oldSim_temp, h.sim_tempBox.UserData.value);
        setBox(h.oldSim_offset, h.sim_offsetBox.UserData.value);
        
        % Update displayed filename
        h.filenameLabel.String = filename;
        
        % Calculate sum of residual squares
        if isstruct(dataAxis.UserData)
            zfactor = settings.zfactor;
            squ = calcSquares(dataAxis.UserData.Z/zfactor, Z/zfactor);
            h.oldSim_squ.String = num2str(squ,3);
        else
            h.oldSim_squ.String = '';
        end
        
        % Save .m file of simulation parameters
        saveTabFile(mfile, tab, settings);
        
    end
    
    %% Callback Functions
    function tabChangedCB(~, eventdata)
        if eventdata.NewValue == newTabTab
            newSimTab(simTabGroup);
        end
    end
    
    function tabDoubleClickCB(src, ~)
        switch fig.SelectionType
            case 'normal'       % single Click
            case 'open'         % Double Click
                renameTab(src);
        end
    end
    
    % Handles the callback for loading a new measured data file
    function loadDataFileCB(~, ~)
        [FileName,PathName] = uigetfile({'*.*', '*.dat'}, 'Select Measurement File', project_path);
        
        % If the user cancelled the dialog
        if FileName == 0 
            return;
        end
        
        dataFileName.String = FileName;
        Z = importdata(fullfile(PathName, FileName)) * factorTextBox.UserData.value;
        plotRawMeasuredData(Z);
        syncZAxis();
        
        settings.measuredDataFile = FileName;
    end
    
    % Recalculate z axis limits based on data
    function autoscaleZCallback(~, ~)
        zmin = min(min(dataAxis.UserData.Z));
        zmax = max(max(dataAxis.UserData.Z));
        
        settings.zmin = zmin;
        settings.zmax = zmax;

        setBox(zminBox, zmin);
        setBox(zmaxBox, zmax);
        
        refreshDataPlot();
        syncZAxis();
    end
    
    % Whenever the linked z checkbox changes state
    function linkedZCallback(src, ~)
        syncZAxis(src.Parent);
    end
    
    function syncZAxis(varargin)
        % Get entire tab list if no individual tab was specified
        if nargin == 0
            tablist = simTabGroup.Children;
        else
            tablist = varargin{1};
        end
        
        for i = 1:length(tablist)
            tab = tablist(i);
            if strcmp(tab.Tag, '+')
                continue;
            end
            
            sim_zminBox = tab.UserData.h.sim_zminBox;
            sim_zmaxBox = tab.UserData.h.sim_zmaxBox;
            
            switch tab.UserData.h.linkedZCheckbox.Value
                case 0
                    sim_zminBox.Enable = 'on';
                    sim_zmaxBox.Enable = 'on';
                case 1
                    sim_zminBox.Enable = 'off';
                    sim_zmaxBox.Enable = 'off';
                    
                    % Copy the limits from the data axis
                    setBox(sim_zminBox, settings.zmin);
                    setBox(sim_zmaxBox, settings.zmax);
                    
                    % Adjust the simulated plot
                    zmin = settings.zmin/settings.zfactor;
                    zmax = settings.zmax/settings.zfactor;
                    caxis(tab.UserData.h.axis, [zmin, zmax]);
            end
        end
    end
    
    % Whenever the "Draw Fit" checkbox changes state
    function drawFitCB(~,~)
        % Draw lines
        redrawFittingLines();
    end
    
    % This function handles callbacks from plot axis limit text boxes
    % changing
    function axisLimitsChangedCB(src, ~)
        [num, status] = str2num(src.String);    %#ok
        if status == 0
            src.String = num2str(src.UserData.value/src.UserData.factor);
            return;
        end
        
        % Convert num from display units to base units
        num = num*src.UserData.factor;
        src.UserData.value = num;
        
        switch src.Tag
            case 'xmin'
                settings.xmin = num;
            case 'xmax'
                settings.xmax = num;
            case 'ymin'
                settings.ymin = num;
            case 'ymax'
                settings.ymax = num;
            case 'zmin'
                settings.zmin = num;
                syncZAxis();
            case 'zmax'
                settings.zmax = num;
                syncZAxis();
        end
        
        refreshDataPlot();
        redrawFittingLines();
    end
    
    % This function handles callbacks from simulation axis limit text boxes
    % changing
    function simLimitsChangedCB(src, ~)
        [num, status] = str2num(src.String);    %#ok
        if status == 0
            src.String = num2str(src.UserData.value/src.UserData.factor);
            return;
        end
        
        % Get axis handle
        h = src.Parent.UserData.h;
        simAxis = h.axis;
        
        % Convert num from display units to base units
        num = num*src.UserData.factor;
        src.UserData.value = num;
        
        zmin = h.sim_zminBox.UserData.value/settings.zfactor;
        zmax = h.sim_zmaxBox.UserData.value/settings.zfactor;
        caxis(simAxis, [zmin, zmax]);
        
        refreshDataPlot();
        redrawFittingLines();
    end
    
    % Whenever one of the simulation parameters (Cg, Cs, etc) is changed
    function simParametersChanged(src, ~)
        [num, status] = str2num(src.String);    %#ok
        if status == 0
            src.String = num2str(src.UserData.value/src.UserData.factor);
            return;
        end
        
        src.UserData.value = num * src.UserData.factor;
        
        h = src.Parent.Parent.Parent.UserData.h;
        
        enableDisableRunButton(h);
    end
    
    % Whenever one of the fitting parameters (Cg, Cs, etc) is changed
    function fittingParametersChanged(src, ~)
        [num, status] = str2num(src.String);    %#ok
        if status == 0
            src.String = num2str(src.UserData.value/src.UserData.factor);
            return;
        end
        
        src.UserData.value = num * src.UserData.factor;
        
        enableDisableFitCheckbox();
    end
    
    % Called to copy the fitting parameters from the data window into a new
    % simulation tab
    function copyFitLinesCB(~, ~)
        
        % Copy data into currently active tab
        thisTab = simTabGroup.SelectedTab;
        h = thisTab.UserData.h;
        
        % Copy over all the data we need
        copyBox(cgBox, h.sim_cgBox);
        copyBox(csBox, h.sim_csBox);
        copyBox(cdBox, h.sim_cdBox);
        copyBox(offsetBox, h.sim_offsetBox);
        
        % Copy data but only if something has been entered into that box
        function copyBox(src, dest)
            if ~strcmp(src.String, '')
                dest.UserData.value = src.UserData.value;
                dest.String = num2str(dest.UserData.value/dest.UserData.factor);
            end
        end
        
        enableDisableRunButton(h);
    end
    
    function enableDisableRunButton(h)
        % Determine if all 6 parameters have a value
        state = true;
        if h.sim_csBox.UserData.value <= 0
            state = false;
        elseif h.sim_cdBox.UserData.value <= 0
            state = false;
        elseif h.sim_cgBox.UserData.value <= 0
            state = false;
        elseif h.sim_gsBox.UserData.value <= 0
            state = false;
        elseif h.sim_gdBox.UserData.value <= 0
            state = false;
        end
        
        % Enable or disable the run simulation button as appropriate
        if state
            h.runSimButton.Enable = 'on';
        else
            h.runSimButton.Enable = 'off';
        end
    end
    
    function enableDisableFitCheckbox()
        % Determine if all 4 parameters have a value
        state = true;
        if csBox.UserData.value <= 0
            state = false;
        end
        if cdBox.UserData.value <= 0
            state = false;
        end
        if cgBox.UserData.value <= 0
            state = false;
        end
        
        % Enable or disable the checkbox as appropriate
        if state
            fitLineCheckbox.Enable = 'on';
            redrawFittingLines();
        else
            fitLineCheckbox.Enable = 'off';
            fitLineCheckbox.Value = 0;
            
            % Clear lines
            clearLines(dataAxis);
        end
    end
    
    % Actually run the simulation
    function runSimCB(src, ~)
        h = src.Parent.Parent.Parent.UserData.h;
        
        % Disable simulation parameters while the sim is running
        enableDisableSimParams(h, 'off');
        drawnow;
        
        offset = h.sim_offsetBox.UserData.value;
        
        vds_start = num2str(settings.ymin * 1e3);   % mV
        vds_end = num2str(settings.ymax * 1e3);     % mV
        numVdspoints = num2str(101 + 1);    % Note, for some reason the simulator runs one less point than requested for this parameter
        Cs = num2str(h.sim_csBox.UserData.value);
        Cd = num2str(h.sim_cdBox.UserData.value);
        Gs = num2str(h.sim_gsBox.UserData.value/G0);
        Gd = num2str(h.sim_gdBox.UserData.value/G0);
        num_e = num2str(5);
        vg_start = num2str((settings.xmin-offset) * 1e3);   % mV
        vg_end = num2str((settings.xmax-offset) * 1e3);     % mV
        numVgpoints = num2str(101);
        Cg = num2str(h.sim_cgBox.UserData.value);
        T = num2str(h.sim_tempBox.UserData.value);
        
        % Run the python simulator
        filename = makeFileName();
        datfile = [filename '.dat'];
        command=[python_path ' ' simulator_path ' ' T ' ' vds_start ' ' vds_end ' ' ...
            numVdspoints ' ' Cs ' ' Cd ' ' Gs ' ' Gd ' ' num_e ' '...
            vg_start ' ' vg_end ' ' numVgpoints ' ' Cg ' ' fullfile(simData_path, datfile)];
        [~,result]=system(command);
        disp(['Simulation Output: ' result])
        Z = load(fullfile(simData_path, datfile));
        
        handleNewSimData(Z, src.Parent.Parent.Parent, filename);
        
        % Re-enable the sim parameters
        enableDisableSimParams(h, 'on');
    end
    
    % When the figure closes clean some stuff up
    function figureCloseCB(src, ~)
        try
            % Save the main settings
            save('mainsettings.m', '-struct', 'mainsettings');
            
            % Save project settings
            save(fullfile(project_path, 'settings.m'), '-struct', 'settings');
            
            % Save individual .m files for each plot
            for i = 1:length(simTabGroup.Children)
                tab = simTabGroup.Children(i);
                filename = tab.UserData.filename;
                mfile = fullfile(simData_path, [filename '.m']);
                saveTabFile(mfile, tab, settings);
            end
        catch
            % If there was an error, just close the window
            delete(src);
        end
        
        % Close the figure
        delete(src);
    end
    
    % Called to initiate manually draging the fit lines around
    function fitCheckboxCB(src, ~)
        % Determine if we are enabling or disabling the fitline. If we are
        % disabling the line we skip most of the function
        if src.Value == 0       % Disabling the fitline
            delete(src.UserData.fitline);
            return;
        end
        
        % Get the axis boundaries
        xmin = settings.xmin;
        xmax = settings.xmax;
        ymin = settings.ymin;
        ymax = settings.ymax;
        xFactor = settings.xfactor;
        yFactor = settings.yfactor;
        offset = offsetBox.UserData.value;
        edges = [xmin, xmax, ymin, ymax];
        
        % Use existing fit if possible
        iscg = false;
        needDefaultLine = true;
        switch src.Tag
            case 'cg'
                iscg = true;
                recalculateFcn = @recalculateCG;
                
                if ~strcmp(cgBox.String, '')
                    needDefaultLine = false;
                    
                    cg = cgBox.UserData.value;
                    dWidth = q/cg;
                    
                    % Find first node to the right of xmin
                    startingNode = findNodeRight(xmin, offset, dWidth);
                    
                    % Find second node, n periods away
                    n = cgPeriodBox.UserData.value;
                    endingNode = startingNode + n*dWidth;
                    
                    h = imline(dataAxis, [startingNode/xFactor 0;endingNode/xFactor 0]);
                end
            case 'cs'
                recalculateFcn = @recalculateCS;
                % If cg isn't set, set it ourself to 1 aF
                if strcmp(cgBox.String, '')
                    cgBox.String = '1';
                    cgBox.UserData.value = 1/cgBox.UserData.factor;
                end
                
                if ~strcmp(csBox.String, '')
                    needDefaultLine = false;
                    
                    % Find nearest node to the midpoint
                    midpoint = (xmax + xmin)/2;
                    cg = cgBox.UserData.value;
                    cs = csBox.UserData.value;
                    dWidth = q/cg;
                    nodeLeft = findNodeLeft(midpoint, offset, dWidth);
                    nodeRight = findNodeRight(midpoint, offset, dWidth);
                    
                    xpoint = nodeLeft;
                    if (midpoint - nodeLeft) > (nodeRight - midpoint)
                        xpoint = nodeRight;
                    end
                    
                    m = cg / (cg + cs);
                    [xs, ys] = findLine([xpoint 0], m, edges);
                    xs = xs/xFactor;
                    ys = ys/yFactor;
                    
                    h = imline(dataAxis, [xs(1) ys(1);xs(2) ys(2)]);
                end
            case 'cd'
                recalculateFcn = @recalculateCD;
                % If cg isn't set, set it ourself to 1 aF
                if strcmp(cgBox.String, '')
                    cgBox.String = '1';
                    cgBox.UserData.value = 1/cgBox.UserData.factor;
                end
                
                if ~strcmp(cdBox.String, '')
                    needDefaultLine = false;
                    
                    % Find nearest node to the midpoint
                    midpoint = (xmax + xmin)/2;
                    cg = cgBox.UserData.value;
                    cd = cdBox.UserData.value;
                    dWidth = q/cg;
                    nodeLeft = findNodeLeft(midpoint, offset, dWidth);
                    nodeRight = findNodeRight(midpoint, offset, dWidth);
                    
                    xpoint = nodeLeft;
                    if (midpoint - nodeLeft) > (nodeRight - midpoint)
                        xpoint = nodeRight;
                    end
                    
                    m = -cg / cd;
                    [xs, ys] = findLine([xpoint 0], m, edges);
                    xs = xs/xFactor;
                    ys = ys/yFactor;
                    
                    h = imline(dataAxis, [xs(1) ys(1);xs(2) ys(2)]);
                end
            otherwise
                
        end
        
        if needDefaultLine
            % Lets draw a default starting line. It should fill most of the
            % screen
            midpt = (xmax + xmin)/2;
            % If y=0 is on the screen use that point. Otherwise use the screen
            % midpoint
            if ymin <= 0 && ymax >= 0
                ypt = 0;
            else
                ypt = (ymax + ymin)/2;
            end
            width = xmax - xmin;
            left = midpt - 0.4*width;
            right = midpt + 0.4*width;
            h = imline(dataAxis, [left/xFactor ypt/yFactor;right/xFactor ypt/yFactor]);
        end
        
        src.UserData.fitline = h;
        addNewPositionCallback(h, recalculateFcn);
        if iscg
            setPositionConstraintFcn(h, @imlineHorizontalConstraint);
        else
            setPositionConstraintFcn(h, @imlineInsideConstraint);
        end
        
        function constrained_position = imlineInsideConstraint(newPos)
            constrained_position = newPos;
            for i = 1:2
                x = newPos(i,1);
                y = newPos(i,2);
                if x < xmin/xFactor
                    x = xmin/xFactor;
                elseif x > xmax/xFactor
                    x = xmax/xFactor;
                end
                if y < ymin/yFactor;
                    y = ymin/yFactor;
                elseif y > ymax/yFactor
                    y = ymax/yFactor;
                end
                constrained_position(i,1) = x;
                constrained_position(i,2) = y;
            end
        end
        
        function constrained_position = imlineHorizontalConstraint(newPos)
            newPos(:,2) = 0;
            constrained_position = imlineInsideConstraint(newPos);
        end
        
        % Functions to recalculate each of the three parameters
        function recalculateCG(newPos)
            n = cgPeriodBox.UserData.value;
            
            len = abs(newPos(2,1) - newPos(1,1))*settings.xfactor;
            
            cg = n*q/len;
            cgBox.UserData.value = cg;
            cgBox.String = num2str(cg/cgBox.UserData.factor, 3);
            
            x = newPos(1,1)*settings.xfactor;
            dWidth = len/n;
            offset = mod(x+dWidth/2,dWidth);
            if abs(offset) > abs(offset - dWidth)
                offset = offset - dWidth;
            end
            
            offsetBox.UserData.value = offset;
            offsetBox.String = num2str(offset/offsetBox.UserData.factor ,3);
            
            if fitLineCheckbox.Value
                redrawFittingLines();
            end
            
            enableDisableFitCheckbox();
        end
        
        function recalculateCS(newPos)
            m = (newPos(2,2) - newPos(1,2))/(newPos(2,1) - newPos(1,1)) ...
                * (settings.xfactor/settings.yfactor);
            
            cg = cgBox.UserData.value;
            cs = cg/m - cg;
            csBox.UserData.value = cs;
            csBox.String = num2str(cs/csBox.UserData.factor, 3);
            
            if fitLineCheckbox.Value
                redrawFittingLines();
            end
            
            enableDisableFitCheckbox();
        end
        
        function recalculateCD(newPos)
            m = (newPos(2,2) - newPos(1,2))/(newPos(2,1) - newPos(1,1)) ...
                * (settings.xfactor/settings.yfactor);
            cg = cgBox.UserData.value;
            cd = -cg/m;
            cdBox.UserData.value = cd;
            cdBox.String = num2str(cd/cdBox.UserData.factor, 3);
            
            if fitLineCheckbox.Value
                redrawFittingLines();
            end
            
            enableDisableFitCheckbox();
        end
    end
    
    function cgPeriodCallback(src,~)
        [num, status] = str2num(src.String);    %#ok
        if status == 0
            src.String = num2str(src.UserData.value);
            return;
        end
        
        newNum = round(num);
        
        src.String = num2str(newNum);
        src.UserData.value = newNum;
        
        % Only update the Cg box if the fit Cg checkbox is checked
        if fitCgCheckbox.Value
            newPos = fitCgCheckbox.UserData.fitline.getPosition();
            
            len = abs(newPos(2,1) - newPos(1,1))*settings.xfactor;
            
            cg = newNum*q/len;
            cgBox.UserData.value = cg;
            cgBox.String = num2str(cg/cgBox.UserData.factor, 3);
            
            x = newPos(1,1)*settings.xfactor;
            dWidth = len/newNum;
            offset = mod(x+dWidth/2,dWidth);
            if abs(offset) > abs(offset - dWidth)
                offset = offset - dWidth;
            end
            
            offsetBox.UserData.value = offset;
            offsetBox.String = num2str(offset/offsetBox.UserData.factor ,3);
            
            cgBox.UserData.value = cg;
            cgBox.String = cg/cgBox.UserData.factor;
            
            redrawFittingLines();
        end
    end
    
    function dataFileFactorCB(src, ~)
        [num, status] = str2num(src.String);    %#ok
        if status == 0
            src.String = num2str(src.UserData.value);
            return;
        end
        
        oldFactor = src.UserData.value;
        newFactor = num;
        src.UserData.value = newFactor;
        
        
        if isstruct(dataAxis.UserData)
            dataAxis.UserData.Z = dataAxis.UserData.Z * (newFactor/oldFactor);
            refreshDataPlot();
        end
    end
end

%% More helper functions
% point is a 1x2 vector cottaining a point on the line
% m is the slope of the line
% edges is a 4x1 vector of: [xmin, xmax, ymin, ymax]
function [xs, ys] = findLine(point, m, edges)
    % Unpack the parameters
    xmin = edges(1);
    xmax = edges(2);
    ymin = edges(3);
    ymax = edges(4);
    
    % Check each of the 4 edges to find 2 points inside
    nPoints = 0;
    xs = [];
    ys = [];
    % left
    y = verticalWall(point, m, xmin);
    if isin([xmin,y],edges)
        nPoints = nPoints + 1;
        xs(nPoints) = xmin;
        ys(nPoints) = y;
    end
    % right
    y = verticalWall(point, m, xmax);
    if isin([xmax,y],edges)
        nPoints = nPoints + 1;
        xs(nPoints) = xmax;
        ys(nPoints) = y;
    end
    % top
    x = horizontalWall(point, m, ymax);
    if isin([x,ymax],edges)
        nPoints = nPoints + 1;
        xs(nPoints) = x;
        ys(nPoints) = ymax;
    end
    % bottom
    x = horizontalWall(point, m, ymin);
    if isin([x,ymin],edges)
        nPoints = nPoints + 1;
        xs(nPoints) = x;
        ys(nPoints) = ymin;
    end
end

% Determine if the point is inside the boundaries given by edges
function status = isin(point, edges)
    x = point(1);
    y = point(2);
    xmin = edges(1);
    xmax = edges(2);
    ymin = edges(3);
    ymax = edges(4);
    
    status = (x >= xmin) & (x <= xmax) & (y >= ymin) & (y <= ymax);
end

function Y = verticalWall(point, m, X)
    x0 = point(1);
    y0 = point(2);
    
    Y = m*X - m*x0 + y0;
end

function X = horizontalWall(point, m, Y)
    x0 = point(1);
    y0 = point(2);
    
    X = (Y-y0)/m + x0;
end

% These functions find the nearest node on or left/right (respectively) of
% the given point
function node = findNodeLeft(x, offset, dWidth)
    edge = x - offset - dWidth/2;
    node = floor(edge/dWidth)*dWidth + dWidth/2 + offset;
end

function node = findNodeRight(x, offset, dWidth)
    edge = x - offset - dWidth/2;
    node = ceil(edge/dWidth)*dWidth + dWidth/2 + offset;
end

function clearLines(ax)
    for i = length(ax.Children):-1:1
        if strcmp(ax.Children(i).Type, 'line')
            delete(ax.Children(i));
        end
    end
end

% This function deletes all the plots from the specified axis while keeping
% anything else
function deletePlots(ax)
    for i = length(ax.Children):-1:1
        if strcmp(ax.Children(i).Type,'surface')
            delete(ax.Children(i));
        end
    end
end

% This function sorts the elements of an axis so imlines are on top and the
% plot itself is on the bottom
function sortPlotElements(ax)
    
    while true
        for i = 1:length(ax.Children)
            switch ax.Children(i).Type
                case 'hggroup'
                    uistack(ax.Children(i), 'top');
                    continue;
                case 'surface'
                    uistack(ax.Children(i), 'bottom');
                    continue;
            end
        end
        break;
    end
end

% Get the current date and time and use it to build a unique filename for a
% simulation
function filename = makeFileName()
    filename = datestr(datetime(), 'yyyymmmdd_HH.MM.SS');
end

% Calculate the sum of the squared residuals between two datasets.
% If they are of different sizes, Z2 is resampled to match Z1. Therefore,
% Z1 should generally be the measured data and Z2 the simulation data.
function S = calcSquares(Z1, Z2)
    nx1 = size(Z1, 2);
    ny1 = size(Z1, 1);
    nx2 = size(Z2, 2);
    ny2 = size(Z2, 1);
    
    xs1 = linspace(0,1,nx1);
    ys1 = linspace(0,1,ny1);
    xs2 = linspace(0,1,nx2);
    ys2 = linspace(0,1,ny2);
    [X1, Y1] = meshgrid(xs1, ys1);
    [X2, Y2] = meshgrid(xs2, ys2);
    
    Z2_interp = interp2(X2, Y2, Z2, X1, Y1, 'spline');
    
    r = (Z1-Z2_interp).^2;
    S = sum(sum(r));
end

% Set the simulation parameter ui elements either enabled or disabled
% according to the state variable
function enableDisableSimParams(h, state)
    h.sim_cgBox.Enable = state;
    h.sim_csBox.Enable = state;
    h.sim_cdBox.Enable = state;
    h.sim_gsBox.Enable = state;
    h.sim_gdBox.Enable = state;
    h.sim_offsetBox.Enable = state;
    h.sim_tempBox.Enable = state;
    h.runSimButton.Enable = state;
end

function setBox(h, value)
    h.UserData.value = value;
    h.String = num2str(value/h.UserData.factor);
end

function factor = unitsToFactor(units)
    switch units
        case 'aF'
            factor = 1e-18;
        case 'mV'
            factor = 1e-3;
        case 'uS'
            factor = 1e-6;
        case 'K'
            factor = 1;
        case ''
            factor = 1;
        otherwise
            warning(['Unit ''' units ''' not recognized']);
            factor = 1;
    end
end

% Save the specified tab's data in an .m file
function saveTabFile(mfile, tab, settings)
    h = tab.UserData.h;
    
    data.tabname = tab.Title;
    
    data.cg = h.oldSim_cg.UserData.value;
    data.cs = h.oldSim_cs.UserData.value;
    data.cd = h.oldSim_cd.UserData.value;
    data.gs = h.oldSim_gs.UserData.value;
    data.gd = h.oldSim_gd.UserData.value;
    data.offset = h.sim_offsetBox.UserData.value;
    data.temp = h.sim_tempBox.UserData.value;
    
    data.xmin = settings.xmin;
    data.xmax = settings.xmax;
    data.ymin = settings.ymin;
    data.ymax = settings.ymax;
    data.zmin = h.sim_zminBox.UserData.value;
    data.zmax = h.sim_zmaxBox.UserData.value;   %#ok  it is saved on the next line
    
    save(mfile, '-struct', 'data');
end


