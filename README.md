# IEA

This repository contains the numerical models, coalition-stability simulations, parameter-calibration code, and figure-generation scripts for a study of International Environmental Agreements (IEAs). The model divides the world into 12 regions, solves temperature-dependent value functions by Chebyshev collocation, and compares stable coalitions, emissions, temperature, payoff allocation, and policy instruments under no-tipping, one-tipping, and two-tipping states.

## Research workflow

1. `code/Parameter Simulation` calibrates regional benefit and damage functions from RICE data.
2. `code/Chebyshev Coefs Simulation` solves value-function coefficients for every coalition and tipping state and saves them as `.mat` files.
3. `code/One Tipping Find Steady Coalition` and `code/Two Tippings Find Steady Coalition` use the coefficients to identify annual stable coalitions and export `.xlsx` results.
4. `code/One Tipping Make Grand` searches for the minimum connection or sanction rate required to stabilize the grand coalition.
5. `R_code` reads the Excel results and generates Figures 4.2–4.5 and the appendix figure.

Precomputed `.mat` coefficients, `.xlsx` simulation results, and `.pdf` figures are included so that the reported results can be inspected without rerunning every numerical solve.

## Requirements

- MATLAB with Optimization Toolbox functions including `fsolve`, `lsqcurvefit`, and `lsqnonlin`.
- MATLAB support for reading and writing Excel workbooks.
- R with `tidyverse`, `ggplot2`, `openxlsx`, `readxl`, `stringr`, `patchwork`, `cowplot`, `ggrepel`, `ggtext`, `scales`, and `grid`.

All scripts use relative paths. Run each entry script from its own directory. Do not recursively add every subdirectory under `code` to the MATLAB path: several modules intentionally contain local versions of functions such as `ChebyEval`, `GetRatiomatrix`, and `Residuals*`, and path shadowing may select the wrong implementation.

## Quick start

### MATLAB

Change to the relevant module directory before running an entry script:

```matlab
% 1. Optional: recalibrate regional parameters
cd('code/Parameter Simulation')
run('main_simulation.m')

% 2. Generate one-tipping value-function coefficients
cd('../Chebyshev Coefs Simulation')
run('Main_Test_Value_Function.m')

% 3. Optional: derive no-transfer regional value functions
run('Main_Test_Value_Function_NT.m')

% 4. Simulate stable coalitions under one tipping event
cd('../One Tipping Find Steady Coalition')
run('Main_Test_Once_Tipping_Allocation.m')
```

Start the one-tipping coalition simulation from `code/One Tipping Find Steady Coalition/Main_Test_Once_Tipping_Allocation.m`. Start the grand-coalition policy search from `code/One Tipping Make Grand/Main_Test_Once_MakeGrand.m`. Before running either entry script, review the tipping years, damage increments, connection or sanction rates, discount rate, allocation rule, and input directories defined near the top of the file.

### R

Set the working directory to `R_code`, then source the script for the desired figure:

```r
setwd("R_code")
source("IEA_Plot_Figure_4.2.1.R")
```

The R scripts read simulation results from `../code` and save PDFs under the corresponding `R_code/IEA Figures ...` directory.

## Directory and function reference

### `code/Parameter Simulation`

- `main_simulation.m`: reads output, emissions, climate damages, and temperature for 12 regions from `COPY_RICE_2010_BAU1.xlsx`; interpolates decadal data to annual observations; and estimates the benefit parameters `alpha` and `beta` and damage parameters `eta` and `gamma` by nonlinear least squares.
- `COPY_RICE_2010_BAU1.xlsx` / `.xls`: RICE benchmark data used for parameter calibration.

### `code/Chebyshev Coefs Simulation`

This directory contains the core value-function solvers.

