function [J, M, S] = boost_pid_cost(K, P, c)
%BOOST_PID_COST  GWO fitness of PID gains for the DC-DC boost converter.
%
%   [J, M, S] = boost_pid_cost(K, P, c)
%
%   K   n-by-3 gains [Kp Ki Kd], one row per wolf (n-by-4 adds Nf)
%   P   plant / scenario struct from boost_read_params
%   c   cost options (any missing field takes the default below)
%
%   J   n-by-1 cost, lower is better
%   M   struct of n-by-1 performance metrics on the nominal plant:
%       ITAE1/ITAE2, IAE1/IAE2, ISE1/ISE2, ITSE1/ITSE2   per event
%       OS1 (start-up overshoot, %), Mp2 (peak deviation after the line step, %)
%       Ts1/Ts2 (settling time, s), Ess1/Ess2 (mean |e| at the end of each
%       window, V), ILpk1/ILpk2 (peak inductor current, A), feasible (logical)
%   S   (only for n = 1) traces of the nominal response for plotting:
%       S.t, S.vout, S.iL, S.d, S.Vin  (one point per switching period)
%
%   Test scenario = the Simulink test with the idle time cut out:
%     event 1  start-up from iL = vC = 0 at Vin = P.Vin0 (window c.Twin)
%     event 2  Vin steps to P.Vin1 (window c.Twin), continuing from event 1
%
%   Plant model = state-space averaged boost converter (CCM; diode Vf and
%   on-resistances; iL >= 0 because the diode blocks reverse current), with
%   exactly the controller of the .slx:
%       e = Vref - vout
%       u = Kp*e + I + Kd*Nf*(e - z),  dI/dt = Ki*e (I limited), dz/dt = Nf*(e - z)
%       duty = sat(u), held for one switching period (PWM update)
%   Integration: classic RK4, c.nSub steps per switching period. All wolves
%   (and all robustness variants) are simulated together as vectors.
%
%   Cost (per wolf)
%     Jobj = objective of event 1 + objective of event 2, where the objective
%            is c.objective = 'ITAE' | 'IAE' | 'ISE' | 'ITSE'
%            (time is measured from each event)
%     J    = Jobj * (1 + c.wOS * max(0, OS1 - c.osMax))
%            OS1 = start-up overshoot (fraction); with the default
%            wOS = 100 every 1 % above osMax doubles the cost
%     robust (c.robust = true): the wolf is simulated on the nominal plant
%            and on every [L C] scaling in c.variants; the WORST J counts,
%            which keeps the gains away from the start-up latch-up region
%     infeasible (latched / unstable / not settled within the window /
%            non-finite): J = c.penalty * (1 + Jobj)
%
%   Options c (defaults)
%     Twin      0.5      evaluation window per event [s]
%     nSub      2        RK4 steps per switching period
%     Nf        100      derivative filter coefficient when K has 3 columns
%     objective 'ITAE'
%     osMax     0.02     allowed start-up overshoot (fraction)
%     wOS       100      overshoot penalty weight
%     robust    true
%     variants  [1.2 1.2; 0.8 0.8; 1.2 0.8; 0.8 1.2]   [L C] multipliers
%     band      0.02     settling band (fraction of Vref)
%     essTol    0.02     |e| at window end above this (fraction of Vref)
%                        marks the wolf infeasible
%     penalty   1e3

if nargin < 3 || isempty(c), c = struct(); end
c = costDefaults(c);
P = plantDefaults(P);

n = size(K, 1);
Kp = K(:, 1);  Ki = K(:, 2);  Kd = K(:, 3);
if size(K, 2) >= 4
    Nf = K(:, 4);
else
    Nf = c.Nf * ones(n, 1);
end

% ---- plant variants (nominal first) -------------------------------------
V = [1 1];
if c.robust && ~isempty(c.variants)
    V = [V; c.variants];
end
nv = size(V, 1);
G.Kp = repmat(Kp, nv, 1);   G.Ki = repmat(Ki, nv, 1);
G.Kd = repmat(Kd, nv, 1);   G.Nf = repmat(Nf, nv, 1);
G.L  = kron(V(:, 1), ones(n, 1)) * P.L;
G.C  = kron(V(:, 2), ones(n, 1)) * P.C;
m = n * nv;

% ---- scenario ------------------------------------------------------------
if P.tStep > 0
    vin1 = P.Vin0;
    T1 = min([P.tStep, P.Tstop, c.Twin]);
