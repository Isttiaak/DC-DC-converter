function make_figures(cfg, T, S, M)
%MAKE_FIGURES  Print-quality figures of the PID comparison.
%
%   results/figures/combined/   comparison figures with several panels
%   results/figures/individual/ every panel again as its own figure
%   Formats: PNG (cfg.fig.dpi), vector PDF and MATLAB .fig (editable).

dirs = {cfg.figCombDir, cfg.figIndDir};
for k = 1:numel(dirs)
    if ~exist(dirs{k}, 'dir'), mkdir(dirs{k}); end
end
applyStyle(cfg);
P = T.plant;
W = cfg.noise.windows;
nW = size(W, 1);
Z = cfg.zoom;
noiseZoom = Z.noiseWin;                  % one zoom window inside each noise window
lineZoomNoise = Z.line;
condTxt = {'without noise', 'with sensor noise'};
condTag = {'without_noise', 'with_noise'};

% ---- panel specifications ------------------------------------------------------
% sig: signal name; cond: 1 = without, 2 = with noise; win: time window;
% mode: 'env' (min/max envelope) or 'raw'
specs = struct('id', {}, 'sig', {}, 'cond', {}, 'win', {}, 'mode', {}, ...
    'title', {}, 'ylabel', {}, 'shade', {}, 'legendLoc', {}, 'short', {});
shortCond = {'no noise', 'with noise'};
for c = 1:2
    tg = condTag{c};
    tx = condTxt{c};
    specs(end+1) = mk(['vout_full_' tg], 'vout', c, [0 cfg.Tstop], 'env', ...
        ['Output voltage, ' tx], 'V_{out} (V)', c == 2, 'southeast', ...
        'Output voltage V_{out}'); %#ok<AGROW>
    specs(end+1) = mk(['vout_startup_' tg], 'vout', c, Z.startup, 'raw', ...
        ['Output voltage at start-up, ' tx], 'V_{out} (V)', c == 2, 'southeast', ...
        ['V_{out} at start-up (' shortCond{c} ')']); %#ok<AGROW>
    specs(end+1) = mk(['vout_linestep_' tg], 'vout', c, lineZoomNoise, 'raw', ...
        sprintf('Output voltage after the V_{in} step %g \\rightarrow %g V, %s', P.Vin0, P.Vin1, tx), ...
        'V_{out} (V)', c == 2, 'northeast', ...
        sprintf('V_{out}, V_{in} %g\\rightarrow%g V (%s)', P.Vin0, P.Vin1, shortCond{c})); %#ok<AGROW>
    specs(end+1) = mk(['vout_ripple_' tg], 'vout', c, Z.ripple, 'raw', ...
        ['Output voltage ripple (steady state), ' tx], 'V_{out} (V)', false, 'northeast', ...
        ['V_{out} ripple (' shortCond{c} ')']); %#ok<AGROW>
    specs(end+1) = mk(['iL_full_' tg], 'iL', c, [0 cfg.Tstop], 'env', ...
        ['Inductor current, ' tx], 'i_L (A)', c == 2, 'northeast', ...
        'Inductor current i_L'); %#ok<AGROW>
    specs(end+1) = mk(['iL_startup_' tg], 'iL', c, Z.startup, 'raw', ...
        ['Inductor current at start-up, ' tx], 'i_L (A)', c == 2, 'northeast', ...
        ['i_L at start-up (' shortCond{c} ')']); %#ok<AGROW>
    specs(end+1) = mk(['iL_linestep_' tg], 'iL', c, lineZoomNoise, 'raw', ...
        sprintf('Inductor current after the V_{in} step %g \\rightarrow %g V, %s', P.Vin0, P.Vin1, tx), ...
        'i_L (A)', c == 2, 'northeast', ...
        sprintf('i_L, V_{in} %g\\rightarrow%g V (%s)', P.Vin0, P.Vin1, shortCond{c})); %#ok<AGROW>
    specs(end+1) = mk(['iL_ripple_' tg], 'iL', c, Z.ripple, 'raw', ...
        ['Inductor current ripple (steady state), ' tx], 'i_L (A)', false, 'northeast', ...
        ['i_L ripple (' shortCond{c} ')']); %#ok<AGROW>
    specs(end+1) = mk(['duty_full_' tg], 'duty', c, [0 cfg.Tstop], 'env', ...
        ['Duty cycle, ' tx], 'Duty cycle d', c == 2, 'northeast', ...
        ['Duty cycle (' shortCond{c} ')']); %#ok<AGROW>
