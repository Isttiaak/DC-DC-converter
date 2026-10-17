function make_figures(cfg, T, S, M)
%MAKE_FIGURES  Figures of the ZN / PSO / GWO PID comparison.
%
%   results/figures/combined/
%     fig01_vout_noise_levels    noise levels on top, Vout of every controller
%                                in its own row (PWM-period averages, same
%                                scale), then start-up and Vin-step close-ups
%     fig02_iL_noise_levels      the same for the inductor current
%     fig03_vout_without_noise   Vout 0-10 s, all controllers, then start-up,
%                                switching ripple and Vin-step close-ups
%     fig04_iL_without_noise     the same for the inductor current
%     fig05_vout_with_noise      Vout 0-10 s with sensor noise, then start-up,
%                                noise switching on and Vin-step close-ups
%     fig06_iL_with_noise        the same for the inductor current
%     fig07_convergence_PSO_GWO
%     fig08_performance_metrics
%     fig09_noise_robustness
%     fig10_simulink_model
%   results/figures/individual/  every panel of fig03-fig09 on its own
%
%   Formats: PNG (cfg.fig.dpi) and MATLAB .fig (editable; opens visible).

dirs = {cfg.figCombDir, cfg.figIndDir};
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir'), mkdir(dirs{k}); end
end
cfg.fig.font = pickFont(cfg.fig.fonts);
fprintf('Figure font: %s\n', cfg.fig.font);
applyStyle(cfg);
warning('off', 'MATLAB:print:ContentTypeImageSuggested');
P = T.plant;
G = struct('cfg', cfg, 'S', S, 'P', P, ...
    'stepTxt', sprintf('V_{in} %g \\rightarrow %g V', P.Vin0, P.Vin1));
sigs = {'vout', 'iL'};

% ---- fig01 / fig02: noise levels, one row per controller -----------------------------
for q = 1:2
    fig = rowsFigure(G, sigs{q});
    exportFigure(fig, cfg.figCombDir, sprintf('fig%02d_%s_noise_levels', q, sigs{q}), cfg);
end

% ---- fig03 - fig06: overview + three close-ups -----------------------------------------
n = 3;
for cond = 1:2
    for q = 1:2
        fig = overviewFigure(G, sigs{q}, cond);
        exportFigure(fig, cfg.figCombDir, sprintf('fig%02d_%s_%s', n, sigs{q}, condTag(cond)), cfg);
        n = n + 1;
    end
end

% ---- individual panels of fig03 - fig06 ---------------------------------------------------
for cond = 1:2
    for q = 1:2
        s = sigs{q};
        pans = panelList(G, s, cond);
        for k = 1:numel(pans)
            fig = newFigure(cfg.fig.single);
            ax = axes(fig);
            pans(k).draw(ax, true);
            exportFigure(fig, cfg.figIndDir, sprintf('%s_%s_%s', s, pans(k).tag, condTag(cond)), cfg);
        end
    end
end

% ---- fig07 - fig09: optimisers and metrics -----------------------------------------------
fig = newFigure([16 9]);
drawConvergence(axes(fig), cfg, T, true);
exportFigure(fig, cfg.figCombDir, 'fig07_convergence_PSO_GWO', cfg);
fig = newFigure(cfg.fig.single);
drawConvergence(axes(fig), cfg, T, true);
exportFigure(fig, cfg.figIndDir, 'convergence_PSO_GWO', cfg);

metricList = {
    'StartupOvershoot_pct',  'Start-up overshoot (%)',             'startup_overshoot'
    'StartupSettling_ms',    'Start-up settling time (ms)',        'startup_settling_time'
    'LineStepPeakDev_pct',   'Peak deviation after V_{in} step (%)', 'linestep_peak_deviation'
    'LineStepSettling_ms',   'Settling time after V_{in} step (ms)', 'linestep_settling_time'
    'TotalITAE',             'Total ITAE (V s^2)',                 'total_ITAE'
    'iLPeakLineStep_A',      'Peak i_L after V_{in} step (A)',     'linestep_peak_iL'};
