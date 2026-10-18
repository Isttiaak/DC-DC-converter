function make_figures(cfg, T, S, M)
%MAKE_FIGURES  Figures of the ZN / PSO / GA / GWO PID comparison.
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
%     fig07_convergence          PSO / GA / GWO: best cost vs evaluations, every run
%     fig08_all_runs             final cost of every run, relative to the optimum
%     fig09_cost_landscape       cost around the optimum with every run's end point
%     fig10_performance_metrics  bar charts (switching model, no noise)
%     fig11_noise_robustness     deviation caused by the sensor noise vs its level
%     fig12_simulink_model
%   results/figures/individual/  every panel of fig03-fig11 on its own
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

% ---- fig07 - fig09: the optimisers (all runs) -------------------------------------
fig = newFigure([18 9.5]);
drawConvergence(axes(fig), cfg, T, true);
exportFigure(fig, cfg.figCombDir, 'fig07_convergence', cfg);
fig = newFigure(cfg.fig.single);
drawConvergence(axes(fig), cfg, T, true);
exportFigure(fig, cfg.figIndDir, 'convergence', cfg);

fig = newFigure([18 9.5]);
drawRuns(axes(fig), cfg, T);
exportFigure(fig, cfg.figCombDir, 'fig08_all_runs', cfg);
fig = newFigure(cfg.fig.single);
drawRuns(axes(fig), cfg, T);
exportFigure(fig, cfg.figIndDir, 'all_runs_final_cost', cfg);

if isfield(T, 'ref') && isfield(T.ref, 'maps') && isstruct(T.ref.maps) && isfield(T.ref.maps, 'box')
    fig = landscapeFigure(cfg, T);
    exportFigure(fig, cfg.figCombDir, 'fig09_cost_landscape', cfg);
end

% ---- fig10 / fig11: performance and noise robustness ----------------------------------------
metricList = {
    'StartupOvershoot_pct',  'Start-up overshoot (%)',             'startup_overshoot'
    'StartupSettling_ms',    'Start-up settling time (ms)',        'startup_settling_time'
    'LineStepPeakDev_pct',   'Peak deviation after V_{in} step (%)', 'linestep_peak_deviation'
    'LineStepSettling_ms',   'Settling time after V_{in} step (ms)', 'linestep_settling_time'
    'TotalITAE',             'Total ITAE (V s^2)',                 'total_ITAE'
    'iLPeakLineStep_A',      'Peak i_L after V_{in} step (A)',     'linestep_peak_iL'};
fig = newFigure([22 13]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'loose', 'Padding', 'compact');
for k = 1:size(metricList, 1)
    ax = nexttile(tl);
    drawBars(ax, M.clean.(metricList{k, 1}), metricList{k, 2}, cfg);
end
title(tl, 'Performance without noise (switching model)', 'FontWeight', 'bold', ...
    'FontSize', cfg.fig.labelSize + 1, 'Color', cfg.fig.textColor);
exportFigure(fig, cfg.figCombDir, 'fig10_performance_metrics', cfg);
for k = 1:size(metricList, 1)
    fig = newFigure([10 7]);
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
exportFigure(fig, cfg.figCombDir, 'fig11_noise_robustness', cfg);
for k = 1:2
    fig = newFigure([10 7.5]);
    drawRobust(axes(fig), M, robust{k, 1}, robust{k, 2}, cfg, true);
    exportFigure(fig, cfg.figIndDir, robust{k, 3}, cfg);
end

% ---- fig12: the Simulink model --------------------------------------------------------------
try
    load_system(cfg.modelFile);
    print(['-s' cfg.model], '-dpng', '-r300', fullfile(cfg.figCombDir, 'fig12_simulink_model.png'));
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
% Heights are set in cm, so any number of controllers fits.
cfg = G.cfg;  P = G.P;
W = cfg.noise.windows;
nC = numel(cfg.ctrl.names);
Wcm = cfg.fig.rowsSize(1);
topT = 1.3;  stripH = 1.15;  gapS = 0.95;  rowH = 2.0;  rowG = 0.85;
xlab = 1.25;  gapP = 0.9;  panH = 4.6;  bot = 1.25;
H = topT + stripH + gapS + nC * rowH + (nC - 1) * rowG + xlab + gapP + panH + bot;
fig = newFigure([Wcm H]);
L = 0.075;  Wd = 0.905;
figTitle(fig, sprintf('%s with sensor noise of different size at different times', ...
    sigName(sig)), cfg, [0, (H - 1.15) / H, 1, 0.9 / H]);

