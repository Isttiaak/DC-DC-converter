function T = tune_controllers(cfg)
%TUNE_CONTROLLERS  Gains of the three PID controllers.
%
%   ZN-PID   Ziegler-Nichols ultimate-gain rules on the small-signal model
%   PSO-PID  best of cfg.opt.nRuns independent PSO runs
%   GWO-PID  best of cfg.opt.nRuns independent GWO runs
%
%   PSO and GWO minimise the same cost (boost_pid_cost: ITAE of start-up +
%   line step, start-up overshoot penalty, worst case over L, C +-20 %),
%   inside the same box, with the same swarm size and iteration budget.
%   Run r of both algorithms starts from the same random initial
%   population (rng(seed + r - 1) before each run).

P = boost_read_params(cfg.model, true);
[lb, ub, binfo] = pid_search_bounds(P, cfg.Nf);
c = cfg.opt.cost;
fobj = @(X) boost_pid_cost(X, P, c);
fprintf('Search box: Kp [0, %.4g]  Ki [0, %.4g]  Kd [0, %.4g]\n', ub);

% ---- conventional PID ---------------------------------------------------------
[Kzn, zn] = zn_pid(P, cfg.Nf);
fprintf('ZN-PID: Ku = %.5g, Tu = %.5g s -> Kp = %.6g, Ki = %.6g, Kd = %.6g\n', ...
    zn.Ku, zn.Tu, Kzn(1:3));

% ---- PSO and GWO, nRuns independent runs each ---------------------------------
nR = cfg.opt.nRuns;
algos = {'PSO', 'GWO'};
runs = struct('algo', {}, 'run', {}, 'seed', {}, 'J', {}, 'K', {}, 'curve', {}, 'time', {});
for r = 1:nR
    seed = cfg.opt.seed + r - 1;
    for a = 1:2
        rng(seed, 'twister');
        o = struct('verbose', false, 'label', algos{a});
        t0 = tic;
        if a == 1
            [J, x, curve] = pso(fobj, lb, ub, cfg.opt.nPop, cfg.opt.maxIter, o);
        else
            [J, x, curve] = gwo(fobj, lb, ub, cfg.opt.nPop, cfg.opt.maxIter, o);
        end
        el = toc(t0);
        runs(end + 1) = struct('algo', algos{a}, 'run', r, 'seed', seed, 'J', J, ...
            'K', [x, cfg.Nf], 'curve', curve, 'time', el); %#ok<AGROW>
        fprintf('  %s run %2d/%d (seed %d): J = %-10.6g Kp = %.5g Ki = %.5g Kd = %.4g  [%.0f s]\n', ...
            algos{a}, r, nR, seed, J, x, el);
    end
end

% ---- best run of each algorithm -------------------------------------------------
T = struct();
T.names  = cfg.ctrl.names;
T.labels = cfg.ctrl.labels;
T.K = zeros(3, 4);
T.K(1, :) = Kzn;
T.bestRun = zeros(1, 2);
stats = struct();
for a = 1:2
    sel = runs(strcmp({runs.algo}, algos{a}));
    Js = [sel.J];
    [~, ib] = min(Js);
    T.K(a + 1, :) = sel(ib).K;
    T.bestRun(a) = sel(ib).run;
    ok = Js < 1e3;                     % infeasible wolves/particles cost >= 1e3 (penalty)
    stats.(algos{a}) = struct('best', min(Js), 'worst', max(Js), 'mean', mean(Js), ...
        'median', median(Js), 'std', std(Js), 'feasibleRuns', sum(ok), 'nRuns', numel(Js), ...
        'meanTime', mean([sel.time]), 'curves', vertcat(sel.curve));
end
[T.J, M] = boost_pid_cost(T.K(:, 1:3), P, c);
T.metricsAvg = M;
T.runs = runs;
T.stats = stats;
T.plant = P;
T.lb = lb;  T.ub = ub;  T.bounds = binfo;
T.zn = zn;
T.cost = c;

% ---- save ------------------------------------------------------------------------
if ~exist(cfg.dataDir, 'dir'), mkdir(cfg.dataDir); end
if ~exist(cfg.tableDir, 'dir'), mkdir(cfg.tableDir); end
save(fullfile(cfg.dataDir, 'tuning.mat'), 'T');
G = table(string(T.labels(:)), T.K(:, 1), T.K(:, 2), T.K(:, 3), T.K(:, 4), T.J(:), ...
    'VariableNames', {'Controller', 'Kp', 'Ki', 'Kd', 'Nf', 'Cost_J'});
writetable(G, fullfile(cfg.tableDir, 'pid_gains.csv'));
S = table(string(algos(:)), ...
    [stats.PSO.best; stats.GWO.best], [stats.PSO.mean; stats.GWO.mean], ...
    [stats.PSO.median; stats.GWO.median], [stats.PSO.worst; stats.GWO.worst], ...
    [stats.PSO.std; stats.GWO.std], [stats.PSO.feasibleRuns; stats.GWO.feasibleRuns], ...
    [stats.PSO.nRuns; stats.GWO.nRuns], [stats.PSO.meanTime; stats.GWO.meanTime], ...
    'VariableNames', {'Algorithm', 'BestJ', 'MeanJ', 'MedianJ', 'WorstJ', 'StdJ', ...
    'FeasibleRuns', 'Runs', 'MeanTime_s'});
writetable(S, fullfile(cfg.tableDir, 'optimizer_statistics.csv'));
fprintf('\n');
disp(G);
disp(S);
end
