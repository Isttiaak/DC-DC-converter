function S = simulate_cases(cfg, T)
%SIMULATE_CASES  Switching-model simulations of every controller, without
%   and with sensor noise, through Simulink.SimulationInput (the model
%   file is not modified).
%
%   S.t                 uniform time grid (Tsw / cfg.samplesPerPeriod)
%   S.sig(i, j).<name>  resampled signals (single), i = controller,
%                       j = 1 without noise, 2 with noise;
%                       names: vout, iL, duty, vmeas, vin
%   S.avg(i, j).<name>  one value per PWM period (ripple-free averages)
%   S.tAvg              time of the period averages (period start)
%   S.noiseProfile      [t sigma] table given to the model
%   S.elapsed(i, j)     wall time of each simulation

mdl = cfg.model;
load_system(cfg.modelFile);
P = boost_read_params(mdl);
Tsw = 1 / P.fsw;
dt = Tsw / cfg.samplesPerPeriod;
t = (0:dt:cfg.Tstop).';

% noise profile [t sigma]: held between the points (From Workspace, no interpolation)
W = cfg.noise.windows;
if W(1, 1) > 0, prof = [0 0]; else, prof = zeros(0, 2); end
for k = 1:size(W, 1)
    prof = [prof; W(k, 1), W(k, 3) / 100 * P.Vref; W(k, 2), 0]; %#ok<AGROW>
end
conds = {'without noise', 'with noise'};
nC = numel(cfg.ctrl.names);
sigNames = {'vout', 'iL', 'duty', 'vmeas', 'vin'};
S = struct();
S.t = t;
S.conds = conds;
S.noiseProfile = prof;
S.elapsed = zeros(nC, 2);
nPer = floor(cfg.Tstop / Tsw);
S.tAvg = (0:nPer - 1).' * Tsw;

for i = 1:nC
    for j = 1:2
        in = Simulink.SimulationInput(mdl);
        in = setVariable(in, 'Kp', T.K(i, 1));
        in = setVariable(in, 'Ki', T.K(i, 2));
        in = setVariable(in, 'Kd', T.K(i, 3));
        in = setVariable(in, 'Nf', T.K(i, 4));
        if j == 1
            in = setVariable(in, 'noise_sigma', [0 0; cfg.Tstop 0]);
        else
            in = setVariable(in, 'noise_sigma', prof);
        end
        in = setVariable(in, 'noise_Ts', cfg.noise.Ts);
        in = setVariable(in, 'noise_seed', cfg.noise.seed);
        in = setModelParameter(in, 'StopTime', num2str(cfg.Tstop, 17));
        in = setBlockParameter(in, [mdl '/Step'], 'Time', num2str(cfg.tStep, 17));
        fprintf('Simulating %s, %s ... ', cfg.ctrl.labels{i}, conds{j});
        t0 = tic;
        out = sim(in);
        S.elapsed(i, j) = toc(t0);
        if ~isempty(out.ErrorMessage)
            error('simulate_cases:sim', 'Simulation failed (%s, %s): %s', ...
                cfg.ctrl.labels{i}, conds{j}, out.ErrorMessage);
        end
        fprintf('%.1f s, %d solver points\n', S.elapsed(i, j), numel(out.vout.Time));
        for s = 1:numel(sigNames)
            y = resampleTs(out.(sigNames{s}), t);
            S.sig(i, j).(sigNames{s}) = single(y);
            S.avg(i, j).(sigNames{s}) = periodMean(y, cfg.samplesPerPeriod, nPer);
        end
    end
end
end

% -------------------------------------------------------------------------
function y = resampleTs(ts, t)
% Logged timeseries -> uniform grid (linear interpolation; duplicate
% time stamps at switching events keep the last value).
[tt, iu] = unique(ts.Time(:), 'last');
v = squeeze(ts.Data);
v = double(v(iu));
y = interp1(tt, v, t, 'linear', 'extrap');
end

function a = periodMean(y, n, nPer)
% Mean over each PWM period (n samples per period).
a = mean(reshape(y(1:n * nPer), n, nPer), 1).';
end
