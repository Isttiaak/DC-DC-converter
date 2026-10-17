function run_all(mode)
%RUN_ALL  Complete PID study of the DC-DC boost converter.
%
%   run_all          full study (about 20-30 min)
%   run_all('quick') short version to check the pipeline (a few minutes)
%
%   1. build model/boost_PID.slx (if missing) from build/boost_GWO_PID.slx
%   2. tune the PID three ways: Ziegler-Nichols, PSO, GWO
%   3. simulate the switching model for each PID, without and with sensor
%      noise injected at different times and levels
%   4. compute performance / robustness metrics (results/tables)
%   5. export the figures (results/figures, PNG 600 dpi + PDF + FIG)
%   6. write results/summary.md
%
%   Requires MATLAB, Simulink and Simscape Electrical (Specialized Power
%   Systems). The same function runs on GitHub Actions
%   (.github/workflows/simulate.yml).

if nargin < 1 || isempty(mode), mode = 'full'; end
root = fileparts(mfilename('fullpath'));
addpath(fullfile(root, 'src'), fullfile(root, 'scripts'), fullfile(root, 'build'), ...
    fullfile(root, 'model'));
cfg = study_config(mode);
if ~exist(cfg.resultsDir, 'dir'), mkdir(cfg.resultsDir); end
diary(fullfile(cfg.resultsDir, 'run_log.txt'));
stopDiary = onCleanup(@() diary('off')); %#ok<NASGU>
tAll = tic;
fprintf('=== PID study (%s) - MATLAB %s ===\n', cfg.mode, version);
try
    if ~exist(cfg.modelFile, 'file') || strcmp(getenv('REBUILD_MODEL'), '1')
        build_model(cfg);
    end
    load_system(cfg.modelFile);

    fprintf('\n--- 1/5 tuning ---\n');
    T = tune_controllers(cfg);
    fprintf('\n--- 2/5 simulations ---\n');
    S = simulate_cases(cfg, T);
    fprintf('\n--- 3/5 metrics ---\n');
    M = compute_metrics(cfg, T, S);
    save(fullfile(cfg.dataDir, 'metrics.mat'), 'M');
    save_light_data(cfg, T, S);
    fprintf('\n--- 4/5 figures ---\n');
    make_figures(cfg, T, S, M);
    fprintf('\n--- 5/5 summary ---\n');
    write_summary(cfg, T, M, S);
catch err
    % make sure the reason ends up in results/run_log.txt
    fprintf('\n*** ERROR ***\n%s\n', getReport(err, 'extended', 'hyperlinks', 'off'));
    rethrow(err);
end
fprintf('\n=== done in %.1f min ===\n', toc(tAll) / 60);
end

% -------------------------------------------------------------------------
function save_light_data(cfg, T, S)
% Compact data for re-plotting: one value per PWM period for the whole
% run, plus the full-resolution signals inside the zoom windows.
D = struct();
D.labels = cfg.ctrl.labels;
D.conds = S.conds;
D.K = T.K;
D.tAvg = S.tAvg;
D.avg = S.avg;
D.noiseProfile = S.noiseProfile;
wins = [cfg.zoom.startup; cfg.zoom.line; cfg.zoom.ripple; cfg.zoom.noiseWin];
D.zoomWindows = wins;
D.zoom = struct('t', {}, 'sig', {});
for w = 1:size(wins, 1)
    in = S.t >= wins(w, 1) & S.t <= wins(w, 2);
    z = struct();
    for i = 1:size(S.sig, 1)
        for j = 1:size(S.sig, 2)
            f = fieldnames(S.sig(i, j));
            for k = 1:numel(f)
                z(i, j).(f{k}) = S.sig(i, j).(f{k})(in);
            end
        end
    end
    D.zoom(w).t = S.t(in);
    D.zoom(w).sig = z;
end
save(fullfile(cfg.dataDir, 'simulation_data.mat'), 'D', '-v7');
end