end
for k = 1:nW
    specs(end+1) = mk(sprintf('vout_noise_window%d', k), 'vout', 2, noiseZoom(k, :), 'raw', ...
        sprintf('V_{out} in noise window %d (\\sigma = %g %% of V_{ref})', k, W(k, 3)), ...
        'V_{out} (V)', false, 'northeast', ...
        sprintf('V_{out}, window %d (\\sigma = %g %%)', k, W(k, 3))); %#ok<AGROW>
    specs(end+1) = mk(sprintf('iL_noise_window%d', k), 'iL', 2, noiseZoom(k, :), 'raw', ...
        sprintf('i_L in noise window %d (\\sigma = %g %% of V_{ref})', k, W(k, 3)), ...
        'i_L (A)', false, 'northeast', ...
        sprintf('i_L, window %d (\\sigma = %g %%)', k, W(k, 3))); %#ok<AGROW>
end
byId = containers.Map({specs.id}, num2cell(1:numel(specs)));
draw = @(ax, id, showLegend) drawSignal(ax, specs(byId(id)), showLegend, cfg, S, T, true);

% =================================================================================
% Individual figures (one panel each, for printing)
% =================================================================================
for k = 1:numel(specs)
    fig = newFigure(cfg.fig.single);
    ax = axes(fig);
    drawSignal(ax, specs(k), true, cfg, S, T, false);
    exportFigure(fig, cfg.figIndDir, specs(k).id, cfg);
end
% injected noise, convergence, metrics, robustness
fig = newFigure(cfg.fig.single); drawNoise(axes(fig), cfg, S, T);
exportFigure(fig, cfg.figIndDir, 'injected_sensor_noise', cfg);
fig = newFigure(cfg.fig.single); drawConvergence(axes(fig), cfg, T);
exportFigure(fig, cfg.figIndDir, 'convergence_PSO_GWO', cfg);
metricList = {
    'StartupOvershoot_pct',  'Start-up overshoot (%)',               'startup_overshoot'
    'StartupSettling_ms',    'Start-up settling time, 2 % (ms)',     'startup_settling_time'
    'LineStepPeakDev_pct',   'Peak deviation after V_{in} step (%)', 'linestep_peak_deviation'
    'LineStepSettling_ms',   'Settling time after V_{in} step (ms)', 'linestep_settling_time'
    'TotalITAE',             'ITAE, start-up + V_{in} step (V s^2)', 'total_ITAE'
    'iLPeakLineStep_A',      'Peak i_L after V_{in} step (A)',       'linestep_peak_iL'};
for k = 1:size(metricList, 1)
    fig = newFigure([9 7]);
    drawBars(axes(fig), M.clean.(metricList{k, 1}), metricList{k, 2}, cfg);
    exportFigure(fig, cfg.figIndDir, ['metric_' metricList{k, 3}], cfg);
end
fig = newFigure([9 7]); drawRobust(axes(fig), M, 'dVout_rms_mV', 'RMS deviation of V_{out} (mV)', cfg);
exportFigure(fig, cfg.figIndDir, 'noise_robustness_vout', cfg);
fig = newFigure([9 7]); drawRobust(axes(fig), M, 'diL_rms_A', 'RMS deviation of i_L (A)', cfg);
exportFigure(fig, cfg.figIndDir, 'noise_robustness_iL', cfg);

