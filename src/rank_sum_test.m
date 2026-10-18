function [p, W, z] = rank_sum_test(x, y)
%RANK_SUM_TEST  Two-sided Wilcoxon rank-sum (Mann-Whitney) test.
%
%   [p, W, z] = rank_sum_test(x, y)
%
%   H0: x and y come from the same distribution. p is the two-sided
%   p-value, W the rank sum of x (mid-ranks for ties).
%   Small samples (as in this study, 10 vs 10 runs): exact p-value from all
%   nchoosek(nx+ny, nx) ways to split the pooled ranks (z = NaN).
%   Larger samples: normal approximation with tie and continuity
%   correction. No Statistics Toolbox needed.

x = x(:);  y = y(:);
x = x(isfinite(x));  y = y(isfinite(y));
n1 = numel(x);  n2 = numel(y);  N = n1 + n2;
if n1 == 0 || n2 == 0
    p = NaN;  W = NaN;  z = NaN;
    return
end
r = midranks([x; y]);
W = sum(r(1:n1));
mu = n1 * (N + 1) / 2;
z = NaN;
exact = N <= 24 && nchoosek(N, n1) <= 3e5;
if exact
    C = nchoosek(1:N, n1);
    Ws = sum(reshape(r(C), size(C)), 2);
    p = mean(abs(Ws - mu) >= abs(W - mu) - 1e-9);
else
    [~, ~, ic] = unique(r);
    t = accumarray(ic, 1);
    s2 = n1 * n2 / 12 * ((N + 1) - sum(t.^3 - t) / (N * (N - 1)));
    z = (W - mu - 0.5 * sign(W - mu)) / sqrt(s2);
    p = erfc(abs(z) / sqrt(2));
end
p = min(1, p);
end

function r = midranks(v)
[s, i] = sort(v);
n = numel(v);
r = zeros(n, 1);
k = 1;
while k <= n
    j = k;
    while j < n && s(j + 1) == s(k)
        j = j + 1;
    end
    r(i(k:j)) = (k + j) / 2;
    k = j + 1;
end
end
