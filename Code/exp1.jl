# exp1.jl
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
using Colors

using JuMP

#Random seeds 
n_seeds = 5;
seeds = collect(1:n_seeds);


input_dir = "../Input_Data_and_Results/tutorial-9";
output_dir = "../Input_Data_and_Results/tutorial-9/results";

#Include the utils file
include("utils.jl");
include("plotting.jl");
env = Gurobi.Env();

# ── Reference run (all periods, no clustering) ─────────────────────────────
ref = run_full(input_dir)

ref_cost = ref.objective_value
println("Reference cost: $ref_cost")
println("Termination status: $(ref.termination_status)")

inv_cost_ref, fixed_inv_cost_ref = investment_cost(ref)

println("Reference investment cost: $inv_cost_ref, with fixed cost:$fixed_inv_cost_ref")

investment_decisions = get_investment_decisions(ref)
lol_ref = compute_loss_of_load(ref)

# ── Experiment grid ────────────────────────────────────────────────────────
period_duration = 24;  # for 1 day

k_values = [4, 6, 8, 10, 12, 14, 16, 18, 20, 30, 40, 50, 60, 70, 80, 100, 150, 200, 250, 300, 350];

#for cross-scenario
#k_values = [4, 6, 8, 10, 12, 14, 16, 18, 20, 30, 40, 50, 60, 70, 80, 100, 150, 200, 250, 300, 350, 450, 600, 750, 900];


clustering_methods = [
    #(clustering_method,         distance,       weight_type,       label)
    (:k_medoids,       Euclidean(),    :dirac,            "kmedoids_dirac"),
    (:k_medoids,       Euclidean(),    :convex,           "kmedoids_convex"),
    (:k_medoids,       Euclidean(),    :conical,          "kmedoids_conical"),
    (:k_medoids,       Euclidean(),    :conical_bounded,  "kmedoids_conical_bounded"),
    (:k_means,       Euclidean(),    :dirac,            "kmeans_dirac"),
    (:k_means,       Euclidean(),    :convex,           "kmeans_convex"),
    (:k_means,       Euclidean(),    :conical,          "kmeans_conical"),
    (:k_means,       Euclidean(),    :conical_bounded,          "kmeans_conical_bounded"),
];

worst_case_options = [
    # (worst_case,  label)
    #(:none,         "no_wc"),
    (:global,     "global_wc"), 
    (:local,      "local_wc"), #cluster first then for each cluster find the worst case constructed from the cluster periods. Use the centroids and the worst-cases
    (:global_fixed, "global_fixed_wc"), # This clusters with k-1 clusters and adds the global worst case after weight fitting and assigns to it 10% of the total weight to it
];

global_fixed_percentages = [
    #0.0001,    
    #0.001,    
    #0.01,    
    #0.05,
    0.10,
    #0.20,
];


