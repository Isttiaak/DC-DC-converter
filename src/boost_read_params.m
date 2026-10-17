function P = boost_read_params(mdl, verbose)
%BOOST_READ_PARAMS  Converter and test-scenario parameters of the boost model.
%
%   P = boost_read_params(mdl) reads the plant parameters from the blocks of
%   the Simulink model mdl (loading it if needed), so the GWO cost always
%   matches the model you simulate. A value that cannot be read keeps the
%   default below (the values of boost_GWO_PID.slx) and a warning lists it.
%
%   P = boost_read_params() returns the defaults only.
%
%   Fields
%     L, RL     inductance [H] and its series resistance [ohm]  (Series RLC Branch)
%     C         output capacitance [F]                          (Series RLC Branch1)
%     R         load resistance [ohm]                           (Series RLC Branch2)
%     Vf, RonD  diode forward voltage [V] / on-resistance       (Diode)
%     RonS      switch on-resistance [ohm]                      (IGBT/Diode)
%     Vin0      input voltage before the step [V]               (Step: Before)
%     Vin1      input voltage after the step [V]                (Step: After)
%     tStep     time of the input-voltage step [s]              (Step: Time)
%     Vref      output-voltage reference [V]                    (Step1: After)
%     fsw       switching frequency [Hz]                        (PWM Generator (DC-DC))
%     dMin,dMax duty limits                                     (Duty Limiter)
%     iMin,iMax integrator output limits                        (Integrator)
%     iL0, vC0  initial inductor current / capacitor voltage
%     Tstop     simulation stop time [s]
%     missing   cell array of parameters that kept their default

if nargin < 2, verbose = false; end

P = struct( ...
    'L', 1.4e-3, 'RL', 0, 'C', 4.3e-3, 'R', 1.152, ...
    'Vf', 0.8, 'RonD', 1e-3, 'RonS', 1e-3, ...
    'Vin0', 12, 'Vin1', 20, 'tStep', 5, 'Vref', 24, 'fsw', 5000, ...
    'dMin', 0, 'dMax', 1, 'iMin', 0, 'iMax', 1, ...
    'iL0', 0, 'vC0', 0, 'Tstop', 10);
P.missing = {};

if nargin < 1 || isempty(mdl)
    return
end
if ~bdIsLoaded(mdl)
    load_system(mdl);
end

pwmName = ['PWM Generator' char(10) '(DC-DC)']; %#ok<CHARTEN>
% block name (relative to the model root), block parameter, field of P
map = {
    'Series RLC Branch',  'Inductance',           'L'
    'Series RLC Branch1', 'Capacitance',          'C'
    'Series RLC Branch2', 'Resistance',           'R'
    'Diode',              'Vf',                   'Vf'
    'Diode',              'Ron',                  'RonD'
    'IGBT//Diode',        'Ron',                  'RonS'
    'Step',               'Before',               'Vin0'
    'Step',               'After',                'Vin1'
    'Step',               'Time',                 'tStep'
    'Step1',              'After',                'Vref'
    pwmName,              'Fsw',                  'fsw'
    'Duty Limiter',       'LowerLimit',           'dMin'
    'Duty Limiter',       'UpperLimit',           'dMax'
    'Integrator',         'LowerSaturationLimit', 'iMin'
    'Integrator',         'UpperSaturationLimit', 'iMax'
    };
for k = 1:size(map, 1)
    blk = [mdl '/' map{k, 1}];
    [v, ok] = readParam(blk, map{k, 2});
    if ok
        P.(map{k, 3}) = v;
    else
        P.missing{end+1} = sprintf('%s : %s', strrep(map{k, 1}, char(10), ' '), map{k, 2}); %#ok<CHARTEN>
    end
end

% Inductor series resistance, if the branch type includes R (e.g. 'RL')
blkL = [mdl '/Series RLC Branch'];
bt = readString(blkL, 'BranchType');
if ~isempty(bt) && any(bt == 'R')
    [v, ok] = readParam(blkL, 'Resistance');
    if ok, P.RL = v; end
end
% Initial conditions (only if enabled in the branch dialogs)
if strcmpi(readString(blkL, 'SetiL0'), 'on')
    [v, ok] = readParam(blkL, 'InitialCurrent');
    if ok, P.iL0 = v; end
end
blkC = [mdl '/Series RLC Branch1'];
if strcmpi(readString(blkC, 'Setx0'), 'on')
    [v, ok] = readParam(blkC, 'InitialVoltage');
    if ok, P.vC0 = v; end
end
% Stop time
try
    st = get_param(mdl, 'StopTime');
    v = str2double(st);
    if ~isfinite(v)
        v = evalin('base', st);
    end
    if isscalar(v) && isfinite(v) && v > 0
        P.Tstop = double(v);
    end
catch
    P.missing{end+1} = 'StopTime';
end

if ~isempty(P.missing)
    warning('boost_read_params:default', ...
        'Could not read %d parameter(s) from "%s"; using defaults for: %s', ...
        numel(P.missing), mdl, strjoin(P.missing, ', '));
end
if verbose
    fprintf(['Plant read from %s: L = %.4g H, C = %.4g F, R = %.4g ohm, Vf = %.3g V, ' ...
        'fsw = %.6g Hz\n  Vin = %.4g V -> %.4g V at t = %.4g s, Vref = %.4g V, ' ...
        'duty limits [%g %g], integrator limits [%g %g]\n'], mdl, P.L, P.C, P.R, ...
        P.Vf, P.fsw, P.Vin0, P.Vin1, P.tStep, P.Vref, P.dMin, P.dMax, P.iMin, P.iMax);
end
end

% -------------------------------------------------------------------------
function [v, ok] = readParam(blk, prm)
% Read a numeric block parameter (literal, expression or workspace variable).
v = NaN;
ok = false;
try
    s = get_param(blk, prm);
catch
    return
end
if isnumeric(s) || islogical(s)
    v = double(s);
else
    v = str2double(strtrim(s));
    if ~isfinite(v)
        try
            v = slResolve(s, blk);
        catch
            try
                v = evalin('base', s);
            catch
                v = NaN;
            end
        end
    end
end
v = double(v);
ok = isscalar(v) && isfinite(v);
end

function s = readString(blk, prm)
try
    s = get_param(blk, prm);
catch
    s = '';
end
end
