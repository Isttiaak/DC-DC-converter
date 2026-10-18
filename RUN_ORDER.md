# Run order: ZN vs PSO vs GA vs GWO PID study of the boost converter

Test in the model: Vin = 12 V for 0–5 s, 20 V for 5–10 s, Vref = 24 V.
Sensor noise on the measured Vout in four windows: 0–1.5 s at 1 %, 2.5–4 s at 2.5 %, 4.5–6 s at 5 % and 7.5–9.5 s at 10 % of Vref.

## What you need

- MATLAB R2025a or newer, with Simulink, Simscape and Simscape Electrical (Specialized Power Systems).
- The model was saved in R2025a, so older releases may not open it.

## The folder

Put all 23 files in ONE new, empty folder, with no subfolders: 20 MATLAB files (`.m`), the 2 models (`.slx`) and this guide. Don't put them into a folder that already holds files from the MOPSO/PSO work. The code also runs in the GitHub repository layout (`src/`, `scripts/`, `build/`, `model/`); it detects which layout it is in.

## The steps, in order

Step 0: start MATLAB and make that folder the Current Folder. Then open `run_step_by_step.m` and run it one section at a time: click inside a section, then press Ctrl+Enter. The step numbers below match the sections.

| Step | What it does | Command inside the section | Time | What you get |
|---|---|---|---|---|
| 1 | Paths and settings | `cfg = study_config('full');` | seconds | settings loaded |
| 2 | Opens the model (rebuilds it only if it is missing) | `use_study_model(cfg)` | seconds | `boost_PID.slx` open |
| 3 | Optional: one run by hand with the GWO gains and noise | `out = sim(cfg.model, ...)` | ~30 s | Vout and iL plot, Scope |
| 4 | Tunes the PIDs: ZN, then PSO, GA and GWO (10 runs each); finds the true optimum by exhaustive search and measures every run against it | `T = tune_controllers(cfg);` | 6–10 min | `results/tables/pid_gains.csv`, `optimizer_runs.csv`, `optimizer_statistics.csv`, `optimizer_rank_sum_tests.csv`, `reference_optimum.csv`, `results/data/tuning.mat` |
| 5 | Simulates the switching model: 4 controllers, each with and without noise | `S = simulate_cases(cfg, T);` | ~4 min | signals in memory |
| 6 | Computes the metrics | `M = compute_metrics(cfg, T, S);` | seconds | `results/tables/*.csv` |
| 7 | Makes the figures | `make_figures(cfg, T, S, M);` | a few min | `results/figures/combined/` (12 figures, PNG + .fig), `results/figures/individual/` |
| 8 | Writes the summary | `write_summary(cfg, T, M, S);` | seconds | `results/summary.md` |

The `results` folder is created next to the files. Steps 5–8 must run in the same MATLAB session, because the simulation data `S` is kept only in memory.

If MATLAB was closed after step 4, reload the gains instead of re-tuning:

```matlab
cfg = study_config('full'); load(fullfile(cfg.dataDir, 'tuning.mat'), 'T');
```

## If you see "Undefined function 'mopso_tuner_init'" or "PSO PID Tuner"

MATLAB has picked up a different model that is also called `boost_PID`, for example one from the MOPSO/PSO work.
`use_study_model` closes that model and warns you where it is. To clear it by hand:

```matlab
bdclose all                   % closes every open Simulink model
which boost_PID -all          % lists every boost_PID MATLAB can see
```

Rename the other file, or remove its folder from the path with `rmpath`. Then run again.

## Shortcut: everything in one command

```matlab
run_all            % steps 1, 2 and 4-8 in one go, about 15-20 min
run_all('quick')   % short check that everything works (a few minutes)
```

`run_all` also writes `results/run_log.txt` and `results/data/simulation_data.mat`, the compact data for re-plotting.

## The figures (`results/figures/combined/`)

| Figure | What it shows |
|---|---|
| `fig01_vout_noise_levels` | Noise levels on top; Vout of ZN, PSO, GA and GWO each in its own row (same scale); start-up and Vin-step close-ups |
| `fig02_iL_noise_levels` | The same for the inductor current |
| `fig03_vout_without_noise` | Vout 0–10 s, all controllers; start-up, switching ripple, Vin step |
| `fig04_iL_without_noise` | The same for the inductor current |
| `fig05_vout_with_noise` | Vout 0–10 s with noise; start-up, noise switching on, Vin step |
| `fig06_iL_with_noise` | The same for the inductor current |
| `fig07_convergence` | PSO, GA and GWO: best cost against cost evaluations, every run and the median |
| `fig08_all_runs` | Final cost of every run of every optimiser, above the true optimum |
| `fig09_cost_landscape` | Cost around the optimum, with the end point of every run |
| `fig10` – `fig12` | Performance metrics, noise robustness, Simulink model |

Each figure is saved as a PNG and as a `.fig` you can open and edit in MATLAB. Every panel of fig03–fig11 is also saved on its own in `results/figures/individual/`.

## Changing the test

All settings are in `study_config.m`:

- `cfg.noise.windows`: noise times and levels.
- `cfg.tStep`: time of the 12 → 20 V step.
- `cfg.opt`: population size, iterations, number of runs and the GA settings (`cfg.opt.ga`).
- `cfg.ctrl.names`: which controllers are compared (remove `'GA'` or `'PSO'` to leave one out).
- `cfg.ref`: the exhaustive search for the true optimum (`enable = false` skips it).

The input voltages themselves (12 V and 20 V) are set in the model's Step block.

## Which file does what

| File | Role |
|---|---|
| `boost_PID.slx` | Simulink switching model of the converter with the PID, sensor noise and iL measurement |
| `boost_GWO_PID.slx`, `build_model.m`, `gwo_tuner_init.m` | Base model and the builder that recreates `boost_PID.slx`; only used if that file is missing |
| `study_config.m` | All settings |
| `zn_pid.m` | Ziegler–Nichols tuning |
| `pso.m`, `genetic_algorithm.m`, `gwo.m` | The three optimisers |
| `boost_pid_cost.m` | Cost function on the fast averaged model |
| `boost_read_params.m` | Reads L, C, R and the voltages from the model |
| `pid_search_bounds.m` | Search range for Kp, Ki, Kd |
| `reference_optimum.m` | True optimum of the cost by exhaustive search (no optimiser) |
| `rank_sum_test.m` | Wilcoxon rank-sum test (no toolbox needed) |
| `use_study_model.m` | Makes sure this folder's `boost_PID.slx` is the one simulated, not another file named `boost_PID` |
| `tune_controllers.m` | Step 4 |
| `simulate_cases.m` | Step 5 |
| `compute_metrics.m` | Step 6 |
| `make_figures.m` | Step 7 |
| `write_summary.m` | Step 8 |
| `run_all.m` | All steps in one go |
| `run_step_by_step.m` | The same steps as sections |