| File or function                  | Purpose                                                                                                                                                                                   |
| --------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Main_Test_Value_Function.m`    | Benchmark entry script. Sets regional and case parameters and runs the one-tipping solver. The final commented section provides configurations for extensions such as two tipping events. |
| `Main_Test_Value_Function_NT.m` | Loads coalition-level coefficients and derives region-level value functions for the no-transfer case.                                                                                     |
| `No_Tipping_Chebyshev`          | Solves coalition and outsider Chebyshev value functions when no tipping event occurs.                                                                                                     |
| `Once_Tipping_Chebyshev`        | Solves value functions before and after one tipping event across low- and high-temperature intervals; supports quadratic or quartic damages.                                              |
| `Twice_Tipping_Chebyshev`       | Solves the multi-state value functions associated with two tipping events.                                                                                                                |
| `Once_Tipping_Chebyshev_NT`     | Decomposes coalition values into member-specific no-transfer values for all one-tipping states.                                                                                           |
| `Twice_Tipping_Chebyshev_NT`    | Decomposes coalition values into member-specific no-transfer values for all two-tipping states.                                                                                           |
| `InitialCoefs`                  | Constructs low-order initial coefficients, Chebyshev nodes and basis matrices, and regional damage terms.                                                                                 |
| `UpdateInitCoefs`               | Prolongs a lower-degree solution to a higher-degree initial guess and recomputes damages on the refined grid.                                                                             |
| `CalculateChebyshevMatrices`    | Builds Gauss–Chebyshev nodes, basis functions, and temperature-derivative matrices.                                                                                                      |
| `Calculate_Q_and_Benefits`      | Recovers regional emissions, total emissions, and flow benefits from value-function derivatives.                                                                                          |
| `Residuals0`                    | Evaluates HJB collocation residuals before the first tipping event, including the continuation-value term.                                                                                |
| `Residuals1`                    | Evaluates HJB collocation residuals before the next tipping event, including the continuation-value term.                                                                                 |
| `Residuals2`                    | Evaluates HJB collocation residuals in the terminal tipping state or any state without another transition.                                                                                |
| `AnalyticalSol`                 | Computes closed-form value-function parameters under the quadratic specification for validation of the numerical solution.                                                                |
| `funu1`                         | Supplies the scalar equilibrium residual solved by `fsolve` inside `AnalyticalSol`.                                                                                                   |
| `ChebyEval`                     | Evaluates a univariate Chebyshev approximation over a specified temperature interval.                                                                                                     |
| `GetRatiomatrix`                | Enumerates all nonempty coalitions and calculates their shares of baseline 2005 world GDP.                                                                                                |

### `code/One Tipping Chebyshev Coefs`

This directory contains precomputed `.mat` coefficients for the one-tipping model. Subdirectories identify benchmark and sensitivity cases, including connection, sanction, no connection or sanction, costly sanctions, no transfers, alternative benefit and damage powers, tipping damages, and tipping-event timing. Numeric filename suffixes encode the principal scenario parameters and are parsed automatically by the coalition-simulation scripts.

### `code/One Tipping Find Steady Coalition`

This module loads one-tipping coefficients, compares all nonempty coalitions, and constructs annual paths from 2025 to 2100.

| File or function                        | Purpose                                                                                                                                                     |
| --------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Main_Test_Once_Tipping_Allocation.m` | Entry script. Enumerates coalition states, loads scenario coefficients, selects `Shapley` or `NoTransfer` allocation, and writes trajectories to Excel. |
| `Once_Tipping_Allocation`             | Updates temperature, utilities, and emissions annually; tests internal and external stability; and selects a stable coalition for a specified tipping year. |
| `GetNationFutureProfit`               | Recovers regional continuation values from the coefficient layout containing one coalition-value block followed by outsider blocks.                         |
| `GetNationFutureProfit_NoTransfer`    | Recovers each region's continuation value directly from no-transfer coefficient blocks.                                                                     |
| `PerformShapleyAllocation`            | Computes member allocations from marginal contributions of subcoalitions and returns the regional payoff matrix.                                            |
| `ChebyshevDeriv`                      | Evaluates the temperature derivative of a Chebyshev value function for the emissions first-order condition and temperature transition.                      |
| `ChebyEval`                           | Evaluates a Chebyshev value function at the current temperature.                                                                                            |
| `GetRatiomatrix`                      | Builds the coalition GDP-share matrix.                                                                                                                      |

