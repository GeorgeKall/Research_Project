#test.jl

# Guarantee to run in the current directory
using Pkg: Pkg

Pkg.activate(@__DIR__)
using Revise

import TulipaIO as TIO
import TulipaEnergyModel as TEM
import TulipaClustering as TC
import Gurobi

using DuckDB
using DataFrames
using Plots
using Distances
using CSV
using Statistics
using Plots.PlotMeasures

using JuMP
# pwd() to check where the fuck you are 
# Define the directories - notice we now select tutorial 2 for both the input and output directory
# input_dir = "my-awesome-energy-system/Data";
# output_dir = "my-awesome-energy-system/Data/results";


input_dir = "my-awesome-energy-system/tutorial-9";
#output_dir = "my-awesome-energy-system/tutorial-9/result";
#Include the utils file
include("utils.jl");
include("plotting.jl")
env = Gurobi.Env();


ref = run_full(input_dir)
println(ref)
ref_cost = ref.objective_value
lol_ref = compute_loss_of_load(ref)
#println(DBInterface.execute(ref.db_connection, "SHOW TABLES"))
original_profiles = (DBInterface.execute(ref.db_connection, "SELECT * FROM profiles") |> DataFrame)


println("Reference cost: $ref_cost")


# ── Experiment grid ────────────────────────────────────────────────────────
period_duration = 24;  # for 1 day

k_values = [ 6 ];

clustering_methods = [
    # (clustering_method,         distance,       weight_type,       label)
    (:k_means,       Euclidean(),    :dirac,            "kmeans_dirac")
];

worst_case_options = [
    # (worst_case,  label)
    #(:none,         "nowc"),
    (:global,     "wc_global"),   
    (:local,      "wc_local")    
];


# ── Run ────────────────────────────────────────────────────────────────────
results = DataFrame(
    k=Int[], seed=Int[], construction=Int[],  method=String[], worst_case=String[], 
    reduced_cost=Float64[], cost_ratio=Float64[], cost_diff=Float64[], regret=Float64[],
    lol_reduced=Int[], lol_full=Int[], relative_wc_weight=Float64[]
);

construction = 2
for k in k_values
        all_reg_demand  = Dict{Symbol, Vector{Float64}}()
        all_reg_avail   = Dict{Symbol, Vector{Float64}}()
        all_wc_demand   = Dict{Symbol, Vector{Float64}}()
        all_wc_avail    = Dict{Symbol, Vector{Float64}}()
    for (method, dist, wtype, method_label) in clustering_methods
        for (wc, wc_label) in worst_case_options
            for seed in [1]
                println("---------------------------------------------------------------------------------\n");
                
                label = "$(method_label)_$(wc_label)_$construction"
                    lol_full = lol_ref
                
                    ep_reduced, regret, lol_red, clusters = run_clustered(
                        ref, ref_cost, input_dir, period_duration, k, method, dist, wtype;
                        worst_case=wc, seed=seed, construction=construction
                    );

                    reduced_cost = ep_reduced.objective_value;
                    cost_ratio   = reduced_cost / ref_cost;
                    cost_diff    = reduced_cost - ref_cost;
                    relative_wc_weight = get_relative_wc_weight(clusters, wc)

                    #push!(results, (k, seed, construction, label, wc_label,
                                    #reduced_cost, cost_ratio, cost_diff, regret,
                                   # lol_red, lol_full, relative_wc_weight));
                    #Save results so if it crashes we are safe
                    #CSV.write(joinpath(output_dir, "results_checkpoint.csv"), results)
                    
                    #PLOT THE REPRESENTATIVE DAYS
                    plot_representative_periods(clusters, label, wc, output_dir)

                    for (_, clustering_result) in clusters
                        n_cols   = size(clustering_result.weight_matrix, 2)
                        n_wc_rps = wc == :none ? 0 : (wc == :local ? (n_cols ÷ 2) : 1)
                        wc_start = n_cols - n_wc_rps + 1
                        rep_periods = sort(unique(clustering_result.profiles.rep_period))

                        reg_d, reg_a = summarise_rp_periods(
                            filter(r -> r.rep_period in rep_periods[1:wc_start-1], clustering_result.profiles)
                        )
                        wc_d, wc_a = wc_start > n_cols ? (Float64[], Float64[]) :
                            summarise_rp_periods(
                                filter(r -> r.rep_period in rep_periods[wc_start:end], clustering_result.profiles)
                            )

                        all_reg_demand[wc]  = reg_d
                        all_reg_avail[wc]   = reg_a
                        all_wc_demand[wc]   = wc_d
                        all_wc_avail[wc]    = wc_a
                    end
                    
                    println("\nk=$k seed=$seed $label reduced=$reduced_cost regret=$regret loss of load=$lol_red lol_full=$lol_full relative_wc_weight=$relative_wc_weight");

            
                println("---------------------------------------------------------------------------------\n\n\n");
            end    
            
        end
        plot_profiles_combined(all_reg_demand, all_reg_avail, all_wc_demand, all_wc_avail,original_profiles, "$(method_label)_k$(k)"; period_duration=period_duration)
    end
    
end



