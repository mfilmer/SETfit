% Try to automatically calculate Cg given
% Z: Matrix containing coulomb diamonds. Rows -> Vd, Cols -> Vg
% vgs: Vector of the values of Vg that correspond to the columns of Z
% vds: Vector of the values of Vd that correspond to the rows of Z
function Cg = calculateCg(Z, vgs, vds)
    % Constants
    q = 1.602e-19;      % Coulombs
    
    % Get the row closest to Vd = 0
    vdIndex = round(interp1(vds, 1:length(vds), 0, 'pchip'));
    
    C = xcorr(Z(vdIndex, :));
    [value, locs] = findpeaks(C);
    
    i1 = find(value == max(value),1);
    
    value(i1) = 0;
    i2 = find(value == max(value),1);
    i3 = i1 + 2*(i2 - i1);
    
    is = sort([i1 i2 i3]);
    i1 = is(1);
    i2 = is(2);
    i3 = is(3);
    
    p1 = locs(i3) - locs(i2);
    p2 = locs(i2) - locs(i1);
    period = (p2 + p1)/2;
    
    vg_step = vgs(2) - vgs(1);
    
    Cg = q/(period*vg_step);
end