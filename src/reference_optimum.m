function R = reference_optimum(P, lb, ub, c, opt)
%REFERENCE_OPTIMUM  Best PID gains of the tuning cost found WITHOUT a
%   metaheuristic, as the yardstick for PSO, GA and GWO.
%
%   R = reference_optimum(P, lb, ub, c, opt)
%
%   1. exhaustive grid: opt.n points per gain over the whole search box
%      (opt.n = 35 -> 42,875 gain sets), cost from boost_pid_cost
%   2. local minima of the grid (each point lower than its 26 neighbours)
%   3. every one of the opt.nStart best minima is refined by a pattern
%      search: an m-point grid per gain around the current point plus
%      "pattern moves" along the last successful step (follows the long,
%      narrow valley of this cost); the grid keeps its size while the cost
%      improves and is halved when it does not, until it is smaller than
%      opt.tol of the box (or opt.maxIt iterations). m = opt.m(1) for the
%      best minimum (the optimum needs the finer grid: the valley floor is
%      a narrow ridge), opt.m(end) for the others
%   4. cost maps around the optimum for the landscape figure
%
%   R.Kstar, R.Jstar    best gains [Kp Ki Kd] and their cost
%   R.minima            refined local minima, best first (struct array J, K, Jgrid, Kgrid)
%   R.feasibleFraction  share of the box with a feasible PID (stable,
%                       no latch-up, settled; i.e. not penalised)
%   R.maps              cost maps: .box (Kp-Ki over the whole box, Kd = Kd*),
%                       .Kp_Ki, .Kp_Kd, .Ki_Kd (zoom around K*); fields a, b, J
%   R.nEval, R.time

t0 = tic;
lb = lb(:).';  ub = ub(:).';
pen = 1e3;
if isfield(c, 'penalty') && ~isempty(c.penalty), pen = c.penalty; end
cost = @(X) costBatch(X, P, c, opt.batch);
nEval = 0;

% ---- 1) exhaustive grid --------------------------------------------------------
n = opt.n;
ax = arrayfun(@(d) linspace(lb(d), ub(d), n), 1:3, 'UniformOutput', false);
[A, B, C] = ndgrid(ax{:});
G = [A(:), B(:), C(:)];
Jg = reshape(cost(G), n, n, n);
nEval = nEval + size(G, 1);
feas = Jg < 0.5 * pen;
R.feasibleFraction = mean(feas(:));
fprintf('Reference optimum: %d-point grid done (%.0f s), %.1f %% of the box feasible\n', ...
    numel(Jg), toc(t0), 100 * R.feasibleFraction);

% ---- 2) local minima of the grid ---------------------------------------------------
Jinf = Jg;
Jinf(~feas) = inf;
Pd = inf(n + 2, n + 2, n + 2);
Pd(2:n + 1, 2:n + 1, 2:n + 1) = Jinf;
isMin = feas;
for di = -1:1
    for dj = -1:1
        for dk = -1:1
            if di == 0 && dj == 0 && dk == 0, continue; end
            nb = Pd((2:n + 1) + di, (2:n + 1) + dj, (2:n + 1) + dk);
            isMin = isMin & (Jinf <= nb);
        end
    end
end
idx = find(isMin);
[~, o] = sort(Jg(idx));
idx = idx(o);
nS = min(opt.nStart, numel(idx));

