# Research Project 

Code, data, and results for the research project for CSE3000 course at TU Delft.

## Paper

> Experimenting with Blended Weights and Extreme Representative Periods for
Energy System Optimization, George Kalliakmanis Danassis, TU Delft, 2026.


## Repository Structure
Code/                            Julia scripts and environment
exp1.jl                        Main experiment script
utils.jl                       Helper functions
plotting.jl                    Plotting functions
Project.toml                   Julia environment specification
Manifest.toml                  Exact dependency versions (pinned)
Input_Data_and_Results/
tutorial-9/                    Input CSV files for the energy system
results/                     Output CSVs and graphs produced by the experiments
results_1.8/                      Output CSVs and graphs produced by the experiments with ENS=1.8
results_0.18/                     Output CSVs and graphs produced by the experiments with ENS=0.18
results_cross-scenario/                     Output CSVs and graphs produced by the experiments with cross-scenario clustering
## Requirements

- Julia 1.12.6
- A valid **Gurobi license** 

## How to Reproduce

1. Clone this repository.
2. Install Julia 1.12.6
3. Open a terminal in the `Code/` directory and start Julia:

```bash
cd Code
julia --project=.
```

4. In the Julia REPL, instantiate the environment:

```julia
] instantiate
```

5. Run the main experiment:

```julia
include("exp1.jl")
```

Results will be written to `Input_Data_and_Results/tutorial-9/results/`.

## Dependencies

All dependencies are pinned in `Manifest.toml` for reproducibility.

| Package | Version | Source |
|---|---|---|
| TulipaEnergyModel | v0.21.0 | [TulipaEnergy/TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl) |
| TulipaClustering | v0.5.2 @ e65efad | [GeorgeKall/TulipaClustering.jl](https://github.com/GeorgeKall/TulipaClustering.jl) (fork with modifications) |
| TulipaIO | v0.5.0 | [TulipaEnergy/TulipaIO.jl](https://github.com/TulipaEnergy/TulipaIO.jl) |