# ── Run ────────────────────────────────────────────────────────────────────
results = DataFrame(
    k                 = Int[],      # number of representative periods created
    seed              = Int[],      # random seed used for clustering
    construction      = Int[],      # worst-case construction variant (1 or 2) 1 is the old
    method            = String[],   # full label: clustering_method + weight_type + wc_strategy + construction
    worst_case        = String[],   # worst-case strategy label (no_wc, global_wc, local_wc, global_fixed_wc)
    reduced_cost      = Float64[],  # objective value of the reduced model (investment + operation on clustered data)
    cost_ratio        = Float64[],  # reduced_cost / ref_cost: how much more expensive than the optimum
    cost_diff         = Float64[],  # reduced_cost - ref_cost: absolute cost gap
    regret            = Float64[],  # % cost increase when fixing reduced-model investments and re-solving on full data
    lol_reduced       = Int[],      # loss of load (ENS timesteps) when re-solving full model with fixed investments
    lol_full          = Int[],      # loss of load on the full reference model (should equal lol_ref, kept for sanity)
    relative_wc_weight = Float64[], # weight of WC RP(s) divided by the fair-share weight (total/k); >1 means over-weighted NOT USED
    percentage        = Float64[],  # fraction of total weight hard-assigned to WC for global_fixed (e.g. 0.10); 0.10 for others
    avg_weight_normal = Float64[],  # average weight (days represented) across the regular (non-WC) RPs
    avg_weight_wc     = Float64[],  # average weight (days represented) across the WC RPs; 0.0 if wc == :none
    max_weight_normal  = Float64[],  # maximum weight assigned to any single normal RP across all groups
    max_weight_wc      = Float64[],  # maximum weight assigned to any single WC RP across all groups
    avg_local_wc_dist  = Float64[],  # average distance between each local WC and its paired centroid; 0.0 if wc != :local
    inv_cost_reduced       = Float64[],  # total investment + fixed cost of the reduced model (assets_investment_cost + assets_fixed_cost_simple_method)
    fixed_inv_cost_reduced = Float64[],  # fixed inv cost of the reduced model (assets_fixed_cost_simple_method only)
    inv_cost_ref           = Float64[],  # total investment + fixed cost of the reference model (same breakdown, constant across runs)
    fixed_inv_cost_ref     = Float64[],  # fixed inv cost of the reference model (assets_fixed_cost_simple_method only, constant across runs)
    inv_ccgt          = Float64[],  # units invested in combined cycle gas turbine
    inv_solar         = Float64[],  # units invested in solar PV
    inv_ocgt          = Float64[],  # units invested in open cycle gas turbine (peaker plant)
    inv_wind          = Float64[],  # units invested in onshore wind
    inv_wind_offshore = Float64[],  # units invested in offshore wind
    inv_battery       = Float64[],  # units invested in battery storage
    inv_electrolizer  = Float64[],  # units invested in electrolyzer (hydrogen production)
    clustering_time  = Float64[],  # clustering time
);



