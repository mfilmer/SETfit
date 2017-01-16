function [finalZ, bestParams] = iterationSolver(measuredZ, simZ, limits, startingParams)
    
    % Order of solving:
    % Gs and Gd Together, proportionally
    % Gs and Gd separate
    % Cg
    % Cs
    % Cd
    % T
    
    %% Create Window
    figWidth = 1200;      % Pixels
    figHeight = 610;     % Pixels
    figCenter = figWidth/2;
    fig = figure('Position', [125,20,figWidth,figHeight]);
    fig.MenuBar = 'none';
    %fig.CloseRequestFcn = @figureCloseCB;
    
    % Create the main panels
    bottomMargin = 40;         % Pixels
    dataPanel = uipanel(fig, 'Units', 'pixels', ...
        'Position', [0,bottomMargin,figCenter,figHeight-bottomMargin-30]);
    settingsPanel = uipanel(fig, 'Units', 'pixels', ...
        'Position', [0,0,figWidth,bottomMargin]);
    simTabGroup = uitabgroup('Parent', fig, 'Units', 'pixels', ...
        'Position', [figCenter,bottomMargin,figCenter,figHeight-bottomMargin]);
    
    % Create tabs
    fitTab = uitab('Parent', simTabGroup, 'Title', 'Fit');
    gTab = uitab('Parent', simTabGroup, 'Title', 'G');
    cgTab = uitab('Parent', simTabGroup, 'Title', 'Cg');
    cTab = uitab('Parent', simTabGroup, 'Title', 'Cs & Cd');
    tTab = uitab('Parent', simTabGroup, 'Title', 'T');
    
    fitAxis = axes('Parent', fitTab, 'OuterPosition', [0,0,1,1]);
    gAxis = axes('Parent', gTab, 'OuterPosition', [0,0,1,1]);
    cgAxis = axes('Parent', cgTab, 'OuterPosition', [0,0,1,1]);
    cAxis = axes('Parent', cTab, 'OuterPosition', [0,0,1,1]);
    tAxis = axes('Parent', tTab, 'OuterPosition', [0,0,1,1]);
    
    % Create main plot axis
    dataAxis = axes('Parent', dataPanel, 'Visible', 'on', ...
        'OuterPosition', [0,0,1,1]);
    xs = linspace(limits(1)*1e3,limits(2)*1e3,101);
    ys = linspace(limits(3)*1e3,limits(4)*1e3,101);
    [X,Y] = meshgrid(xs,ys);
    pcolor(dataAxis, X,Y,simZ*1e6);
    shading(dataAxis, 'interp');
    xlabel('V_G [mV]');
    ylabel('V_D [mV]');
    h = colorbar(dataAxis);
    ylabel(h, 'G [uS]');
    colormap jet;
    caxis(dataAxis, limits(5:6)*1e6);
    
    % Current value labels
    boxWidth = 30;
    fitBox = labelBox(settingsPanel, 'Fit', '', [figWidth - 100,10,boxWidth,20]);
    gdBox = labelBox(settingsPanel, 'Gd', 'uS', [680,10,boxWidth,20]);
    gsBox = labelBox(settingsPanel, 'Gs', 'uS', [580,10,boxWidth,20]);
    cdBox = labelBox(settingsPanel, 'Cd', 'aF', [480,10,boxWidth,20]);
    csBox = labelBox(settingsPanel, 'Cs', 'aF', [380,10,boxWidth,20]);
    offsetBox = labelBox(settingsPanel, 'Offset', 'mV', [270,10,boxWidth,20]);
    cgBox = labelBox(settingsPanel, 'Cg', 'aF', [150,10,boxWidth,20]);
    tBox = labelBox(settingsPanel, 'T', 'K', [50,10,boxWidth,20]);
    
    setBox(cgBox, startingParams.Cg);
    setBox(offsetBox, startingParams.offset);
    setBox(csBox, startingParams.Cs);
    setBox(cdBox, startingParams.Cd);
    setBox(gsBox, startingParams.Gs);
    setBox(gdBox, startingParams.Gd);
    setBox(tBox, startingParams.T);
    
    % Other initial setup
    simFile = tempname;
    bestParams = startingParams;
    testParams = startingParams;
    startingFactor = 0.1;
    gCorrFactor = startingFactor; gCorrMomentum = false;
    gUnCorrFactor = startingFactor; gUnCorrMomentum = false;
    cgFactor = startingFactor; cgMomentum = false;
    csFactor = startingFactor; csMomentum = false;
    cdFactor = startingFactor; cdMomentum = false;
    tFactor = startingFactor; tMomentum = false;
    offsetFactor = startingFactor; offsetMomentum = false;
    
    
    % Simulate initial parameters
    %bestZ = runSim(startingParams);
    
    % Initial parameters were passed in
    bestZ = simZ;
    bestSqu = calcSquares(measuredZ*1e6, bestZ*1e6);
    setBox(fitBox, bestSqu);
    disp(['Starting fit: ' num2str(bestSqu,3)]);
    history = struct('fit',bestSqu,'cg',bestParams.Cg,'cs',...
        bestParams.Cs,'cd',bestParams.Cd,'t',bestParams.T,...
        'offset',bestParams.offset,'gs',bestParams.Gs,'gd',bestParams.Gd);
    
    % Main loop
    while (startingParams.fitG && abs(gCorrFactor) > 0.0001) || ...
            (startingParams.fitG && abs(gUnCorrFactor) > 0.0001) || ...
            (startingParams.fitOffset && abs(offsetFactor) > 0.0001) || ...
            (startingParams.fitCg && abs(cgFactor) > 0.0001) || ...
            (startingParams.fitCs && abs(csFactor) > 0.0001) || ...
            (startingParams.fitCd && abs(cdFactor) > 0.0001) || ...
            (startingParams.fitT && abs(tFactor) > 0.0001)
        % Optimize Gs and Gd together
        if startingParams.fitG && abs(gCorrFactor) > 0.0001
            updateGCorr = false;
            testParams.Gs = bestParams.Gs * (1+gCorrFactor);
            testParams.Gd = bestParams.Gd * (1+gCorrFactor);
            testZ = runSim(testParams, limits);
            testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             gsSlope = (testSqu - bestSqu)/(gCorrFactor*bestParams.Gs);
            %             gdSlope = (testSqu - bestSqu)/(gCorrFactor*bestParams.Gd);
            if testSqu < bestSqu
                bestSqu = testSqu;
                bestZ = testZ;
                bestParams = testParams;
                updateGCorr = true;
                gCorrMomentum = true;
            end
            
            testParams = bestParams;
            %             testParams.Gs = testParams.Gs - testSqu/(gsSlope);
            %             testParams.Gd = testParams.Gd - testSqu/(gdSlope);
            %             testZ = runSim(testParams, limits);
            %             testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             if testSqu < bestSqu
            %                 bestSqu = testSqu;
            %                 bestZ = testZ;
            %                 bestParams = testParams;
            %                 updateGCorr = true;
            %             end
            
            disp(['Gs & Gd together fit: ' num2str(bestSqu, 3)]);
            disp(['gCorrFactor: ' num2str(gCorrFactor, 3)]);
            disp(['Gs: ' num2str(bestParams.Gs*1e6,3)]);
            disp(['Gd: ' num2str(bestParams.Gd*1e6,3)]);
            pcolor(dataAxis, X,Y,bestZ*1e6);
            shading(dataAxis, 'interp');
            xlabel('V_G [mV]');
            ylabel('V_D [mV]');
            h = colorbar(dataAxis);
            ylabel(h, 'G [uS]');
            colormap jet;
            caxis(dataAxis, limits(5:6)*1e6);
            setBox(gsBox, bestParams.Gs);
            setBox(gdBox, bestParams.Gd);
            setBox(fitBox, bestSqu);
            drawnow;
            
            if ~updateGCorr
                if gCorrFactor > 0 && ~gCorrMomentum
                    gCorrFactor = -gCorrFactor;
                else
                    gCorrFactor = -gCorrFactor/2;
                end
                gCorrMomentum = false;
            end
        end
        
        
        % Optimize Gs and Gd separate
        if startingParams.fitG && abs(gUnCorrFactor) > 0.0001
            updateGUnCorr = false;
            testParams.Gs = bestParams.Gs * (1+gUnCorrFactor);
            testParams.Gd = bestParams.Gd * (1-gUnCorrFactor);
            testZ = runSim(testParams, limits);
            testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             gsSlope = (testSqu - bestSqu)/(gUnCorrFactor*bestParams.Gs);
            %             gdSlope = (testSqu - bestSqu)/(gUnCorrFactor*testParams.Gd);
            if testSqu < bestSqu
                bestSqu = testSqu;
                bestZ = testZ;
                bestParams = testParams;
                updateGUnCorr = true;
                gUnCorrMomentum = true;
            end
            
            testParams = bestParams;
            %             testParams.Gs = testParams.Gs - testSqu/(gsSlope);
            %             testParams.Gd = testParams.Gd + testSqu/(gdSlope);
            %             testZ = runSim(testParams, limits);
            %             testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             if testSqu < bestSqu
            %                 bestSqu = testSqu;
            %                 bestZ = testZ;
            %                 bestParams = testParams;
            %                 updateGUnCorr = true;
            %             end
            
            disp(['Gs & Gd separate fit: ' num2str(bestSqu, 3)]);
            disp(['gUnCorrFactor: ' num2str(gUnCorrFactor,3)]);
            disp(['Gs: ' num2str(bestParams.Gs*1e6,3)]);
            disp(['Gd: ' num2str(bestParams.Gd*1e6,3)]);
            pcolor(dataAxis, X,Y,bestZ*1e6);
            shading(dataAxis, 'interp');
            xlabel('V_G [mV]');
            ylabel('V_D [mV]');
            h = colorbar(dataAxis);
            ylabel(h, 'G [uS]');
            colormap jet;
            caxis(dataAxis, limits(5:6)*1e6);
            setBox(gsBox, bestParams.Gs);
            setBox(gdBox, bestParams.Gd);
            setBox(fitBox, bestSqu);
            drawnow;
            
            if ~updateGUnCorr
                if gUnCorrFactor > 0 && ~gUnCorrMomentum
                    gUnCorrFactor = -gUnCorrFactor;
                else
                    gUnCorrFactor = -gUnCorrFactor/2;
                end
                gUnCorrMomentum = false;
            end
        end
        
        % Optimize Offset
        if startingParams.fitOffset && abs(offsetFactor) > 0.0001
            updateOffset = false;
            if testParams.offset == 0
                testParams.offset = offsetFactor;
            else
                testParams.offset = bestParams.offset * (1+offsetFactor);
            end
            testZ = runSim(testParams, limits);
            testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             slope = (testSqu - bestSqu)/(offsetFactor*bestParams.offset);
            if testSqu < bestSqu
                bestSqu = testSqu;
                bestZ = testZ;
                bestParams = testParams;
                updateOffset = true;
                offsetMomentum = true;
            end
            
            testParams = bestParams;
            %             testParams.offset = testParams.offset - testSqu/(slope);
            %             testZ = runSim(testParams, limits);
            %             testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             if testSqu < bestSqu
            %                 bestSqu = testSqu;
            %                 bestZ = testZ;
            %                 bestParams = testParams;
            %                 updateOffset = true;
            %             end
            
            disp(['Offset fit: ' num2str(bestSqu, 3)]);
            disp(['offsetFactor: ' num2str(offsetFactor,3)]);
            disp(['Offset: ' num2str(bestParams.offset*1e3,3)]);
            pcolor(dataAxis, X,Y,bestZ*1e6);
            shading(dataAxis, 'interp');
            xlabel('V_G [mV]');
            ylabel('V_D [mV]');
            h = colorbar(dataAxis);
            ylabel(h, 'G [uS]');
            colormap jet;
            caxis(dataAxis, limits(5:6)*1e6);
            setBox(offsetBox, bestParams.offset);
            setBox(fitBox, bestSqu);
            drawnow;
            
            if ~updateOffset
                if offsetFactor > 0 && ~offsetMomentum
                    offsetFactor = -offsetFactor;
                else
                    offsetFactor = -offsetFactor/2;
                end
                offsetMomentum = false;
            end
        end
        
        % Optimize Cg
        if startingParams.fitCg && abs(cgFactor) > 0.0001
            updateCg = false;
            testParams.Cg = bestParams.Cg * (1+cgFactor);
            testZ = runSim(testParams, limits);
            testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             slope = (testSqu - bestSqu)/(cgFactor*bestParams.Cg);
            if testSqu < bestSqu
                bestSqu = testSqu;
                bestZ = testZ;
                bestParams = testParams;
                updateCg = true;
                cgMomentum = true;
            end
            
            testParams = bestParams;
            %             testParams.Cg = testParams.Cg - testSqu/(slope);
            %             testZ = runSim(testParams, limits);
            %             testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             if testSqu < bestSqu
            %                 bestSqu = testSqu;
            %                 bestZ = testZ;
            %                 bestParams = testParams;
            %                 updateCg = true;
            %             end
            
            disp(['Cg fit: ' num2str(bestSqu, 3)]);
            disp(['cgFactor: ' num2str(cgFactor,3)]);
            disp(['Cg: ' num2str(bestParams.Cg*1e18,3)]);
            pcolor(dataAxis, X,Y,bestZ*1e6);
            shading(dataAxis, 'interp');
            xlabel('V_G [mV]');
            ylabel('V_D [mV]');
            h = colorbar(dataAxis);
            ylabel(h, 'G [uS]');
            colormap jet;
            caxis(dataAxis, limits(5:6)*1e6);
            setBox(cgBox, bestParams.Cg);
            setBox(fitBox, bestSqu);
            drawnow;
            
            if ~updateCg
                if cgFactor > 0 && ~cgMomentum
                    cgFactor = -cgFactor;
                else
                    cgFactor = -cgFactor/2;
                end
                cgMomentum = false;
            end
        end
        
        % Optimize Cs
        if startingParams.fitCs && abs(csFactor) > 0.0001
            updateCs = false;
            testParams.Cs = bestParams.Cs * (1+csFactor);
            testZ = runSim(testParams, limits);
            testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             slope = (testSqu - bestSqu)/(csFactor*bestParams.Cs);
            if testSqu < bestSqu
                bestSqu = testSqu;
                bestZ = testZ;
                bestParams = testParams;
                updateCs = true;
                csMomentum = true;
            end
            
            testParams = bestParams;
            %             testParams.Cs = testParams.Cs - testSqu/(slope);
            %             testZ = runSim(testParams, limits);
            %             testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             if testSqu < bestSqu
            %                 bestSqu = testSqu;
            %                 bestZ = testZ;
            %                 bestParams = testParams;
            %                 updateCs = true;
            %             end
            
            disp(['Cs fit: ' num2str(bestSqu, 3)]);
            disp(['csFactor: ' num2str(csFactor,3)]);
            disp(['Cs: ' num2str(bestParams.Cs*1e18,3)]);
            pcolor(dataAxis, X,Y,bestZ*1e6);
            shading(dataAxis, 'interp');
            xlabel('V_G [mV]');
            ylabel('V_D [mV]');
            h = colorbar(dataAxis);
            ylabel(h, 'G [uS]');
            colormap jet;
            caxis(dataAxis, limits(5:6)*1e6);
            setBox(csBox, bestParams.Cs);
            setBox(fitBox, bestSqu);
            drawnow;
            
            if ~updateCs
                if csFactor > 0 && ~csMomentum
                    csFactor = -csFactor;
                else
                    csFactor = -csFactor/2;
                end
                csMomentum = false;
            end
        end
        
        % Optimize Cd
        if startingParams.fitCd && abs(tFactor) > 0.0001
            updateCd = false;
            testParams.Cd = bestParams.Cd * (1+cdFactor);
            testZ = runSim(testParams, limits);
            testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             slope = (testSqu - bestSqu)/(cdFactor*bestParams.Cd);
            if testSqu < bestSqu
                bestSqu = testSqu;
                bestZ = testZ;
                bestParams = testParams;
                updateCd = true;
                cdMomentum = true;
            end
            
            testParams = bestParams;
            %             testParams.Cd = testParams.Cd - testSqu/(slope);
            %             testZ = runSim(testParams, limits);
            %             testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             if testSqu < bestSqu
            %                 bestSqu = testSqu;
            %                 bestZ = testZ;
            %                 bestParams = testParams;
            %                 updateCd = true;
            %             end
            
            disp(['Cd fit: ' num2str(bestSqu, 3)]);
            disp(['cdFactor: ' num2str(cdFactor, 3)]);
            disp(['Cd: ' num2str(bestParams.Cd*1e18,3)]);
            pcolor(dataAxis, X,Y,bestZ*1e6);
            shading(dataAxis, 'interp');
            xlabel('V_G [mV]');
            ylabel('V_D [mV]');
            h = colorbar(dataAxis);
            ylabel(h, 'G [uS]');
            colormap jet;
            caxis(dataAxis, limits(5:6)*1e6);
            setBox(cdBox, bestParams.Cd);
            setBox(fitBox, bestSqu);
            drawnow;
            
            if ~updateCd
                if cdFactor > 0 && ~cdMomentum
                    cdFactor = -cdFactor;
                else
                    cdFactor = -cdFactor/2;
                end
                cdMomentum = false;
            end
        end
        
        
        % Optimize T
        if startingParams.fitT && abs(tFactor) > 0.0001
            updateT = false;
            testParams.T = bestParams.T * (1+tFactor);
            testZ = runSim(testParams, limits);
            testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             slope = (testSqu - bestSqu)/(tFactor*bestParams.T);
            if testSqu < bestSqu
                bestSqu = testSqu;
                bestZ = testZ;
                bestParams = testParams;
                updateT = true;
                tMomentum = true;
            end
            
            testParams = bestParams;
            %             testParams.T = testParams.T - testSqu/(slope);
            %             testZ = runSim(testParams, limits);
            %             testSqu = calcSquares(measuredZ*1e6, testZ*1e6);
            %             if testSqu < bestSqu
            %                 bestSqu = testSqu;
            %                 bestZ = testZ;
            %                 bestParams = testParams;
            %                 updateT = true;
            %             end
            
            disp(['T fit: ' num2str(bestSqu, 3)]);
            disp(['tFactor: ' num2str(tFactor,3)]);
            disp(['T: ' num2str(bestParams.T,3)]);
            pcolor(dataAxis, X,Y,bestZ*1e6);
            shading(dataAxis, 'interp');
            xlabel('V_G [mV]');
            ylabel('V_D [mV]');
            h = colorbar(dataAxis);
            ylabel(h, 'G [uS]');
            colormap jet;
            caxis(dataAxis, limits(5:6)*1e6);
            setBox(tBox, bestParams.T);
            setBox(fitBox, bestSqu);
            drawnow;
            
            if ~updateT
                if tFactor > 0 && ~tMomentum
                    tFactor = -tFactor;
                else
                    tFactor = -tFactor/2;
                end
                tMomentum = false;
            end
        end
        
        % Update history and display
        history.fit(end+1) = bestSqu;
        history.cg(end+1) = bestParams.Cg;
        history.cs(end+1) = bestParams.Cs;
        history.cd(end+1) = bestParams.Cd;
        history.t(end+1) = bestParams.T;
        history.offset(end+1) = bestParams.offset;
        history.gs(end+1) = bestParams.Gs;
        history.gd(end+1) = bestParams.Gd;
        
        xs = 0:(length(history.fit)-1);
        
        semilogy(fitAxis,xs,history.fit);
        xlabel(fitAxis,'Iterations');
        ylabel(fitAxis, 'Squares');
        
        xlabel(cgAxis, 'Iterations');
        yyaxis(cgAxis, 'left');
        plot(cgAxis,xs,history.cg*1e18);
        ylabel(cgAxis,'Cg [aF]');
        yyaxis(cgAxis, 'right');
        plot(cgAxis,xs,history.offset*1e3);
        ylabel(cgAxis,'Offset [mV]');
        
        plot(cAxis,xs,history.cs*1e18,xs,history.cd*1e18);
        xlabel(cAxis,'Iterations');
        ylabel(cAxis,'C [aF]');
        legend(cAxis, 'Cs', 'Cd', 'Location', 'northwest');
        
        plot(tAxis,xs,history.t);
        xlabel(tAxis, 'Iterations');
        ylabel(tAxis, 'T [K]');
        
        plot(gAxis,xs,history.gs*1e6,xs,history.gd*1e6);
        xlabel(gAxis, 'Iterations');
        ylabel(gAxis, 'G [uS]');
        legend(gAxis, 'Gs', 'Gd', 'Location', 'northwest');
        
        drawnow;
    end
    
    finalZ = bestZ;
    
    function Z = runSim(P, limits)
        Z = runSimMain(simFile, P.Cg,P.Cs,P.Cd,P.Gs,P.Gd,P.offset,P.T,limits(1),limits(2),limits(3),limits(4));
    end
