function build_model(cfg)
%BUILD_MODEL  Create model/boost_PID.slx from build/boost_GWO_PID.slx.
%
%   Changes made with the Simulink API (the power stage is untouched):
%   1. "GWO PID Tuner" (MATLAB Function, tuned at t = 0) is replaced by
%      "PID Gains": constants Kp, Ki, Kd, Nf from the workspace, so the same
%      model runs the ZN-, PSO- and GWO-tuned PID.
%   2. "Sensor Noise" between the output-voltage measurement and the error
%      sum: vmeas = vout + sigma(t)*n(t), n ~ N(0,1) (Random Number, sample
%      time noise_Ts, seed noise_seed), sigma(t) from noise_sigma = [t sigma]
%      (From Workspace, held between points). noise_sigma = [0 0; 1 0] -> no noise.
%   3. "iL Measurement" in series with the inductor; iL goes to the Scope
%      (4th input) and to the workspace.
%   4. Logging (To Workspace, timeseries): vout, iL, duty, err, vin, vmeas.
%   5. InitFcn defines default values for all of these variables.

if nargin < 1, cfg = study_config('full'); end
src = fullfile(cfg.root, 'build', 'boost_GWO_PID.slx');
dst = cfg.modelFile;
mdl = cfg.model;
if bdIsLoaded(mdl), close_system(mdl, 0); end
if bdIsLoaded('boost_GWO_PID'), close_system('boost_GWO_PID', 0); end
if ~exist(fileparts(dst), 'dir'), mkdir(fileparts(dst)); end
copyfile(src, dst, 'f');
fileattrib(dst, '+w');
load_system(dst);
fprintf('build_model: building %s\n', dst);

%% 1) PID gains from the workspace -----------------------------------------
tuner = [mdl '/GWO PID Tuner'];
pos = get_param(tuner, 'Position');
ph = get_param(tuner, 'PortHandles');
dstPorts = cell(1, numel(ph.Outport));
for k = 1:numel(ph.Outport)
    ln = get_param(ph.Outport(k), 'Line');
    dstPorts{k} = get_param(ln, 'DstPortHandle');
    delete_line(ln);
end
lnIn = get_param(ph.Inport(1), 'Line');
if lnIn ~= -1, delete_line(lnIn); end
delete_block(tuner);
if getSimulinkBlockHandle([mdl '/Clock']) ~= -1
    delete_block([mdl '/Clock']);
end

gains = [mdl '/PID Gains'];
add_block('built-in/Subsystem', gains, 'Position', pos);
names = {'Kp', 'Ki', 'Kd', 'Nf'};
for k = 1:4
    y = 30 + 55 * (k - 1);
    add_block('built-in/Constant', [gains '/' names{k} ' value'], ...
        'Value', names{k}, 'Position', [40 y 110 y + 26]);
    add_block('built-in/Outport', [gains '/' names{k}], ...
        'Port', num2str(k), 'Position', [190 y + 6 220 y + 20]);
    add_line(gains, [names{k} ' value/1'], [names{k} '/1']);
end
phG = get_param(gains, 'PortHandles');
for k = 1:4
    d = dstPorts{k};
    for m = 1:numel(d)
        add_line(mdl, phG.Outport(k), d(m), 'autorouting', 'on');
    end
end
set_param(gains, 'BackgroundColor', 'lightBlue');
renameIfExists([mdl '/GWO gains'], 'PID gains');

fprintf('  step 1 done: PID Gains block\n');

%% 2) Sensor noise on the Vout feedback -------------------------------------
delete_line(mdl, 'Voltage Measurement/1', 'Sum/1');
nsys = [mdl '/Sensor Noise'];
add_block('built-in/Subsystem', nsys, 'Position', [1060 330 1130 370]);
add_block('built-in/Inport', [nsys '/vout'], 'Position', [30 43 60 57]);
add_block('simulink/Sources/Random Number', [nsys '/White noise N(0,1)'], ...
    'Mean', '0', 'Variance', '1', 'Seed', 'noise_seed', 'SampleTime', 'noise_Ts', ...
    'Position', [30 100 70 130]);
add_block('simulink/Sources/From Workspace', [nsys '/Noise level sigma(t)'], ...
    'VariableName', 'noise_sigma', 'Interpolate', 'off', ...
    'OutputAfterFinalValue', 'Holding final value', 'SampleTime', '0', ...
    'Position', [20 160 90 190]);
add_block('built-in/Product', [nsys '/Scale'], 'Position', [140 112 170 148]);
add_block('built-in/Sum', [nsys '/Add noise'], 'Inputs', '++', ...
    'Position', [220 40 240 140]);
add_block('built-in/Outport', [nsys '/vmeas'], 'Position', [290 83 320 97]);
add_line(nsys, 'White noise N(0,1)/1', 'Scale/1');
add_line(nsys, 'Noise level sigma(t)/1', 'Scale/2');
add_line(nsys, 'vout/1', 'Add noise/1');
add_line(nsys, 'Scale/1', 'Add noise/2');
add_line(nsys, 'Add noise/1', 'vmeas/1');
set_param(nsys, 'BackgroundColor', 'orange');
add_line(mdl, 'Voltage Measurement/1', 'Sensor Noise/1', 'autorouting', 'on');
add_line(mdl, 'Sensor Noise/1', 'Sum/1', 'autorouting', 'on');

