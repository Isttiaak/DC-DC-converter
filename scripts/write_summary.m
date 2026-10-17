function write_summary(cfg, T, M, S)
%WRITE_SUMMARY  Markdown summary of the study (results/summary.md); on
%   GitHub Actions it is also shown on the run page (job summary).

L = {};
L{end+1} = sprintf('# Boost converter PID study: ZN vs PSO vs GWO (%s run)', cfg.mode);
L{end+1} = '';
L{end+1} = sprintf('MATLAB %s, %s. Switching model `%s.slx`, 0 to %g s, V_in step at %g s.', ...
    version, char(datetime('now', 'Format', 'yyyy-MM-dd HH:mm')), cfg.model, cfg.Tstop, cfg.tStep);
L{end+1} = '';

% ---- gains ------------------------------------------------------------------------
L{end+1} = '## PID gains';
L{end+1} = '';
hdr = {'Controller', 'Kp', 'Ki', 'Kd', 'Nf', 'Cost J'};
rows = cell(numel(T.labels), numel(hdr));
for i = 1:numel(T.labels)
    rows(i, :) = {T.labels{i}, num(T.K(i, 1)), num(T.K(i, 2)), num(T.K(i, 3)), ...
        num(T.K(i, 4)), num(T.J(i))};
end
L = [L, mdTable(hdr, rows)];
L{end+1} = sprintf(['J = ITAE of start-up + V_in step, start-up overshoot penalty above %g %%, ' ...
    'worst case over L, C +-20 %%. Search box: Kp <= %.4g, Ki <= %.4g, Kd <= %.4g.'], ...
    100 * T.cost.osMax, T.ub(1), T.ub(2), T.ub(3));
L{end+1} = '';

% ---- optimiser statistics ----------------------------------------------------------
L{end+1} = sprintf('## PSO vs GWO over %d independent runs (%d agents x %d iterations each)', ...
    cfg.opt.nRuns, cfg.opt.nPop, cfg.opt.maxIter);
L{end+1} = '';
hdr = {'Algorithm', 'Best J', 'Mean J', 'Median J', 'Worst J', 'Std J', 'Feasible runs', 'Mean time (s)'};
algos = {'PSO', 'GWO'};
rows = cell(2, numel(hdr));
for a = 1:2
    st = T.stats.(algos{a});
    rows(a, :) = {algos{a}, num(st.best), num(st.mean), num(st.median), num(st.worst), ...
        num(st.std), sprintf('%d / %d', st.feasibleRuns, st.nRuns), sprintf('%.1f', st.meanTime)};
end
L = [L, mdTable(hdr, rows)];
L{end+1} = '';

% ---- without noise ------------------------------------------------------------------
L{end+1} = '## Performance without noise (switching model)';
L{end+1} = '';
C = M.clean;
hdr = {'Controller', 'Start-up OS (%)', 'Rise time (ms)', 'Start-up settling (ms)', ...
    'Line-step peak (V)', 'Line-step settling (ms)', 'Total ITAE', 'Peak iL at step (A)'};
rows = cell(height(C), numel(hdr));
for i = 1:height(C)
    rows(i, :) = {char(C.Controller(i)), sprintf('%.2f', C.StartupOvershoot_pct(i)), ...
        sprintf('%.1f', C.RiseTime_ms(i)), sprintf('%.1f', C.StartupSettling_ms(i)), ...
        sprintf('%.2f', C.LineStepPeak_V(i)), sprintf('%.1f', C.LineStepSettling_ms(i)), ...
        num(C.TotalITAE(i)), sprintf('%.1f', C.iLPeakLineStep_A(i))};
end
L = [L, mdTable(hdr, rows)];
L{end+1} = '';

% ---- with noise ------------------------------------------------------------------------
W = cfg.noise.windows;
L{end+1} = '## Robustness to sensor noise (RMS deviation from the noise-free response)';
L{end+1} = '';
hdr = {'Controller'};
for k = 1:size(W, 1)
    hdr{end+1} = sprintf('W%d %g-%g s, sigma %g %%: dVout (mV) / diL (A)', k, W(k, 1), W(k, 2), W(k, 3)); %#ok<AGROW>
end
rows = cell(numel(cfg.ctrl.labels), numel(hdr));
for i = 1:numel(cfg.ctrl.labels)
    rows{i, 1} = cfg.ctrl.labels{i};
    for k = 1:size(W, 1)
        r = M.noise(M.noise.Controller == cfg.ctrl.labels{i} & M.noise.Window == k, :);
        rows{i, k + 1} = sprintf('%.1f / %.3f', r.dVout_rms_mV, r.diL_rms_A);
    end
end
L = [L, mdTable(hdr, rows)];
L{end+1} = '';
L{end+1} = sprintf('Simulation wall time: %.0f s in total.', sum(S.elapsed(:)));
L{end+1} = '';

% ---- figures -------------------------------------------------------------------------------
L{end+1} = '## Figures';
L{end+1} = '';
f = dir(fullfile(cfg.figCombDir, '*.png'));
for k = 1:numel(f)
    L{end+1} = sprintf('- [%s](figures/combined/%s)', f(k).name, f(k).name); %#ok<AGROW>
end
L{end+1} = '';
L{end+1} = 'Every panel is also saved on its own in `figures/individual/` (PNG 600 dpi, vector PDF, .fig).';

txt = strjoin(L, newline);
fid = fopen(fullfile(cfg.resultsDir, 'summary.md'), 'w');
fprintf(fid, '%s\n', txt);
fclose(fid);
gh = getenv('GITHUB_STEP_SUMMARY');
if ~isempty(gh)
    fid = fopen(gh, 'a');
    fprintf(fid, '%s\n', txt);
    fclose(fid);
end
fprintf('%s\n', txt);
end

% -------------------------------------------------------------------------
function L = mdTable(hdr, rows)
L = {['| ' strjoin(hdr, ' | ') ' |'], ['|' repmat('---|', 1, numel(hdr))]};
for i = 1:size(rows, 1)
    L{end+1} = ['| ' strjoin(rows(i, :), ' | ') ' |']; %#ok<AGROW>
end
end

function s = num(x)
s = sprintf('%.5g', x);
end
