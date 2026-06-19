# Research Project 

This repository contains code, data, and results created as part of the 2025/2026 edition of the for the   [CSE3000 Research Project](https://github.com/TU-Delft-CSE/Research-Project) course at TU Delft.


## Paper

> Experimenting with Blended Weights and Extreme Representative Periods for
Energy System Optimization, George Kalliakmanis Danassis, TU Delft, 2026.

Paper can be found in the following [link](). 

## Repository Structure
- Code/                            Julia scripts and environment
    - exp1.jl:                        Main experiment script
    - utils.jl:                       Helper functions
    - plotting.jl:                    Plotting functions
    - Project.toml:                   Julia environment specification
    - Manifest.toml:                  Exact dependency versions
- Input_Data_and_Results/
    - tutorial-9/:                    Input CSV files for the energy system
    - results/:                    Output CSV produced by the experiments
        - 0.18:                     Output CSV produced by the experiments with tutorial-9 original data
        - cross-scenario:                     Output CSV  produced by the experiments with cross-scenario clustering
        - results_checkpoint:                 Output CSV  produced by the experiments with cross-scenario clustering
## Requirements

- Julia 1.12.6
- A **Gurobi license** 

## How to Reproduce

1. Clone this repository
2. Install Julia
3. Open a terminal in the `Code/` directory and start Julia:

``` 
   julia --project=.
```
4. Instantiate the environment (downloads all dependencies):
```julia
   using Pkg
   Pkg.instantiate()
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
| TulipaEnergyModel | v0.21.0 @ 79a9af54 | [TulipaEnergy/TulipaEnergyModel.jl](https://github.com/TulipaEnergy/TulipaEnergyModel.jl) |
| TulipaClustering | v0.5.2 @ e65efad | [GeorgeKall/TulipaClustering.jl](https://github.com/GeorgeKall/TulipaClustering.jl) (fork with modifications) |
| TulipaIO | v0.5.0 | [TulipaEnergy/TulipaIO.jl](https://github.com/TulipaEnergy/TulipaIO.jl) |
