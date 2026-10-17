# Boost converter PID study: ZN vs PSO vs GWO (full run)

MATLAB 25.1.0.2973910 (R2025a) Update 1, 2026-10-17 08:32. Switching model `boost_PID.slx`, 0 to 10 s, V_in step at 5 s.

## PID gains

| Controller | Kp | Ki | Kd | Nf | Cost J |
|---|---|---|---|---|---|
| ZN-PID | 0.011707 | 1.0393 | 3.2966e-05 | 100 | 0.034025 |
| PSO-PID | 0.0032649 | 1.4086 | 3.6512e-05 | 100 | 0.013855 |
| GWO-PID | 0.0032799 | 1.4082 | 3.6044e-05 | 100 | 0.013867 |
J = ITAE of start-up + V_in step, start-up overshoot penalty above 2 %, worst case over L, C +-20 %. Search box: Kp <= 0.02083, Ki <= 3.759, Kd <= 0.0002083.

## PSO vs GWO over 10 independent runs (20 agents x 40 iterations each)

| Algorithm | Best J | Mean J | Median J | Worst J | Std J | Feasible runs | Mean time (s) |
|---|---|---|---|---|---|---|---|
| PSO | 0.013855 | 0.013881 | 0.013881 | 0.013922 | 2.216e-05 | 10 / 10 | 5.9 |
| GWO | 0.013867 | 0.013996 | 0.013905 | 0.014646 | 0.0002348 | 10 / 10 | 5.9 |

## Performance without noise (switching model)

| Controller | Start-up OS (%) | Rise time (ms) | Start-up settling (ms) | Line-step peak (V) | Line-step settling (ms) | Total ITAE | Peak iL at step (A) |
|---|---|---|---|---|---|---|---|
| ZN-PID | 0.26 | 66.6 | 99.4 | 39.55 | 114.2 | 0.035522 | 64.2 |
| PSO-PID | 1.36 | 45.4 | 58.0 | 40.84 | 71.6 | 0.020148 | 68.6 |
| GWO-PID | 1.35 | 45.4 | 58.0 | 40.84 | 71.6 | 0.019916 | 68.6 |

## Robustness to sensor noise (RMS deviation from the noise-free response)

| Controller | W1 0-1.5 s, sigma 1 %: dVout (mV) / diL (A) | W2 2.5-4 s, sigma 2.5 %: dVout (mV) / diL (A) | W3 4.5-6 s, sigma 5 %: dVout (mV) / diL (A) | W4 7.5-9.5 s, sigma 10 %: dVout (mV) / diL (A) |
|---|---|---|---|---|
| ZN-PID | 73.6 / 0.195 | 230.6 / 0.612 | 319.4 / 0.818 | 376.3 / 0.911 |
| PSO-PID | 30.4 / 0.091 | 82.5 / 0.245 | 117.6 / 0.318 | 183.9 / 0.427 |
| GWO-PID | 30.4 / 0.091 | 82.4 / 0.245 | 117.5 / 0.318 | 183.5 / 0.426 |

Simulation wall time: 178 s in total.

## Figures

- [fig01_convergence_PSO_GWO.png](figures/combined/fig01_convergence_PSO_GWO.png)
- [fig02_comparison_without_noise.png](figures/combined/fig02_comparison_without_noise.png)
- [fig03_robustness_sensor_noise.png](figures/combined/fig03_robustness_sensor_noise.png)
- [fig04_vout_detail_with_and_without_noise.png](figures/combined/fig04_vout_detail_with_and_without_noise.png)
- [fig05_iL_detail_with_and_without_noise.png](figures/combined/fig05_iL_detail_with_and_without_noise.png)
- [fig06_noise_windows_vout_iL.png](figures/combined/fig06_noise_windows_vout_iL.png)
- [fig07_performance_metrics.png](figures/combined/fig07_performance_metrics.png)
- [fig08_noise_robustness_metrics.png](figures/combined/fig08_noise_robustness_metrics.png)
- [fig09_duty_cycle.png](figures/combined/fig09_duty_cycle.png)
- [fig10_simulink_model.png](figures/combined/fig10_simulink_model.png)

Every panel is also saved on its own in `figures/individual/` (PNG 600 dpi, vector PDF, .fig).