end

function Z = runSimMain(simFile, Cg,Cs,Cd,Gs,Gd,offset,T,vgs_min,vgs_max,vds_min,vds_max)
    python_path = 'C:\Python27_32\python.exe';
    simulator_path = 'SETsimulator\guidiamonds.py';
    
    % Constants
    G0 = 7.7480917346e-5;   % Conductance quantum in Siemens;
    q = 1.602e-19;          % Coulombs
    
    % Vds conversion
    vds_start = num2str(vds_min * 1e3);   % mV
    vds_end = num2str(vds_max * 1e3);     % mV
    numVdspoints = num2str(101 + 1);    % Note, for some reason the simulator runs one less point than requested for this parameter
    
    % Make capacitances strings
    Cs = num2str(Cs);
    Cd = num2str(Cd);
    Gs = num2str(Gs/G0);
    Gd = num2str(Gd/G0);
    
    % Shift the simulated Vgs values by n*q/Cg to try and center (as
    % close as possible) around Vg = 0. This will minimize the number
    % of electrons we need to simulate. Then calculate how many
    % electrons we need to simulate.
    start = vgs_min - offset;
    stop = vgs_max - offset;
    center = (start + stop)/2;
    period = q/Cg;
    pShift = round(center/period)*period;
    start = start - pShift;
    stop = stop - pShift;
    
    % Vg string conversion
    vg_start = num2str(start * 1e3);   % mV
    vg_end = num2str(stop * 1e3);     % mV
    num_e = ceil((stop-start)/(period*2)) + 1;
    num_e = num2str(num_e);
    numVgpoints = num2str(101);
    Cg = num2str(Cg);
    T = num2str(T);
    
    % Run the python simulator
    command=[python_path ' ' simulator_path ' ' T ' ' vds_start ' ' vds_end ' ' ...
        numVdspoints ' ' Cs ' ' Cd ' ' Gs ' ' Gd ' ' num_e ' '...
        vg_start ' ' vg_end ' ' numVgpoints ' ' Cg ' ' simFile];
    [~,~] = system(command);
    Z = load(simFile);
end

function dataHandle = labelBox(parent, label, units, pVec)
    % Constants
    lw = 70;
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
            'String', [label ':']);
    else
        uicontrol(parent, 'Style', 'text', 'HorizontalAlignment', 'right', ...
            'Units', 'pixels', 'Position', [pVec(1)-lw-2, pVec(2), lw, h], ...
            'String', [label ' [' units ']' ':']);
    end
    
    % Store data
    dataHandle.UserData.factor = factor;
    dataHandle.UserData.value = 0;
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

function setBox(h, value, varargin)
    if nargin > 2
        sigFigs = varargin{1};
    else
        sigFigs = 3;
    end
    h.UserData.value = value;
    h.String = num2str(value/h.UserData.factor, sigFigs);
end
