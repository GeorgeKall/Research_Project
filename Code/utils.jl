# utils.jl
using Random

# Use this layout for running the experiments with per-scenario clustering
const LAYOUT = TC.ProfilesTableLayout(;
    year = :milestone_year,
    cols_to_groupby = [:milestone_year, :scenario]
)

#Use this layout for running the experiments with cross-scenario clustering
# const LAYOUT = TC.ProfilesTableLayout(;
#     year = :milestone_year,
#     cols_to_groupby = [:milestone_year],
#     cols_to_crossby = [:scenario]
# )


# Creates a fresh DuckDB connection and loads all CSVs from input_dir.
# Renames milestone_year -> year in profiles_wide because TC.transform_wide_to_long!
# expects a column called "year", not "milestone_year".
function fresh_connection(input_dir)
    connection = DBInterface.connect(DuckDB.DB);
    TIO.read_csv_folder(connection, input_dir);
    return connection;
end

# Solves the full model on all periods without any clustering.
# Used to get the reference optimal cost for regret calculation.
function run_full(input_dir)
    connection = fresh_connection(input_dir);
    # TC.transform_wide_to_long!(connection, "profiles_wide", "profiles");
    TC.transform_wide_to_long!(connection, "profiles_wide", "profiles";
        exclude_columns=[ "scenario", "milestone_year", "timestep"]);
    # TC.transform_wide_to_long!(connection, "profiles_wide", "profiles";
    #     exclude_columns=[  "milestone_year", "timestep"]);

    TC.dummy_cluster!(connection; layout=LAYOUT);  # creates a single RP covering all periods
    TEM.populate_with_defaults!(connection);
    ep = TEM.run_scenario(connection; optimizer = () -> Gurobi.Optimizer(env), show_log = false);
    return ep;
end


# Full regret pipeline for a given clustering configuration:
# - Cluster the time series into k representative periods
# - Solve the reduced model to get investment decisions
# - Fix those investments and re-solve on the full data
function run_clustered(ref, ref_cost,  input_dir, period_duration, k, method, distance, weight_type;
                       worst_case=:none,
                       seed,
                       construction=1,
                       percentage=0.10,
                       )
   
    #Initialize new connection with a fresh db                   
    connection = fresh_connection(input_dir);
    #Transform the table profiles_wide from wide to lond
    TC.transform_wide_to_long!(connection, "profiles_wide", "profiles";
        exclude_columns=["scenario", "milestone_year", "timestep"]);
    Random.seed!(seed)
    #Cluster with the given combination     
    # clusters = TC.cluster_with_worst_case!(connection, period_duration, k;
    #     method=method, distance=distance, worst_case=worst_case, weight_type=weight_type, layout=LAYOUT, construction=construction, percentage=percentage);
    
    clustering_time = @elapsed clusters = TC.cluster_with_worst_case!(connection, period_duration, k;
        method=method, distance=distance, worst_case=worst_case, weight_type=weight_type, layout=LAYOUT, construction=construction, percentage=percentage);

    #Run the reduced model    
   
    TEM.populate_with_defaults!(connection);
    ep_reduced = TEM.run_scenario(connection; optimizer = () -> Gurobi.Optimizer(env), optimizer_parameters = Dict("OutputFlag" => 0,"LogToConsole" => 0), show_log = false);
    
    #Calculate relative regret by fixing the investments and runnning the full model again 
    #lol_red = compute_loss_of_load(ep_reduced)

    #Calculate relative regret by fixing the investments and runnning the full model again
    fix_variables_from_solution!(ref, ep_reduced, :assets_investment)
    fix_variables_from_solution!(ref, ep_reduced, :assets_investment_energy)
    
    TEM.solve_model!(ref)
    TEM.save_solution!(ref)
    #JuMP.optimize!(ref.model)

    #C_agg_path = JuMP.objective_value(ref.model)
    regret   = NaN
    lol_red = -1
    if ref.solved
        regret   = (ref.objective_value - ref_cost) / ref_cost * 100
        lol_red = compute_loss_of_load(ref)
    else
        @warn "Benchmark model infeasible for this combination"
    end 
    

    unfix_investment_variables!(ref, :assets_investment)
    unfix_investment_variables!(ref, :assets_investment_energy)

    return ep_reduced, regret, lol_red, clusters, clustering_time
end

# Extracts the investment decisions (units_invested per asset per year)
# from a solved EnergyProblem, to be used for fixing investments in the full model.
function get_investments(ep::TEM.EnergyProblem)
     df = DBInterface.execute(ep.db_connection,
        "SELECT asset, milestone_year, solution AS units_invested 
         FROM var_assets_investment"
    ) |> DataFrame;
    return df;
end



function fix_variables_from_solution!(benchmark_model, reduced_model, var_symbol)
    var_to_fix = benchmark_model.variables[var_symbol].container
    val_to_fix = TEM.JuMP.value(reduced_model.variables[var_symbol].container)
    for (var, val) in zip(var_to_fix, val_to_fix)
        TEM.JuMP.fix(var, val; force=true)
    end
end

function unfix_investment_variables!(ep, var_symbol)
    vars = ep.variables[var_symbol].container
    for var in vars
        TEM.JuMP.unfix(var)
        TEM.JuMP.set_lower_bound(var, 0.0)
    end
end



# Number of rep-period timesteps with any unmet demand from an ENS asset.
function compute_loss_of_load(ep)
    n = DBInterface.execute(ep.db_connection, """
        SELECT COUNT(*) AS n
        FROM var_flow
        WHERE LOWER(from_asset) LIKE '%ens%'
          AND solution > 1e-6
    """) |> DataFrame
    return n.n[1]