% =================================================================================
% Combined figures
% =================================================================================
% Fig. 1 - convergence
fig = newFigure([16 9]);
drawConvergence(axes(fig), cfg, T);
exportFigure(fig, cfg.figCombDir, 'fig01_convergence_PSO_GWO', cfg);

% Fig. 2 - all controllers without noise
fig = newFigure([18 20]);
tl = tiledlayout(fig, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ids = {'vout_full_without_noise', 'iL_full_without_noise', ...
       'vout_startup_without_noise', 'iL_startup_without_noise', ...
       'vout_linestep_without_noise', 'iL_linestep_without_noise'};
tiles(tl, ids, draw, '(%s)');
title(tl, 'ZN-PID vs PSO-PID vs GWO-PID, without noise', 'FontSize', cfg.fig.labelSize + 1);
exportFigure(fig, cfg.figCombDir, 'fig02_comparison_without_noise', cfg);

% Fig. 3 - robustness to sensor noise at different times and levels
fig = newFigure([18 20]);
tl = tiledlayout(fig, 3, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); drawNoise(ax, cfg, S, T); addTag(ax, '(a)');
ax = nexttile(tl); draw(ax, 'vout_full_with_noise', false); addTag(ax, '(b)');
lg = legend(ax, 'Orientation', 'horizontal'); lg.Layout.Tile = 'north';
ax = nexttile(tl); draw(ax, 'iL_full_with_noise', false); addTag(ax, '(c)');
title(tl, 'Robustness to sensor noise injected at different times and levels', ...
    'FontSize', cfg.fig.labelSize + 1);
exportFigure(fig, cfg.figCombDir, 'fig03_robustness_sensor_noise', cfg);

% Fig. 4 / 5 - Vout and iL detail, without and with noise
detailCols = {'startup', 'linestep', 'ripple'};
for q = 1:2
    sigName = {'vout', 'iL'};
    sigTitle = {'Output voltage V_{out}', 'Inductor current i_L'};
    fig = newFigure([24 13]);
    tl = tiledlayout(fig, 2, 4, 'TileSpacing', 'compact', 'Padding', 'compact');
    ids = {};
    for c = 1:2
        for d = 1:numel(detailCols)
            ids{end+1} = sprintf('%s_%s_%s', sigName{q}, detailCols{d}, condTag{c}); %#ok<AGROW>
        end
        if c == 1
            ids{end+1} = sprintf('%s_window4_clean', sigName{q}); %#ok<AGROW>
        else
            ids{end+1} = sprintf('%s_noise_window%d', sigName{q}, nW); %#ok<AGROW>
        end
    end
    for n = 1:numel(ids)
        ax = nexttile(tl);
        if endsWith(ids{n}, '_window4_clean')
            sp = specs(byId(sprintf('%s_noise_window%d', sigName{q}, nW)));
            sp.cond = 1;
            sp.short = sprintf('Window %d (%s)', nW, shortCond{1});
            drawSignal(ax, sp, false, cfg, S, T, true);
        else
            draw(ax, ids{n}, false);
        end
        addTag(ax, sprintf('(%c)', 'a' + n - 1));
        if n == 1
            lg = legend(ax, 'Orientation', 'horizontal');
            lg.Layout.Tile = 'north';
        end
    end
    title(tl, sprintf('%s in detail: top row without noise, bottom row with sensor noise', ...
        sigTitle{q}), 'FontSize', cfg.fig.labelSize + 1);
    exportFigure(fig, cfg.figCombDir, sprintf('fig%02d_%s_detail_with_and_without_noise', 3 + q, sigName{q}), cfg);
end

% Fig. 6 - every noise window, Vout and iL
fig = newFigure([24 12]);
tl = tiledlayout(fig, 2, nW, 'TileSpacing', 'compact', 'Padding', 'compact');
n = 0;
for s = {'vout', 'iL'}
    for k = 1:nW
        n = n + 1;
        ax = nexttile(tl);
        draw(ax, sprintf('%s_noise_window%d', s{1}, k), false);
        addTag(ax, sprintf('(%c)', 'a' + n - 1));
        if n == 1
            lg = legend(ax, 'Orientation', 'horizontal');
            lg.Layout.Tile = 'north';
        end
    end
end
title(tl, 'Response inside each noise window (sensor noise \sigma in % of V_{ref})', ...
    'FontSize', cfg.fig.labelSize + 1);
exportFigure(fig, cfg.figCombDir, 'fig06_noise_windows_vout_iL', cfg);

% Fig. 7 - performance metrics without noise
fig = newFigure([20 12]);
tl = tiledlayout(fig, 2, 3, 'TileSpacing', 'compact', 'Padding', 'compact');
for k = 1:size(metricList, 1)
    ax = nexttile(tl);
    drawBars(ax, M.clean.(metricList{k, 1}), metricList{k, 2}, cfg);
    addTag(ax, sprintf('(%c)', 'a' + k - 1));
end
title(tl, 'Performance without noise', 'FontSize', cfg.fig.labelSize + 1);
exportFigure(fig, cfg.figCombDir, 'fig07_performance_metrics', cfg);

% Fig. 8 - noise robustness metrics
fig = newFigure([18 8]);
tl = tiledlayout(fig, 1, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); drawRobust(ax, M, 'dVout_rms_mV', 'RMS deviation of V_{out} (mV)', cfg); addTag(ax, '(a)');
lg = legend(ax, 'Orientation', 'horizontal'); lg.Layout.Tile = 'north';
ax = nexttile(tl); drawRobust(ax, M, 'diL_rms_A', 'RMS deviation of i_L (A)', cfg); addTag(ax, '(b)');
title(tl, 'Effect of sensor noise (deviation from the noise-free response)', ...
    'FontSize', cfg.fig.labelSize + 1);
exportFigure(fig, cfg.figCombDir, 'fig08_noise_robustness_metrics', cfg);

% Fig. 9 - duty cycle
fig = newFigure([18 12]);
tl = tiledlayout(fig, 2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');
ax = nexttile(tl); draw(ax, 'duty_full_without_noise', false); addTag(ax, '(a)');
lg = legend(ax, 'Orientation', 'horizontal'); lg.Layout.Tile = 'north';
ax = nexttile(tl); draw(ax, 'duty_full_with_noise', false); addTag(ax, '(b)');
exportFigure(fig, cfg.figCombDir, 'fig09_duty_cycle', cfg);

% Fig. 10 - the Simulink model
try
    load_system(cfg.modelFile);
    print(['-s' cfg.model], '-dpng', '-r300', fullfile(cfg.figCombDir, 'fig10_simulink_model.png'));
    print(['-s' cfg.model], '-dpdf', fullfile(cfg.figCombDir, 'fig10_simulink_model.pdf'));
catch err
    warning('make_figures:model', 'Model diagram not printed: %s', err.message);
end
fprintf('Figures written to %s\n', fileparts(cfg.figCombDir));
end

% =================================================================================
function s = mk(id, sig, cond, win, mode, ttl, ylab, shade, legendLoc, short)
s = struct('id', id, 'sig', sig, 'cond', cond, 'win', win, 'mode', mode, ...
    'title', ttl, 'ylabel', ylab, 'shade', shade, 'legendLoc', legendLoc, 'short', short);
end

function tiles(tl, ids, draw, tagFmt)
for n = 1:numel(ids)
    ax = nexttile(tl);
    draw(ax, ids{n}, false);
    addTag(ax, sprintf(tagFmt, char('a' + n - 1)));
    if n == 1
        lg = legend(ax, 'Orientation', 'horizontal');
        lg.Layout.Tile = 'north';
    end
end
end

function drawSignal(ax, sp, showLegend, cfg, S, T, useShort)
P = T.plant;
t = S.t;
in = t >= sp.win(1) & t <= sp.win(2);
ti = t(in);
hold(ax, 'on');
for i = 1:numel(cfg.ctrl.names)
    y = double(S.sig(i, sp.cond).(sp.sig)(in));
    x = ti;
    if strcmp(sp.mode, 'env') || numel(x) > 2 * cfg.fig.maxPoints
        [x, y] = minMaxDecimate(x, y, cfg.fig.maxPoints);
        style = '-';
    else
        style = cfg.ctrl.styles{i};
    end
    plot(ax, x, y, 'LineStyle', style, 'Color', cfg.ctrl.colors(i, :), ...
        'LineWidth', cfg.ctrl.widths(i), 'DisplayName', cfg.ctrl.labels{i});
end
xlim(ax, sp.win);
if strcmp(sp.sig, 'vout')
    yline(ax, P.Vref, ':', 'Color', cfg.fig.refColor, 'LineWidth', 0.9, ...
        'HandleVisibility', 'off');
end
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

function drawNoise(ax, cfg, S, T)
% Injected sensor noise (vmeas - vout, identical for every controller) and its level.
P = T.plant;
t = S.t;
n = double(S.sig(end, 2).vmeas) - double(S.sig(end, 2).vout);
[x, y] = minMaxDecimate(t, n, cfg.fig.maxPoints);
hold(ax, 'on');
plot(ax, x, y, '-', 'Color', [0.55 0.55 0.53], 'LineWidth', 0.5, 'DisplayName', 'injected noise n(t)');
prof = S.noiseProfile;
ts = [prof(:, 1); cfg.Tstop];
sg = [prof(:, 2); prof(end, 2)];
stairs(ax, ts, 3 * sg, '-', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.0, 'DisplayName', '\pm3\sigma(t)');
stairs(ax, ts, -3 * sg, '-', 'Color', [0.1 0.1 0.1], 'LineWidth', 1.0, 'HandleVisibility', 'off');
xlim(ax, [0 cfg.Tstop]);
shadeNoise(ax, cfg.noise.windows, [0 cfg.Tstop], cfg);
xlabel(ax, 'Time (s)', 'FontSize', cfg.fig.labelSize);
ylabel(ax, 'Sensor noise (V)', 'FontSize', cfg.fig.labelSize);
title(ax, sprintf(['Sensor noise added to the V_{out} feedback (Gaussian, sampled every ' ...
    '%g ms, same noise for every controller, V_{ref} = %g V)'], 1e3 * cfg.noise.Ts, P.Vref), ...
    'FontWeight', 'normal', 'FontSize', cfg.fig.labelSize);
legend(ax, 'Location', 'northwest');
end

function drawConvergence(ax, cfg, T)
algos = {'PSO', 'GWO'};
cols = cfg.ctrl.colors(2:3, :);
sty = cfg.ctrl.styles(2:3);
hold(ax, 'on');
for a = 1:2
    st = T.stats.(algos{a});
    C = st.curves;
    it = 1:size(C, 2);
    faded = 0.25 * cols(a, :) + 0.75;
    for r = 1:size(C, 1)
        plot(ax, it, C(r, :), '-', 'Color', faded, 'LineWidth', 0.6, 'HandleVisibility', 'off');
    end
end
for a = 1:2
    st = T.stats.(algos{a});
    C = st.curves;
    [~, ib] = min(C(:, end));
    plot(ax, 1:size(C, 2), C(ib, :), sty{a}, 'Color', cols(a, :), 'LineWidth', 1.8, ...
        'DisplayName', sprintf('%s, best of %d runs (J = %.5g)', algos{a}, size(C, 1), C(ib, end)));
end
set(ax, 'YScale', 'log');
xlabel(ax, 'Iteration', 'FontSize', cfg.fig.labelSize);
ylabel(ax, 'Best cost J (ITAE-based)', 'FontSize', cfg.fig.labelSize);
title(ax, sprintf('Convergence of PSO and GWO (%d agents, thin lines: individual runs)', ...
    cfg.opt.nPop), 'FontWeight', 'normal', 'FontSize', cfg.fig.labelSize);
legend(ax, 'Location', 'northeast');
xlim(ax, [1 cfg.opt.maxIter]);
end

function drawBars(ax, vals, ylab, cfg)
b = bar(ax, 1:numel(vals), vals, 0.6, 'FaceColor', 'flat', 'EdgeColor', 'none');
b.CData = cfg.ctrl.colors(1:numel(vals), :);
set(ax, 'XTick', 1:numel(vals), 'XTickLabel', cfg.ctrl.labels);
ylabel(ax, ylab, 'FontSize', cfg.fig.labelSize);
yl = ylim(ax);
ylim(ax, [0, max(yl(2), max(vals) * 1.18)]);
for k = 1:numel(vals)
    text(ax, k, vals(k), sprintf('%.3g', vals(k)), 'HorizontalAlignment', 'center', ...
        'VerticalAlignment', 'bottom', 'FontSize', cfg.fig.fontSize);
end
ax.XGrid = 'off';
end

function drawRobust(ax, M, field, ylab, cfg)
hold(ax, 'on');
for i = 1:numel(cfg.ctrl.labels)
    r = M.noise(M.noise.Controller == cfg.ctrl.labels{i}, :);
    plot(ax, r.NoiseSigma_pct, r.(field), cfg.ctrl.styles{i}, 'Color', cfg.ctrl.colors(i, :), ...
        'LineWidth', cfg.ctrl.widths(i), 'Marker', 'o', 'MarkerSize', 5, ...
        'MarkerFaceColor', cfg.ctrl.colors(i, :), 'DisplayName', cfg.ctrl.labels{i});
end
xlabel(ax, 'Sensor noise \sigma (% of V_{ref})', 'FontSize', cfg.fig.labelSize);
ylabel(ax, ylab, 'FontSize', cfg.fig.labelSize);
legend(ax, 'Location', 'northwest');
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
    text(ax, (a + b) / 2, yl(2), sprintf('\\sigma = %g %%', W(k, 3)), ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top', ...
        'FontSize', cfg.fig.fontSize - 1, 'Color', [0.3 0.3 0.3]);
end
ylim(ax, yl);
set(ax, 'Layer', 'top');
end

function addTag(ax, tag)
text(ax, 0.01, 0.98, tag, 'Units', 'normalized', 'FontWeight', 'bold', ...
    'VerticalAlignment', 'top', 'HorizontalAlignment', 'left');
end

function [xd, yd] = minMaxDecimate(x, y, nb)
% Keep the minimum and the maximum of each of nb buckets, in time order,
% so the switching ripple envelope survives the decimation.
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

function fig = newFigure(sizeCm)
fig = figure('Visible', 'off', 'Color', 'w', 'Units', 'centimeters', ...
    'Position', [2 2 sizeCm(1) sizeCm(2)]);
end

function applyStyle(cfg)
set(groot, 'defaultAxesFontName', cfg.fig.font, 'defaultTextFontName', cfg.fig.font, ...
    'defaultAxesFontSize', cfg.fig.fontSize, 'defaultTextFontSize', cfg.fig.fontSize, ...
    'defaultLegendFontSize', cfg.fig.fontSize, 'defaultLegendBox', 'off', ...
    'defaultAxesLineWidth', 0.6, 'defaultAxesTickDir', 'out', 'defaultAxesBox', 'off', ...
    'defaultAxesXGrid', 'on', 'defaultAxesYGrid', 'on', ...
    'defaultAxesGridColor', [0.80 0.80 0.78], 'defaultAxesGridAlpha', 0.6, ...
    'defaultAxesXColor', [0.25 0.25 0.25], 'defaultAxesYColor', [0.25 0.25 0.25], ...
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