% noise levels (block height proportional to sigma)
yS = H - topT - stripH;
ax = axes(fig, 'Position', [L, yS / H, Wd, stripH / H]);
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
ax.YAxis.Visible = 'off';  ax.XTick = [];
grid(ax, 'off');
text(ax, -0.012, 0.3, 'noise \sigma', 'Units', 'normalized', 'HorizontalAlignment', 'right', ...
    'FontSize', cfg.fig.labelSize);

% one row per controller, PWM-period averages, same y-limits
yl = rowLimits(G, sig);
edges = unique([W(:, 1); W(:, 2); cfg.tStep]);
edges = edges(edges > 0 & edges < cfg.Tstop);
yTop = yS - gapS;
for i = 1:nC
    yb = yTop - i * rowH - (i - 1) * rowG;
    ax = axes(fig, 'Position', [L, yb / H, Wd, rowH / H]);
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
ax = axes(fig, 'Position', [L, bot / H, 0.42, panH / H]);
pans(2).draw(ax, false);  addLegend(ax, 'southeast');
ax = axes(fig, 'Position', [L + Wd - 0.42, bot / H, 0.42, panH / H]);
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
h = gobjects(1, numel(cfg.ctrl.names));
for i = cfg.ctrl.drawOrder
    [t, y] = getTrace(G, i, cond, sig, 'avg');
    [t, y] = minMaxDecimate(t, y, cfg.fig.maxPoints);
    h(i) = plot(ax, t, y, '-', 'Color', cfg.ctrl.colors(i, :), 'LineWidth', cfg.ctrl.widths(i), ...
        'DisplayName', cfg.ctrl.labels{i});
    hi = max(hi, max(y));
end
ax.UserData = h;                            % legend in controller order
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
h = gobjects(1, numel(cfg.ctrl.names));
for i = cfg.ctrl.drawOrder
    [t, y] = getTrace(G, i, cond, sig, mode);
    in = t >= win(1) & t <= win(2);
    [x, yy] = minMaxDecimate(t(in), y(in), cfg.fig.maxPoints);
    h(i) = plot(ax, x, yy, '-', 'Color', cfg.ctrl.colors(i, :), 'LineWidth', cfg.ctrl.widths(i), ...
        'DisplayName', cfg.ctrl.labels{i});
    lo = min(lo, min(yy));  hi = max(hi, max(yy));
end
ax.UserData = h;                            % legend in controller order
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
% Best cost so far vs cost evaluations, every run (thin) and the median (thick),
% as % above the optimum when the reference optimum is known.
algos = T.algos;
[yfun, ylab] = relScale(T);
hold(ax, 'on');
nPop = cfg.opt.nPop;
for a = 1:numel(algos)
    col = algoColor(cfg, algos{a});
    C = T.stats.(algos{a}).curves;
    ev = (1:size(C, 2)) * nPop;
    for r = 1:size(C, 1)
        plot(ax, ev, yfun(C(r, :)), '-', 'Color', 0.35 * col + 0.65, 'LineWidth', 0.6, ...
            'HandleVisibility', 'off');
    end
end
h = gobjects(1, numel(algos));
for a = 1:numel(algos)
    col = algoColor(cfg, algos{a});
    C = T.stats.(algos{a}).curves;
    ev = (1:size(C, 2)) * nPop;
    h(a) = plot(ax, ev, median(yfun(C), 1), '-', 'Color', col, 'LineWidth', 2.2, ...
        'DisplayName', sprintf('%s: median of %d runs', algos{a}, size(C, 1)));
end
ax.UserData = h;
set(ax, 'YScale', 'log');
xlim(ax, [nPop, cfg.opt.maxIter * nPop]);
xlabel(ax, sprintf('cost evaluations (%d agents x iterations)', nPop), 'FontSize', cfg.fig.labelSize);
ylabel(ax, ['best cost so far' ylab], 'FontSize', cfg.fig.labelSize);
title(ax, sprintf('Convergence of %s (thin lines: each of the %d runs)', strjoin(algos, ', '), ...
    cfg.opt.nRuns), 'FontSize', cfg.fig.labelSize);
if showLegend, addLegend(ax, 'northeast'); end
end

