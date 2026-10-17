function K = gwo_tuner_init(mdl)
%GWO_TUNER_INIT  Grey Wolf Optimizer tuning of the boost-converter PID.
%
%   K = gwo_tuner_init(mdl) returns K = [Kp Ki Kd Nf].
%
%   The "GWO PID Tuner" block of boost_GWO_PID.slx calls this function once,
%   at t = 0 of every simulation (extrinsic call), then holds the gains for
%   the rest of the run. You can also call it yourself from a script.
%
%   What it does
%     1. reads L, C, R, Vf, Ron, Vin step, Vref, fsw and the duty /
%        integrator limits from the blocks of the model (boost_read_params)
%     2. runs GWO (gwo.m) over [Kp Ki Kd]; every wolf is scored by
%        boost_pid_cost.m, an averaged-model simulation of the converter
%        with exactly the PID of the model (start-up + line step)
%     3. stores everything in gwo_result (base workspace) and copies the
%        gains to Kp, Ki, Kd, Nf in the base workspace
%
%   Options: struct gwo_opts in the base workspace (every field optional)
%     mode       'auto'  (default) run GWO, but reuse the previous gwo_result
%                        if the plant and the options have not changed
%                'tune'  always run GWO
%                'fixed' no optimisation: use Kp, Ki, Kd, Nf from the base
%                        workspace (e.g. to simulate the MOPSO or manual gains)
%     nWolves    20      pack size
%     maxIter    40      GWO iterations
%     lb, ub     []      bounds of [Kp Ki Kd]; [] = automatic from the plant:
%                        Kp <= 1/Vref, Ki <= 2*wz/G0, Kd <= 1/(Nf*Vref)
%                        (wz: right-half-plane zero, G0: duty-to-voltage gain)
%     Nf         100     derivative filter coefficient [rad/s] (as in the .slx)
%     tuneNf     false   true: Nf becomes a 4th GWO variable within nfBounds
%     nfBounds   [10 2000]
%     seed       1       RNG seed for reproducible runs ([] = random)
%     objective  'ITAE'  'ITAE' | 'IAE' | 'ISE' | 'ITSE'
%     osMax      0.02    start-up overshoot limit (fraction of Vref)
%     wOS        100     overshoot penalty weight (see boost_pid_cost)
%     robust     true    worst case over L and C +-20 % (see boost_pid_cost)
%     variants   []      custom [L C] multipliers for the robustness check
%     Twin       0.5     evaluation window after each event [s]
%     nSub       2       RK4 steps per switching period
%     x0         []      initial wolves, rows [Kp Ki Kd] (e.g. the MOPSO gains)
%     plant      struct  overrides of plant fields, e.g. struct('R', 2.304)
%     verbose    true    print GWO progress in the Command Window

if nargin < 1, mdl = ''; end
t0 = tic;
opts = readOptions();
Kws  = workspaceGains();            % [Kp Ki Kd Nf] currently in the base workspace

% ---- fixed gains, no optimisation ---------------------------------------
if strcmpi(opts.mode, 'fixed')
    K = Kws;
    if opts.verbose
        fprintf('GWO PID Tuner: mode ''fixed'' -> Kp = %.6g, Ki = %.6g, Kd = %.6g, Nf = %.6g\n', K);
    end
    return
end

