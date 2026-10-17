function [bestScore, bestPos, curve, info] = gwo(fobj, lb, ub, nWolves, maxIter, opts)
%GWO  Grey Wolf Optimizer (Mirjalili, Mirjalili & Lewis, 2014).
%
%   [bestScore, bestPos, curve, info] = gwo(fobj, lb, ub, nWolves, maxIter, opts)
%
%   Minimises fobj inside the box lb <= x <= ub.
%
%   Inputs
%     fobj     function handle returning the cost of candidate solutions.
%              opts.vectorized = true : fobj(X) gets an nWolves-by-dim matrix
%                                       and returns nWolves-by-1 costs
%              opts.vectorized = false: fobj(x) gets one 1-by-dim row
%     lb, ub   1-by-dim lower / upper bounds
%     nWolves  pack size (number of search agents)
%     maxIter  number of iterations
%     opts     optional struct
%        .vectorized  true   see above
%        .verbose     true   print progress
%        .printEvery  1      print every N iterations
%        .x0          []     rows used as initial wolves (e.g. a known design)
%        .stallIter   inf    stop if alpha has not improved for N iterations
%        .label       'GWO'  prefix of the progress lines
%
%   Outputs
%     bestScore  cost of the alpha wolf (best solution found)
%     bestPos    position of the alpha wolf, 1-by-dim
%     curve      alpha cost after every iteration (convergence curve)
%     info       struct: betaPos, deltaPos, betaScore, deltaScore,
%                nEval, nIter, alphaHistory (alpha position per iteration),
%                meanCost (mean pack cost per iteration)
%
%   Algorithm (one iteration)
%     1. clamp every wolf to [lb, ub] and evaluate its cost
%     2. alpha, beta, delta = the three best wolves found so far
%     3. a decreases linearly from 2 to 0 (exploration -> exploitation)
%     4. for each leader L in {alpha, beta, delta}:
%            A = 2*a*r1 - a,  C = 2*r2,   r1, r2 ~ U(0,1)
%            D = |C.*X_L - X|,  X_L' = X_L - A.*D
%     5. new position X = (X_alpha' + X_beta' + X_delta') / 3

if nargin < 6 || isempty(opts), opts = struct(); end
opts = setDefault(opts, 'vectorized', true);
opts = setDefault(opts, 'verbose', true);
opts = setDefault(opts, 'printEvery', 1);
opts = setDefault(opts, 'x0', []);
opts = setDefault(opts, 'stallIter', inf);
opts = setDefault(opts, 'label', 'GWO');

lb = lb(:).';
ub = ub(:).';
dim = numel(lb);
if numel(ub) ~= dim || any(ub < lb)
    error('gwo:bounds', 'lb and ub must have the same length and satisfy lb <= ub.');
end

% ---- initial pack: uniform in the box (+ optional seeded wolves) ---------
X = lb + rand(nWolves, dim) .* (ub - lb);
if ~isempty(opts.x0)
    n0 = min(size(opts.x0, 1), nWolves);
    X(1:n0, :) = opts.x0(1:n0, :);
end

alphaPos = zeros(1, dim);  alphaScore = inf;
betaPos  = zeros(1, dim);  betaScore  = inf;
deltaPos = zeros(1, dim);  deltaScore = inf;

curve        = nan(1, maxIter);
meanCost     = nan(1, maxIter);
alphaHistory = nan(maxIter, dim);
nEval = 0;
stall = 0;
it = 0;

for it = 1:maxIter
    % 1) keep the pack inside the search box, evaluate
    X = min(max(X, lb), ub);
    if opts.vectorized
        fit = fobj(X);
    else
        fit = zeros(nWolves, 1);
        for i = 1:nWolves
            fit(i) = fobj(X(i, :));
        end
    end
    fit = double(fit(:));
    fit(~isfinite(fit)) = realmax;          % NaN/Inf -> worst, still rankable
    nEval = nEval + nWolves;

    % 2) update the three leaders (alpha <= beta <= delta)
    prevAlpha = alphaScore;
    for i = 1:nWolves
        f = fit(i);
        if f < alphaScore
            deltaScore = betaScore;   deltaPos = betaPos;
            betaScore  = alphaScore;  betaPos  = alphaPos;
            alphaScore = f;           alphaPos = X(i, :);
        elseif f < betaScore
            deltaScore = betaScore;   deltaPos = betaPos;
            betaScore  = f;           betaPos  = X(i, :);
        elseif f < deltaScore
            deltaScore = f;           deltaPos = X(i, :);
        end
    end
    if ~isfinite(betaScore),  betaPos  = alphaPos; end
    if ~isfinite(deltaScore), deltaPos = betaPos;  end

    % 3) control parameter a: 2 (first iteration) -> 0 (last iteration)
    a = 2 - 2 * (it - 1) / max(maxIter - 1, 1);

    % 4)-5) encircle / hunt the prey guided by alpha, beta and delta
    r1 = rand(nWolves, dim);  r2 = rand(nWolves, dim);
    A1 = 2 * a * r1 - a;      C1 = 2 * r2;
    X1 = alphaPos - A1 .* abs(C1 .* alphaPos - X);

    r1 = rand(nWolves, dim);  r2 = rand(nWolves, dim);
    A2 = 2 * a * r1 - a;      C2 = 2 * r2;
    X2 = betaPos - A2 .* abs(C2 .* betaPos - X);

    r1 = rand(nWolves, dim);  r2 = rand(nWolves, dim);
    A3 = 2 * a * r1 - a;      C3 = 2 * r2;
    X3 = deltaPos - A3 .* abs(C3 .* deltaPos - X);

    X = (X1 + X2 + X3) / 3;

    % bookkeeping
    curve(it) = alphaScore;
    meanCost(it) = mean(fit(fit < realmax));
    alphaHistory(it, :) = alphaPos;
    if alphaScore < prevAlpha
        stall = 0;
    else
        stall = stall + 1;
    end
    if opts.verbose && (mod(it, opts.printEvery) == 0 || it == 1 || it == maxIter)
        fprintf('%s iter %3d/%d  best cost = %-12.6g  x = [%s]\n', opts.label, ...
            it, maxIter, alphaScore, sprintf(' %.6g', alphaPos));
    end
    if stall >= opts.stallIter
        if opts.verbose
            fprintf('%s stopped: no improvement in %d iterations.\n', opts.label, stall);
        end
        break
    end
end

nIter = it;
curve = curve(1:nIter);
bestScore = alphaScore;
bestPos = alphaPos;
info = struct('betaPos', betaPos, 'betaScore', betaScore, ...
    'deltaPos', deltaPos, 'deltaScore', deltaScore, ...
    'nEval', nEval, 'nIter', nIter, ...
    'alphaHistory', alphaHistory(1:nIter, :), 'meanCost', meanCost(1:nIter));
end

function s = setDefault(s, name, value)
if ~isfield(s, name) || isempty(s.(name))
    s.(name) = value;
end
end
