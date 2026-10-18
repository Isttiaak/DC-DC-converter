# DC-DC boost converter: PID tuned by Ziegler–Nichols, PSO, GA and GWO

MATLAB/Simulink study of the output-voltage PID controller of a 12 V → 24 V,
500 W boost converter. It compares a conventional PID (Ziegler–Nichols) with a
PID tuned by Particle Swarm Optimization (PSO), one tuned by a Genetic Algorithm
(GA) and one tuned by the Grey Wolf Optimizer (GWO). The test runs with and
without sensor noise, and the three optimisers are also compared over all their
runs against the true optimum of the tuning cost. The whole study
runs on GitHub Actions with real MATLAB R2025a, Simulink and Simscape
Electrical.

## Converter and test (model/boost_PID.slx)

- **Power stage (Specialized Power Systems, switching model):**
  - L = 1.4 mH, C = 4.3 mF, R_load = 1.152 Ω
  - IGBT/diode with Ron = 1 mΩ; output diode with Vf = 0.8 V
  - PWM at 5 kHz
- **Test (0–10 s):**
  - start-up at Vin = 12 V with Vref = 24 V
  - input-voltage step 12 → 20 V at t = 5 s
- **Controller (same structure for all four tunings):**
  - e = Vref − Vout_measured
  - u = Kp·e + sat[0,1](∫Ki·e) + Kd·Nf·(e − z), with dz/dt = Nf·(e − z) and Nf = 100 rad/s
  - duty = sat[0,1](u)
- **Model blocks:**
  - "PID Gains" takes Kp, Ki, Kd and Nf from the workspace.
  - "Sensor Noise" adds Gaussian noise to the Vout feedback, with its level σ(t) set by a time table.
  - "iL Measurement" logs the inductor current.

## Controllers

| Controller | Tuning |
|---|---|
| ZN-PID | Ziegler–Nichols ultimate-gain rules (Kp = 0.6 Ku, Ti = Tu/2, Td = Tu/8). Ku and Tu come from the small-signal duty-to-Vout model at Vin = 12 V. |
| PSO-PID | Global-best PSO: inertia 0.9 → 0.4, c1 = c2 = 2, velocity limit 20 % of the range |
| GA-PID | Real-coded genetic algorithm: binary tournament selection, SBX crossover (p = 0.9, η = 15), polynomial mutation (p = 1/3, η = 20), 2 elites |
| GWO-PID | Grey Wolf Optimizer: a = 2 → 0, alpha/beta/delta leaders |

PSO, GA and GWO share the following:

- **Cost:** ITAE of the start-up plus ITAE after the Vin step.
  - It is computed on an averaged model of the same converter and PID.
  - Start-up overshoot above 2 % is penalised.
  - The cost is the worst case over L and C ± 20 %.
  - Latch-up or no settling gets a penalty.
- **Search box:**
  - Kp ≤ 0.5/Vref
  - Ki ≤ ωz/G0
  - Kd ≤ 0.5/(Nf·Vref)
- **Budget:** 20 agents × 40 iterations (generations) = 800 cost evaluations per run.
- **Runs:** 10 independent runs. Run *r* of every algorithm starts from the same random population, and the best run of each is simulated.
- **Reference optimum:** the true minimum of the cost is found without any metaheuristic: an exhaustive 35 × 35 × 35 grid over the search box, then a pattern search from the best local minima of the grid. Every run of every optimiser is measured against it (% above the optimum), and Wilcoxon rank-sum tests compare the optimisers' final costs.

## Sensor-noise test (robustness)

Gaussian noise (sampled every 0.1 ms, the same realisation for every
controller) is added to the measured Vout during four windows. Each window
has a different level:

| Window | Time (s) | σ (% of Vref) | What it covers |
|---|---|---|---|
| 1 | 0.0–1.5 | 1 % | start-up |
| 2 | 2.5–4.0 | 2.5 % | steady state at 12 V |
| 3 | 4.5–6.0 | 5 % | the 12 → 20 V input step |
| 4 | 7.5–9.5 | 10 % | steady state at 20 V |

## Run it

**On GitHub:** Actions → *Boost converter PID study* → *Run workflow*. Choose
`full`; `quick` is a short check. Figures, tables and the model are uploaded as
the run's artifact and pushed to the `ci-results` branch. The run page shows a
summary table.

**Locally (MATLAB R2025a + Simulink + Simscape Electrical):**

```matlab
run_all            % full study, about 20–30 min
run_all('quick')   % short pipeline check
```

## Outputs (`results/`)

