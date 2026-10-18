function T = tune_controllers(cfg)
%TUNE_CONTROLLERS  Gains of the PID controllers and the optimiser comparison.
%
%   ZN-PID   Ziegler-Nichols ultimate-gain rules on the small-signal model
%   PSO-PID  best of cfg.opt.nRuns independent PSO runs
%   GA-PID   best of cfg.opt.nRuns independent GA runs
%   GWO-PID  best of cfg.opt.nRuns independent GWO runs
%
%   PSO, GA and GWO minimise the same cost (boost_pid_cost: ITAE of
%   start-up + line step, start-up overshoot penalty, worst case over
%   L, C +-20 %), inside the same box, with the same population size and
%   evaluation budget. Run r of every optimiser starts from the same random
%   initial population (rng(seed + r - 1) before each run).
%
%   The optimisers are also compared on ALL runs, not only the best one:
%   the true optimum of the cost is found by exhaustive search
%   (reference_optimum, no metaheuristic) and every run is measured
%   against it; Wilcoxon rank-sum tests compare the final costs.
%
%   Tables (results/tables): pid_gains.csv, optimizer_statistics.csv,
%   optimizer_runs.csv, optimizer_rank_sum_tests.csv, reference_optimum.csv

P = boost_read_params(cfg.model, true);
[lb, ub, binfo] = pid_search_bounds(P, cfg.Nf);
c = cfg.opt.cost;
fobj = @(X) boost_pid_cost(X, P, c);
fprintf('Search box: Kp [0, %.4g]  Ki [0, %.4g]  Kd [0, %.4g]\n', ub);
algos = cfg.opt.algos;
nA = numel(algos);
nR = cfg.opt.nRuns;
nPop = cfg.opt.nPop;

% ---- conventional PID ---------------------------------------------------------
[Kzn, zn] = zn_pid(P, cfg.Nf);
fprintf('ZN-PID: Ku = %.5g, Tu = %.5g s -> Kp = %.6g, Ki = %.6g, Kd = %.6g\n', ...
    zn.Ku, zn.Tu, Kzn(1:3));

% ---- every optimiser, nRuns independent runs ---------------------------------------
runs = struct('algo', {}, 'run', {}, 'seed', {}, 'J', {}, 'K', {}, 'curve', {}, 'time', {});
for r = 1:nR
    seed = cfg.opt.seed + r - 1;
    for a = 1:nA
        rng(seed, 'twister');               % same initial population for every optimiser
        t0 = tic;
        [J, x, curve] = runOptimizer(algos{a}, fobj, lb, ub, cfg);
        el = toc(t0);
        runs(end + 1) = struct('algo', algos{a}, 'run', r, 'seed', seed, 'J', J, ...
            'K', [x, cfg.Nf], 'curve', curve, 'time', el); %#ok<AGROW>
        fprintf('  %-3s run %2d/%d (seed %d): J = %-10.6g Kp = %.5g Ki = %.5g Kd = %.4g  [%.0f s]\n', ...
            algos{a}, r, nR, seed, J, x, el);
    end
end

% ---- reference optimum (exhaustive search) ---------------------------------------------
if cfg.ref.enable
    ref = reference_optimum(P, lb, ub, c, cfg.ref);
    bestRunJ = min([runs.J]);
    if bestRunJ < ref.Jstar
        fprintf(['Note: an optimiser run (J = %.8g) beat the grid search (J = %.8g); ' ...
            'the reference uses the lower value.\n'], bestRunJ, ref.Jstar);
        [~, k] = min([runs.J]);
        ref.Jstar = runs(k).J;
        ref.Kstar = runs(k).K(1:3);
        ref.source = sprintf('%s run %d', runs(k).algo, runs(k).run);
    else
        ref.source = 'exhaustive grid search + refinement';
    end
else
    [Jb, k] = min([runs.J]);
    ref = struct('Jstar', Jb, 'Kstar', runs(k).K(1:3), 'source', 'best optimiser run', ...
        'minima', [], 'maps', [], 'feasibleFraction', NaN);
end
Jstar = ref.Jstar;

