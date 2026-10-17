function use_study_model(cfg)
%USE_STUDY_MODEL  Make sure Simulink uses this study's model/boost_PID.slx.
%
%   Simulink finds models by NAME. If another file called boost_PID.slx is
%   open, in the Current Folder or on the MATLAB path (for example a model
%   from the MOPSO/PSO work with a "PSO PID Tuner" block), it can be run
%   instead of this study's model, and the run fails with errors such as
%   "Undefined function 'mopso_tuner_init'". This function
%     1. closes any other model named boost_PID that is already open,
%     2. warns about every other boost_PID file MATLAB can see,
%     3. loads model/boost_PID.slx from this folder,
%     4. rebuilds it from build/boost_GWO_PID.slx if it contains a tuner
%        block (i.e. the file was replaced by another model).

mdl = cfg.model;
want = normPath(cfg.modelFile);
if ~isfile(cfg.modelFile)
    build_model(cfg);
end

% 1) another model with the same name already open -> close it
if bdIsLoaded(mdl) && ~strcmp(normPath(get_param(mdl, 'FileName')), want)
    fprintf('Closing the other open model "%s":\n  %s\n', mdl, get_param(mdl, 'FileName'));
    close_system(mdl, 0);
end

% 2) other files with the same name that MATLAB can see
found = which(mdl, '-all');
if ischar(found), found = {found}; end
found = found(~cellfun(@isempty, regexpi(found, '\.(slx|mdl)$', 'once')));
others = found(~strcmp(cellfun(@normPath, found, 'UniformOutput', false), want));
if ~isempty(others)
    warning('study:shadow', ['Other files named "%s" are on the MATLAB path or in the ' ...
        'Current Folder:\n  %s\nThis study uses %s. To avoid mix-ups, rename those ' ...
        'files or remove their folders from the path (rmpath).'], ...
        mdl, strjoin(others, '\n  '), cfg.modelFile);
end

% 3) load this study's model
load_system(cfg.modelFile);

% 4) the model must use the "PID Gains" block, not an optimiser block
tuners = find_system(mdl, 'SearchDepth', 1, 'Regexp', 'on', 'Name', 'Tuner');
if ~isempty(tuners) || getSimulinkBlockHandle([mdl '/PID Gains']) == -1
    fprintf(['%s is not the study model (found: %s). Rebuilding it from ' ...
        'build/boost_GWO_PID.slx ...\n'], cfg.modelFile, strjoin(tuners, ', '));
    close_system(mdl, 0);
    build_model(cfg);
    load_system(cfg.modelFile);
    assert(getSimulinkBlockHandle([mdl '/PID Gains']) ~= -1, ...
        'use_study_model: rebuilt model has no "PID Gains" block.');
end
fprintf('Using model %s\n', get_param(mdl, 'FileName'));
end

function p = normPath(p)
p = lower(strrep(strrep(char(p), '\', '/'), '//', '/'));
end
