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