% ---- every run on the averaged model: cost relative to the optimum, metrics ------------
Kall = vertcat(runs.K);
[~, Mr] = boost_pid_cost(Kall(:, 1:3), P, c);
pctOf = @(J) 100 * (J ./ Jstar - 1);
for i = 1:numel(runs)
    rel = pctOf(runs(i).curve);
    runs(i).pct = pctOf(runs(i).J);
    runs(i).evalsTo5 = evalsTo(rel, 5, nPop);
    runs(i).evalsTo1 = evalsTo(rel, 1, nPop);
    runs(i).OS1 = Mr.OS1(i);
    runs(i).Ts1 = Mr.Ts1(i);
    runs(i).Ts2 = Mr.Ts2(i);
    runs(i).Mp2 = Mr.Mp2(i);
    runs(i).ILpk2 = Mr.ILpk2(i);
end

% ---- best run of each optimiser, statistics -----------------------------------------
T = struct();
T.names  = cfg.ctrl.names;
T.labels = cfg.ctrl.labels;
nC = numel(cfg.ctrl.names);
T.K = zeros(nC, 4);
T.K(1, :) = Kzn;
T.bestRun = zeros(1, nA);
stats = struct();
for a = 1:nA
    sel = runs(strcmp({runs.algo}, algos{a}));
    Js = [sel.J];
    [~, ib] = min(Js);
    iC = find(strcmp(cfg.ctrl.names, algos{a}), 1);
    T.K(iC, :) = sel(ib).K;
    T.bestRun(a) = sel(ib).run;
    pct = [sel.pct];
    e1 = [sel.evalsTo1];
    stats.(algos{a}) = struct('best', min(Js), 'worst', max(Js), 'mean', mean(Js), ...
        'median', median(Js), 'std', std(Js), 'feasibleRuns', sum(Js < 1e3), 'nRuns', numel(Js), ...
        'meanTime', mean([sel.time]), 'curves', vertcat(sel.curve), ...
        'bestPct', min(pct), 'medianPct', median(pct), 'meanPct', mean(pct), 'worstPct', max(pct), ...
        'within1', sum(pct <= 1), 'within5', sum(pct <= 5), ...
        'medianEvalsTo1', median(e1(isfinite(e1))), 'bestRun', sel(ib).run);
end

% pairwise Wilcoxon rank-sum tests on the final cost of all runs
tests = struct('A', {}, 'B', {}, 'medianA', {}, 'medianB', {}, 'p', {});
for a = 1:nA - 1
    for b = a + 1:nA
        xa = [runs(strcmp({runs.algo}, algos{a})).J];
        xb = [runs(strcmp({runs.algo}, algos{b})).J];
        tests(end + 1) = struct('A', algos{a}, 'B', algos{b}, 'medianA', ...
            stats.(algos{a}).medianPct, 'medianB', stats.(algos{b}).medianPct, ...
            'p', rank_sum_test(xa, xb)); %#ok<AGROW>
    end
end

[T.J, M] = boost_pid_cost(T.K(:, 1:3), P, c);
T.metricsAvg = M;
T.algos = algos;
T.runs = runs;
T.stats = stats;
T.tests = tests;
T.ref = ref;
T.plant = P;
T.lb = lb;  T.ub = ub;  T.bounds = binfo;
T.zn = zn;
T.cost = c;

% ---- save ------------------------------------------------------------------------
if ~exist(cfg.dataDir, 'dir'), mkdir(cfg.dataDir); end
if ~exist(cfg.tableDir, 'dir'), mkdir(cfg.tableDir); end
save(fullfile(cfg.dataDir, 'tuning.mat'), 'T');

G = table(string(T.labels(:)), T.K(:, 1), T.K(:, 2), T.K(:, 3), T.K(:, 4), T.J(:), pctOf(T.J(:)), ...
    'VariableNames', {'Controller', 'Kp', 'Ki', 'Kd', 'Nf', 'Cost_J', 'J_above_optimum_pct'});
writetable(G, fullfile(cfg.tableDir, 'pid_gains.csv'));

st = stats.(algos{1});
for a = 2:nA
    st(a) = stats.(algos{a});
