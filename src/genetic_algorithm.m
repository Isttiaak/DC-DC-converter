function [bestScore, bestPos, curve, info] = genetic_algorithm(fobj, lb, ub, nPop, maxGen, opts)
%GENETIC_ALGORITHM  Real-coded genetic algorithm (GA) for box-bounded minimisation.
%
%   [bestScore, bestPos, curve, info] = genetic_algorithm(fobj, lb, ub, nPop, maxGen, opts)
%
%   Same interface as pso.m and gwo.m, so the three optimisers are compared
%   with the same cost, search box, population size and evaluation budget
%   (nPop evaluations per generation, maxGen generations).
%   (Named genetic_algorithm, not ga, so it never clashes with the ga
%   function of the Global Optimization Toolbox.)
%
%   Inputs
%     fobj     function handle (see opts.vectorized)
%     lb, ub   1-by-dim lower / upper bounds
%     nPop     population size
%     maxGen   number of generations (generation 1 = the initial population)
%     opts     optional struct
%        .vectorized  true   fobj(X) gets nPop-by-dim, returns nPop-by-1
%        .verbose     true   print progress
%        .printEvery  1
%        .x0          []     rows used as initial individuals
%        .pc          0.9    crossover probability per pair of parents
%        .etaC        15     SBX distribution index
%        .pm          []     mutation probability per gene (default 1/dim)
%        .etaM        20     polynomial-mutation distribution index
%        .tourSize    2      tournament size
%        .nElite      2      best individuals copied unchanged to the next generation
%        .label       'GA'
%
%   Outputs
%     bestScore  cost of the best individual found
%     bestPos    best individual, 1-by-dim
%     curve      best cost after every generation (convergence curve)
%     info       struct: nEval, nIter, bestHistory, meanCost
%
%   One generation
%     1. selection    binary tournament on cost (lower wins)
%     2. crossover    simulated binary crossover, SBX (Deb & Agrawal 1995),
%                     bounded form, each gene of a pair crossed with prob. 0.5
%     3. mutation     polynomial mutation (Deb & Goyal 1996), bounded form
%     4. evaluation   the nPop offspring
%     5. elitism      the nElite best of the old generation replace the
%                     worst offspring (the best cost never gets worse)
%   The initial population is drawn exactly like pso.m and gwo.m
%   (lb + rand(nPop, dim) .* (ub - lb)), so with the same random seed all
%   three optimisers start from the same population.

if nargin < 6 || isempty(opts), opts = struct(); end
opts = setDefault(opts, 'vectorized', true);
opts = setDefault(opts, 'verbose', true);
opts = setDefault(opts, 'printEvery', 1);
opts = setDefault(opts, 'x0', []);
opts = setDefault(opts, 'pc', 0.9);
opts = setDefault(opts, 'etaC', 15);
opts = setDefault(opts, 'pm', []);
opts = setDefault(opts, 'etaM', 20);
opts = setDefault(opts, 'tourSize', 2);
opts = setDefault(opts, 'nElite', 2);
opts = setDefault(opts, 'label', 'GA');

lb = lb(:).';
ub = ub(:).';
dim = numel(lb);
if numel(ub) ~= dim || any(ub < lb)
    error('genetic_algorithm:bounds', 'lb and ub must have the same length and satisfy lb <= ub.');
end
if isempty(opts.pm), opts.pm = 1 / dim; end
nElite = min(max(round(opts.nElite), 0), nPop - 1);

% ---- initial population: uniform in the box (same draw as pso.m / gwo.m) ----
X = lb + rand(nPop, dim) .* (ub - lb);
if ~isempty(opts.x0)
    n0 = min(size(opts.x0, 1), nPop);
    X(1:n0, :) = opts.x0(1:n0, :);
end
X = min(max(X, lb), ub);

curve = nan(1, maxGen);
meanCost = nan(1, maxGen);
bestHistory = nan(maxGen, dim);
bestScore = inf;
bestPos = X(1, :);
nEval = 0;
fit = [];

