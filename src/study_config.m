function cfg = study_config(mode)
%STUDY_CONFIG  All settings of the PID comparison study in one place.
%
%   cfg = study_config('full')   complete study (default)
%   cfg = study_config('quick')  short version for testing the pipeline
%
%   Controllers compared (all the same filtered PID, different tuning):
%     ZN-PID   conventional, Ziegler-Nichols ultimate-gain rules
%     PSO-PID  Particle Swarm Optimization
%     GA-PID   Genetic Algorithm (real-coded: tournament, SBX, polynomial mutation)
%     GWO-PID  Grey Wolf Optimizer
%   PSO, GA and GWO share the cost function, search box, population size,
%   evaluation budget and initial population (same seed per run).

if nargin < 1 || isempty(mode), mode = 'full'; end
cfg.mode = lower(char(mode));
% Two layouts are supported:
%   all files in ONE folder (run_all.m next to this file), or
%   the repository layout (src/, scripts/, build/, model/ under the root).
here = fileparts(mfilename('fullpath'));
cfg.model = 'boost_PID';
if isfile(fullfile(here, 'run_all.m'))
    cfg.root      = here;
    cfg.modelFile = fullfile(here, 'boost_PID.slx');
    cfg.baseModel = fullfile(here, 'boost_GWO_PID.slx');
else
    cfg.root      = fileparts(here);
    cfg.modelFile = fullfile(cfg.root, 'model', 'boost_PID.slx');
    cfg.baseModel = fullfile(cfg.root, 'build', 'boost_GWO_PID.slx');
end

% ---- output folders ----------------------------------------------------------
cfg.resultsDir = fullfile(cfg.root, 'results');
cfg.figCombDir = fullfile(cfg.resultsDir, 'figures', 'combined');
cfg.figIndDir  = fullfile(cfg.resultsDir, 'figures', 'individual');
cfg.dataDir    = fullfile(cfg.resultsDir, 'data');
cfg.tableDir   = fullfile(cfg.resultsDir, 'tables');

% ---- controllers ------------------------------------------------------------
cfg.ctrl.names  = {'ZN', 'PSO', 'GA', 'GWO'};
cfg.ctrl.labels = {'ZN-PID', 'PSO-PID', 'GA-PID', 'GWO-PID'};
% colour-blind-safe set (all pairs distinguishable): amber, blue, pink, green
cfg.ctrl.colors = [0.929 0.631 0.000;     % ZN  #eda100 amber
                   0.165 0.471 0.839;     % PSO #2a78d6 blue
                   0.910 0.482 0.643;     % GA  #e87ba4 pink
                   0.000 0.514 0.000];    % GWO #008300 green
cfg.ctrl.styles  = {'-', '-', '-', '-'};
cfg.ctrl.widths  = [0.9 0.7 1.3 2.0];
cfg.ctrl.markers = {'s', 'o', 'd', '^'};
% the tuned PIDs can overlap: GWO widest at the bottom, then GA, PSO thin on top
cfg.ctrl.drawOrder = [1 4 3 2];
cfg.Nf = 100;                             % derivative filter [rad/s], same for all

% ---- optimisation (identical for PSO, GA and GWO) ----------------------------
cfg.opt.algos   = cfg.ctrl.names(2:end);  % optimisers = every controller except ZN
cfg.opt.nPop    = 20;                     % particles / individuals / wolves
cfg.opt.maxIter = 40;                     % iterations / generations (20 x 40 = 800 evaluations)
cfg.opt.nRuns   = 10;                     % independent runs per algorithm
cfg.opt.seed    = 1;                      % run r uses seed + r - 1
cfg.opt.cost = struct('Twin', 0.5, 'nSub', 2, 'objective', 'ITAE', ...
    'osMax', 0.02, 'wOS', 100, 'robust', true, 'Nf', cfg.Nf);
% GA operators (standard real-coded GA settings)
cfg.opt.ga = struct('pc', 0.9, 'etaC', 15, 'pm', [], 'etaM', 20, 'tourSize', 2, 'nElite', 2);
% PSO: inertia 0.9 -> 0.4, c1 = c2 = 2, velocity limit 20 % of the range (pso.m defaults)
% GWO: a = 2 -> 0 (gwo.m)

