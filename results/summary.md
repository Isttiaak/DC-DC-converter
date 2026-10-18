# Boost converter PID study: ZN-PID vs PSO-PID vs GA-PID vs GWO-PID (full run)

MATLAB 25.1.0.2973910 (R2025a) Update 1, 2026-10-18 04:20. Switching model `boost_PID.slx`, 0 to 10 s, V_in step at 5 s.

## PID gains

| Controller | Kp | Ki | Kd | Nf | Cost J | Above optimum |
|---|---|---|---|---|---|---|
| ZN-PID | 0.011707 | 1.0393 | 3.2966e-05 | 100 | 0.034025 | +146 % |
| PSO-PID | 0.0032649 | 1.4086 | 3.6512e-05 | 100 | 0.013855 | +0.0387 % |
| GA-PID | 0.003319 | 1.4135 | 3.7548e-05 | 100 | 0.013854 | +0.0305 % |
| GWO-PID | 0.0032799 | 1.4082 | 3.6044e-05 | 100 | 0.013867 | +0.122 % |
J = ITAE of start-up + V_in step, start-up overshoot penalty above 2 %, worst case over L, C +-20 %. Search box: Kp <= 0.02083, Ki <= 3.759, Kd <= 0.0002083.

## PSO vs GA vs GWO over 10 independent runs (20 agents x 40 iterations = 800 evaluations each)

Reference optimum (exhaustive grid search + refinement): J* = 0.01385 at Kp = 0.0032243, Ki = 1.4058, Kd = 3.571e-05. Every run is measured as % above J*.

| Algorithm | Best J | Median J | Worst J | Best | Median | Worst | Runs within 1 % | Median evaluations to 1 % | Mean time (s) |
|---|---|---|---|---|---|---|---|---|---|
| PSO | 0.013855 | 0.013881 | 0.013922 | +0.0387 % | +0.225 % | +0.523 % | 10 / 10 | 480 | 6.0 |
| GA | 0.013854 | 0.01389 | 0.013929 | +0.0305 % | +0.288 % | +0.57 % | 10 / 10 | 370 | 6.0 |
| GWO | 0.013867 | 0.013905 | 0.014646 | +0.122 % | +0.396 % | +5.75 % | 7 / 10 | 540 | 6.0 |

Wilcoxon rank-sum test on the final cost of all runs (two-sided, exact):

| Pair | Median above optimum | p-value | Different at 5 %? |
|---|---|---|---|
| PSO vs GA | +0.225 % vs +0.288 % | 0.393 | no |
| PSO vs GWO | +0.225 % vs +0.396 % | 0.043 | yes |
| GA vs GWO | +0.288 % vs +0.396 % | 0.218 | no |

## Performance without noise (switching model)

| Controller | Start-up OS (%) | Rise time (ms) | Start-up settling (ms) | Line-step peak (V) | Line-step settling (ms) | Total ITAE | Peak iL at step (A) |
|---|---|---|---|---|---|---|---|
| ZN-PID | 0.26 | 66.6 | 99.4 | 39.55 | 114.2 | 0.035522 | 64.2 |
| PSO-PID | 1.36 | 45.4 | 58.0 | 40.84 | 71.6 | 0.020148 | 68.6 |
| GA-PID | 1.39 | 45.4 | 58.0 | 40.80 | 71.4 | 0.020101 | 68.5 |
| GWO-PID | 1.35 | 45.4 | 58.0 | 40.84 | 71.6 | 0.019916 | 68.6 |

## Robustness to sensor noise (RMS deviation from the noise-free response)

| Controller | W1 0-1.5 s, sigma 1 %: dVout (mV) / diL (A) | W2 2.5-4 s, sigma 2.5 %: dVout (mV) / diL (A) | W3 4.5-6 s, sigma 5 %: dVout (mV) / diL (A) | W4 7.5-9.5 s, sigma 10 %: dVout (mV) / diL (A) |
|---|---|---|---|---|
| ZN-PID | 73.6 / 0.195 | 230.6 / 0.612 | 319.4 / 0.818 | 376.3 / 0.911 |
| PSO-PID | 30.4 / 0.091 | 82.5 / 0.245 | 117.6 / 0.318 | 183.9 / 0.427 |
| GA-PID | 30.8 / 0.091 | 83.6 / 0.248 | 119.3 / 0.322 | 186.7 / 0.434 |
| GWO-PID | 30.4 / 0.091 | 82.4 / 0.245 | 117.5 / 0.318 | 183.5 / 0.426 |

Simulation wall time: 234 s in total.

## Figures

- [fig01_vout_noise_levels.png](figures/combined/fig01_vout_noise_levels.png)
- [fig02_iL_noise_levels.png](figures/combined/fig02_iL_noise_levels.png)
- [fig03_vout_without_noise.png](figures/combined/fig03_vout_without_noise.png)
- [fig04_iL_without_noise.png](figures/combined/fig04_iL_without_noise.png)
- [fig05_vout_with_noise.png](figures/combined/fig05_vout_with_noise.png)
- [fig06_iL_with_noise.png](figures/combined/fig06_iL_with_noise.png)
- [fig07_convergence.png](figures/combined/fig07_convergence.png)
- [fig08_all_runs.png](figures/combined/fig08_all_runs.png)
- [fig09_cost_landscape.png](figures/combined/fig09_cost_landscape.png)
- [fig10_performance_metrics.png](figures/combined/fig10_performance_metrics.png)
- [fig11_noise_robustness.png](figures/combined/fig11_noise_robustness.png)
- [fig12_simulink_model.png](figures/combined/fig12_simulink_model.png)

Every panel of fig03-fig11 is also saved on its own in `figures/individual/` (PNG 300 dpi + editable .fig).