fprintf('  step 2 done: Sensor Noise block\n');

%% 3) Inductor current measurement -----------------------------------------
% The switching node joins the inductor, the diode anode and the IGBT
% collector. Remove every wire segment of that node (a branched physical
% connection is stored as several segments), then rebuild it through the
% current measurement: L -> iL Measurement -> {diode, IGBT}.
Lblk = [mdl '/Series RLC Branch'];
phL = get_param(Lblk, 'PortHandles');
phD = get_param([mdl '/Diode'], 'PortHandles');
phS = get_param([mdl '/IGBT//Diode'], 'PortHandles');
nodePorts = [phL.RConn(1), phD.LConn(1), phS.LConn(1)];
for pass = 1:4
    for h = nodePorts
        ln = get_param(h, 'Line');
        if ln ~= -1
            delete_line(ln);
        end
    end
end
cm = [mdl '/iL Measurement'];
add_block([mdl '/Current Measurement'], cm, 'Position', [650 103 675 127]);
phCM = get_param(cm, 'PortHandles');
add_line(mdl, phL.RConn(1), phCM.LConn(1), 'autorouting', 'on');
add_line(mdl, phCM.RConn(1), phD.LConn(1), 'autorouting', 'on');
add_line(mdl, phCM.RConn(1), phS.LConn(1), 'autorouting', 'on');
for h = [phL.RConn(1), phCM.LConn(1), phCM.RConn(1), phD.LConn(1), phS.LConn(1)]
    assert(get_param(h, 'Line') ~= -1, 'build_model: switching node not connected');
end

fprintf('  step 3 done: iL Measurement\n');

%% 4) Logging ------------------------------------------------------------------
addLog(mdl, 'Log iL',    'iL',    [700 30 760 50],   'iL Measurement/1');
addLog(mdl, 'Log Vin',   'vin',   [520 230 580 250], 'Voltage Measurement1/1');
addLog(mdl, 'Log Vmeas', 'vmeas', [1180 380 1240 400], 'Sensor Noise/1');
% Scope: add iL as 4th display
scope = [mdl '/Scope'];
try
    set_param(scope, 'NumInputPorts', '4');
    add_line(mdl, 'iL Measurement/1', 'Scope/4', 'autorouting', 'on');
    sc = get_param(scope, 'ScopeConfiguration');
    sc.LayoutDimensions = [4 1];
catch err
    warning('build_model:scope', 'Scope not extended: %s', err.message);
end

fprintf('  step 4 done: logging\n');

%% 5) Annotation, callbacks ------------------------------------------------------
ann = find_system(mdl, 'FindAll', 'on', 'SearchDepth', 1, 'Type', 'annotation');
txt = ['PID (same structure for ZN-, PSO- and GWO-tuned gains): ' ...
    'u = Kp*e + int(Ki*e) + Kd*Nf*(e - z),  dz/dt = Nf*(e - z);  ' ...
    'gains Kp, Ki, Kd, Nf from the workspace ("PID Gains")'];
for k = 1:numel(ann)
    try
        set_param(ann(k), 'Text', txt);
    catch
        set_param(ann(k), 'Name', txt);
    end
end
init = [ ...
    'if ~exist(''Kp'',''var''), Kp = 0.0033193; end; ' ...
    'if ~exist(''Ki'',''var''), Ki = 1.41243; end; ' ...
    'if ~exist(''Kd'',''var''), Kd = 3.7605e-05; end; ' ...
    'if ~exist(''Nf'',''var''), Nf = 100; end; ' ...
    'if ~exist(''noise_sigma'',''var''), noise_sigma = [0 0; 1 0]; end; ' ...
    'if ~exist(''noise_Ts'',''var''), noise_Ts = 1e-4; end; ' ...
    'if ~exist(''noise_seed'',''var''), noise_seed = 23341; end'];
set_param(mdl, 'PreLoadFcn', init);
set_param(mdl, 'InitFcn', init);

% compile once: catches unconnected ports or bad parameters right here
set_param(mdl, 'SimulationCommand', 'update');
fprintf('  model update (compile) OK\n');
save_system(mdl, dst);
fprintf('build_model: saved %s\n', dst);
close_system(mdl, 0);
end

% -------------------------------------------------------------------------
function addLog(mdl, name, var, pos, srcPort)
blk = [mdl '/' name];
add_block('simulink/Sinks/To Workspace', blk, 'VariableName', var, ...
    'MaxDataPoints', 'inf', 'SaveFormat', 'Timeseries', 'SampleTime', '-1', ...
    'Position', pos);
add_line(mdl, srcPort, [name '/1'], 'autorouting', 'on');
end

function renameIfExists(blk, newName)
if getSimulinkBlockHandle(blk) ~= -1
    set_param(blk, 'Name', newName);
end
end