% ---- reference optimum (exhaustive search, no metaheuristic) -----------------
% yardstick for the optimisers: "% above the true optimum", runs within 1 %
cfg.ref = struct('enable', true, 'n', 35, 'nStart', 4, 'm', 5, 'maxIt', 150, 'tol', 1e-7, ...
    'batch', 2500, 'mapSpan', 0.45, 'mapN', 51, 'boxN', 61);

% ---- test scenario (start-up, then the Vin step of the model) ----------------
cfg.Tstop = 10;                           % [s]
cfg.tStep = 5;                            % Vin 12 -> 20 V [s]

% ---- sensor noise on the Vout feedback: rows [t_on t_off sigma(% of Vref)] ----
% (window 1 covers the start-up, window 3 the Vin step at 5 s)
cfg.noise.windows = [0.0 1.5  1.0
                     2.5 4.0  2.5
                     4.5 6.0  5.0
                     7.5 9.5 10.0];
cfg.noise.Ts   = 1e-4;                    % noise sample time [s] (10 kHz)
cfg.noise.seed = 23341;                   % same noise for every controller

% ---- zoom windows for the detail figures [s] --------------------------------
cfg.zoom.startup = [0 0.30];
cfg.zoom.line    = [4.98 5.30];        % Vin step, from just before it
cfg.zoom.ripple  = [3.400 3.404];         % steady state, inside noise window 2
cfg.zoom.noiseWin = [0.6 0.8; 3.0 3.2; 5.6 5.8; 8.4 8.6];   % one zoom per noise window (data file)
cfg.zoom.onsetWindow = 2;                % 'noise on' close-up: start of this window

% ---- resampling of the logged signals -----------------------------------------
cfg.samplesPerPeriod = 20;                % uniform grid: Tsw/20

% ---- figures -------------------------------------------------------------------
cfg.fig.fonts     = {'Arial', 'Liberation Sans', 'Helvetica', 'DejaVu Sans'};  % first installed one is used
cfg.fig.font      = 'Helvetica';
cfg.fig.fontSize  = 9;                    % axes / ticks [pt]
cfg.fig.labelSize = 10;                   % axis labels [pt]
cfg.fig.single    = [16 8];               % individual figure [cm]
cfg.fig.rowsSize  = [26 17.5];            % noise-level figures (one row per controller) [cm]
cfg.fig.overSize  = [26 14.6];            % overview figures (full run + 3 close-ups) [cm]
cfg.fig.dpi       = 300;
cfg.fig.formats   = {'png', 'fig'};       % PNG + editable MATLAB figure (no PDF)
cfg.fig.shade     = [0.87 0.87 0.84];     % noise-level blocks / noise-window shading
cfg.fig.textColor = [0.25 0.25 0.25];
cfg.fig.axisColor = [0.35 0.35 0.35];
cfg.fig.markColor = [0.70 0.70 0.70];     % vertical marker lines (noise windows, Vin step)
cfg.fig.refColor  = [0.75 0.75 0.75];     % Vref line
cfg.fig.maxPoints = 10000;                % min/max buckets per line (decimation)
cfg.fig.minSpan   = struct('vout', 0.3, 'iL', 0.6, 'duty', 0.02);  % smallest y-range shown

if strcmp(cfg.mode, 'quick')
    cfg.opt.nPop = 10;  cfg.opt.maxIter = 6;  cfg.opt.nRuns = 2;
    cfg.Tstop = 1.0;    cfg.tStep = 0.5;
    cfg.noise.windows = [0.00 0.15 1.0
                         0.25 0.35 2.5
                         0.45 0.60 5.0
                         0.75 0.95 10.0];
    cfg.zoom.startup = [0 0.20];
    cfg.zoom.line    = [0.49 0.60];
    cfg.zoom.ripple  = [0.300 0.304];
    cfg.zoom.noiseWin = [0.08 0.13; 0.28 0.33; 0.53 0.58; 0.82 0.87];
    cfg.fig.formats  = {'png'};
    cfg.ref.n = 9;  cfg.ref.nStart = 2;  cfg.ref.maxIt = 20;  cfg.ref.tol = 1e-4;
    cfg.ref.mapN = 15;  cfg.ref.boxN = 15;
end
end