The `Results of ...` subdirectories contain Excel outputs for benchmark coalitions, alternative coalitions, allocation rules, connection and sanction mechanisms, and benefit, damage, and tipping sensitivity analyses. The nested `One Tipping Chebyshev Coefs` directory is a local copy of coefficients used by this module.

### `code/Two Tippings ChebyEval Results Power_b_2`

This directory contains two-tipping coefficients for the benchmark quadratic benefit specification. Five coefficient groups cover the low- and high-temperature intervals before any tipping event, the low- and high-temperature intervals after one event, and the state after both events.

### `code/Two Tippings Find Steady Coalition`

| File or function                         | Purpose                                                                                                                                                        |
| ---------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Main_Test_Twice_Tipping_Allocation.m` | Two-tipping simulation entry script. Loads all five state-specific coefficient sets, specifies both tipping years, and exports annual results.                 |
| `Twice_Tipping_Allocation`             | Searches for stable coalitions as the model moves through two tipping states and returns temperature, state, utility, coalition, emissions, and benefit paths. |
| `GetNationFutureProfit`                | Recovers regional continuation values from coalition and outsider coefficient blocks.                                                                          |
| `GetNationFutureProfit_NoTransfer`     | Recovers regional continuation values from no-transfer coefficient blocks.                                                                                     |
| `PerformShapleyAllocation`             | Applies the Shapley rule to coalition value.                                                                                                                   |
| `ChebyshevDeriv`                       | Evaluates the temperature derivative of the value function.                                                                                                    |
| `ChebyEval`                            | Evaluates the value function at the current temperature.                                                                                                       |
| `GetRatiomatrix`                       | Builds the coalition GDP-share matrix.                                                                                                                         |

The nested `Two Tippings ChebyEval Results Power_b_2` directory supplies coefficient inputs, while `Extension` contains the two-tipping Excel output.

### `code/One Tipping Make Grand`

This module searches for the minimum connection or sanction rate that keeps the 12-region grand coalition stable.

| File or function                       | Purpose                                                                                                                                                           |
| -------------------------------------- | ----------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `Main_Test_Once_MakeGrand.m`         | Entry script. Uses interval expansion and bisection each year to find the minimum policy rate, then exports temperature, rate, value-function, and utility paths. |
| `EvaluateGrandCoalitionRate`         | Computes the grand coalition and all single-region exit cases at a given year, temperature, and policy rate, then tests stability using continuation values.      |
| `Once_Tipping_Chebyshev_for_Grand`   | Solves one-tipping value functions only for the grand coalition and single-region exits, avoiding unnecessary coalition solves.                                   |
| `AnalyticalSol`                      | Computes the quadratic analytical solution used by this module.                                                                                                   |
| `InitialCoefs` / `UpdateInitCoefs` | Construct and successively refine initial coefficients for the Chebyshev solver.                                                                                  |
| `CalculateChebyshevMatrices`         | Builds Chebyshev nodes, basis functions, and derivative matrices.                                                                                                 |
| `Residuals1` / `Residuals2`        | Evaluate the HJB residuals before tipping and in the terminal post-tipping state.                                                                                 |
| `funu1` / `funu2`                  | Supply nonlinear residuals for the analytical or low-dimensional coefficient systems.                                                                             |
| `ChebyEval` / `ChebyshevDeriv`     | Evaluate value functions and their temperature derivatives.                                                                                                       |
| `GetRatiomatrix`                     | Builds the coalition GDP-share matrix; the entry script retains only the grand coalition and single-region exits.                                                 |

`GrandCoalitionTrace_Once_Connection.xlsx` and `GrandCoalitionTrace_Once_Sanction.xlsx` contain the connection-rate and sanction-rate experiments, respectively.

### `R_code`

| Script                         | Figure and internal helpers                                                                                                                                                                                                                                                                              |
| ------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `IEA_Plot_Figure_4.2.1.R`    | Plots emissions, temperature, and coalition membership under one tipping event.`extract_plot_data` prepares the Excel data, `make_emission_temp_plot` draws the dual-axis time series, `make_membership_grid_plot` draws the membership/emissions grid, and `get_axis_params` harmonizes scales. |
| `IEA_Plot_Figure_4.2.2.R`    | Compares coalition scenarios with the grand coalition.`extract_metrics`, `calc_diff_vs_grand`, and `make_merged_plot_data` prepare the comparison; `get_ylim`, `make_panel`, and `make_custom_legend` create the panels and legend.                                                          |
| `IEA_Plot_Figure_4.2.3.R`    | Plots benefit, damage, and profit differences relative to no coalition.`extract_calibration_metrics`, `calc_diff_vs_no_coalition`, and `make_calibration_plot_data` prepare the data; `get_ylim_diff`, `make_calibration_panel`, and `make_custom_legend` produce the figure.                |
| `IEA_Plot_Figure_4.3.1.R`    | Compares connection, sanction, and related benefit-policy cases.`read_scenario_data` standardizes results, `get_ylim_diff` harmonizes axes, and `make_panel` constructs the comparison panels.                                                                                                     |
| `IEA_Plot_Figure_4.3.2.R`    | Compares the minimum connection and sanction rates required for a stable grand coalition.`read_and_process` reads, cleans, and combines the policy trajectories.                                                                                                                                       |
| `IEA_Plot_Figure_4.4.R`      | Compares Shapley allocation with no transfers.`extract_plot_data` prepares each case, `get_axis_params` defines dual-axis scaling, and `make_panel_plot` draws the allocation, emissions, and temperature panels.                                                                                  |
| `IEA_Plot_Figure_4.5.1.R`    | Compares connection-rate and tipping-damage sensitivity cases with the benchmark.`extract_plot_data`, `build_scenario_diff_data`, `get_dual_axis_params`, `make_top_diff_plot`, `make_membership_compare_grid`, and `make_scenario_block` assemble the comparison.                           |
| `IEA_Plot_Figure_4.5.2.R`    | Benefit-function sensitivity analysis.`extract_plot_data`, `make_emission_temp_plot`, `make_membership_grid_plot`, and `get_axis_params` handle extraction, dual-axis curves, the membership grid, and scale selection.                                                                          |
| `IEA_Plot_Figure_4.5.3.R`    | Damage-function sensitivity analysis using helpers with the same roles as Figure 4.5.2.                                                                                                                                                                                                                  |
| `IEA_Plot_Figure_4.5.4.R`    | Compares one and two tipping events. In addition to the shared extraction, time-series, membership-grid, and scale helpers,`make_scenario_block` assembles a complete panel for each scenario.                                                                                                         |
| `IEA_Plot_Figure_Appendix.R` | Uses the regional parameter arrays to produce the appendix scatter plots for benefit and damage parameters.                                                                                                                                                                                              |

`IEA Figures 4.2`, `IEA Figures 4.3`, `IEA Figures 4.4`, `IEA Figures 4.5`, and `IEA Figures Appendix` contain the generated PDF figures.

## Data and output naming

- `.mat`: Chebyshev coefficients. Prefixes identify tipping states and temperature intervals; suffixes encode scenario values such as damage increments, connection or sanction rates, loss rates, benefit powers, approximation degrees, and discount rates.
- `.xlsx`: annual coalition membership, emissions, temperature, payoff or utility, and policy-rate trajectories.
- `.pdf`: final figures used in the paper and appendix.

## Notes

- Research outputs are versioned to support result verification, so most repository storage is used by `.mat` and `.xlsx` files.
- Local R session files such as `.RData`, `.RDataTmp*`, and `.Rhistory` are excluded through `.gitignore` because they are not part of the reproducible workflow.
- `ChebyEval.m` retains its original authorship and citation notice. Follow the citation requirement in that source file when reusing the numerical routine.