else
    vin1 = P.Vin1;                       % the step happens at t = 0
    T1 = min(P.Tstop, c.Twin);
end
hasEvent2 = P.tStep > 0 && P.tStep < P.Tstop;
T2 = min(P.Tstop - P.tStep, c.Twin);

record = nargout > 2 && n == 1;
x0 = [P.iL0 * ones(m, 1), P.vC0 * ones(m, 1), zeros(m, 1), zeros(m, 1)];

[W1, x, S1] = simWindow(x0, vin1, T1, P, G, c, record);
if hasEvent2
    [W2, ~, S2] = simWindow(x, P.Vin1, T2, P, G, c, record);
else
    W2 = emptyWindow(m);
    S2 = struct('t', [], 'vout', [], 'iL', [], 'd', [], 'Vin', []);
end

% ---- cost per simulated plant ---------------------------------------------
switch upper(c.objective)
    case 'ITAE', Jobj = W1.ITAE + W2.ITAE;
    case 'IAE',  Jobj = W1.IAE  + W2.IAE;
    case 'ISE',  Jobj = W1.ISE  + W2.ISE;
    case 'ITSE', Jobj = W1.ITSE + W2.ITSE;
    otherwise
        error('boost_pid_cost:objective', 'Unknown objective "%s".', c.objective);
end
OS1 = max(0, W1.vmax - P.Vref) / P.Vref;
Jall = Jobj .* (1 + c.wOS * max(0, OS1 - c.osMax));

tol = c.essTol * P.Vref;
bad = ~isfinite(Jobj) | ~isfinite(W1.Ess) | ~isfinite(W2.Ess) | ...
      W1.Ess > tol | W2.Ess > tol;
Jall(bad) = c.penalty * (1 + min(Jobj(bad), 1e12));
Jall(~isfinite(Jall)) = c.penalty * 1e12;

% worst case over the plant variants
Jall = reshape(Jall, n, nv);
J = max(Jall, [], 2);

% ---- metrics of the nominal plant (first n entries) ---------------------
if nargout > 1
    k = 1:n;
    M = struct();
    M.ITAE1 = W1.ITAE(k);  M.ITAE2 = W2.ITAE(k);
    M.IAE1  = W1.IAE(k);   M.IAE2  = W2.IAE(k);
    M.ISE1  = W1.ISE(k);   M.ISE2  = W2.ISE(k);
    M.ITSE1 = W1.ITSE(k);  M.ITSE2 = W2.ITSE(k);
    M.OS1   = 100 * OS1(k);
    M.Mp2   = 100 * W2.emax(k) / P.Vref;
    M.Ts1   = W1.Ts(k);    M.Ts2   = W2.Ts(k);
    M.Ess1  = W1.Ess(k);   M.Ess2  = W2.Ess(k);
    M.ILpk1 = W1.ILpk(k);  M.ILpk2 = W2.ILpk(k);
    M.feasible = ~reshape(any(reshape(bad, n, nv), 2), n, 1);
    M.Jnominal = Jall(:, 1);
end
if record
    t2 = S2.t;
    if ~isempty(t2), t2 = t2 + S1.t(end); end
    S = struct('t', [S1.t; t2], 'vout', [S1.vout; S2.vout], 'iL', [S1.iL; S2.iL], ...
               'd', [S1.d; S2.d], 'Vin', [S1.Vin; S2.Vin], 'tEvent2', S1.t(end));
elseif nargout > 2
    S = [];
end
end

% =========================================================================
function [W, x, S] = simWindow(x, Vin, T, P, G, c, record)
% Integrate one event window for all m simulated plants at once.
Tsw = 1 / P.fsw;
nP  = max(1, round(T / Tsw));
h   = Tsw / c.nSub;
m   = size(x, 1);
iL = x(:, 1);  vC = x(:, 2);  I = x(:, 3);  z = x(:, 4);

W = emptyWindow(m);
W.vmax = vC;
W.ILpk = iL;
band = c.band * P.Vref;
nTail = max(1, round(0.1 * nP));
essSum = zeros(m, 1);
if record
    S.t = (0:nP).' * Tsw;
    S.vout = zeros(nP + 1, 1);  S.iL = S.vout;  S.d = S.vout;
    S.vout(1) = vC(1);  S.iL(1) = iL(1);
    S.Vin = Vin * ones(nP + 1, 1);
