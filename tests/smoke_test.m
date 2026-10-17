function smoke_test()
%SMOKE_TEST  First CI check: MATLAB products, model loading and a short
%   simulation of the base model, with timing to size the full run.
root = fileparts(fileparts(mfilename('fullpath')));
resDir = fullfile(root, 'results');
if ~exist(resDir, 'dir'), mkdir(resDir); end
diary(fullfile(resDir, 'smoke_log.txt'));
cleanup = onCleanup(@() diary('off')); %#ok<NASGU>

fprintf('MATLAB %s\n', version);
v = ver;
for k = 1:numel(v)
    fprintf('  %-45s %s\n', v(k).Name, v(k).Version);
end
addpath(fullfile(root, 'src'), fullfile(root, 'build'));

mdl = 'boost_GWO_PID';
t0 = tic;
load_system(mdl);
fprintf('load_system: %.1f s\n', toc(t0));
assignin('base', 'gwo_opts', struct('mode', 'fixed', 'verbose', true));

for T = [0.02, 0.5]
    t0 = tic;
    out = sim(mdl, 'StopTime', num2str(T));
    el = toc(t0);
    vo = out.vout;
    fprintf('sim to %.2f s: %.1f s wall, %d logged points, Vout(end) = %.3f V\n', ...
        T, el, numel(vo.Time), vo.Data(end));
end
P = boost_read_params(mdl, true);
disp(P);
fprintf('SMOKE TEST OK\n');
end
