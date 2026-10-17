function cfg = study_config(mode)
%STUDY_CONFIG  All settings of the PID comparison study in one place.
%
%   cfg = study_config('full')   complete study (default)
%   cfg = study_config('quick')  short version for testing the pipeline
%
%   Controllers compared (all the same filtered PID, different tuning):
%     ZN-PID   conventional, Ziegler-Nichols ultimate-gain rules
%     PSO-PID  Particle Swarm Optimization
%     GWO-PID  Grey Wolf Optimizer
%   PSO and GWO share the cost function, search box, population size,
%   iteration budget and initial population (same seed per run).

if nargin < 1 || isempty(mode), mode = 'full'; end
cfg.mode = lower(char(mode));
cfg.root = fileparts(fileparts(mfilename('fullpath')));

% ---- model and output folders ---------------------------------------------
cfg.model      = 'boost_PID';
cfg.modelFile  = fullfile(cfg.root, 'model', 'boost_PID.slx');
cfg.resultsDir = fullfile(cfg.root, 'results');
cfg.figCombDir = fullfile(cfg.resultsDir, 'figures', 'combined');
cfg.figIndDir  = fullfile(cfg.resultsDir, 'figures', 'individual');
cfg.dataDir    = fullfile(cfg.resultsDir, 'data');
cfg.tableDir   = fullfile(cfg.resultsDir, 'tables');

% ---- controllers ------------------------------------------------------------
cfg.ctrl.names  = {'ZN', 'PSO', 'GWO'};
cfg.ctrl.labels = {'ZN-PID', 'PSO-PID', 'GWO-PID'};
cfg.ctrl.colors = [0.165 0.471 0.839;     % #2a78d6 blue
                   0.922 0.408 0.204;     % #eb6834 orange
                   0.106 0.686 0.478];    % #1baf7a green
cfg.ctrl.styles = {'--', '-.', '-'};
cfg.ctrl.widths = [1.3 1.3 1.5];
cfg.Nf = 100;                             % derivative filter [rad/s], same for all

% ---- optimisation (identical for PSO and GWO) --------------------------------
cfg.opt.nPop    = 20;                     % particles / wolves
cfg.opt.maxIter = 40;                     % iterations
cfg.opt.nRuns   = 10;                     % independent runs per algorithm
cfg.opt.seed    = 1;                      % run r uses seed + r - 1
cfg.opt.cost = struct('Twin', 0.5, 'nSub', 2, 'objective', 'ITAE', ...
    'osMax', 0.02, 'wOS', 100, 'robust', true, 'Nf', cfg.Nf);

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
cfg.zoom.line    = [5 5.30];
cfg.zoom.ripple  = [3.400 3.404];         % steady state, inside noise window 2
cfg.zoom.noiseWin = [0.6 0.8; 3.0 3.2; 5.6 5.8; 8.4 8.6];   % one zoom per noise window

% ---- resampling of the logged signals -----------------------------------------
cfg.samplesPerPeriod = 20;                % uniform grid: Tsw/20

% ---- figures -------------------------------------------------------------------
cfg.fig.font      = 'Helvetica';
cfg.fig.fontSize  = 9;                    % axes / ticks [pt]
cfg.fig.labelSize = 10;                   % axis labels [pt]
cfg.fig.single    = [16 8];               % individual figure [cm]
cfg.fig.dpi       = 600;
cfg.fig.formats   = {'png', 'pdf', 'fig'};
cfg.fig.shade     = [0.93 0.93 0.91];     % noise-window shading
cfg.fig.refColor  = [0.45 0.45 0.43];     % Vref line
cfg.fig.maxPoints = 6000;                 % min/max buckets for full-range plots

if strcmp(cfg.mode, 'quick')
    cfg.opt.nPop = 10;  cfg.opt.maxIter = 6;  cfg.opt.nRuns = 2;
    cfg.Tstop = 1.0;    cfg.tStep = 0.5;
    cfg.noise.windows = [0.00 0.15 1.0
                         0.25 0.35 2.5
                         0.45 0.60 5.0
                         0.75 0.95 10.0];
    cfg.zoom.startup = [0 0.20];
    cfg.zoom.line    = [0.5 0.60];
    cfg.zoom.ripple  = [0.300 0.304];
    cfg.zoom.noiseWin = [0.08 0.13; 0.28 0.33; 0.53 0.58; 0.82 0.87];
    cfg.fig.formats  = {'png', 'pdf'};
end
end