try
    % ---- plant & cost options -------------------------------------------
    mdl = resolveModel(mdl);
    P = boost_read_params(mdl, opts.verbose);
    if isstruct(opts.plant)
        f = fieldnames(opts.plant);
        for i = 1:numel(f)
            P.(f{i}) = opts.plant.(f{i});
        end
    end
    c = struct('Twin', opts.Twin, 'nSub', opts.nSub, 'Nf', opts.Nf, ...
        'objective', opts.objective, 'osMax', opts.osMax, 'wOS', opts.wOS, ...
        'robust', opts.robust, 'variants', opts.variants);

    [lb, ub] = searchBounds(P, opts);

    % ---- reuse the last result if nothing changed ('auto' mode) ---------
    sig = signature(P, opts, lb, ub);
    if strcmpi(opts.mode, 'auto') && evalin('base', 'exist(''gwo_result'', ''var'')')
        R = evalin('base', 'gwo_result');
        if isstruct(R) && isfield(R, 'signature') && isequal(R.signature, sig)
            K = R.K;
            assignGains(K);
            if opts.verbose
                fprintf(['GWO PID Tuner: plant and options unchanged -> reusing the last GWO ' ...
                    'result (set gwo_opts.mode = ''tune'' to force a new run)\n' ...
                    '  Kp = %.6g, Ki = %.6g, Kd = %.6g, Nf = %.6g\n'], K);
            end
            return
        end
    end

    % ---- run the Grey Wolf Optimizer ------------------------------------
    if ~isempty(opts.seed)
        rngState = rng;
        restoreRng = onCleanup(@() rng(rngState)); %#ok<NASGU> restores the RNG on exit
        rng(opts.seed, 'twister');
    end
    if opts.verbose
        fprintf(['\n=== GWO PID tuning (%s): %d wolves x %d iterations, objective %s, ' ...
            'robust %d ===\n'], modelLabel(mdl), opts.nWolves, opts.maxIter, ...
            upper(opts.objective), opts.robust);
        fprintf('  search box: Kp [%g, %g]  Ki [%g, %g]  Kd [%g, %g]', ...
            lb(1), ub(1), lb(2), ub(2), lb(3), ub(3));
        if opts.tuneNf
            fprintf('  Nf [%g, %g]', lb(4), ub(4));
        end
        fprintf('\n');
    end
    x0 = opts.x0;
    if ~isempty(x0) && opts.tuneNf && size(x0, 2) == 3
        x0 = [x0, opts.Nf * ones(size(x0, 1), 1)];
    end
    gopts = struct('vectorized', true, 'verbose', opts.verbose, ...
        'printEvery', max(1, round(opts.maxIter / 20)), 'x0', x0, 'label', 'GWO');
    fobj = @(X) boost_pid_cost(X, P, c);
    [Jbest, xbest, curve, info] = gwo(fobj, lb, ub, opts.nWolves, opts.maxIter, gopts);

    if opts.tuneNf
        K = xbest(1:4);
    else
        K = [xbest(1:3), opts.Nf];
    end

    % ---- check the winner, store everything ------------------------------
    [~, M, S] = boost_pid_cost(K, P, c);
    R = struct();
    R.K = K;  R.Kp = K(1);  R.Ki = K(2);  R.Kd = K(3);  R.Nf = K(4);
    R.J = Jbest;
    R.curve = curve;
    R.meanCost = info.meanCost;
    R.alphaHistory = info.alphaHistory;
    R.nEval = info.nEval;
    R.metrics = M;
    R.response = S;
    R.plant = P;
    R.lb = lb;  R.ub = ub;
    R.opts = opts;
    R.cost = c;
    R.model = mdl;
    R.elapsed = toc(t0);
    R.created = char(datetime('now'));
    R.signature = sig;
    assignin('base', 'gwo_result', R);
    assignGains(K);

    if opts.verbose
        fprintf('=== GWO result (%.1f s, %d cost evaluations) ===\n', R.elapsed, R.nEval);
        fprintf('  Kp = %.6g   Ki = %.6g   Kd = %.6g   Nf = %.6g   (J = %.6g)\n', K, Jbest);
        fprintf(['  averaged model: start-up overshoot %.2f %%, settling %.1f ms | ' ...
            'line step peak %+.1f %%, settling %.1f ms\n'], M.OS1, 1e3 * M.Ts1, ...
            M.Mp2, 1e3 * M.Ts2);
        if ~M.feasible
            warning('gwo_tuner_init:infeasible', ['The best wolf is still penalised ' ...
                '(latch-up / not settled). Widen the bounds or raise maxIter.']);
        end
        fprintf('  results: gwo_result (base workspace); gains copied to Kp, Ki, Kd, Nf\n\n');
    end
catch err
    K = Kws;
    warning('gwo_tuner_init:failed', ['GWO tuning failed (%s).\nUsing the workspace ' ...
        'gains Kp = %.6g, Ki = %.6g, Kd = %.6g, Nf = %.6g instead.'], err.message, K);
end
K = double(reshape(K, 1, 4));
end

% =========================================================================
function opts = readOptions()
def = struct('mode', 'auto', 'nWolves', 20, 'maxIter', 40, 'lb', [], 'ub', [], ...
    'Nf', 100, 'tuneNf', false, 'nfBounds', [10 2000], 'seed', 1, ...
    'objective', 'ITAE', 'osMax', 0.02, 'wOS', 100, 'robust', true, ...
    'variants', [], 'Twin', 0.5, 'nSub', 2, 'x0', [], 'plant', [], 'verbose', true);