fig = newFigure([20 13]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'loose', 'Padding', 'compact');
for k = 1:size(metricList, 1)
    ax = nexttile(tl);
    drawBars(ax, M.clean.(metricList{k, 1}), metricList{k, 2}, cfg);
end
title(tl, 'Performance without noise (switching model)', 'FontWeight', 'bold', ...
    'FontSize', cfg.fig.labelSize + 1, 'Color', cfg.fig.textColor);
exportFigure(fig, cfg.figCombDir, 'fig08_performance_metrics', cfg);
for k = 1:size(metricList, 1)
    fig = newFigure([9 7]);
    drawBars(axes(fig), M.clean.(metricList{k, 1}), metricList{k, 2}, cfg);
    exportFigure(fig, cfg.figIndDir, ['metric_' metricList{k, 3}], cfg);
end

robust = {'dVout_rms_mV', 'RMS deviation of v_{out} (mV)', 'noise_robustness_vout'
          'diL_rms_A',    'RMS deviation of i_L (A)',      'noise_robustness_iL'};
fig = newFigure([18 8.5]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'loose', 'Padding', 'compact');
for k = 1:2
    drawRobust(nexttile(tl), M, robust{k, 1}, robust{k, 2}, cfg, k == 1);
end
title(tl, 'Effect of sensor noise: deviation from the noise-free response', ...
    'FontWeight', 'bold', 'FontSize', cfg.fig.labelSize + 1, 'Color', cfg.fig.textColor);
exportFigure(fig, cfg.figCombDir, 'fig09_noise_robustness', cfg);
for k = 1:2
    fig = newFigure([10 7.5]);
    drawRobust(axes(fig), M, robust{k, 1}, robust{k, 2}, cfg, true);
    exportFigure(fig, cfg.figIndDir, robust{k, 3}, cfg);
end

% ---- fig10: the Simulink model --------------------------------------------------------------
try
    load_system(cfg.modelFile);
    print(['-s' cfg.model], '-dpng', '-r300', fullfile(cfg.figCombDir, 'fig10_simulink_model.png'));
    fprintf('Model diagram printed.\n');
catch err
    warning('make_figures:model', 'Model diagram not printed: %s', err.message);
end
fprintf('Figures written to %s\n', fileparts(cfg.figCombDir));
end

% =====================================================================================
% Figure layouts
% =====================================================================================
function fig = rowsFigure(G, sig)
% Noise levels on top, one row per controller (same y-scale), two close-ups.
cfg = G.cfg;  P = G.P;
W = cfg.noise.windows;
nC = numel(cfg.ctrl.names);
fig = newFigure(cfg.fig.rowsSize);
L = 0.075;  Wd = 0.905;
figTitle(fig, sprintf('%s with sensor noise of different size at different times', ...
    sigName(sig)), cfg);

% noise levels (block height proportional to sigma)
ax = axes(fig, 'Position', [L 0.865 Wd 0.065]);
hold(ax, 'on');
sMax = max(W(:, 3));
for k = 1:size(W, 1)
    h = W(k, 3) / sMax;
    patch(ax, W(k, [1 2 2 1]), [0 0 h h], cfg.fig.shade, 'EdgeColor', [0.62 0.62 0.58], ...
        'LineWidth', 0.5);
    text(ax, mean(W(k, 1:2)), h, sprintf('%.3g V', W(k, 3) / 100 * P.Vref), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
        'FontSize', cfg.fig.fontSize - 1);