function drawRuns(ax, cfg, T)
% Final cost of every run of every optimiser (filled marker = best run,
% the one simulated in the study); median and worst written next to it.
algos = T.algos;
[yfun, ylab] = relScale(T);
hold(ax, 'on');
nA = numel(algos);
lo = inf;  hi = -inf;
for a = 1:nA
    col = algoColor(cfg, algos{a});
    mk = cfg.ctrl.markers{strcmp(cfg.ctrl.names, algos{a})};
    sel = T.runs(strcmp({T.runs.algo}, algos{a}));
    v = yfun([sel.J]);
    jit = linspace(-0.13, 0.13, numel(v));
    plot(ax, a + jit, v, mk, 'MarkerSize', 7, 'MarkerEdgeColor', col, 'MarkerFaceColor', 'w', ...
        'LineWidth', 1.2, 'HandleVisibility', 'off');
    [~, ib] = min([sel.J]);
    plot(ax, a + jit(ib), v(ib), mk, 'MarkerSize', 10, 'MarkerEdgeColor', 'w', ...
        'MarkerFaceColor', col, 'LineWidth', 1.0, 'HandleVisibility', 'off');
    plot(ax, a + [-0.2 0.2], median(v) * [1 1], '-', 'Color', cfg.fig.textColor, 'LineWidth', 1.2, ...
        'HandleVisibility', 'off');
    st = T.stats.(algos{a});
    if isfield(st, 'within1')
        txt = sprintf('median %s\nworst %s\nwithin 1 %%: %d / %d', fmtPct(median(v)), fmtPct(max(v)), ...
            st.within1, st.nRuns);
    else
        txt = sprintf('median %.4g\nworst %.4g', median(v), max(v));
    end
    text(ax, a + 0.24, median(v), txt, 'VerticalAlignment', 'middle', ...
        'FontSize', cfg.fig.fontSize - 0.5);
    lo = min(lo, min(v));  hi = max(hi, max(v));
end
set(ax, 'YScale', 'log', 'XTick', 1:nA, 'XTickLabel', strcat(algos, sprintf(' (%d runs)', cfg.opt.nRuns)), ...
    'XLim', [0.5, nA + 0.85]);
ylim(ax, [lo / 2, hi * 2]);
ax.XGrid = 'off';
ylabel(ax, ['final cost' ylab], 'FontSize', cfg.fig.labelSize);
title(ax, 'Where every run ended (filled: best run, used in the simulations; bar: median)', ...
    'FontSize', cfg.fig.labelSize);
end