else
    S = [];
end

for k = 1:nP
    % PWM: duty computed at the start of the period and held
    e = P.Vref - vC;
    u = G.Kp .* e + I + G.Kd .* G.Nf .* (e - z);
    d = min(max(u, P.dMin), P.dMax);
    for s = 1:c.nSub
        [a1, b1, c1, d1] = deriv(iL, vC, I, z, d, Vin, P, G);
        [a2, b2, c2, d2] = deriv(iL + 0.5*h*a1, vC + 0.5*h*b1, I + 0.5*h*c1, z + 0.5*h*d1, d, Vin, P, G);
        [a3, b3, c3, d3] = deriv(iL + 0.5*h*a2, vC + 0.5*h*b2, I + 0.5*h*c2, z + 0.5*h*d2, d, Vin, P, G);
        [a4, b4, c4, d4] = deriv(iL + h*a3, vC + h*b3, I + h*c3, z + h*d3, d, Vin, P, G);
        iL = iL + h/6 * (a1 + 2*a2 + 2*a3 + a4);
        vC = vC + h/6 * (b1 + 2*b2 + 2*b3 + b4);
        I  = I  + h/6 * (c1 + 2*c2 + 2*c3 + c4);
        z  = z  + h/6 * (d1 + 2*d2 + 2*d3 + d4);
        iL = max(iL, 0);                       % diode blocks reverse current
        I  = min(max(I, P.iMin), P.iMax);      % integrator output limits
    end
    % performance integrals (time measured from the event)
    tk = k * Tsw;
    e  = P.Vref - vC;
    ae = abs(e);
    W.ITAE = W.ITAE + tk .* ae * Tsw;
    W.IAE  = W.IAE  + ae * Tsw;
    W.ISE  = W.ISE  + e.^2 * Tsw;
    W.ITSE = W.ITSE + tk .* e.^2 * Tsw;
    W.vmax = max(W.vmax, vC);
    W.emax = max(W.emax, ae);
    W.ILpk = max(W.ILpk, iL);
    W.Ts(ae > band) = tk;                      % last time outside the band
    if k > nP - nTail
        essSum = essSum + ae;
    end
    if record
        S.vout(k + 1) = vC(1);  S.iL(k + 1) = iL(1);  S.d(k) = d(1);
    end
end
W.Ess = essSum / nTail;
if record
    S.d(end) = S.d(end - 1);
end
x = [iL, vC, I, z];
end

% -------------------------------------------------------------------------
function [diL, dvC, dI, dz] = deriv(iL, vC, ~, z, d, Vin, P, G)
% Averaged boost converter + PID controller states.
e   = P.Vref - vC;
ron = P.RL + d .* P.RonS + (1 - d) .* P.RonD;
diL = (Vin - iL .* ron - (1 - d) .* (vC + P.Vf)) ./ G.L;
dvC = ((1 - d) .* iL - vC / P.R) ./ G.C;
dI  = G.Ki .* e;
dz  = G.Nf .* (e - z);
end

% -------------------------------------------------------------------------
function W = emptyWindow(m)
W = struct('ITAE', zeros(m, 1), 'IAE', zeros(m, 1), 'ISE', zeros(m, 1), ...
    'ITSE', zeros(m, 1), 'vmax', -inf(m, 1), 'emax', zeros(m, 1), ...
    'ILpk', zeros(m, 1), 'Ts', zeros(m, 1), 'Ess', zeros(m, 1));
end

% -------------------------------------------------------------------------
function P = plantDefaults(P)
% Any plant field that is missing takes the default of boost_read_params.
D = boost_read_params();
f = fieldnames(D);
for i = 1:numel(f)
    if ~isfield(P, f{i})
        P.(f{i}) = D.(f{i});
    end
end
end

% -------------------------------------------------------------------------
function c = costDefaults(c)
def = struct('Twin', 0.5, 'nSub', 2, 'Nf', 100, 'objective', 'ITAE', ...
    'osMax', 0.02, 'wOS', 100, 'robust', true, ...
    'variants', [1.2 1.2; 0.8 0.8; 1.2 0.8; 0.8 1.2], ...
    'band', 0.02, 'essTol', 0.02, 'penalty', 1e3);
f = fieldnames(def);
for i = 1:numel(f)
    if ~isfield(c, f{i}) || isempty(c.(f{i}))
        c.(f{i}) = def.(f{i});
    end
end
end
