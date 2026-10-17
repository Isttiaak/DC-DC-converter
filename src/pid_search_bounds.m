function [lb, ub, info] = pid_search_bounds(P, Nf)
%PID_SEARCH_BOUNDS  Search box for [Kp Ki Kd], derived from the plant.
%
%   [lb, ub, info] = pid_search_bounds(P, Nf)
%
%   Worst case = lowest input voltage (largest duty, lowest RHP zero):
%     D  = 1 - Vin/(Vref + Vf)
%     G0 = Vin/(1-D)^2        duty-to-output-voltage gain [V]
%     wz = R*(1-D)^2/L        right-half-plane zero [rad/s]
%   Bounds
%     0 <= Kp <= 0.5/Vref         P action alone gives at most 50 % duty at start-up
%     0 <= Ki <= wz/G0            integral crossover not above the RHP zero
%     0 <= Kd <= 0.5/(Nf*Vref)    derivative kick alone at most 50 % duty at start-up
%   Both optimisers (PSO and GWO) use this same box.

if nargin < 2 || isempty(Nf), Nf = 100; end
Vin = min(P.Vin0, P.Vin1);
D   = min(max(1 - Vin / (P.Vref + P.Vf), 0.05), 0.95);
G0  = Vin / (1 - D)^2;
wz  = P.R * (1 - D)^2 / P.L;
lb  = [0, 0, 0];
ub  = [0.5 / P.Vref, wz / G0, 0.5 / (Nf * P.Vref)];
info = struct('D', D, 'G0', G0, 'wz', wz);
end