function fig = landscapeFigure(cfg, T)
% Cost around the optimum (contours, % above the optimum) with the end point
% of every run; (a) whole box in the Kp-Ki plane, (b)-(d) zooms.
R = T.ref;
Js = R.Jstar;
sc = [1e3, 1, 1e6];
lab = {'K_p (\times10^{-3})', 'K_i', 'K_d (\times10^{-6})'};
fig = newFigure([24 19]);
tl = tiledlayout(fig, 2, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
panels = {'box', '(a) whole search box, K_d at the optimum'
          'Kp_Ki', '(b) zoom: K_p - K_i'
          'Kp_Kd', '(c) zoom: K_p - K_d'
          'Ki_Kd', '(d) zoom: K_i - K_d'};
hLeg = gobjects(0);
for p = 1:4
    ax = nexttile(tl);
    hold(ax, 'on');
    mp = R.maps.(panels{p, 1});
    d = mp.dims;
    a = mp.a * sc(d(1));  b = mp.b * sc(d(2));
    if p == 1
        bad = double(mp.J >= 0.5 * R.penalty);
        imagesc(ax, a, b, bad.');
        colormap(ax, [1 1 1; cfg.fig.shade]);
        set(ax, 'CLim', [0 1]);
        set(ax, 'YDir', 'normal');
        lv = [10 100 400];
        text(ax, 0.98, 0.97, sprintf('shaded: unstable / latch-up /\nnot settled (penalised)'), ...
            'Units', 'normalized', 'HorizontalAlignment', 'right', 'VerticalAlignment', 'top', ...
            'FontSize', cfg.fig.fontSize - 1);
    else
        lv = [1 2 5 10 50];
    end
    rel = 100 * (mp.J / Js - 1);
    rel(mp.J >= 0.5 * R.penalty) = NaN;
    [Cc, hc] = contour(ax, a, b, rel.', lv, 'LineColor', [0.55 0.55 0.53], 'LineWidth', 0.6);
    try
        hc.LabelFormat = '+%g%%';
    catch
    end
    if ~isempty(Cc)
        clabel(Cc, hc, 'FontSize', cfg.fig.fontSize - 2, 'Color', cfg.fig.textColor, 'LabelSpacing', 520);
    end
    for q = 1:numel(T.algos)
        al = T.algos{q};
        col = algoColor(cfg, al);
        mk = cfg.ctrl.markers{strcmp(cfg.ctrl.names, al)};
        sel = T.runs(strcmp({T.runs.algo}, al));
        K = vertcat(sel.K);
        h1 = plot(ax, K(:, d(1)) * sc(d(1)), K(:, d(2)) * sc(d(2)), mk, 'MarkerSize', 6, ...
            'MarkerEdgeColor', col, 'MarkerFaceColor', 'w', 'LineWidth', 1.1, ...
            'DisplayName', sprintf('%s: end point of each run', al));
        [~, ib] = min([sel.J]);
        h2 = plot(ax, K(ib, d(1)) * sc(d(1)), K(ib, d(2)) * sc(d(2)), mk, 'MarkerSize', 10, ...
            'MarkerEdgeColor', 'w', 'MarkerFaceColor', col, 'LineWidth', 1.0, ...
            'DisplayName', sprintf('%s: best run (simulated)', al));
        if p == 1, hLeg = [hLeg, h1, h2]; end %#ok<AGROW>
    end
    h3 = plot(ax, R.Kstar(d(1)) * sc(d(1)), R.Kstar(d(2)) * sc(d(2)), 'x', 'Color', [0 0 0], ...
        'MarkerSize', 12, 'LineWidth', 2.2, 'DisplayName', 'optimum (exhaustive search)');
    if p == 1
        hLeg = [hLeg, h3]; %#ok<AGROW>
        h4 = plot(ax, T.K(1, 1) * sc(1), T.K(1, 2) * sc(2), cfg.ctrl.markers{1}, 'MarkerSize', 9, ...
            'MarkerEdgeColor', 'w', 'MarkerFaceColor', cfg.ctrl.colors(1, :), ...
            'DisplayName', 'ZN-PID (not optimised)');
        hLeg = [hLeg, h4]; %#ok<AGROW>
    end
    xlim(ax, [min(a) max(a)]);  ylim(ax, [min(b) max(b)]);
    xlabel(ax, lab{d(1)}, 'FontSize', cfg.fig.labelSize);
    ylabel(ax, lab{d(2)}, 'FontSize', cfg.fig.labelSize);
    title(ax, panels{p, 2}, 'FontSize', cfg.fig.labelSize);
    set(ax, 'Layer', 'top');
end
lg = legend(hLeg, 'Orientation', 'horizontal', 'NumColumns', 4, 'Box', 'off');
lg.Layout.Tile = 'south';
title(tl, 'Cost of the PID gains around the optimum, with the end point of every PSO, GA and GWO run', ...
    'FontWeight', 'bold', 'FontSize', cfg.fig.labelSize + 1, 'Color', cfg.fig.textColor);
subtitle(tl, ['contours: cost above the optimum (other gain held at the optimum; ' ...
    'run end points projected onto the plane)'], 'FontSize', cfg.fig.fontSize, 'Color', cfg.fig.textColor);
end

function [f, lab] = relScale(T)
% Cost as % above the reference optimum (log axis; values below 1e-3 % are
% shown at 1e-3 %), or the raw cost when there is no reference.
if isfield(T, 'ref') && isfield(T.ref, 'Jstar') && T.ref.Jstar > 0
    Js = T.ref.Jstar;
    f = @(J) max(100 * (J / Js - 1), 1e-3);
    lab = ', % above the optimum';
else
    f = @(J) J;
    lab = ' J';
end
end

function s = fmtPct(v)
if v < 0.01, s = sprintf('+%.3f %%', v); else, s = sprintf('+%.2f %%', v); end
end

function c = algoColor(cfg, name)
c = cfg.ctrl.colors(strcmp(cfg.ctrl.names, name), :);
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
h = gobjects(1, numel(cfg.ctrl.labels));
for i = cfg.ctrl.drawOrder                  % widest first, so overlapping lines stay visible
    r = M.noise(M.noise.Controller == cfg.ctrl.labels{i}, :);
    h(i) = plot(ax, r.NoiseSigma_pct, r.(field), '-', 'Color', cfg.ctrl.colors(i, :), ...
        'LineWidth', 0.6 + cfg.ctrl.widths(i) / 2, 'Marker', cfg.ctrl.markers{i}, ...
        'MarkerSize', 4 + 2 * cfg.ctrl.widths(i), ...
        'MarkerFaceColor', cfg.ctrl.colors(i, :), 'DisplayName', cfg.ctrl.labels{i});
end
ax.UserData = h;
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
h = ax.UserData;
if isa(h, 'matlab.graphics.Graphics') && all(isgraphics(h))
    lg = legend(ax, h, 'Location', loc, 'Box', 'on');
else
    lg = legend(ax, 'Location', loc, 'Box', 'on');
end
lg.EdgeColor = [0.15 0.15 0.15];
lg.Color = 'w';
end

function figTitle(fig, txt, cfg, pos)
if nargin < 4, pos = [0 0.945 1 0.05]; end
annotation(fig, 'textbox', pos, 'String', txt, 'EdgeColor', 'none', ...
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
            savefig(fig, [base '.fig']);
    end
end
close(fig);
end