end
plot(ax, [cfg.tStep cfg.tStep], [0 1.9], '-', 'Color', cfg.fig.markColor, 'LineWidth', 0.6);
text(ax, cfg.tStep, 1.9, ['  ' G.stepTxt], 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', 'FontSize', cfg.fig.fontSize - 1);
xlim(ax, [0 cfg.Tstop]);  ylim(ax, [0 1.9]);
ax.YAxis.Visible = 'off';  ax.XTickLabel = {};
grid(ax, 'off');
text(ax, -0.012, 0.3, 'noise \sigma', 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'FontSize', cfg.fig.labelSize);

% one row per controller, PWM-period averages, same y-limits
yl = rowLimits(G, sig);
edges = unique([W(:, 1); W(:, 2); cfg.tStep]);
edges = edges(edges > 0 & edges < cfg.Tstop);
rowH = 0.112;  gap = 0.043;  top = 0.815;
for i = 1:nC
    ax = axes(fig, 'Position', [L, top - i * rowH - (i - 1) * gap, Wd, rowH]);
    hold(ax, 'on');
    for e = edges.'
        plot(ax, [e e], yl, '-', 'Color', cfg.fig.markColor, 'LineWidth', 0.5);
    end
    [t, y] = getTrace(G, i, 2, sig, 'avg');
    [t, y] = minMaxDecimate(t, y, cfg.fig.maxPoints);
    plot(ax, t, y, '-', 'Color', cfg.ctrl.colors(i, :), 'LineWidth', 0.6);
    xlim(ax, [0 cfg.Tstop]);  ylim(ax, yl);
    ylabel(ax, sigLabel(sig), 'FontSize', cfg.fig.labelSize);
    text(ax, 0, 1.03, cfg.ctrl.labels{i}, 'Units', 'normalized', 'FontWeight', 'bold', ...
        'VerticalAlignment', 'bottom', 'FontSize', cfg.fig.labelSize);
    if i == 1
        text(ax, 1, 1.03, 'PWM-period averages, same scale in every row', 'Units', 'normalized', ...
            'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
            'FontSize', cfg.fig.fontSize - 1);
    end
    if i < nC
        ax.XTickLabel = {};
    else
        xlabel(ax, 'time (s)', 'FontSize', cfg.fig.labelSize);
    end
end

% close-ups (switching waveform) of the noisy run
pans = panelList(G, sig, 2);
ax = axes(fig, 'Position', [L 0.065 0.42 0.225]);
pans(2).draw(ax, false);  addLegend(ax, 'southeast');
ax = axes(fig, 'Position', [L + Wd - 0.42 0.065 0.42 0.225]);
pans(4).draw(ax, false);
end

function fig = overviewFigure(G, sig, cond)
% Full run of all controllers on top, three close-ups below.
cfg = G.cfg;
fig = newFigure(cfg.fig.overSize);
if cond == 1
    figTitle(fig, sprintf('%s without noise', sigName(sig)), cfg);
else
    figTitle(fig, sprintf('%s with sensor noise', sigName(sig)), cfg);
end
pans = panelList(G, sig, cond);
L = 0.07;  Wd = 0.905;
ax = axes(fig, 'Position', [L 0.575 Wd 0.335]);
pans(1).draw(ax, false);  addLegend(ax, 'southeast');
w = 0.262;  g = (Wd - 3 * w) / 2;
for k = 2:4
    ax = axes(fig, 'Position', [L + (k - 2) * (w + g), 0.085, w, 0.365]);
    pans(k).draw(ax, false);
end
end

function pans = panelList(G, sig, cond)
% The four panels of the overview figure: full run, start-up, middle, Vin step.
cfg = G.cfg;  Z = cfg.zoom;  W = cfg.noise.windows;
pans = struct('tag', {}, 'draw', {});
pans(1).tag = 'full';
pans(1).draw = @(ax, long) drawFull(ax, G, sig, cond, long);
pans(2).tag = 'startup';
pans(2).draw = @(ax, long) drawOverlay(ax, G, sig, cond, Z.startup, 'raw', ...
    pick(long, sprintf('%s at start-up, %s', sigName(sig), condText(cond)), 'start-up'), 'zero', []);
if cond == 1
    pans(3).tag = 'ripple';
    pans(3).draw = @(ax, long) drawOverlay(ax, G, sig, cond, Z.ripple, 'raw', ...
        pick(long, sprintf('%s switching ripple in steady state (V_{in} = %g V)', sigName(sig), G.P.Vin0), ...
        sprintf('steady state, V_{in} = %g V (switching ripple)', G.P.Vin0)), 'auto', []);
else
    k = min(cfg.zoom.onsetWindow, size(W, 1));
    t0 = W(k, 1);
    span = min(0.3, 0.6 * (W(k, 2) - W(k, 1)));
    win = [t0 - span / 6, t0 + 5 * span / 6];
    pans(3).tag = 'noise_on';
    pans(3).draw = @(ax, long) drawOverlay(ax, G, sig, cond, win, 'avg', ...
        pick(long, sprintf('%s when noise \\sigma = %.3g V switches on at t = %g s (PWM-period average)', ...
        sigName(sig), W(k, 3) / 100 * G.P.Vref, t0), ...
        sprintf('noise on at t = %g s (PWM-period average)', t0)), 'auto', t0);
end
pans(4).tag = 'vin_step';
pans(4).draw = @(ax, long) drawOverlay(ax, G, sig, cond, Z.line, 'raw', ...
    pick(long, sprintf('%s after the input step %s at t = %g s, %s', sigName(sig), G.stepTxt, ...
    cfg.tStep, condText(cond)), sprintf('input step %s at t = %g s', G.stepTxt, cfg.tStep)), ...
    'auto', cfg.tStep);
end

% =====================================================================================
% Panels
% =====================================================================================
function drawFull(ax, G, sig, cond, long)
% 0 - Tstop, all controllers, PWM-period averages; noise windows shaded.
cfg = G.cfg;  W = cfg.noise.windows;
hold(ax, 'on');
hi = -inf;
for i = 1:numel(cfg.ctrl.names)
    [t, y] = getTrace(G, i, cond, sig, 'avg');
    [t, y] = minMaxDecimate(t, y, cfg.fig.maxPoints);
    plot(ax, t, y, '-', 'Color', cfg.ctrl.colors(i, :), 'LineWidth', cfg.ctrl.widths(i), ...
        'DisplayName', cfg.ctrl.labels{i});
    hi = max(hi, max(y));
end
yl = [0, niceTop(hi)];
xlim(ax, [0 cfg.Tstop]);  ylim(ax, yl);
if cond == 2
    for k = 1:size(W, 1)
        p = patch(ax, W(k, [1 2 2 1]), yl([1 1 2 2]), cfg.fig.shade, 'FaceAlpha', 0.45, ...
            'EdgeColor', 'none', 'HandleVisibility', 'off');
        uistack(p, 'bottom');
        text(ax, mean(W(k, 1:2)), yl(2), sprintf('noise %.3g V', W(k, 3) / 100 * G.P.Vref), ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
            'FontSize', cfg.fig.fontSize - 1);
    end
end
plot(ax, [cfg.tStep cfg.tStep], yl, '-', 'Color', cfg.fig.markColor, 'LineWidth', 0.6, ...
    'HandleVisibility', 'off');
text(ax, cfg.tStep, yl(1) + 0.86 * diff(yl), ['  ' G.stepTxt], 'HorizontalAlignment', 'left', ...
    'VerticalAlignment', 'top', 'FontSize', cfg.fig.fontSize - 1);
set(ax, 'Layer', 'top');
xlabel(ax, 'time (s)', 'FontSize', cfg.fig.labelSize);
ylabel(ax, sigLabel(sig), 'FontSize', cfg.fig.labelSize);
title(ax, pick(long, sprintf('%s, %s (PWM-period averages)', sigName(sig), condText(cond)), ''), ...
    'FontSize', cfg.fig.labelSize);
if long, addLegend(ax, 'southeast'); end
end

function drawOverlay(ax, G, sig, cond, win, mode, ttl, yMode, tMark)
% All controllers in one time window; 'raw' = switching waveform,
% 'avg' = one value per PWM period.
cfg = G.cfg;  P = G.P;
hold(ax, 'on');
if strcmp(sig, 'vout')
    plot(ax, win, [P.Vref P.Vref], '-', 'Color', cfg.fig.refColor, 'LineWidth', 0.5, ...
        'HandleVisibility', 'off');
end
lo = inf;  hi = -inf;
for i = 1:numel(cfg.ctrl.names)
    [t, y] = getTrace(G, i, cond, sig, mode);
    in = t >= win(1) & t <= win(2);
    [x, yy] = minMaxDecimate(t(in), y(in), cfg.fig.maxPoints);
    plot(ax, x, yy, '-', 'Color', cfg.ctrl.colors(i, :), 'LineWidth', cfg.ctrl.widths(i), ...
        'DisplayName', cfg.ctrl.labels{i});
    lo = min(lo, min(yy));  hi = max(hi, max(yy));
end
xlim(ax, win);
if strcmp(yMode, 'zero')
    yl = [0, niceTop(hi)];
else
    yl = paddedLimits(lo, hi, cfg.fig.minSpan.(sig));
end
ylim(ax, yl);
if ~isempty(tMark)
    plot(ax, [tMark tMark], yl, '-', 'Color', cfg.fig.markColor, 'LineWidth', 0.6, ...
        'HandleVisibility', 'off');
end
xlabel(ax, 'time (s)', 'FontSize', cfg.fig.labelSize);
ylabel(ax, sigLabel(sig), 'FontSize', cfg.fig.labelSize);
title(ax, ttl, 'FontSize', cfg.fig.labelSize);
end

function [t, y] = getTrace(G, i, cond, sig, mode)
if strcmp(mode, 'raw')
    t = G.S.t;
    y = double(G.S.sig(i, cond).(sig));
else
    t = G.S.tAvg + 0.5 / G.P.fsw;           % centre of each PWM period
    y = double(G.S.avg(i, cond).(sig));
end
t = t(:);  y = y(:);
end

function yl = rowLimits(G, sig)
% Same y-limits for every row: range of the noisy runs outside the start-up
% and Vin-step transients (those are shown in the close-ups and may clip).
cfg = G.cfg;
lo = inf;  hi = -inf;
for i = 1:numel(cfg.ctrl.names)
    [t, y] = getTrace(G, i, 2, sig, 'avg');
    keep = ~(t < cfg.zoom.startup(2) | (t >= cfg.tStep & t < cfg.zoom.line(2)));
    lo = min(lo, min(y(keep)));  hi = max(hi, max(y(keep)));
end
if strcmp(sig, 'vout')
    d = max(abs([lo hi] - G.P.Vref));
    lo = G.P.Vref - d;  hi = G.P.Vref + d;
end
yl = paddedLimits(lo, hi, cfg.fig.minSpan.(sig));
end

% =====================================================================================
% Optimiser and metric charts
% =====================================================================================
function drawConvergence(ax, cfg, T, showLegend)
algos = {'PSO', 'GWO'};
cols = cfg.ctrl.colors(2:3, :);
hold(ax, 'on');
for a = 1:2
    C = T.stats.(algos{a}).curves;
    faded = 0.3 * cols(a, :) + 0.7;
    for r = 1:size(C, 1)
        plot(ax, 1:size(C, 2), C(r, :), '-', 'Color', faded, 'LineWidth', 0.6, ...
            'HandleVisibility', 'off');
    end
end
for a = 1:2
    C = T.stats.(algos{a}).curves;
    [~, ib] = min(C(:, end));
    plot(ax, 1:size(C, 2), C(ib, :), '-', 'Color', cols(a, :), 'LineWidth', 2.0, ...
        'DisplayName', sprintf('%s, best of %d runs (J = %.5g)', algos{a}, size(C, 1), C(ib, end)));
end
set(ax, 'YScale', 'log');
xlim(ax, [1 cfg.opt.maxIter]);
xlabel(ax, 'iteration', 'FontSize', cfg.fig.labelSize);
ylabel(ax, 'best cost J', 'FontSize', cfg.fig.labelSize);
title(ax, sprintf('PSO vs GWO convergence (%d agents; thin lines: all %d runs)', ...
    cfg.opt.nPop, cfg.opt.nRuns), 'FontSize', cfg.fig.labelSize);
if showLegend, addLegend(ax, 'northeast'); end
end

function drawBars(ax, vals, ylab, cfg)
vals = vals(:).';
b = bar(ax, 1:numel(vals), vals, 0.6, 'FaceColor', 'flat', 'EdgeColor', 'none');
b.CData = cfg.ctrl.colors(1:numel(vals), :);
set(ax, 'XTick', 1:numel(vals), 'XTickLabel', cfg.ctrl.labels, 'XTickLabelRotation', 0, ...
    'XLim', [0.4, numel(vals) + 0.6]);
ylabel(ax, ylab, 'FontSize', cfg.fig.labelSize);
top = max(vals);
if ~(top > 0), top = 1; end
ylim(ax, [0, 1.22 * top]);
for k = 1:numel(vals)
    text(ax, k, vals(k), sprintf('%.3g', vals(k)), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', cfg.fig.fontSize);
end
ax.XGrid = 'off';
end

function drawRobust(ax, M, field, ylab, cfg, showLegend)
hold(ax, 'on');
for i = 1:numel(cfg.ctrl.labels)
    r = M.noise(M.noise.Controller == cfg.ctrl.labels{i}, :);
    plot(ax, r.NoiseSigma_pct, r.(field), '-', 'Color', cfg.ctrl.colors(i, :), ...
        'LineWidth', 1.2, 'Marker', 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', cfg.ctrl.colors(i, :), 'DisplayName', cfg.ctrl.labels{i});
end
xlabel(ax, 'sensor noise \sigma (% of V_{ref})', 'FontSize', cfg.fig.labelSize);
ylabel(ax, ylab, 'FontSize', cfg.fig.labelSize);
ylim(ax, [0, 1.15 * max(M.noise.(field))]);
if showLegend, addLegend(ax, 'northwest'); end
end

% =====================================================================================
% Helpers
% =====================================================================================
function s = sigName(sig)
if strcmp(sig, 'vout'), s = 'Output voltage'; else, s = 'Inductor current'; end
end

function s = sigLabel(sig)
if strcmp(sig, 'vout'), s = 'v_{out} (V)'; else, s = 'i_L (A)'; end
end

function s = condTag(cond)
if cond == 1, s = 'without_noise'; else, s = 'with_noise'; end
end

function s = condText(cond)
if cond == 1, s = 'without noise'; else, s = 'with sensor noise'; end
end

function v = pick(long, a, b)
if long, v = a; else, v = b; end
end

function addLegend(ax, loc)
lg = legend(ax, 'Location', loc, 'Box', 'on');
lg.EdgeColor = [0.15 0.15 0.15];
lg.Color = 'w';
end

function figTitle(fig, txt, cfg)
annotation(fig, 'textbox', [0 0.945 1 0.05], 'String', txt, 'EdgeColor', 'none', ...
    'HorizontalAlignment', 'center', 'VerticalAlignment', 'middle', 'FontWeight', 'bold', ...
    'FontSize', cfg.fig.labelSize + 1, 'FontName', cfg.fig.font, 'Color', cfg.fig.textColor);
end

function v = niceTop(hi)
% Round an upper axis limit up to a tidy value (42.6 -> 45, 70.1 -> 80).
if ~(hi > 0), v = 1; return; end
s = 10 ^ floor(log10(hi));
r = hi / s;
if r < 2.5, s = s / 5; elseif r < 5, s = s / 2; end
v = ceil(1.04 * hi / s) * s;
end

function yl = paddedLimits(lo, hi, minSpan)
% y-limits with 10 % margin; a nearly flat trace gets at least minSpan.
if hi - lo < minSpan
    mid = (hi + lo) / 2;
    lo = mid - minSpan / 2;
    hi = mid + minSpan / 2;
end
r = hi - lo;
if ~(r > 0), r = max(abs(hi), 1) * 0.1; end
ylo = lo - 0.1 * r;
if lo >= 0 && ylo < 0, ylo = 0; end
yl = [ylo, hi + 0.1 * r];
end

function [xd, yd] = minMaxDecimate(x, y, nb)
% Minimum and maximum of each of nb buckets, in time order: keeps peaks,
% noise and the switching-ripple envelope while limiting the point count.
n = numel(x);
if n <= 2 * nb
    xd = x;  yd = y;
    return
end
edges = round(linspace(0, n, nb + 1));
xd = zeros(2 * nb, 1);  yd = xd;
for b = 1:nb
    idx = edges(b) + 1:edges(b + 1);
    [ymin, i1] = min(y(idx));
    [ymax, i2] = max(y(idx));
    if i1 <= i2
        xd(2*b-1:2*b) = x(idx([i1 i2]));  yd(2*b-1:2*b) = [ymin; ymax];
    else
        xd(2*b-1:2*b) = x(idx([i2 i1]));  yd(2*b-1:2*b) = [ymax; ymin];
    end
end
end

function f = pickFont(candidates)
f = candidates{end};
try
    avail = listfonts;
    for k = 1:numel(candidates)
        if any(strcmpi(avail, candidates{k}))
            f = candidates{k};
            return
        end
    end
catch
end
end

function fig = newFigure(sizeCm)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [1 1 sizeCm(1) sizeCm(2)]);
end

function applyStyle(cfg)
tc = cfg.fig.textColor;  ac = cfg.fig.axisColor;
set(groot, 'defaultAxesFontName', cfg.fig.font, 'defaultTextFontName', cfg.fig.font, ...
    'defaultLegendFontName', cfg.fig.font, ...
    'defaultAxesFontSize', cfg.fig.fontSize, 'defaultTextFontSize', cfg.fig.fontSize, ...
    'defaultLegendFontSize', cfg.fig.fontSize, 'defaultLegendBox', 'off', ...
    'defaultAxesLineWidth', 0.5, 'defaultAxesTickDir', 'out', 'defaultAxesTickLength', [0.006 0.006], ...
    'defaultAxesBox', 'off', 'defaultAxesXGrid', 'on', 'defaultAxesYGrid', 'on', ...
    'defaultAxesGridColor', [0.85 0.85 0.85], 'defaultAxesGridAlpha', 0.7, ...
    'defaultAxesXColor', ac, 'defaultAxesYColor', ac, 'defaultTextColor', tc, ...
    'defaultAxesTitleFontWeight', 'normal', 'defaultAxesTitleFontSizeMultiplier', 1, ...
    'defaultAxesLabelFontSizeMultiplier', 1, 'defaultFigureColor', 'w');
end

function exportFigure(fig, folder, name, cfg)
base = fullfile(folder, name);
for k = 1:numel(cfg.fig.formats)
    switch cfg.fig.formats{k}
        case 'png'
            exportgraphics(fig, [base '.png'], 'Resolution', cfg.fig.dpi);
        case 'fig'
            % saved invisible (made off-screen); opens visible in MATLAB
            set(fig, 'CreateFcn', 'set(gcbo, ''Visible'', ''on'')');
            savefig(fig, [base '.fig'], 'compact');
    end
end
close(fig);
end
