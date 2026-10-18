%% RUN_STEP_BY_STEP  The ZN / PSO / GA / GWO PID study, one step at a time
%
% Open this file in MATLAB and run it ONE SECTION AT A TIME: click inside a
% section and press Ctrl+Enter (or "Run Section" on the Editor tab).
% Each section prints what it did; check it before going to the next one.
%
% run_all does steps 1, 2 and 4-8 in one go. This file does the same work, but lets
% you stop and look after every stage.
%
% Needs: MATLAB R2025a (or newer) + Simulink + Simscape + Simscape
% Electrical (Specialized Power Systems).
%
% Test scenario (built into model/boost_PID.slx):
%   0-5 s   Vin = 12 V (start-up to Vref = 24 V)
%   5-10 s  Vin = 20 V (input-voltage step at 5 s)
%   sensor noise on the measured Vout, 4 windows with different levels:
%     0.0-1.5 s  1 %,  2.5-4.0 s  2.5 %,  4.5-6.0 s  5 %,  7.5-9.5 s  10 % of Vref

%% Step 1 - folder, paths and settings  (seconds)
% Before running: in MATLAB, make the unzipped DC-DC-converter folder the
% Current Folder (the one that contains run_all.m).
root = pwd;
assert(isfile(fullfile(root, 'run_all.m')), ...
    'Make the DC-DC-converter folder (the one with run_all.m) the Current Folder first.');
addpath(root);                           % all files in one folder
sub = fullfile(root, {'src', 'scripts', 'build', 'model'});
sub = sub(cellfun(@isfolder, sub));      % repository layout
if ~isempty(sub), addpath(sub{:}); end
mode = 'full';            % 'quick' = short pipeline check (1 s test, small swarm)
cfg = study_config(mode);
fprintf('Settings loaded (%s). Results go to %s\n', cfg.mode, cfg.resultsDir);

%% Step 2 - the Simulink model  (seconds)
% model/boost_PID.slx is already in the package. It is rebuilt from
% build/boost_GWO_PID.slx only if it is missing (set rebuild = true to force).
rebuild = false;
if rebuild || ~isfile(cfg.modelFile)
    build_model(cfg);
end
% closes any OTHER open model called boost_PID (e.g. one with a "PSO PID
% Tuner" block from the MOPSO work) and loads this folder's model
use_study_model(cfg);
open_system(cfg.model);
fprintf('Model %s is open. Blocks to look at: PID Gains, Sensor Noise, iL Measurement, Scope.\n', ...
    cfg.model);

%% Step 3 (optional) - one run of the model by hand  (about 30 s)
% Runs the switching model once with the GWO gains from the full study and
% the noise windows switched on, then plots Vout and iL. This is the same
% as setting the variables yourself and pressing Run in Simulink.
Kp = 0.0032799;  Ki = 1.4082;  Kd = 3.60e-5;  Nf = cfg.Nf;   % GWO-PID
use_study_model(cfg);
P0 = boost_read_params(cfg.model);
W = cfg.noise.windows;                 % rows [t_on t_off sigma(% of Vref)]
if W(1, 1) > 0, noise_sigma = [0 0]; else, noise_sigma = zeros(0, 2); end
for k = 1:size(W, 1)
    noise_sigma = [noise_sigma; W(k, 1), W(k, 3) / 100 * P0.Vref; W(k, 2), 0]; %#ok<AGROW>
end
% noise_sigma = [0 0; cfg.Tstop 0];      % <- use this line instead for no noise
noise_Ts = cfg.noise.Ts;
noise_seed = cfg.noise.seed;
out = sim(cfg.model, 'ReturnWorkspaceOutputs', 'on');
figure('Name', 'Single run: GWO-PID');
subplot(2, 1, 1); plot(out.vout.Time, squeeze(out.vout.Data)); grid on
ylabel('V_{out} (V)'); title('GWO-PID, Vin 12 V \rightarrow 20 V at 5 s, with sensor noise');
subplot(2, 1, 2); plot(out.iL.Time, squeeze(out.iL.Data)); grid on
ylabel('i_L (A)'); xlabel('time (s)');

%% Step 4 - tune the PIDs: ZN, PSO, GA, GWO  (about 6-10 min)
% ZN from the small-signal model; PSO, GA and GWO 10 runs each from the same
% starting populations, best run of each kept. Then the true optimum of the
% cost is found by exhaustive search (no optimiser) and every run is
% measured against it.
% Saves results/data/tuning.mat and, in results/tables: pid_gains.csv,
% optimizer_runs.csv, optimizer_statistics.csv, optimizer_rank_sum_tests.csv,
% reference_optimum.csv.
T = tune_controllers(cfg);
% If MATLAB was closed after this step, reload the gains instead of re-tuning:
%   cfg = study_config('full'); load(fullfile(cfg.dataDir, 'tuning.mat'), 'T');

%% Step 5 - simulate the switching model  (about 3 min)
% 3 controllers x {without noise, with noise} = 6 runs of 0-10 s.
% S stays in memory only (it is large), so do steps 5-8 in the same session.
S = simulate_cases(cfg, T);

%% Step 6 - performance and noise-robustness metrics  (seconds)
% Writes results/tables/*.csv (overshoot, rise/settling time, ITAE, peaks,
% ripple, and the Vout / iL deviation in every noise window).
M = compute_metrics(cfg, T, S);
save(fullfile(cfg.dataDir, 'metrics.mat'), 'M');
disp(M.clean);

%% Step 7 - figures  (a few minutes)
% results/figures/combined/
%   fig01/fig02  Vout / iL: noise levels on top, one row per controller,
%                start-up and Vin-step close-ups
%   fig03/fig04  Vout / iL without noise: 0-10 s, start-up, ripple, Vin step
%   fig05/fig06  Vout / iL with noise: 0-10 s, start-up, noise on, Vin step
%   fig07-fig09  PSO / GA / GWO: convergence, every run, cost landscape
%   fig10-fig12  performance metrics, noise robustness, Simulink model
% results/figures/individual/ every panel of fig03-fig11 on its own
% Each as PNG (300 dpi) and MATLAB .fig (opens visible).
make_figures(cfg, T, S, M);

%% Step 8 - summary  (seconds)
% results/summary.md: all tables in one page.
write_summary(cfg, T, M, S);
fprintf('Done. Open %s\n', fullfile(cfg.resultsDir, 'summary.md'));
