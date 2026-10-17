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
cfg.ctrl.names  = {'ZN', 'PSO', 'GWO'};
cfg.ctrl.labels = {'ZN-PID', 'PSO-PID', 'GWO-PID'};
cfg.ctrl.colors = [0.922 0.408 0.204;     % ZN  #eb6834 orange
                   0.165 0.471 0.839;     % PSO #2a78d6 blue
                   0.106 0.686 0.478];    % GWO #1baf7a green
cfg.ctrl.styles = {'-', '-', '-'};
cfg.ctrl.widths = [0.8 0.8 1.8];
cfg.ctrl.drawOrder = [1 3 2];             % PSO and GWO overlap: GWO wide underneath, PSO thin on top
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
end
end
