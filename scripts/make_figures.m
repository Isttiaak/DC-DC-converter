function make_figures(cfg, T, S, M)
%MAKE_FIGURES  Print-quality figures of the PID comparison.
%
%   results/figures/combined/   comparison figures with several panels
%   results/figures/individual/ every panel again as its own figure
%   Formats: PNG (cfg.fig.dpi), vector PDF and MATLAB .fig (editable).
%
%   Traces are averaged over each PWM period (the converter's average
%   behaviour), except the "ripple" close-ups, which show the raw
%   switching waveform.

dirs = {cfg.figCombDir, cfg.figIndDir};
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir'), mkdir(dirs{k}); end
end
cfg.fig.font = pickFont(cfg.fig.fonts);
fprintf('Figure font: %s\n', cfg.fig.font);
applyStyle(cfg);
warning('off', 'MATLAB:print:ContentTypeImageSuggested');
P = T.plant;
W = cfg.noise.windows;
nW = size(W, 1);
Z = cfg.zoom;
condTxt = {'without noise', 'with sensor noise'};
condTag = {'without_noise', 'with_noise'};
shortCond = {'no noise', 'with noise'};
stepTxt = sprintf('V_{in} %g\\rightarrow%g V', P.Vin0, P.Vin1);

% ---- panel specifications ---------------------------------------------------------
% sig: vout | iL | duty;  cond: 1 without / 2 with noise;  win: time window [s]
% mode: 'avg' (one point per PWM period) | 'raw' (switching waveform)
specs = struct('id', {}, 'sig', {}, 'cond', {}, 'win', {}, 'mode', {}, ...
    'title', {}, 'short', {}, 'ylabel', {}, 'shade', {}, 'legendLoc', {});
