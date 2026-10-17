function [bestScore, bestPos, curve, info] = pso(fobj, lb, ub, nParticles, maxIter, opts)
%PSO  Particle Swarm Optimization (global-best PSO, Shi & Eberhart 1998).
%
%   [bestScore, bestPos, curve, info] = pso(fobj, lb, ub, nParticles, maxIter, opts)
%
%   Minimises fobj inside the box lb <= x <= ub. Same interface as gwo.m,
%   so both algorithms can be compared with the same cost and budget.
%
%   Inputs
%     fobj        function handle (see opts.vectorized)
%     lb, ub      1-by-dim lower / upper bounds
%     nParticles  swarm size
%     maxIter     number of iterations
%     opts        optional struct
%        .vectorized  true       fobj(X) gets nParticles-by-dim, returns nParticles-by-1
%        .verbose     true       print progress
%        .printEvery  1
%        .x0          []         rows used as initial particles
%        .w           [0.9 0.4]  inertia weight, linearly from w(1) to w(2)
%        .c1          2.0        cognitive (personal-best) acceleration
%        .c2          2.0        social (global-best) acceleration
%        .vmaxFrac    0.2        velocity limit = vmaxFrac*(ub - lb)
%        .label       'PSO'
%
%   Outputs
%     bestScore  cost of the global best position
%     bestPos    global best position, 1-by-dim
%     curve      global best cost after every iteration
%     info       struct: nEval, nIter, gbestHistory, meanCost
%
%   Update for particle i, dimension j:
%     v = w*v + c1*r1*(pbest - x) + c2*r2*(gbest - x),  |v| <= vmax
%     x = x + v;  a coordinate that leaves the box is clamped to the
%     bound and its velocity is set to zero.

if nargin < 6 || isempty(opts), opts = struct(); end
opts = setDefault(opts, 'vectorized', true);
opts = setDefault(opts, 'verbose', true);
opts = setDefault(opts, 'printEvery', 1);
opts = setDefault(opts, 'x0', []);
opts = setDefault(opts, 'w', [0.9 0.4]);
opts = setDefault(opts, 'c1', 2.0);
opts = setDefault(opts, 'c2', 2.0);
opts = setDefault(opts, 'vmaxFrac', 0.2);
opts = setDefault(opts, 'label', 'PSO');

lb = lb(:).';
ub = ub(:).';
dim = numel(lb);
if numel(ub) ~= dim || any(ub < lb)
    error('pso:bounds', 'lb and ub must have the same length and satisfy lb <= ub.');
end

% ---- initial swarm: uniform in the box (same draw as gwo.m) -------------
X = lb + rand(nParticles, dim) .* (ub - lb);
if ~isempty(opts.x0)
    n0 = min(size(opts.x0, 1), nParticles);
    X(1:n0, :) = opts.x0(1:n0, :);
end
X = min(max(X, lb), ub);
V = zeros(nParticles, dim);
vMax = opts.vmaxFrac * (ub - lb);

pBest = X;
pBestScore = inf(nParticles, 1);
gBest = X(1, :);
gBestScore = inf;

curve = nan(1, maxIter);
meanCost = nan(1, maxIter);
gbestHistory = nan(maxIter, dim);
nEval = 0;
it = 0;

for it = 1:maxIter
    % 1) evaluate the swarm
    if opts.vectorized
        fit = fobj(X);
    else
        fit = zeros(nParticles, 1);
        for i = 1:nParticles
            fit(i) = fobj(X(i, :));
        end
    end
    fit = double(fit(:));
    fit(~isfinite(fit)) = realmax;
    nEval = nEval + nParticles;

    % 2) personal and global bests
    better = fit < pBestScore;
    pBest(better, :) = X(better, :);
    pBestScore(better) = fit(better);
    [m, k] = min(pBestScore);
    if m < gBestScore
        gBestScore = m;
        gBest = pBest(k, :);
    end

    % 3) velocity and position update
    w = opts.w(1) - (opts.w(1) - opts.w(end)) * (it - 1) / max(maxIter - 1, 1);
    r1 = rand(nParticles, dim);
    r2 = rand(nParticles, dim);
    V = w * V + opts.c1 * r1 .* (pBest - X) + opts.c2 * r2 .* (gBest - X);
    V = min(max(V, -vMax), vMax);
    X = X + V;
    out = X < lb | X > ub;
    X = min(max(X, lb), ub);
    V(out) = 0;

    % bookkeeping
    curve(it) = gBestScore;
    meanCost(it) = mean(fit(fit < realmax));
    gbestHistory(it, :) = gBest;
    if opts.verbose && (mod(it, opts.printEvery) == 0 || it == 1 || it == maxIter)
        fprintf('%s iter %3d/%d  best cost = %-12.6g  x = [%s]\n', opts.label, ...
            it, maxIter, gBestScore, sprintf(' %.6g', gBest));
    end
end

nIter = it;
bestScore = gBestScore;
bestPos = gBest;
info = struct('nEval', nEval, 'nIter', nIter, ...
    'gbestHistory', gbestHistory(1:nIter, :), 'meanCost', meanCost(1:nIter));
curve = curve(1:nIter);
end

function s = setDefault(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
