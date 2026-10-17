# DC-DC boost converter: PID tuned by Ziegler–Nichols, PSO and GWO

MATLAB/Simulink study of the output-voltage PID controller of a 12 V → 24 V,
500 W boost converter. It compares a conventional PID (Ziegler–Nichols) with a
PID tuned by Particle Swarm Optimization (PSO) and one tuned by the Grey Wolf
Optimizer (GWO). The test runs with and without sensor noise. The whole study
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
- **Controller (same structure for all three tunings):**
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
| GWO-PID | Grey Wolf Optimizer: a = 2 → 0, alpha/beta/delta leaders |

PSO and GWO share the following:

- **Cost:** ITAE of the start-up plus ITAE after the Vin step.
  - It is computed on an averaged model of the same converter and PID.
  - Start-up overshoot above 2 % is penalised.
  - The cost is the worst case over L and C ± 20 %.
  - Latch-up or no settling gets a penalty.
- **Search box:**
  - Kp ≤ 0.5/Vref
  - Ki ≤ ωz/G0
  - Kd ≤ 0.5/(Nf·Vref)
- **Budget:** 20 agents × 40 iterations per run.
- **Runs:** 10 independent runs. Run *r* of both algorithms starts from the same random population, and the best run of each is used.

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
| `tables/*.csv` | gains, PSO/GWO statistics, performance and noise-robustness metrics |
| `data/*.mat` | tuning results, per-PWM-period signals, full-resolution zoom data |
| `summary.md` | all tables in one page |
| `run_log.txt` | MATLAB log of the run |

Every figure is saved as PNG (600 dpi), vector PDF and MATLAB `.fig`.

Combined figures:

1. Convergence of PSO and GWO (all runs, best run highlighted)
2. ZN vs PSO vs GWO without noise: Vout and iL, full run, start-up and Vin step
3. Robustness to sensor noise at different times and levels: injected noise, Vout, iL
4. Vout in detail, without and with noise: start-up, Vin step, ripple, noise window 4
5. iL in detail, without and with noise
6. Vout and iL inside each noise window
7. Performance metrics without noise (bar charts)
8. Noise robustness: RMS deviation of Vout and iL against the noise level
9. Duty cycle without and with noise
10. Simulink model diagram

## Repository layout

| Path | Content |
|---|---|
| `run_all.m` | entry point |
| `src/` | `pso.m`, `gwo.m`, `zn_pid.m`, `boost_pid_cost.m` (averaged-model cost), `boost_read_params.m`, `pid_search_bounds.m`, `study_config.m` (all settings) |
| `scripts/` | tuning, simulation, metrics, figures, summary |
| `build/` | `build_model.m` builds `model/boost_PID.slx` from `boost_GWO_PID.slx` with the Simulink API |
| `model/boost_PID.slx` | the simulated model |
| `.github/workflows/simulate.yml` | GitHub Actions workflow |