% ---- 3) refine the best local minima -------------------------------------------------
step = (ub - lb) / (n - 1);
minima = struct('J', {}, 'K', {}, 'Jgrid', {}, 'Kgrid', {}, 'iterations', {});
for s0 = 1:nS
    x = G(idx(s0), :);
    xPrev = x;
    h = 1.5 * step;
    Jx = Jg(idx(s0));
    it = 0;
    mS = opt.m(min(s0, numel(opt.m)));
    while it < opt.maxIt && any(h >= opt.tol * (ub - lb))
        it = it + 1;
        g = arrayfun(@(d) min(max(linspace(x(d) - h(d), x(d) + h(d), mS), lb(d)), ub(d)), ...
            1:3, 'UniformOutput', false);
        [a, b, cc] = ndgrid(g{:});
        X = [a(:), b(:), cc(:)];
        dx = x - xPrev;
        if any(dx ~= 0)                       % pattern moves along the last step
            X = [X; min(max(x + [0.5; 1; 2; 4; 8] * dx, lb), ub)]; %#ok<AGROW>
        end
        J = cost(X);
        nEval = nEval + size(X, 1);
        [Jm, k] = min(J);
        if Jm < Jx
            xPrev = x;
            x = X(k, :);
            Jx = Jm;
        else
            xPrev = x;
            h = 0.5 * h;
        end
    end
    minima(end + 1) = struct('J', Jx, 'K', x, 'Jgrid', Jg(idx(s0)), 'Kgrid', G(idx(s0), :), ...
        'iterations', it); %#ok<AGROW>
    fprintf('  local minimum %d: grid J = %.6g -> refined J = %.8g at Kp = %.6g, Ki = %.6g, Kd = %.6g (%d it.)\n', ...
        s0, Jg(idx(s0)), Jx, x, it);
end
if isempty(minima)
    [Jm, k] = min(Jg(:));
    minima = struct('J', Jm, 'K', G(k, :), 'Jgrid', Jm, 'Kgrid', G(k, :), 'iterations', 0);
end
[~, o] = sort([minima.J]);
minima = minima(o);
R.minima = minima;
R.nGridMinima = numel(idx);
R.Kstar = minima(1).K;
R.Jstar = minima(1).J;
R.grid = struct('n', n, 'axes', {ax});

% ---- 4) cost maps around the optimum ------------------------------------------------
Ks = R.Kstar;
pairs = {'Kp_Ki', [1 2]; 'Kp_Kd', [1 3]; 'Ki_Kd', [2 3]};
for p = 1:size(pairs, 1)
    ij = pairs{p, 2};
    lo = max(Ks * (1 - opt.mapSpan), lb);
    hi = min(Ks * (1 + opt.mapSpan), ub);
    a = linspace(lo(ij(1)), hi(ij(1)), opt.mapN);
    b = linspace(lo(ij(2)), hi(ij(2)), opt.mapN);
    [AA, BB] = ndgrid(a, b);
    X = repmat(Ks, numel(AA), 1);
    X(:, ij(1)) = AA(:);
    X(:, ij(2)) = BB(:);
    R.maps.(pairs{p, 1}) = struct('a', a, 'b', b, 'J', reshape(cost(X), size(AA)), 'dims', ij);
    nEval = nEval + size(X, 1);
end
a = linspace(lb(1), ub(1), opt.boxN);
b = linspace(lb(2), ub(2), opt.boxN);
[AA, BB] = ndgrid(a, b);
X = repmat(Ks, numel(AA), 1);
X(:, 1) = AA(:);
X(:, 2) = BB(:);
R.maps.box = struct('a', a, 'b', b, 'J', reshape(cost(X), size(AA)), 'dims', [1 2]);
nEval = nEval + size(X, 1);
R.penalty = pen;
R.nEval = nEval;
R.time = toc(t0);
fprintf(['Reference optimum: J* = %.8g at Kp = %.6g, Ki = %.6g, Kd = %.6g ' ...
    '(%d grid minima, %d cost evaluations, %.0f s)\n'], R.Jstar, R.Kstar, R.nGridMinima, nEval, R.time);
end

% -------------------------------------------------------------------------
function J = costBatch(X, P, c, batch)
% Cost of many gain sets, in batches (keeps the vectorised arrays small).
J = zeros(size(X, 1), 1);
for i0 = 1:batch:size(X, 1)
    ii = i0:min(i0 + batch - 1, size(X, 1));
    J(ii) = boost_pid_cost(X(ii, :), P, c);
end
end