opts = def;
if evalin('base', 'exist(''gwo_opts'', ''var'')')
    user = evalin('base', 'gwo_opts');
    if isstruct(user)
        f = fieldnames(user);
        for i = 1:numel(f)
            if isfield(def, f{i})
                if ~isempty(user.(f{i})) || any(strcmp(f{i}, {'lb', 'ub', 'seed', 'x0', 'variants'}))
                    opts.(f{i}) = user.(f{i});
                end
            else
                warning('gwo_tuner_init:option', 'Unknown gwo_opts field "%s" ignored.', f{i});
            end
        end
    end
end
if isempty(opts.variants)
    opts.variants = [1.2 1.2; 0.8 0.8; 1.2 0.8; 0.8 1.2];
end
opts.mode = lower(char(opts.mode));
if ~any(strcmp(opts.mode, {'auto', 'tune', 'fixed'}))
    error('gwo_tuner_init:mode', 'gwo_opts.mode must be ''auto'', ''tune'' or ''fixed''.');
end
end

% -------------------------------------------------------------------------
function K = workspaceGains()
% Gains from the base workspace (defined by the model PreLoadFcn).
K = [0.0033193, 1.41243, 3.7605e-05, 100];  % fallback: a verified GWO result
names = {'Kp', 'Ki', 'Kd', 'Nf'};
for i = 1:4
    if evalin('base', sprintf('exist(''%s'', ''var'')', names{i}))
        v = evalin('base', names{i});
        if isnumeric(v) && isscalar(v) && isfinite(v)
            K(i) = double(v);
        end
    end
end
end

% -------------------------------------------------------------------------
function assignGains(K)
assignin('base', 'Kp', K(1));
assignin('base', 'Ki', K(2));
assignin('base', 'Kd', K(3));
assignin('base', 'Nf', K(4));
end

% -------------------------------------------------------------------------
function [lb, ub] = searchBounds(P, opts)
% Automatic box from the plant at the lowest input voltage:
%   G0 = Vin/(1-D)^2         duty-to-output-voltage gain
%   wz = R*(1-D)^2/L         right-half-plane zero (limits the bandwidth)
%   Kp <= 1/Vref             P term alone would saturate the duty at start-up
%   Ki <= 2*wz/G0            integral crossover at most 2x the RHP zero
%   Kd <= 1/(Nf*Vref)        derivative kick alone would saturate the duty
Vin = min(P.Vin0, P.Vin1);
D   = min(max(1 - Vin / (P.Vref + P.Vf), 0.05), 0.95);
G0  = Vin / (1 - D)^2;
wz  = P.R * (1 - D)^2 / P.L;
autoLb = [0, 0, 0];
autoUb = [1 / P.Vref, 2 * wz / G0, 1 / (opts.Nf * P.Vref)];
if isempty(opts.lb), lb = autoLb; else, lb = opts.lb(:).'; end
if isempty(opts.ub), ub = autoUb; else, ub = opts.ub(:).'; end
lb = lb(1:3);
ub = ub(1:3);
if opts.tuneNf
    lb = [lb, opts.nfBounds(1)];
    ub = [ub, opts.nfBounds(2)];
end
end

% -------------------------------------------------------------------------
function sig = signature(P, opts, lb, ub)
% Everything that changes the GWO result.
p = rmfield(P, 'missing');
o = rmfield(opts, {'mode', 'verbose'});
sig = struct('plant', p, 'opts', o, 'lb', lb, 'ub', ub);
end

% -------------------------------------------------------------------------
function mdl = resolveModel(mdl)
% Model to read the plant from: the given one if loaded, else a loaded model
% that contains a "GWO PID Tuner" block, else the model file on the path.
if ~isempty(mdl) && bdIsLoaded(mdl)
    return
end
models = find_system('SearchDepth', 0, 'type', 'block_diagram', 'BlockDiagramType', 'model');
for i = 1:numel(models)
    if ~isempty(find_system(models{i}, 'SearchDepth', 1, 'Name', 'GWO PID Tuner'))
        mdl = models{i};
        return
    end
end
if ~isempty(mdl) && exist(mdl, 'file') == 4
    load_system(mdl);
    return
end
warning('gwo_tuner_init:model', ['Model "%s" not found; using the default plant ' ...
    'parameters of boost_read_params.'], mdl);
mdl = '';
end

% -------------------------------------------------------------------------
function s = modelLabel(mdl)
if isempty(mdl), s = 'default plant'; else, s = mdl; end
end