for c = 1:2
    tg = condTag{c};  tx = condTxt{c};  sc = shortCond{c};
    specs(end+1) = mk(['vout_full_' tg], 'vout', c, [0 cfg.Tstop], 'avg', ...
        ['Output voltage, ' tx], 'Output voltage V_{out}', 'V_{out} (V)', c == 2, 'southeast'); %#ok<AGROW>
    specs(end+1) = mk(['vout_startup_' tg], 'vout', c, Z.startup, 'avg', ...
        ['Output voltage at start-up, ' tx], ['V_{out} at start-up (' sc ')'], 'V_{out} (V)', c == 2, 'southeast'); %#ok<AGROW>
    specs(end+1) = mk(['vout_linestep_' tg], 'vout', c, Z.line, 'avg', ...
        ['Output voltage after the ' stepTxt ' step, ' tx], ['V_{out}, ' stepTxt ' (' sc ')'], 'V_{out} (V)', c == 2, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(['vout_ripple_' tg], 'vout', c, Z.ripple, 'raw', ...
        ['Output-voltage ripple in steady state, ' tx], ['V_{out} ripple (' sc ')'], 'V_{out} (V)', false, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(['vout_window4_' tg], 'vout', c, Z.noiseWin(nW, :), 'avg', ...
        sprintf('Output voltage, %.4g-%.4g s, %s', Z.noiseWin(nW, :), tx), ...
        sprintf('V_{out}, %.4g-%.4g s (%s)', Z.noiseWin(nW, :), sc), 'V_{out} (V)', false, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(['iL_full_' tg], 'iL', c, [0 cfg.Tstop], 'avg', ...
        ['Inductor current, ' tx], 'Inductor current i_L', 'i_L (A)', c == 2, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(['iL_startup_' tg], 'iL', c, Z.startup, 'avg', ...
        ['Inductor current at start-up, ' tx], ['i_L at start-up (' sc ')'], 'i_L (A)', c == 2, 'southeast'); %#ok<AGROW>
    specs(end+1) = mk(['iL_linestep_' tg], 'iL', c, Z.line, 'avg', ...
        ['Inductor current after the ' stepTxt ' step, ' tx], ['i_L, ' stepTxt ' (' sc ')'], 'i_L (A)', c == 2, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(['iL_ripple_' tg], 'iL', c, Z.ripple, 'raw', ...
        ['Inductor-current ripple in steady state, ' tx], ['i_L ripple (' sc ')'], 'i_L (A)', false, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(['iL_window4_' tg], 'iL', c, Z.noiseWin(nW, :), 'avg', ...
        sprintf('Inductor current, %.4g-%.4g s, %s', Z.noiseWin(nW, :), tx), ...
        sprintf('i_L, %.4g-%.4g s (%s)', Z.noiseWin(nW, :), sc), 'i_L (A)', false, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(['duty_full_' tg], 'duty', c, [0 cfg.Tstop], 'avg', ...
        ['Duty cycle, ' tx], ['Duty cycle (' sc ')'], 'Duty cycle d', c == 2, 'northeast'); %#ok<AGROW>
end
for k = 1:nW
    specs(end+1) = mk(sprintf('vout_noise_window%d', k), 'vout', 2, Z.noiseWin(k, :), 'avg', ...
        sprintf('Output voltage in noise window %d (\\sigma = %g %% of V_{ref})', k, W(k, 3)), ...
        sprintf('V_{out}, window %d (\\sigma = %g %%)', k, W(k, 3)), 'V_{out} (V)', false, 'northeast'); %#ok<AGROW>
    specs(end+1) = mk(sprintf('iL_noise_window%d', k), 'iL', 2, Z.noiseWin(k, :), 'avg', ...
        sprintf('Inductor current in noise window %d (\\sigma = %g %% of V_{ref})', k, W(k, 3)), ...
        sprintf('i_L, window %d (\\sigma = %g %%)', k, W(k, 3)), 'i_L (A)', false, 'northeast'); %#ok<AGROW>
end
byId = containers.Map({specs.id}, num2cell(1:numel(specs)));
draw = @(ax, id) drawSignal(ax, specs(byId(id)), false, cfg, S, T, true);

% =====================================================================================
% Individual figures: one panel each, for printing
% =====================================================================================
for k = 1:numel(specs)
    fig = newFigure(cfg.fig.single);
    drawSignal(axes(fig), specs(k), true, cfg, S, T, false);
    exportFigure(fig, cfg.figIndDir, specs(k).id, cfg);
end
fig = newFigure(cfg.fig.single);
drawNoise(axes(fig), cfg, S, T, true);
exportFigure(fig, cfg.figIndDir, 'injected_sensor_noise', cfg);
fig = newFigure(cfg.fig.single);
drawConvergence(axes(fig), cfg, T, true);
exportFigure(fig, cfg.figIndDir, 'convergence_PSO_GWO', cfg);
metricList = {
    'StartupOvershoot_pct',  'Start-up overshoot (%)',             'startup_overshoot'
    'StartupSettling_ms',    'Start-up settling time (ms)',        'startup_settling_time'
    'LineStepPeakDev_pct',   'Peak deviation after step (%)',      'linestep_peak_deviation'
    'LineStepSettling_ms',   'Settling time after step (ms)',      'linestep_settling_time'
    'TotalITAE',             'Total ITAE (V s^2)',                 'total_ITAE'
    'iLPeakLineStep_A',      'Peak i_L after step (A)',            'linestep_peak_iL'};
for k = 1:size(metricList, 1)
    fig = newFigure([9 7]);
    drawBars(axes(fig), M.clean.(metricList{k, 1}), metricList{k, 2}, cfg);
    exportFigure(fig, cfg.figIndDir, ['metric_' metricList{k, 3}], cfg);
end
fig = newFigure([10 7.5]);
drawRobust(axes(fig), M, 'dVout_rms_mV', 'RMS deviation of V_{out} (mV)', cfg, true);
exportFigure(fig, cfg.figIndDir, 'noise_robustness_vout', cfg);
fig = newFigure([10 7.5]);
drawRobust(axes(fig), M, 'diL_rms_A', 'RMS deviation of i_L (A)', cfg, true);
exportFigure(fig, cfg.figIndDir, 'noise_robustness_iL', cfg);

% =====================================================================================
% Combined figures
% =====================================================================================
% Fig. 1 - convergence of PSO and GWO
fig = newFigure([16 9]);
drawConvergence(axes(fig), cfg, T, true);
exportFigure(fig, cfg.figCombDir, 'fig01_convergence_PSO_GWO', cfg);

% Fig. 2 - all controllers without noise
fig = newFigure([18 21]);
tl = newLayout(fig, 3, 2);
tiles(tl, {'vout_full_without_noise', 'iL_full_without_noise', ...
    'vout_startup_without_noise', 'iL_startup_without_noise', ...
    'vout_linestep_without_noise', 'iL_linestep_without_noise'}, draw);
figTitle(tl, 'ZN-PID vs PSO-PID vs GWO-PID without noise', cfg);
exportFigure(fig, cfg.figCombDir, 'fig02_comparison_without_noise', cfg);

% Fig. 3 - robustness to sensor noise injected at different times and levels
fig = newFigure([18 21]);
tl = newLayout(fig, 3, 1);
ax = nexttile(tl); drawNoise(ax, cfg, S, T, false); addTag(ax, '(a)');
ax = nexttile(tl); draw(ax, 'vout_full_with_noise'); addTag(ax, '(b)');
topLegend(ax);
ax = nexttile(tl); draw(ax, 'iL_full_with_noise'); addTag(ax, '(c)');
figTitle(tl, 'Robustness to sensor noise injected at different times and levels', cfg);
exportFigure(fig, cfg.figCombDir, 'fig03_robustness_sensor_noise', cfg);

% Fig. 4 / 5 - Vout and iL in detail, without (top) and with (bottom) noise
names = {'vout', 'iL'};
longNames = {'Output voltage V_{out}', 'Inductor current i_L'};
for q = 1:2
    fig = newFigure([25 13.5]);
    tl = newLayout(fig, 2, 4);
    ids = {};
    for c = 1:2
        for part = {'startup', 'linestep', 'ripple', 'window4'}
            ids{end+1} = sprintf('%s_%s_%s', names{q}, part{1}, condTag{c}); %#ok<AGROW>
        end
    end
    tiles(tl, ids, draw);
    figTitle(tl, sprintf('%s in detail: top row without noise, bottom row with sensor noise', ...
        longNames{q}), cfg);
    exportFigure(fig, cfg.figCombDir, sprintf('fig%02d_%s_detail_with_and_without_noise', 3 + q, names{q}), cfg);
end

% Fig. 6 - inside every noise window
fig = newFigure([25 13]);
tl = newLayout(fig, 2, nW);
ids = {};
for s = names
    for k = 1:nW
        ids{end+1} = sprintf('%s_noise_window%d', s{1}, k); %#ok<AGROW>
    end
end
tiles(tl, ids, draw);
figTitle(tl, 'Response inside each noise window (sensor noise \sigma in % of V_{ref})', cfg);
exportFigure(fig, cfg.figCombDir, 'fig06_noise_windows_vout_iL', cfg);

% Fig. 7 - performance metrics without noise
fig = newFigure([20 13]);
tl = newLayout(fig, 2, 3);
for k = 1:size(metricList, 1)
    ax = nexttile(tl);
    drawBars(ax, M.clean.(metricList{k, 1}), metricList{k, 2}, cfg);
    addTag(ax, sprintf('(%c)', 'a' + k - 1));
end
figTitle(tl, 'Performance without noise (switching model)', cfg);
exportFigure(fig, cfg.figCombDir, 'fig07_performance_metrics', cfg);

% Fig. 8 - noise robustness metrics
fig = newFigure([18 8.5]);
tl = newLayout(fig, 1, 2);
ax = nexttile(tl); drawRobust(ax, M, 'dVout_rms_mV', 'RMS deviation of V_{out} (mV)', cfg, false); addTag(ax, '(a)');
topLegend(ax);
ax = nexttile(tl); drawRobust(ax, M, 'diL_rms_A', 'RMS deviation of i_L (A)', cfg, false); addTag(ax, '(b)');
figTitle(tl, 'Effect of sensor noise: deviation from the noise-free response', cfg);
exportFigure(fig, cfg.figCombDir, 'fig08_noise_robustness_metrics', cfg);

% Fig. 9 - duty cycle
fig = newFigure([18 13]);
tl = newLayout(fig, 2, 1);
tiles(tl, {'duty_full_without_noise', 'duty_full_with_noise'}, draw);
figTitle(tl, 'Duty cycle', cfg);
exportFigure(fig, cfg.figCombDir, 'fig09_duty_cycle', cfg);

% Fig. 10 - the Simulink model
try
    load_system(cfg.modelFile);
    print(['-s' cfg.model], '-dpng', '-r300', fullfile(cfg.figCombDir, 'fig10_simulink_model.png'));
    print(['-s' cfg.model], '-dpdf', fullfile(cfg.figCombDir, 'fig10_simulink_model.pdf'));
    fprintf('Model diagram printed.\n');
catch err
    warning('make_figures:model', 'Model diagram not printed: %s', err.message);
end
fprintf('Figures written to %s\n', fileparts(cfg.figCombDir));
end

% =====================================================================================
function s = mk(id, sig, cond, win, mode, ttl, short, ylab, shade, legendLoc)
s = struct('id', id, 'sig', sig, 'cond', cond, 'win', win, 'mode', mode, ...
    'title', ttl, 'short', short, 'ylabel', ylab, 'shade', shade, 'legendLoc', legendLoc);
end

function tl = newLayout(fig, r, c)
tl = tiledlayout(fig, r, c, 'TileSpacing', 'loose', 'Padding', 'compact');
end

function tiles(tl, ids, draw)
for n = 1:numel(ids)
    ax = nexttile(tl);
    draw(ax, ids{n});
    addTag(ax, sprintf('(%c)', 'a' + n - 1));
    if n == 1
        topLegend(ax);
    end
end
end

function topLegend(ax)
lg = legend(ax, 'Orientation', 'horizontal');
lg.Layout.Tile = 'north';
end

function figTitle(tl, txt, cfg)
title(tl, txt, 'FontSize', cfg.fig.labelSize + 1, 'FontWeight', 'bold', 'FontName', cfg.fig.font);
end

function drawSignal(ax, sp, showLegend, cfg, S, T, useShort)
P = T.plant;
if strcmp(sp.mode, 'raw')
    t = S.t;
else
    t = S.tAvg + 0.5 / P.fsw;            % centre of each PWM period
end
in = t >= sp.win(1) & t <= sp.win(2);
x0 = t(in);
hold(ax, 'on');
lo = inf;  hi = -inf;
for i = 1:numel(cfg.ctrl.names)
    if strcmp(sp.mode, 'raw')
        y = double(S.sig(i, sp.cond).(sp.sig)(in));
    else
        y = double(S.avg(i, sp.cond).(sp.sig)(in));
    end
    [x, y] = minMaxDecimate(x0, y, cfg.fig.maxPoints);
    plot(ax, x, y, 'LineStyle', cfg.ctrl.styles{i}, 'Color', cfg.ctrl.colors(i, :), ...
        'LineWidth', cfg.ctrl.widths(i), 'DisplayName', cfg.ctrl.labels{i});
    lo = min(lo, min(y));  hi = max(hi, max(y));
end
if strcmp(sp.sig, 'vout')
    yline(ax, P.Vref, ':', 'Color', cfg.fig.refColor, 'LineWidth', 1.0, 'HandleVisibility', 'off');
    lo = min(lo, P.Vref);  hi = max(hi, P.Vref);
end
padLimits(ax, sp.win, lo, hi);
if sp.shade
    shadeNoise(ax, cfg.noise.windows, sp.win, cfg);
end
xlabel(ax, 'Time (s)', 'FontSize', cfg.fig.labelSize);
ylabel(ax, sp.ylabel, 'FontSize', cfg.fig.labelSize);
if useShort, ttl = sp.short; else, ttl = sp.title; end
title(ax, ttl, 'FontWeight', 'normal', 'FontSize', cfg.fig.labelSize);
if showLegend
    legend(ax, 'Location', sp.legendLoc);
end
end

function padLimits(ax, xw, lo, hi)
r = hi - lo;
if ~(r > 0), r = max(abs(hi), 1) * 0.1; end
ylo = lo - 0.08 * r;
if lo >= 0 && ylo < 0, ylo = 0; end          % no negative axis for positive signals
xlim(ax, xw);
ylim(ax, [ylo, hi + 0.12 * r]);
end

function drawNoise(ax, cfg, S, T, full)
% Injected sensor noise (vmeas - vout of the noisy runs; identical for all controllers).
P = T.plant;
n = double(S.sig(end, 2).vmeas) - double(S.sig(end, 2).vout);
[x, y] = minMaxDecimate(S.t, n, cfg.fig.maxPoints);
hold(ax, 'on');
plot(ax, x, y, '-', 'Color', [0.50 0.50 0.48], 'LineWidth', 0.4, 'DisplayName', 'injected noise');
prof = S.noiseProfile;
ts = [prof(:, 1); cfg.Tstop];
sg = [prof(:, 2); prof(end, 2)];
stairs(ax, ts, 3 * sg, '-', 'Color', [0.05 0.05 0.05], 'LineWidth', 1.1, 'DisplayName', '\pm3\sigma');
stairs(ax, ts, -3 * sg, '-', 'Color', [0.05 0.05 0.05], 'LineWidth', 1.1, 'HandleVisibility', 'off');
lim = max(4 * max(sg), 0.5);
xlim(ax, [0 cfg.Tstop]);
ylim(ax, [-lim, 1.25 * lim]);
shadeNoise(ax, cfg.noise.windows, [0 cfg.Tstop], cfg);
xlabel(ax, 'Time (s)', 'FontSize', cfg.fig.labelSize);
ylabel(ax, 'Sensor noise (V)', 'FontSize', cfg.fig.labelSize);
if full
    ttl = sprintf(['Sensor noise added to the measured V_{out} (Gaussian, new sample every ' ...
        '%g ms, same for all controllers)'], 1e3 * cfg.noise.Ts);
else
    ttl = 'Injected sensor noise on the V_{out} feedback';
end
title(ax, ttl, 'FontWeight', 'normal', 'FontSize', cfg.fig.labelSize);
legend(ax, 'Location', 'southwest', 'Orientation', 'horizontal');
end

function drawConvergence(ax, cfg, T, showLegend)
algos = {'PSO', 'GWO'};
cols = cfg.ctrl.colors(2:3, :);
sty = cfg.ctrl.styles(2:3);
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
    plot(ax, 1:size(C, 2), C(ib, :), sty{a}, 'Color', cols(a, :), 'LineWidth', 2.0, ...
        'DisplayName', sprintf('%s, best of %d runs (J = %.5g)', algos{a}, size(C, 1), C(ib, end)));
end
set(ax, 'YScale', 'log');
xlim(ax, [1 cfg.opt.maxIter]);
xlabel(ax, 'Iteration', 'FontSize', cfg.fig.labelSize);
ylabel(ax, 'Best cost J', 'FontSize', cfg.fig.labelSize);
title(ax, sprintf('PSO vs GWO convergence (%d agents; thin lines: all %d runs)', ...
    cfg.opt.nPop, cfg.opt.nRuns), 'FontWeight', 'normal', 'FontSize', cfg.fig.labelSize);
if showLegend
    legend(ax, 'Location', 'northeast');
end
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
    plot(ax, r.NoiseSigma_pct, r.(field), cfg.ctrl.styles{i}, 'Color', cfg.ctrl.colors(i, :), ...
        'LineWidth', cfg.ctrl.widths(i), 'Marker', 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', cfg.ctrl.colors(i, :), 'DisplayName', cfg.ctrl.labels{i});
end
xlabel(ax, 'Sensor noise \sigma (% of V_{ref})', 'FontSize', cfg.fig.labelSize);
ylabel(ax, ylab, 'FontSize', cfg.fig.labelSize);
ylim(ax, [0, 1.15 * max(M.noise.(field))]);
if showLegend
    legend(ax, 'Location', 'northwest');
end
end

function shadeNoise(ax, W, win, cfg)
yl = ylim(ax);
for k = 1:size(W, 1)
    a = max(W(k, 1), win(1));
    b = min(W(k, 2), win(2));
    if b <= a, continue; end
    p = patch(ax, [a b b a], [yl(1) yl(1) yl(2) yl(2)], cfg.fig.shade, ...
        'EdgeColor', 'none', 'HandleVisibility', 'off');
    uistack(p, 'bottom');
    text(ax, (a + b) / 2, yl(2), sprintf('\\sigma = %g%%', W(k, 3)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'FontSize', cfg.fig.fontSize - 0.5, 'Color', [0.30 0.30 0.30]);
end
ylim(ax, yl);
set(ax, 'Layer', 'top');
end

function addTag(ax, tag)
text(ax, 0.012, 0.975, tag, 'Units', 'normalized', 'FontWeight', 'bold', ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
end

function [xd, yd] = minMaxDecimate(x, y, nb)
% Minimum and maximum of each of nb buckets, in time order: keeps peaks
% and the switching-ripple envelope while limiting the number of points.
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
    'Position', [2 2 sizeCm(1) sizeCm(2)]);
end

function applyStyle(cfg)
set(groot, 'defaultAxesFontName', cfg.fig.font, 'defaultTextFontName', cfg.fig.font, ...
    'defaultLegendFontName', cfg.fig.font, ...
    'defaultAxesFontSize', cfg.fig.fontSize, 'defaultTextFontSize', cfg.fig.fontSize, ...
    'defaultLegendFontSize', cfg.fig.fontSize, 'defaultLegendBox', 'off', ...
    'defaultAxesLineWidth', 0.6, 'defaultAxesTickDir', 'out', 'defaultAxesBox', 'off', ...
    'defaultAxesXGrid', 'on', 'defaultAxesYGrid', 'on', ...
    'defaultAxesGridColor', [0.80 0.80 0.78], 'defaultAxesGridAlpha', 0.6, ...
    'defaultAxesXColor', [0.20 0.20 0.20], 'defaultAxesYColor', [0.20 0.20 0.20], ...
    'defaultAxesTitleFontSizeMultiplier', 1, 'defaultAxesLabelFontSizeMultiplier', 1, ...
    'defaultFigureColor', 'w');
end

function exportFigure(fig, folder, name, cfg)
base = fullfile(folder, name);
for k = 1:numel(cfg.fig.formats)
    switch cfg.fig.formats{k}
        case 'png'
            exportgraphics(fig, [base '.png'], 'Resolution', cfg.fig.dpi);
        case 'pdf'
            exportgraphics(fig, [base '.pdf'], 'ContentType', 'vector');
        case 'fig'
            savefig(fig, [base '.fig'], 'compact');
    end
end
close(fig);
end
