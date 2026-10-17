function [K, info] = zn_pid(P, Nf)
%ZN_PID  Conventional PID by the Ziegler-Nichols ultimate-gain rules.
%
%   [K, info] = zn_pid(P, Nf) returns K = [Kp Ki Kd Nf].
%
%   The ultimate gain Ku and period Tu are computed from the small-signal
%   duty-to-output-voltage transfer function of the boost converter at the
%   lowest input voltage (worst case, lowest RHP zero):
%
%       Gvd(s) = G0 * (1 - s/wz) / (1 + s/(Q*w0) + s^2/w0^2)
%       G0 = Vin/(1-D)^2,  wz = R*(1-D)^2/L,  w0 = (1-D)/sqrt(L*C),
%       Q  = (1-D)*R*sqrt(C/L),  D = 1 - Vin/(Vref + Vf)
%
%   wu solves angle(Gvd(j*wu)) = -180 deg, Ku = 1/|Gvd(j*wu)|, Tu = 2*pi/wu.
%   Classic Ziegler-Nichols PID:
%       Kp = 0.6*Ku,  Ti = Tu/2,  Td = Tu/8  ->  Ki = Kp/Ti,  Kd = Kp*Td
%   The derivative uses the same first-order filter Nf as the other
%   controllers (default 100 rad/s), so all three PIDs share one structure.

if nargin < 2 || isempty(Nf), Nf = 100; end
Vin = min(P.Vin0, P.Vin1);
D   = min(max(1 - Vin / (P.Vref + P.Vf), 0.05), 0.95);
G0  = Vin / (1 - D)^2;
wz  = P.R * (1 - D)^2 / P.L;
w0  = (1 - D) / sqrt(P.L * P.C);
Q   = (1 - D) * P.R * sqrt(P.C / P.L);

phase = @(w) -atan(w / wz) - atan2(w / (Q * w0), 1 - (w / w0).^2);   % continuous, rad
mag   = @(w) G0 * sqrt(1 + (w / wz).^2) ./ sqrt((1 - (w / w0).^2).^2 + (w / (Q * w0)).^2);

wu = fzero(@(w) phase(w) + pi, [w0 / 100, 100 * max(w0, wz)]);
Ku = 1 / mag(wu);
Tu = 2 * pi / wu;

Kp = 0.6 * Ku;
Ti = Tu / 2;
Td = Tu / 8;
K  = [Kp, Kp / Ti, Kp * Td, Nf];

info = struct('Ku', Ku, 'Tu', Tu, 'wu', wu, 'D', D, 'G0', G0, 'wz', wz, ...
    'w0', w0, 'Q', Q, 'Ti', Ti, 'Td', Td);
end