for gen = 1:maxGen
    if gen > 1
        % 1) selection: tournaments on the current population
        parents = tournament(fit, nPop, opts.tourSize);
        P = X(parents, :);
        % 2) crossover: consecutive parents form pairs
        C = P;
        for k = 1:2:nPop - 1
            if rand < opts.pc
                [C(k, :), C(k + 1, :)] = sbx(P(k, :), P(k + 1, :), lb, ub, opts.etaC);
            end
        end
        % 3) mutation
        C = polyMutation(C, lb, ub, opts.pm, opts.etaM);
        % 4) evaluate the offspring
        fitC = evaluate(fobj, C, opts.vectorized);
        nEval = nEval + nPop;
        % 5) elitism: the best of the old generation replace the worst offspring
        if nElite > 0
            [~, iOld] = sort(fit, 'ascend');
            [~, iNew] = sort(fitC, 'descend');
            C(iNew(1:nElite), :) = X(iOld(1:nElite), :);
            fitC(iNew(1:nElite)) = fit(iOld(1:nElite));
        end
        X = C;
        fit = fitC;
    else
        fit = evaluate(fobj, X, opts.vectorized);
        nEval = nEval + nPop;
    end

    [m, k] = min(fit);
    if m < bestScore
        bestScore = m;
        bestPos = X(k, :);
    end
    curve(gen) = bestScore;
    meanCost(gen) = mean(fit(fit < realmax));
    bestHistory(gen, :) = bestPos;
    if opts.verbose && (mod(gen, opts.printEvery) == 0 || gen == 1 || gen == maxGen)
        fprintf('%s gen %3d/%d  best cost = %-12.6g  x = [%s]\n', opts.label, ...
            gen, maxGen, bestScore, sprintf(' %.6g', bestPos));
    end
end

info = struct('nEval', nEval, 'nIter', maxGen, 'bestHistory', bestHistory, ...
    'meanCost', meanCost);
end

% -------------------------------------------------------------------------
function fit = evaluate(fobj, X, vectorized)
if vectorized
    fit = fobj(X);
else
    fit = zeros(size(X, 1), 1);
    for i = 1:size(X, 1)
        fit(i) = fobj(X(i, :));
    end
end
fit = double(fit(:));
fit(~isfinite(fit)) = realmax;              % NaN/Inf -> worst, still rankable
end

function idx = tournament(fit, n, k)
% n winners of k-way tournaments (lower cost wins).
cand = randi(numel(fit), n, k);
[~, w] = min(fit(cand), [], 2);
idx = cand(sub2ind(size(cand), (1:n).', w));
end

function [c1, c2] = sbx(p1, p2, lb, ub, eta)
% Bounded simulated binary crossover (as in Deb's NSGA-II reference code).
c1 = p1;  c2 = p2;
for j = 1:numel(p1)
    if rand > 0.5 || abs(p1(j) - p2(j)) <= 1e-14 * max(1, ub(j) - lb(j))
        continue
    end
    y1 = min(p1(j), p2(j));  y2 = max(p1(j), p2(j));
    u = rand;
    beta = 1 + 2 * (y1 - lb(j)) / (y2 - y1);
    a = 2 - beta ^ -(eta + 1);
    bq = spread(u, a, eta);
    v1 = 0.5 * ((y1 + y2) - bq * (y2 - y1));
    beta = 1 + 2 * (ub(j) - y2) / (y2 - y1);
    a = 2 - beta ^ -(eta + 1);
    bq = spread(u, a, eta);
    v2 = 0.5 * ((y1 + y2) + bq * (y2 - y1));
    v1 = min(max(v1, lb(j)), ub(j));
    v2 = min(max(v2, lb(j)), ub(j));
    if rand < 0.5
        c1(j) = v2;  c2(j) = v1;
    else
        c1(j) = v1;  c2(j) = v2;
    end
end
end

function bq = spread(u, a, eta)
if u <= 1 / a
    bq = (u * a) ^ (1 / (eta + 1));
else
    bq = (1 / (2 - u * a)) ^ (1 / (eta + 1));
end
end

function X = polyMutation(X, lb, ub, pm, eta)
% Bounded polynomial mutation, each gene mutated with probability pm.
[n, dim] = size(X);
for i = 1:n
    for j = 1:dim
        if rand >= pm || ub(j) <= lb(j)
            continue
        end
        y = X(i, j);
        d1 = (y - lb(j)) / (ub(j) - lb(j));
        d2 = (ub(j) - y) / (ub(j) - lb(j));
        u = rand;
        p = 1 / (eta + 1);
        if u <= 0.5
            val = 2 * u + (1 - 2 * u) * (1 - d1) ^ (eta + 1);
            dq = val ^ p - 1;
        else
            val = 2 * (1 - u) + 2 * (u - 0.5) * (1 - d2) ^ (eta + 1);
            dq = 1 - val ^ p;
        end
        X(i, j) = min(max(y + dq * (ub(j) - lb(j)), lb(j)), ub(j));
    end
end
end

function s = setDefault(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
