function M = compute_metrics(cfg, T, S)
%COMPUTE_METRICS  Performance and noise-robustness metrics from the
%   switching-model simulations (Vout and iL averaged over each PWM period,
%   so the switching ripple does not distort the step-response figures).
%
%   M.clean      table, one row per controller (no noise)
%   M.noise      table, one row per controller and noise window
%   Also written to results/tables/*.csv

P = T.plant;
Vref = P.Vref;
ta = S.tAvg;
nC = numel(cfg.ctrl.names);
Tsw = 1 / P.fsw;

% ---- without noise -------------------------------------------------------------
rows = cell(nC, 1);
for i = 1:nC
    v = S.avg(i, 1).vout;
    il = S.avg(i, 1).iL;
    ilRaw = double(S.sig(i, 1).iL);
    vRaw = double(S.sig(i, 1).vout);
    su = stepMetrics(ta, v, Vref, 0, cfg.tStep);
    ls = stepMetrics(ta, v, Vref, cfg.tStep, cfg.Tstop);
    inSu = S.t < cfg.tStep;
    ss = S.t >= cfg.tStep - 20 * Tsw & S.t < cfg.tStep;     % last 20 periods before the step
    r = struct();
    r.Controller = string(cfg.ctrl.labels{i});
    r.Kp = T.K(i, 1);  r.Ki = T.K(i, 2);  r.Kd = T.K(i, 3);
    r.StartupOvershoot_pct = su.OS;
    r.RiseTime_ms = 1e3 * su.tr;
    r.StartupSettling_ms = 1e3 * su.ts;
    r.StartupITAE = su.ITAE;
    r.StartupIAE = su.IAE;
    r.LineStepPeak_V = ls.vmax;
    r.LineStepPeakDev_pct = ls.Mp;
    r.LineStepSettling_ms = 1e3 * ls.ts;
    r.LineStepITAE = ls.ITAE;
    r.LineStepIAE = ls.IAE;
    r.TotalITAE = su.ITAE + ls.ITAE;
    r.TotalISE = su.ISE + ls.ISE;
    r.SteadyStateError_mV = 1e3 * ls.ess;
    r.iLPeakStartup_A = max(ilRaw(inSu));
    r.iLPeakLineStep_A = max(ilRaw(~inSu));
    r.iLMeanSteady_A = mean(il(ta >= cfg.tStep - 0.05 & ta < cfg.tStep));
    r.VoutRipple_pp_V = max(vRaw(ss)) - min(vRaw(ss));
    r.iLRipple_pp_A = max(ilRaw(ss)) - min(ilRaw(ss));
    rows{i} = struct2table(r);
end
M.clean = vertcat(rows{:});

% ---- with noise: deviation from the noise-free run, per window -------------------
W = cfg.noise.windows;
rows = {};
for i = 1:nC
    for k = 1:size(W, 1)
        in = ta >= W(k, 1) & ta < W(k, 2);
        dv = S.avg(i, 2).vout(in) - S.avg(i, 1).vout(in);
        di = S.avg(i, 2).iL(in) - S.avg(i, 1).iL(in);
        dd = S.avg(i, 2).duty(in);
        r = struct();
        r.Controller = string(cfg.ctrl.labels{i});
        r.Window = k;
        r.tOn_s = W(k, 1);
        r.tOff_s = W(k, 2);
        r.NoiseSigma_pct = W(k, 3);
        r.NoiseSigma_V = W(k, 3) / 100 * Vref;
        r.dVout_rms_mV = 1e3 * sqrt(mean(dv.^2));
        r.dVout_max_mV = 1e3 * max(abs(dv));
        r.diL_rms_A = sqrt(mean(di.^2));
        r.diL_max_A = max(abs(di));
        r.Duty_std = std(dd);
        rows{end + 1, 1} = struct2table(r); %#ok<AGROW>
    end
end
M.noise = vertcat(rows{:});

if ~exist(cfg.tableDir, 'dir'), mkdir(cfg.tableDir); end
writetable(M.clean, fullfile(cfg.tableDir, 'metrics_without_noise.csv'));
writetable(M.noise, fullfile(cfg.tableDir, 'metrics_noise_robustness.csv'));
disp(M.clean);
disp(M.noise);
end

% -------------------------------------------------------------------------
function m = stepMetrics(t, v, Vref, t0, t1)
% Step-response figures of merit inside [t0, t1), time measured from t0.
in = t >= t0 & t < t1;
tau = t(in) - t0;
vv = v(in);
e = Vref - vv;
ae = abs(e);
m.OS = 100 * max(0, max(vv) - Vref) / Vref;
m.Mp = 100 * max(ae) / Vref;
m.vmax = max(vv);
k10 = find(vv >= 0.1 * Vref, 1, 'first');
k90 = find(vv >= 0.9 * Vref, 1, 'first');
if isempty(k10) || isempty(k90), m.tr = NaN; else, m.tr = tau(k90) - tau(k10); end
out = find(ae > 0.02 * Vref, 1, 'last');
if isempty(out), m.ts = 0; else, m.ts = tau(min(out + 1, numel(tau))); end
m.ITAE = trapz(tau, tau .* ae);
m.IAE = trapz(tau, ae);
m.ISE = trapz(tau, e.^2);
nT = max(1, round(0.1 * numel(ae)));
m.ess = mean(ae(end - nT + 1:end));
end