end
S = table(string(algos(:)), [st.best].', [st.mean].', [st.median].', [st.worst].', [st.std].', ...
    [st.bestPct].', [st.medianPct].', [st.worstPct].', [st.within1].', [st.within5].', ...
    [st.medianEvalsTo1].', [st.feasibleRuns].', [st.nRuns].', [st.meanTime].', [st.bestRun].', ...
    'VariableNames', {'Algorithm', 'BestJ', 'MeanJ', 'MedianJ', 'WorstJ', 'StdJ', ...
    'Best_pct_above_opt', 'Median_pct_above_opt', 'Worst_pct_above_opt', 'RunsWithin1pct', ...
    'RunsWithin5pct', 'MedianEvalsToWithin1pct', 'FeasibleRuns', 'Runs', 'MeanTime_s', 'BestRun'});
writetable(S, fullfile(cfg.tableDir, 'optimizer_statistics.csv'));

isBest = arrayfun(@(q) q.run == stats.(q.algo).bestRun, runs);
R = table(string({runs.algo}.'), [runs.run].', [runs.seed].', Kall(:, 1), Kall(:, 2), Kall(:, 3), ...
    [runs.J].', [runs.pct].', [runs.evalsTo5].', [runs.evalsTo1].', [runs.OS1].', ...
    1e3 * [runs.Ts1].', 1e3 * [runs.Ts2].', [runs.Mp2].', [runs.ILpk2].', isBest(:), [runs.time].', ...
    'VariableNames', {'Algorithm', 'Run', 'Seed', 'Kp', 'Ki', 'Kd', 'Cost_J', 'J_above_optimum_pct', ...
    'EvalsToWithin5pct', 'EvalsToWithin1pct', 'StartupOvershoot_pct', 'StartupSettling_ms', ...
    'VinStepSettling_ms', 'VinStepPeakDev_pct', 'VinStepPeak_iL_A', 'BestRun', 'Time_s'});
writetable(R, fullfile(cfg.tableDir, 'optimizer_runs.csv'));

if ~isempty(tests)
    W = table(string({tests.A}.'), string({tests.B}.'), [tests.medianA].', [tests.medianB].', ...
        [tests.p].', [tests.p].' < 0.05, ...
        'VariableNames', {'AlgorithmA', 'AlgorithmB', 'MedianA_pct_above_opt', ...
        'MedianB_pct_above_opt', 'p_value', 'Significant_at_5pct'});
    writetable(W, fullfile(cfg.tableDir, 'optimizer_rank_sum_tests.csv'));
    disp(W);
end

if isfield(ref, 'minima') && ~isempty(ref.minima)
    Km = vertcat(ref.minima.K);
    O = table((1:numel(ref.minima)).', Km(:, 1), Km(:, 2), Km(:, 3), [ref.minima.J].', ...
        pctOf([ref.minima.J].'), 'VariableNames', {'LocalMinimum', 'Kp', 'Ki', 'Kd', 'Cost_J', ...
        'J_above_optimum_pct'});
    writetable(O, fullfile(cfg.tableDir, 'reference_optimum.csv'));
    disp(O);
end
fprintf('\n');
disp(G);
disp(S);
end

% -------------------------------------------------------------------------
function [J, x, curve] = runOptimizer(name, fobj, lb, ub, cfg)
o = struct('verbose', false, 'label', name);
switch upper(name)
    case 'PSO'
        [J, x, curve] = pso(fobj, lb, ub, cfg.opt.nPop, cfg.opt.maxIter, o);
    case 'GA'
        f = fieldnames(cfg.opt.ga);
        for k = 1:numel(f)
            o.(f{k}) = cfg.opt.ga.(f{k});
        end
        [J, x, curve] = genetic_algorithm(fobj, lb, ub, cfg.opt.nPop, cfg.opt.maxIter, o);
    case 'GWO'
        [J, x, curve] = gwo(fobj, lb, ub, cfg.opt.nPop, cfg.opt.maxIter, o);
    otherwise
        error('tune_controllers:algo', 'Unknown optimiser "%s".', name);
end
end

function e = evalsTo(relCurve, thr, nPop)
% Cost evaluations until the best cost is within thr % of the optimum (Inf if never).
k = find(relCurve <= thr, 1, 'first');
if isempty(k), e = Inf; else, e = k * nPop; end
end