end



"""
    get_relative_wc_weight(clusters) -> Float64

Computes the average relative worst-case (WC) weight across all groups in a
clustering result.
The relative WC weight for a group is defined as:
    relative_wc_weight = wc_weight / fair_share
where `wc_weight` is the total weight assigned to the (WC) representatives and `fair_share = total_weight / k` is the weight each RP would
get if weight were distributed evenly across all k columns.

The function averages this ratio across all groups (scenarios) and returns a single scalar, making results comparable across
different values of k since the fair share already accounts for k.
"""
function get_relative_wc_weight(clusters, wc)
    if wc == :none
        return 0.0
    end
    relative_wc_weight = 0.0
    for (_, clustering_result) in clusters
        n_cols      = size(clustering_result.weight_matrix, 2)
        total       = sum(clustering_result.weight_matrix)
        fair_share = total / n_cols
        if wc == :global || wc == :global_fixed
            wc_weight = sum(clustering_result.weight_matrix[:, end])
            relative_wc_weight += wc_weight / fair_share
        elseif wc == :local
            n_wc      = n_cols ÷ 2
            wc_start  = n_cols - n_wc + 1
            wc_weight = sum(clustering_result.weight_matrix[:, wc_start:end])
            relative_wc_weight += wc_weight / (fair_share * n_wc)
        end
    end
    return relative_wc_weight / length(clusters)
end



"""
    get_avg_weights(clusters, wc) -> (Float64, Float64)

Returns the average column weight for normal RPs and for worst-case RPs separately,
averaged across all groups.

For :global and :global_fixed there is 1 WC column (the last one).
For :local there are k/2 WC columns (the last k/2).
For :none all columns are normal and avg_wc is 0.0.

Example: 4 RPs with weights [10, 20, 1, 5], 2 normal and 2 WC
    avg_normal = (10 + 20) / 2 = 15.0
    avg_wc     = (1  +  5) / 2 = 3.0
"""
function get_avg_weights(clusters, wc)
    avg_normal = 0.0
    avg_wc     = 0.0
    max_normal = 0.0
    max_wc     = 0.0

    for (_, clustering_result) in clusters
        n_cols  = size(clustering_result.weight_matrix, 2)
        
        n_wc    = wc == :none    ? 0 :
                  wc == :local   ? (n_cols ÷ 2) : 1
        n_normal = n_cols - n_wc
        wc_start = n_normal + 1

        col_sums = [sum(clustering_result.weight_matrix[:, i]) for i in 1:n_cols]

        avg_normal += n_normal > 0 ? mean(col_sums[1:n_normal])       : 0.0
        avg_wc     += n_wc    > 0 ? mean(col_sums[wc_start:end])      : 0.0
        max_normal += n_normal > 0 ? maximum(col_sums[1:n_normal])    : 0.0
        max_wc     += n_wc    > 0 ? maximum(col_sums[wc_start:end])   : 0.0
    end

    n_groups = length(clusters)
    return avg_normal / n_groups, avg_wc / n_groups, max_normal / n_groups, max_wc / n_groups
end


"""
For local worst-case only: computes the average Euclidean distance between
each local WC feature vector and its paired cluster centroid/medoid.
WC columns are assumed to be appended in cluster order after the normal columns,
so WC i is paired with normal cluster i.
Returns 0.0 for all other worst-case strategies.
"""
function get_avg_local_wc_distance(clusters, wc, distance)
    if wc != :local
        return 0.0
    end
    total_dist = 0.0
    n_groups   = length(clusters)
    for (_, clustering_result) in clusters
        n_cols   = size(clustering_result.rp_matrix, 2)
        n_wc     = n_cols ÷ 2
        n_normal = n_cols - n_wc
        group_dist = 0.0
        for i in 1:n_normal
            centroid_vec  = clustering_result.rp_matrix[:, i]
            wc_vec        = clustering_result.rp_matrix[:, n_normal + i]
            group_dist   += distance(centroid_vec, wc_vec)
        end
        total_dist += group_dist / n_normal
    end
    return total_dist / n_groups
end


function investment_cost(model)
    df = DuckDB.query(model.db_connection,
        "SELECT * FROM t_obj_breakdown_solution"
    ) |> DataFrame
    
    inv   = filter(r -> r.name == "assets_investment_cost",          df)
    fixed = filter(r -> r.name == "assets_fixed_cost_simple_method", df)
    
    return coalesce(get(inv.value,   1, 0.0), 0.0) + coalesce(get(fixed.value, 1, 0.0), 0.0),
           coalesce(get(fixed.value, 1, 0.0), 0.0)
end

function get_investment_decisions(ep)
    df = DuckDB.query(ep.db_connection,
        "SELECT asset, SUM(solution) AS units_invested
         FROM var_assets_investment
         GROUP BY asset"
    ) |> DataFrame
    # return as a dict for easy lookup
     d = Dict(row.asset => row.units_invested for row in eachrow(df))
    return (
        ccgt          = get(d, "ccgt",          0.0),
        solar         = get(d, "solar",         0.0),
        ocgt          = get(d, "ocgt",          0.0),
        wind          = get(d, "wind",          0.0),
        wind_offshore = get(d, "wind_offshore", 0.0),
        battery       = get(d, "battery",       0.0),
        electrolizer  = get(d, "electrolizer",  0.0),
    )
end