for (wc, wc_label) in worst_case_options
    for (method, dist, wtype, method_label) in clustering_methods
        for k in k_values    
            seed_list = seeds
            percentage_list = wc == :global_fixed ? global_fixed_percentages : [0.0] # not applicable for methods other than global_fixed
            for percentage in percentage_list
                for seed in seed_list
                    for construction in [2]
                        println("---------------------------------------------------------------------------------\n");
                        percentage_suffix = wc == :global_fixed ? "_p$(percentage*100)" : ""
                        label = "$(method_label)_$(wc_label)$(percentage_suffix)_$(construction)"

                        # ep_reduced = run_clustered_simple(
                        #     input_dir, period_duration, k, method, dist, wtype;
                        #     worst_case=wc, weight_cap=cap
                        # )
                        try
                            ep_reduced, regret, lol_red, clusters, clustering_time = run_clustered(
                                ref, ref_cost, input_dir, period_duration, k, method, dist, wtype;
                                worst_case=wc, seed=seed, construction=construction, percentage=percentage
                            );
                            
                            reduced_cost = ref.objective_value;
                            
                            cost_ratio   = reduced_cost / ref_cost;
                            cost_diff    = reduced_cost - ref_cost;
                            relative_wc_weight = 0.0 #get_relative_wc_weight(clusters, wc)
                            avg_weight_normal, avg_weight_wc, max_weight_normal, max_weight_wc = get_avg_weights(clusters, wc)
                            avg_local_wc_dist = get_avg_local_wc_distance(clusters, wc, dist)
                            inv_cost_reduced, fixed_inv_cost_reduced = investment_cost(ep_reduced)
                            inv_decisions = get_investment_decisions(ep_reduced)

                            lol_full = lol_ref

                            push!(results, (k, seed, construction, label, wc_label,
                                            reduced_cost, cost_ratio, cost_diff, regret,
                                            lol_red, lol_ref, relative_wc_weight, percentage,
                                            avg_weight_normal, avg_weight_wc, 
                                            max_weight_normal, max_weight_wc, avg_local_wc_dist,
                                            inv_cost_reduced, fixed_inv_cost_reduced,
                                            inv_cost_ref, fixed_inv_cost_ref,
                                            #investment decisions
                                            inv_decisions.ccgt, inv_decisions.solar,
                                            inv_decisions.ocgt, inv_decisions.wind,
                                            inv_decisions.wind_offshore, inv_decisions.battery,
                                            inv_decisions.electrolizer,
                                            clustering_time));
                            #Save results so if it crashes we are safe
                            CSV.write(joinpath(output_dir, "results_checkpoint.csv"), results)

                            
                            #PLOT THE REPRESENTATIVE DAYS
                            #plot_representative_periods(clusters, label, wc, output_dir)
                            
                            println("\nk=$k seed=$seed $label reduced=$reduced_cost, regret=$regret, loss of load=$lol_red, lol_full=$lol_full, relative_wc_weight=$relative_wc_weight, \n 
                                    normal average = $avg_weight_normal,  worst average = $avg_weight_wc,  avg_dist between centroid and local_wc = $avg_local_wc_dist \n  
                                    fixed_inv = $fixed_inv_cost_reduced, inv_cost = $inv_cost_reduced");

                        catch e
                            println("\n!!! ERROR: k=$k seed=$seed $label failed with: $(typeof(e)): $e");
                        end    
                        println("---------------------------------------------------------------------------------\n\n\n");
                    end    
                end
            end
        end
    end
end

results = CSV.read(joinpath(output_dir, "results_checkpoint.csv"), DataFrame, stringtype=String)

println(results)

# Aggregate raw results into mean and std across seeds

results_agg = combine(
    groupby(results, [:k, :method, :construction, :worst_case, :percentage]),
    :regret             => mean => :regret,
    :regret             => std  => :regret_std,
    :cost_ratio         => mean => :cost_ratio,
    :cost_ratio         => std  => :cost_ratio_std,
    :cost_diff          => mean => :cost_diff,
    :cost_diff          => std  => :cost_diff_std,
    :lol_reduced        => mean => :lol_reduced,
    :lol_reduced        => std  => :lol_reduced_std,
    :relative_wc_weight => mean => :relative_wc_weight,
    :relative_wc_weight => std  => :relative_wc_weight_std,
    :avg_weight_normal  => mean => :avg_weight_normal,
    :avg_weight_normal  => std => :avg_weight_normal_std,
    :avg_weight_wc      => mean => :avg_weight_wc,
    :avg_weight_wc      => std => :avg_weight_wc_std,
    :max_weight_normal  => mean => :max_weight_normal,
    :max_weight_normal  => std => :max_weight_normal_std,
    :max_weight_wc      => mean => :max_weight_wc,
    :max_weight_wc      => std => :max_weight_wc_std,
    :avg_local_wc_dist  => mean => :avg_local_wc_dist,
    :avg_local_wc_dist  => std => :avg_local_wc_dist_std,
    :inv_cost_reduced   => mean => :inv_cost_reduced,
    :inv_cost_reduced   => std => :inv_cost_reduced_std,
    :fixed_inv_cost_reduced => mean => :fixed_inv_cost_reduced,
    :fixed_inv_cost_reduced => std => :fixed_inv_cost_reduced_std,
    :inv_cost_ref       => mean => :inv_cost_ref,
    :fixed_inv_cost_ref => mean => :fixed_inv_cost_ref,
    :inv_ccgt            => mean => :inv_ccgt,
    :inv_solar           => mean => :inv_solar,
    :inv_ocgt            => mean => :inv_ocgt,
    :inv_wind            => mean => :inv_wind,
    :inv_wind_offshore   => mean => :inv_wind_offshore,
    :inv_battery         => mean => :inv_battery,
    :inv_electrolizer    => mean => :inv_electrolizer,
);
# Fill NaN std for deterministic methods (only one run)
replace!(results_agg.regret_std,             NaN => 0.0);
replace!(results_agg.cost_ratio_std,         NaN => 0.0);
replace!(results_agg.cost_diff_std,          NaN => 0.0);
replace!(results_agg.lol_reduced_std,        NaN => 0.0);
replace!(results_agg.relative_wc_weight_std, NaN => 0.0);
replace!(results_agg.avg_weight_normal_std,  NaN => 0.0);
replace!(results_agg.avg_weight_wc_std,      NaN => 0.0);
replace!(results_agg.max_weight_normal_std,      NaN => 0.0);
replace!(results_agg.max_weight_wc_std,      NaN => 0.0);
replace!(results_agg.avg_local_wc_dist_std,  NaN => 0.0);
replace!(results_agg.inv_cost_reduced_std,      NaN => 0.0);
replace!(results_agg.fixed_inv_cost_reduced_std,  NaN => 0.0);
#Save aggregated results
CSV.write(joinpath(output_dir, "results_agg_checkpoint.csv"), results_agg)
println(results_agg)
#//////////////////////////////


include("plotting.jl");



#BY WEIGHT TYPE
plot_gallery_regret_byWeightType_Split(results_agg, "kmedoids", output_dir; cross_scenario=false)
plot_gallery_regret_byWeightType_Split(results_agg, "kmeans", output_dir; cross_scenario=false)

plot_gallery_LOL_byWeightType_Split(results_agg, "kmedoids", output_dir, lol_ref; cross_scenario= false)
plot_gallery_LOL_byWeightType_Split(results_agg, "kmeans", output_dir, lol_ref; cross_scenario= false)



#BY WORST CASE
plot_gallery_regret_byWorstCase(results_agg, "kmedoids", output_dir, cross_scenario= false)
plot_gallery_regret_byWorstCase(results_agg, "kmeans", output_dir, cross_scenario= false)

plot_gallery_LOL_byWorstCase(results_agg, "kmedoids", output_dir, lol_ref, cross_scenario= false)
plot_gallery_LOL_byWorstCase(results_agg, "kmeans", output_dir, lol_ref, cross_scenario= false)



#GLOBAL FIXED
#Use this for the appendix 
plot_gallery_globalFixed_regret_and_LOL(results_agg, "kmedoids", output_dir, lol_ref)
plot_gallery_globalFixed_regret_and_LOL(results_agg, "kmeans",   output_dir, lol_ref)

plot_gallery_regret_globalFixed_byPercentage_Dirac(results_agg, "kmedoids", output_dir)
plot_gallery_regret_globalFixed_byPercentage_Dirac(results_agg, "kmeans",   output_dir)



#Weight
#average weight analysis
plot_avgWCweight_vs_k(results_agg,  :local,  output_dir)
plot_avgWCweight_vs_k(results_agg,  :global, output_dir)
#maximum weight analysis
plot_maxWCweight_vs_k(results_agg,  :local,  output_dir)
plot_maxWCweight_vs_k(results_agg,  :global, output_dir)


plot_avg_weights_vs_k(results_agg, "kmedoids", :local, output_dir)
plot_avg_weights_vs_k(results_agg, "kmeans", :local , output_dir)
plot_avg_weights_vs_k(results_agg, "kmedoids", :global, output_dir)
plot_avg_weights_vs_k(results_agg, "kmeans", :global , output_dir)

plot_avg_local_wc_distance_vs_k(results_agg, output_dir)



#Plots for 0.18

plot_gallery_regret_byWeightType(results_agg, "kmedoids", output_dir)
plot_gallery_regret_byWeightType(results_agg, "kmeans", output_dir)
plot_gallery_LOL_byWeightType(results_agg, "kmedoids", output_dir, lol_ref)
plot_gallery_LOL_byWeightType(results_agg, "kmeans", output_dir, lol_ref)




plot_totalWeight_globalFixed(results_agg, "kmedoids", output_dir)
plot_totalWeight_globalFixed(results_agg, "kmeans", output_dir)
plot_totalWeight_global(results_agg, "kmedoids", output_dir)
plot_totalWeight_global(results_agg, "kmeans", output_dir)

plot_totalWeight_local(results_agg, "kmedoids", output_dir)
plot_totalWeight_local(results_agg, "kmeans", output_dir)





include("plotting.jl");
# #for poster
plot_gallery_regret_globalLocal_byClusteringMethod(results_agg, output_dir)
plot_gallery_LOL_globalLocal_byClusteringMethod(results_agg, output_dir, lol_ref)