| Folder / file | Content |
|---|---|
| `figures/combined/` | comparison figures (see the list below) |
| `figures/individual/` | every panel as its own print-ready figure |
| `tables/*.csv` | gains; every optimiser run, optimiser statistics, rank-sum tests, reference optimum; performance and noise-robustness metrics |
| `data/*.mat` | tuning results, per-PWM-period signals, full-resolution zoom data |
| `summary.md` | all tables in one page |
| `run_log.txt` | MATLAB log of the run |

Every figure is saved as PNG (300 dpi) and as an editable MATLAB `.fig`. Colours (colour-blind safe): ZN-PID amber, PSO-PID blue, GA-PID pink, GWO-PID green.

Combined figures:

1. Vout with sensor noise of different size at different times. The noise levels are shown on top, then one row per controller (PWM-period averages, same scale), then start-up and Vin-step close-ups.
2. The same layout for the inductor current iL.
3. Vout without noise: 0–10 s for all controllers, then close-ups of start-up, steady-state switching ripple and the Vin step.
4. iL without noise, same layout.
5. Vout with sensor noise: 0–10 s, then close-ups of start-up, the noise switching on, and the Vin step.
6. iL with sensor noise, same layout.
7. Convergence of PSO, GA and GWO: best cost against cost evaluations, every run and the median, as % above the optimum.
8. Where every run of every optimiser ended (final cost above the optimum).
9. Cost landscape around the optimum with the end point of every run.
10. Performance metrics without noise (bar charts).
11. Noise robustness: RMS deviation of Vout and iL against the noise level.
12. Simulink model diagram.

## Results of the full run (`results/summary.md`)

**Controllers (best of 10 runs each), switching model:**

| | ZN-PID | PSO-PID | GA-PID | GWO-PID |
|---|---|---|---|---|
| Kp / Ki / Kd | 0.01171 / 1.039 / 3.30e-5 | 0.003265 / 1.4086 / 3.65e-5 | 0.003319 / 1.4135 / 3.75e-5 | 0.003280 / 1.4082 / 3.60e-5 |
| Cost J above the optimum | +146 % | +0.039 % | +0.031 % | +0.12 % |
| Start-up overshoot / settling | 0.26 % / 99 ms | 1.36 % / 58 ms | 1.39 % / 58 ms | 1.35 % / 58 ms |
| Vin-step peak / settling | 39.6 V / 114 ms | 40.8 V / 71.6 ms | 40.8 V / 71.4 ms | 40.8 V / 71.6 ms |
| RMS ΔVout at σ = 10 % noise | 376 mV | 184 mV | 187 mV | 184 mV |

**Optimisers over all 10 runs** (true optimum J* = 0.013850 at Kp = 0.003224, Ki = 1.4058, Kd = 3.57e-5, found by exhaustive search):

| | PSO | GA | GWO |
|---|---|---|---|
| Best / median / worst run above J* | +0.039 / +0.22 / +0.52 % | +0.031 / +0.29 / +0.57 % | +0.12 / +0.40 / +5.75 % |
| Runs within 1 % of J* | 10 / 10 | 10 / 10 | 7 / 10 |
| Median evaluations to reach 1 % | 480 | 370 | 540 |

Wilcoxon rank-sum test on the final cost: PSO vs GWO p = 0.043 (different at 5 %), PSO vs GA p = 0.39, GA vs GWO p = 0.22.

**Reading the results:**
- All three optimisers find the same optimal PID, so PSO-PID, GA-PID and GWO-PID perform the same in the converter. Each settles about 40 % faster than ZN-PID and is about twice as robust to sensor noise. Identical final controllers are what a correct comparison should give: there is one optimum, and the exhaustive search confirms that the best runs reach it.
- The optimisers differ in how they get there:
  - GWO is fastest in the first ~150 evaluations.
  - GA leads from about 200 to 650 evaluations and reaches 1 % of the optimum soonest.
  - PSO ends closest to the optimum and is the most consistent.
  - In 3 of 10 runs GWO stopped early on the flat floor of the valley, well short of the optimum. This is premature convergence: a refinement from those end points goes straight down to the optimum, so it is not a separate local minimum.

## Repository layout

| Path | Content |
|---|---|
| `run_all.m` | entry point |
| `src/` | `pso.m`, `genetic_algorithm.m`, `gwo.m`, `zn_pid.m`, `boost_pid_cost.m` (averaged-model cost), `reference_optimum.m`, `rank_sum_test.m`, `boost_read_params.m`, `pid_search_bounds.m`, `use_study_model.m`, `study_config.m` (all settings) |
| `scripts/` | tuning, simulation, metrics, figures, summary |
| `build/` | `build_model.m` builds `model/boost_PID.slx` from `boost_GWO_PID.slx` with the Simulink API |
| `model/boost_PID.slx` | the simulated model |
| `.github/workflows/simulate.yml` | GitHub Actions workflow |
