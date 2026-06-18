#plotting.jl


function plot_gallery_regret_byWeightType(results, clustering_method, output_dir)
    weight_types = ["dirac", "convex", "conical", "conical_bounded"]
    wc_options = [
        ("no_wc",                 :circle,    "None"),
        ("global_wc",             :diamond,   "Global"),
        ("global_fixed_wc_p10.0", :utriangle, "Global-Fixed"),
        ("local_wc",              :square,    "Local"),
    ]
    colors = [:blue, :red, :green, :purple, :orange, :yellow]

    subplots = []
    for (col_idx, wtype) in enumerate(weight_types)
        is_first = col_idx == 1

        p = plot(
            title          = wtype,
            xlabel         = "", #"Number of representative periods (k)",
            ylabel         = is_first ? "Regret (%)" : "",
            # yscale         = :log10,
            # yticks         = ([0.1, 1, 10, 100], ["0.1", "1", "10", "100"]),
            yformatter     = is_first ? :auto : _ -> "",
            # ylim           = (0.01, 900),
            legend         = col_idx == 4 ? :topright : false,
            legendfontsize = 14,
            titlefontsize  = 16,
            guidefontsize  = 18,
            left_margin    = col_idx == 1 ? 15Plots.mm : 0Plots.mm,
            grid           = true,
            xtickfontsize    = 15,
            ytickfontsize    = 15,
            tickfontfamily   = "Times Bold",
        )
        #hline!(p, [0.01], linestyle=:dash, color=:black, label="reference")

        for ((wc_label, lmarker, wc_display), color) in zip(wc_options, colors)
            method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue

            # Clamp regret to ylim lower bound to avoid log(0) issues
            regret_clamped = max.(df.regret, 0.01)

            plot!(p, df.k, regret_clamped;
                label     = wc_display,
                marker    = lmarker,
                color     = color,
                linestyle = :solid,
                fillalpha = 0.08)
        end
        push!(subplots, p)
    end

    method_display = clustering_method == "kmedoids" ? "k-medoids" : "k-means" 
    gallery = plot(
        subplots...;
        layout             = (1, 4),
        size               = (2500, 700),
        plot_title         = "Regret vs number of RPs (k) using $method_display",
        plot_titlefontsize = 20,
        titlefontsize      = 18,
        guidefontsize      = 18,
        legendfontsize     = 16,
        right_margin       = 4Plots.mm,
        top_margin         = 0Plots.mm,
        bottom_margin      = 14Plots.mm,
    )
    
    
    xlabel_text = "Number of representative periods (k)"
    offset = clustering_method == "kmedoids" ? -0.8 : -1.7 
    annotate!(gallery[3], -5.0, offset, text(xlabel_text, 18, :center, :top))
    

    display(gallery)
    savefig(gallery, joinpath(output_dir, "gallery_$(clustering_method)_regret_0.pdf"))
end


function plot_gallery_regret_byWeightType_Split(results, clustering_method, output_dir; cross_scenario = False) # used
    weight_types = ["dirac", "convex", "conical_bounded", "conical"]
    wc_options = [
        ("no_wc",                 :circle,    "None"),
        ("global_wc",             :diamond,   "Global"),
        ("global_fixed_wc_p10.0", :utriangle, "Global-Fixed"),
        ("local_wc",              :square,    "Local"),
    ]
    colors = [:blue, :red, :green, :purple, :orange, :yellow]

    tops    = []
    bottoms = []

    for (col_idx, wtype) in enumerate(weight_types)
        is_first = col_idx == 1
        is_last = col_idx == 4
        max_range = clustering_method == "kmedoids" ? 240 : 1120 
        p_top = plot(
            title         = wtype,
            xlabel        = "",
            ylabel        = is_first ? "Regret (%)" : "",
            yformatter     = is_first ? :auto : _ -> "",
            ylim          = cross_scenario ? (15, 1000) : (12, max_range), 
            legend        = is_last ? :topright : false,
            titlefontsize = 16,
            legendmarkersize   = 18,
            grid          = true,
            left_margin      = is_first ? 14Plots.mm : 0Plots.mm,
            bottom_margin = 5Plots.mm,
            xtickfontsize    = 15,
            ytickfontsize    = 14,
            tickfontfamily   = "Times Bold",
        )

        p_bottom = plot(
            title         = "",
            xlabel        = "",
            ylabel        = is_first ? "Regret (%)" : "",
            yformatter     = is_first ? :auto : _ -> "",
            ylim          = cross_scenario ? (0, 25) : (0, 15),
            legend        = false,
            grid          = true,
            left_margin      = is_first ? 14Plots.mm : 0Plots.mm,
            bottom_margin    = 13Plots.mm,
            xtickfontsize    = 15,
            ytickfontsize    = 14,
            tickfontfamily   = "Times Bold",
        )
        hline!(p_bottom, [0.0], linestyle=:dash, color=:black, label="reference")

        for ((wc_label, lmarker, wc_display), color) in zip(wc_options, colors)
            method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue

            ribbon_top    = hasproperty(df, :regret_std) ? df.regret_std : zeros(nrow(df))
            ribbon_bottom = hasproperty(df, :regret_std) ? df.regret_std : zeros(nrow(df))

            plot!(p_top, df.k, df.regret;
                label     = wc_display,
                marker    = lmarker,
                color     = color,
                linestyle = :solid,
                ribbon    = ribbon_top,
                fillalpha = 0.08)

            plot!(p_bottom, df.k, df.regret;
                label     = wc_display,
                marker    = lmarker,
                color     = color,
                linestyle = :solid,
                ribbon    = ribbon_bottom,
                fillalpha = 0.08)
        end

        push!(tops,    p_top)
        push!(bottoms, p_bottom)
    end

    # Flat layout: 4 tops on row 1, 4 bottoms on row 2
    l = @layout [
        a b c d
        e f g h
    ]

    method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"
    gallery = plot(
        tops..., bottoms...;
        layout             = l,
        size               = (2200, 600),
        plot_title         = "Regret vs number of RPs (k) using $method",
        plot_titlefontsize = 20,
        titlefontsize      = 18,
        guidefontsize      = 16,
        legendfontsize     = 16,
        legendmarkersize   = 28,
    )

    # Single centered x-label drawn as an annotation on the last bottom subplot
    xlabel_text = "Number of representative periods (k)"
    offset = clustering_method == "kmedoids" ? -3.3 : -3.3 
    offset = cross_scenario ? -6 : offset
    annotate!(gallery[7], -15.0, offset, text(xlabel_text, 16, :center, :top))
    
    display(gallery)
    add = cross_scenario ? "_cross" : ""
    savefig(gallery, joinpath(output_dir,
        "gallery_$(clustering_method)$(add)_regret_broken_axis.pdf"))
end



#///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

function plot_gallery_LOL_byWeightType(results, clustering_method,  output_dir, lol_ref) #used
    weight_types = ["dirac", "convex", "conical_bounded", "conical"]
    wc_options = [
        ("no_wc",                 :circle,    "None"),
        ("global_wc",             :diamond,   "Global"),
        ("global_fixed_wc_p10.0", :utriangle, "Global-Fixed"),
        ("local_wc",              :square,    "Local"),
        
    ]
    colors = [:blue, :red, :green, :purple, :orange, :yellow]
    subplots = []
    for (idx, wtype) in enumerate(weight_types)
        is_first = idx == 1
        is_last  = idx == 4
        p = plot(
            title          = wtype,
            xlabel         = "",
            ylim           = clustering_method == "kmedoids" ? (0, 1400) : (0,4500),
            ylabel         = is_first ? "Loss of Load" : "",
            yformatter     = is_first ? :auto : _ -> "",
            legend         = is_last ? :topright : false,
            titlefontsize  = 16,
            guidefontsize  = 14,
            xtickfontsize    = 15,
            ytickfontsize    = 15,
            tickfontfamily   = "Times Bold",
            left_margin      = is_first ? 14Plots.mm : 0Plots.mm,
          
        )
        hline!(p, [lol_ref], linestyle=:dash, color=:black, label="Reference")

        for ((wc_label, lmarker, wc_display), color) in zip(wc_options, colors)
            method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue
            plot!(p, df.k, df.lol_reduced,
                  label=wc_display, marker=lmarker, markersize=6, color=color,
                  linestyle=:solid,
                  ribbon=hasproperty(df, :lol_reduced_std) ? df.lol_reduced_std : zeros(nrow(df)),
                  fillalpha=0.08)
        end
        push!(subplots, p)
    end

    method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"
    gallery = plot(subplots...;
                   layout             = (1, 4),
                   size               = (2200, 700),
                   plot_title         = "Loss of Load vs number of RPs (k) using $method",
                   plot_titlefontsize = 20,
                   titlefontsize      = 18,
                   guidefontsize      = 18,
                   legendfontsize     = 16,
                   legendmarkersize   = 20,
                   top_margin         = 2Plots.mm,
                   bottom_margin      = 15Plots.mm)

    xlabel_text = "Number of representative periods (k)"
    offset = clustering_method == "kmedoids" ? -120 : -390
    annotate!(gallery[3], -20, offset, text(xlabel_text, 18, :center, :top))
    
    display(gallery)
    savefig(gallery, joinpath(output_dir, "gallery_$(clustering_method)_LOL_0.pdf"))
end



###############
function plot_gallery_LOL_byWeightType_Split(results, clustering_method, output_dir, lol_ref; cross_scenario = False) #used
    weight_types = ["dirac", "convex", "conical_bounded", "conical"]
    wc_options = [
        ("no_wc",                 :circle,    "None"),
        ("global_wc",             :diamond,   "Global"),
        ("global_fixed_wc_p10.0", :utriangle, "Global-Fixed"),
        ("local_wc",              :square,    "Local"),
    ]
    colors = [:blue, :red, :green, :purple, :orange, :yellow]

    tops    = []
    bottoms = []

    for (col_idx, wtype) in enumerate(weight_types)
        is_first = col_idx == 1
        is_last  = col_idx == 4
        

        p_top = plot(
            title          = wtype,
            xlabel         = "",
            ylabel         = is_first ? "Loss of Load" : "",
            yformatter     = is_first ? :auto : _ -> "",
            legend         = is_last ? :topright : false,
            titlefontsize  = 16,
            legendmarkersize = 18,
            ylim           = cross_scenario ? (20,1200) : (55, 3000),
            grid           = true,
            left_margin    = is_first ? 14Plots.mm : 0Plots.mm,
            bottom_margin  = 5Plots.mm,
            xtickfontsize  = 15,
            ytickfontsize  = 14,
            tickfontfamily = "Times Bold",
        )
        hline!(p_top, [lol_ref], linestyle=:dash, color=:black, label="Reference")

        p_bottom = plot(
            title          = "",
            xlabel         = "",
            ylabel         = is_first ? "Loss of Load" : "",
            yformatter     = is_first ? :auto : _ -> "",
            ylim           = cross_scenario ? (-1, 30) : (-1, 50),
            legend         = false,
            grid           = true,
            left_margin    = is_first ? 14Plots.mm : 0Plots.mm,
            bottom_margin  = 13Plots.mm,
            xtickfontsize  = 15,
            ytickfontsize  = 14,
            tickfontfamily = "Times Bold",
        )
        hline!(p_bottom, [lol_ref], linestyle=:dash, color=:black, label="Reference")

        for ((wc_label, lmarker, wc_display), color) in zip(wc_options, colors)
            method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue

            ribbon = hasproperty(df, :lol_reduced_std) ? df.lol_reduced_std : zeros(nrow(df))

            plot!(p_top, df.k, df.lol_reduced;
                label     = wc_display,
                marker    = lmarker,
                markersize = 6,
                color     = color,
                linestyle = :solid,
                ribbon    = ribbon,
                fillalpha = 0.08)

            plot!(p_bottom, df.k, df.lol_reduced;
                label     = wc_display,
                marker    = lmarker,
                markersize = 6,
                color     = color,
                linestyle = :solid,
                ribbon    = ribbon,
                fillalpha = 0.08)
        end

        push!(tops,    p_top)
        push!(bottoms, p_bottom)
    end

    l = @layout [
        a b c d
        e f g h
    ]

    method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"
    gallery = plot(
        tops..., bottoms...;
        layout             = l,
        size               = (2200, 700),
        plot_title         = "Loss of Load vs number of RPs (k) using $method",
        plot_titlefontsize = 20,
        titlefontsize      = 18,
        guidefontsize      = 16,
        legendfontsize     = 16,
        legendmarkersize   = 28,
    )

    xlabel_text = "Number of representative periods (k)"
    offset = clustering_method == "kmedoids" ? -4.5 : -11
    offset = cross_scenario ? -7 : offset 
    annotate!(gallery[7], -15.0, offset, text(xlabel_text, 16, :center, :top))

    display(gallery)
    add = cross_scenario ? "_cross" : ""
    savefig(gallery, joinpath(output_dir, "gallery_$(clustering_method)$(add)_LOL_broken_axis.pdf"))
end


################

function plot_gallery_regret_byWorstCase(results, clustering_method,  output_dir, ; cross_scenario = False)
    weight_types = [
        ("dirac", :circle), 
        ("convex", :diamond), 
        ("conical_bounded", :square),
        ("conical", :utriangle), 
    ]
    wc_options = [
        ("no_wc", "None"),
        ("global_fixed_wc_p10.0", "Global-fixed"),
        ("global_wc", "Global"),
        ("local_wc", "Local"),
    ]
    colors = [:blue, :red, :green, :purple, :orange]

    subplots = []
    for (i, (wc_label, wc_display)) in enumerate(wc_options)
        is_First = i == 1;
        p = plot(
            title="$(wc_display)", 
            xlabel="Number of representatives (k)", 
            ylabel=  is_First ? "Regret (%)" : "",
            left_margin = is_First ? 15Plots.mm : 0Plots.mm,
            xtickfontsize  = 15,
            ytickfontsize  = 15,
            tickfontfamily = "Times Bold",
            )
        
        for ((wtype, lmarker), color) in zip(weight_types, colors)
            method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue
            plot!(p, df.k, df.regret,
                  label=wtype, marker=lmarker, color=color,
                  linestyle=:solid,
                  ribbon=hasproperty(df, :regret_std) ? df.regret_std : zeros(nrow(df)),
                  fillalpha=0.08)
        end
        push!(subplots, p)
    end
    method_display = clustering_method == "kmedoids" ? "k-medoids" : "k-means"
    gallery = plot(subplots..., layout=(1, 4), size=(2500, 700),
                   plot_title="$method_display: Regret vs number of RPs (k)",
                   titlefontsize=18,
                   plot_titlefontsize=20,
                   guidefontsize=18,      # x/y axis labels
                   legendfontsize=16,     # legend entries
                   bottom_margin=14mm,
                   )

    add = cross_scenario ? "cross_" : ""
    display(gallery)
    savefig(gallery, joinpath(output_dir, "gallery_$(clustering_method)$(add)_regret_byWorstCase.pdf"))
end


function plot_gallery_LOL_byWorstCase(results, clustering_method,  output_dir, lol_ref, ; cross_scenario = False)
    weight_types = [
        ("dirac", :circle), 
        ("convex", :diamond), 
         ("conical_bounded", :square),
        ("conical", :utriangle), 
    ]
    wc_options = [ 
        ("no_wc", "None"),
        ("global_fixed_wc_p10.0", "Global-fixed"),
        ("global_wc", "Global"),
        ("local_wc", "Local")
    ]
    colors = [:blue, :red, :green, :purple, :orange]

    subplots = []
    for (i, (wc_label, wc_display)) in enumerate(wc_options)
        is_First = i == 1;
        p = plot(
            title="$(wc_display)", 
            xlabel="Number of representatives (k)", 
            ylabel=  is_First ? "Loss of Load" : "",
            left_margin = is_First ? 15Plots.mm : 0Plots.mm,
            xtickfontsize  = 15,
            ytickfontsize  = 15,
            tickfontfamily = "Times Bold",
            )
        hline!(p, [lol_ref], linestyle=:dash, color=:black, label="reference")

        for ((wtype, lmarker), color) in zip(weight_types, colors)
            method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue
            plot!(p, df.k, df.lol_reduced,
                  label=wtype, marker=lmarker, 
                  color=color,
                  linestyle=:solid,
                  ribbon=hasproperty(df, :lol_reduced_std) ? df.lol_reduced_std : zeros(nrow(df)),
                  fillalpha=0.08)
        end
        push!(subplots, p)
    end

    method_display = clustering_method == "kmeans" ? "k-means" : "k-medoids"
    gallery = plot(subplots..., layout=(1, 4), size=(2500, 700),
                   plot_title="$method_display: Loss of load vs number of RPs (k)",
                   titlefontsize=18,
                   plot_titlefontsize=20,
                   guidefontsize=18,      # x/y axis labels
                   legendfontsize=14,     # legend entries
                   legend = :topleft,
                   bottom_margin=14mm,
                   )
    add = cross_scenario ? "cross_" : "" 
    display(gallery)
    savefig(gallery, joinpath(output_dir, "gallery_$(clustering_method)$(add)_LOL_byWorstCase.pdf"))
end









#///////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
#Plotting for the global fixed different values 
function plot_gallery_regret_globalFixed_byPercentage(results, clustering_method, output_dir)
    weight_types = ["dirac", "convex", "conical", "conical_bounded"]
    # one line per percentage, distinguished by color
    percentages  = sort(unique(filter(r -> r.worst_case == "global_fixed_wc", results).percentage))
    colors       = palette(:lightrainbow, max(length(percentages), 2))
    markers      = [:circle, :diamond, :square, :utriangle, :pentagon]

    subplots = []
    for wtype in weight_types
        p_bottom = plot(
            title = "$(wtype)",
            xlabel = "Number of representative periods (k)",
            ylabel = "Regret (%)",
            yscale = :log10,
            legend = true,
            grid   = true,
        )
        hline!(p_bottom, [0.1], linestyle=:dash, color=:black, label="reference")

        for (i, pct) in enumerate(percentages)
            #if pct *100 <1 continue end
            percentage = pct*100 # >= 1 ? round(Int, pct*100) : pct*100 
            method_label = "$(clustering_method)_$(wtype)_global_fixed_wc_p$(percentage)_2"
            
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue
            lbl    = "$percentage %"
            color  = colors[i]
            marker = markers[min(i, length(markers))]
            
            #Plot k values equally spaced
            k_unique = sort(unique(df.k))
            xmap = Dict(k => i for (i, k) in enumerate(k_unique))
            xvals = [xmap[k] for k in df.k]

            
            plot!(p_bottom, xvals, df.regret;
                label     = lbl,
                marker    = marker,
                xticks=(1:length(k_unique), string.(k_unique)),
                color     = color,
                linestyle = :solid,
                #ribbon    = hasproperty(df, :regret_std) ? df.regret_std : zeros(nrow(df)),
                fillalpha = 0.08)
            
        end

        # also add global_wc as reference line for comparison
        method_label_global = "$(clustering_method)_$(wtype)_global_wc_2"
        df_global = filter(r -> r.method == method_label_global, results)
        if !isempty(df_global)
            k_unique = sort(unique(df_global.k))
            xmap = Dict(k => i for (i, k) in enumerate(k_unique))
            xvals = [xmap[k] for k in df_global.k]

            plot!(p_bottom, xvals, df_global.regret;
                xticks=(1:length(k_unique), string.(k_unique)),
                label     = "global_wc",
                color     = :black,
                linestyle = :dash,
                marker    = :star5)
        
        end

        combined = plot(p_bottom,
            layout = @layout([a; b]),
            size   = (700, 700),
            margin = 5Plots.mm)
        push!(subplots, combined)
    end

    gallery = plot(subplots...;
        layout              = (2, 2),
        size                = (1600, 1400),
        plot_title          = "$clustering_method: global_fixed Regret by percentage",
        plot_titlefontsize  = 20,
        titlefontsize       = 16,
        guidefontsize       = 14,
        legendfontsize      = 10,
        margin              = 6Plots.mm)
    display(gallery)
    savefig(gallery, joinpath(output_dir,
        "gallery_$(clustering_method)_globalFixed_regret_byPercentage.png"))
end


function plot_gallery_regret_globalFixed_byPercentage_Dirac(results, clustering_method, output_dir)
    percentages = sort(unique(filter(r -> r.worst_case == "global_fixed_wc", results).percentage))
    colors      = palette(:lightrainbow, max(length(percentages), 2))
    markers     = [:circle, :diamond, :square, :utriangle, :pentagon, :hexagon]

    method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"

    p = plot(
        title          = "Regret vs number of representative periods (k) using $method",
        xlabel         = "Number of representative periods (k)",
        ylabel         = "Regret (%)",
        yscale         = :log10,
        yticks         = ([0.01, 0.1, 1, 10, 100, 1000], ["0.01", "0.1", "1", "10", "100", "1000"]),
        ylim           = (0.005, 2000),
        legend         = :topright,
        titlefontsize  = 20,
        legendfontsize = 14,
        guidefontsize  = 18,
        tickfontsize   = 13,
        grid           = true,
        size           = (1200, 700),
        left_margin    = 10Plots.mm,
        bottom_margin  = 8Plots.mm,
        top_margin     = 8Plots.mm,
        right_margin   = 4Plots.mm,
    )

    for (i, pct) in enumerate(percentages)
        percentage   = pct * 100
        method_label = "$(clustering_method)_dirac_global_fixed_wc_p$(percentage)_2"
        df = filter(r -> r.method == method_label, results)
        isempty(df) && continue

        k_unique = sort(unique(df.k))
        xmap     = Dict(k => idx for (idx, k) in enumerate(k_unique))
        xvals    = [xmap[k] for k in df.k]

        regret_clamped = max.(df.regret, 0.005)

        plot!(p, xvals, regret_clamped;
            label     = "$(percentage)%",
            marker    = markers[min(i, length(markers))],
            color     = colors[i],
            linestyle = :solid,
            xticks    = (1:length(k_unique), string.(k_unique)),
            # ribbon    = hasproperty(df, :regret_std) ? max.(df.regret_std, 0.0) : zeros(nrow(df)),
            # fillalpha = 0.08
            )
    end

    method_label_global = "$(clustering_method)_dirac_global_wc_2"
    df_global = filter(r -> r.method == method_label_global, results)
    if !isempty(df_global)
        k_unique = sort(unique(df_global.k))
        xmap     = Dict(k => idx for (idx, k) in enumerate(k_unique))
        xvals    = [xmap[k] for k in df_global.k]
        regret_clamped = max.(df_global.regret, 0.005)
        plot!(p, xvals, regret_clamped;
            label     = "Global (dynamic)",
            color     = :black,
            linestyle = :dash,
            marker    = :star5,
            xticks    = (1:length(k_unique), string.(k_unique)))
    end

    display(p)
    savefig(p, joinpath(output_dir,
        "$(clustering_method)_globalFixed_dirac_regret_byPercentage.pdf"))
end


function plot_gallery_LOL_globalFixed_byPercentage(results, clustering_method, output_dir, lol_ref)
    weight_types = ["dirac", "convex", "conical", "conical_bounded"]
    percentages  = sort(unique(filter(r -> r.worst_case == "global_fixed_wc", results).percentage))
    colors       = palette(:lightrainbow, max(length(percentages), 2))
    markers      = [:circle, :diamond, :square, :utriangle, :pentagon]

    subplots = []
    for wtype in weight_types
        p = plot(title="$(wtype)", xlabel="Number of representative periods (k)", ylabel="Loss of Load")
        hline!(p, [lol_ref], linestyle=:dash, color=:black, label="reference")

        for (i, pct) in enumerate(percentages)
            percentage = pct*100 #>= 1 ? round(Int, pct*100) : pct*100
            method_label = "$(clustering_method)_$(wtype)_global_fixed_wc_p$(percentage)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue
            plot!(p, df.k, df.lol_reduced;
                label     = "$percentage %",
                marker    = markers[min(i, length(markers))],
                color     = colors[i],
                linestyle = :solid,
                ylim = [0,10],
                ribbon    = hasproperty(df, :lol_reduced_std) ? df.lol_reduced_std : zeros(nrow(df)),
                fillalpha = 0.08)
        end

        method_label_global = "$(clustering_method)_$(wtype)_global_wc_2"
        df_global = filter(r -> r.method == method_label_global, results)
        if !isempty(df_global)
            plot!(p, df_global.k, df_global.lol_reduced;
                label     = "global_wc",
                color     = :black,
                linestyle = :dash,
                marker    = :star5)
        end
        push!(subplots, p)
    end

    gallery = plot(subplots...;
        layout             = (2, 2),
        size               = (1500, 1200),
        plot_title         = "$clustering_method: global_fixed LOL by percentage",
        titlefontsize      = 18,
        plot_titlefontsize = 20,
        guidefontsize      = 16,
        legendfontsize     = 11,
        legend             = :topleft,
        left_margin        = 9mm,
        bottom_margin      = 4mm)
    display(gallery)
    savefig(gallery, joinpath(output_dir,
        "gallery_$(clustering_method)_globalFixed_LOL_byPercentage.png"))
end



function plot_gallery_globalFixed_regret_and_LOL(results, clustering_method, output_dir, lol_ref)
    weight_types = ["dirac", "convex", "conical", "conical_bounded"]
    percentages  = sort(unique(filter(r -> r.worst_case == "global_fixed_wc", results).percentage))
    colors       = palette(:lightrainbow, max(length(percentages), 2))
    markers      = [:circle, :diamond, :square, :utriangle, :pentagon]

    subplots = []

    for wtype in weight_types
        # ── Left: Regret ──────────────────────────────────────────────────
        p_regret = plot(
            xlabel    = "Number of representative periods (k)",
            ylabel    = "Regret (%)",
            yscale         = :log10,
            yticks         = ([0.01, 0.1, 1, 10, 100, 1000], ["0.01", "0.1", "1", "10", "100", "1000"]),
            ylim           = (0.005, 2000),
            legend    = false,
            grid      = true,
            left_margin        = 18Plots.mm,
            xtickfontsize  = 16,
            ytickfontsize  = 16,
            tickfontfamily = "Times Bold",
        )
        # hline!(p_regret, [0.1]; linestyle=:dash, color=:black, label="reference")

        for (i, pct) in enumerate(percentages)
            
            percentage   = pct * 100
            method_label = "$(clustering_method)_$(wtype)_global_fixed_wc_p$(percentage)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue

            k_unique = sort(unique(df.k))
            xmap     = Dict(k => idx for (idx, k) in enumerate(k_unique))
            xvals    = [xmap[k] for k in df.k]
            #Avoid log(0)
            regret_clamped = max.(df.regret, 0.005)
            plot!(p_regret, xvals, regret_clamped;
                label     = "$(percentage)%",
                marker    = markers[min(i, length(markers))],
                color     = colors[i],
                linestyle = :solid,
                xticks    = (1:length(k_unique), string.(k_unique)),
                # ribbon    = hasproperty(df, :regret_std) ? df.regret_std : zeros(nrow(df)),
                # fillalpha = 0.08
                )
        end

        method_label_global = "$(clustering_method)_$(wtype)_global_wc_2"
        df_global = filter(r -> r.method == method_label_global, results)
        if !isempty(df_global)
            k_unique = sort(unique(df_global.k))
            xmap     = Dict(k => idx for (idx, k) in enumerate(k_unique))
            xvals    = [xmap[k] for k in df_global.k]
            regret_clamped = max.(df_global.regret, 0.005)
            plot!(p_regret, xvals, regret_clamped;
                label     = "Global worst-case",
                color     = :black,
                linestyle = :dash,
                marker    = :star5,
                xticks    = (1:length(k_unique), string.(k_unique)))
        end

        # ── Right: Loss of Load ───────────────────────────────────────────
        p_lol = plot(
            xlabel    = "Number of representative periods (k)",
            ylabel    = "Loss of Load",
            legend    = :topright,
            grid      = true,
            yscale    = :log10,
            yticks    = ([1, 10, 100, 1000], ["1", "10", "100", "1000"]),
            ylim      = (0.05, 5000),
            left_margin        = 10Plots.mm,
            xtickfontsize  = 16,
            ytickfontsize  = 16,
            tickfontfamily = "Times Bold",
        )
        hline!(p_lol, [lol_ref]; linestyle=:dash, color=:black, label="reference")

        for (i, pct) in enumerate(percentages)
            
            percentage   = pct * 100
            method_label = "$(clustering_method)_$(wtype)_global_fixed_wc_p$(percentage)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue

            k_unique = sort(unique(df.k))
            xmap     = Dict(k => idx for (idx, k) in enumerate(k_unique))
            xvals    = [xmap[k] for k in df.k]
            
            lol_clamped = max.(df.lol_reduced, 0.05)
            plot!(p_lol, xvals, lol_clamped;
                label     = "$(percentage)%",
                marker    = markers[min(i, length(markers))],
                color     = colors[i],
                linestyle = :solid,
                xticks    = (1:length(k_unique), string.(k_unique)),
                # ribbon    = hasproperty(df, :lol_reduced_std) ? df.lol_reduced_std : zeros(nrow(df)),
                # fillalpha = 0.08
                )
        end

        if !isempty(df_global)
            k_unique = sort(unique(df_global.k))
            xmap     = Dict(k => idx for (idx, k) in enumerate(k_unique))
            xvals    = [xmap[k] for k in df_global.k]
            lol_clamped = max.(df_global.lol_reduced, 0.05)
            plot!(p_lol, xvals, lol_clamped;
                label     = "Global worst-case",
                color     = :black,
                linestyle = :dash,
                marker    = :star5,
                xticks    = (1:length(k_unique), string.(k_unique))
                )

        end
        
        push!(subplots, p_regret)
        push!(subplots, p_lol)
    end

    method_display =  clustering_method == "kmedoids" ? "k-medoids" : "k-means"
    gallery = plot(subplots...;
        layout             = (4, 2),
        size               = (2200, 2800),
        plot_title         = "$method_display: Global-Fixed Regret and Loss of Load for different fixed weights",
        plot_titlefontsize = 20,
        titlefontsize      = 18,
        guidefontsize      = 18,
        legendfontsize     = 14,
        markersize = 6,
        markerstrokewidth   = 0.1,
        right_margin       = 4Plots.mm,
        bottom_margin      = 8Plots.mm,
        top_margin         = 8Plots.mm,
        )

    for (i, wtype) in enumerate(weight_types)
        xlabel_text = "$wtype"
        yoffset = i == 1 ? 13220.0 : 13500.0
        annotate!(gallery[i*2], -1.0, yoffset, text(xlabel_text, 18, :center, :top))

    end    
    display(gallery)
    savefig(gallery, joinpath(output_dir,
        "gallery_$(clustering_method)_globalFixed_regret_and_LOL.pdf"))
end



#////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////



#This function is called inside the main loop to plot the representative periods
function plot_representative_periods(clusters, label, wc, output_dir)

    for (group_key, clustering_result) in clusters

        profile_names = sort(unique(clustering_result.profiles.profile_name))
        rep_periods   = sort(unique(clustering_result.profiles.rep_period))
        n_rp          = length(rep_periods)

        colors = palette(:tab10)[1:min(length(profile_names), 10)]
        profile_colors = Dict(pname => colors[i] for (i, pname) in enumerate(profile_names))


        n_wm_cols = size(clustering_result.weight_matrix, 2)
        n_wc      = wc == :none ? 0 : (wc == :local ? (n_wm_cols ÷ 2) : 1)
        wc_start  = n_wm_cols - n_wc + 1


        subplots = []
        for (i, rp) in enumerate(rep_periods)
            df_rp     = filter(r -> r.rep_period == rp, clustering_result.profiles)
            n_wm_cols = size(clustering_result.weight_matrix, 2)
            weight    = round(Int, i <= n_wm_cols ? sum(clustering_result.weight_matrix[:, i]) : 0.0)
            is_wc  = i >= wc_start
            title_str = "RP $rp  (w=$weight days)"

            p = plot(
                title  = title_str,
                xlabel = "Timestep",
                ylabel = "Value",
                background_color_inside = is_wc ? RGB(1.0, 0.9, 0.9) : :white,
                titlefontsize = 10,
                guidefontsize = 8,
            )

            for pname in profile_names
                  
                df_p = filter(r -> r.profile_name == pname, df_rp)
                isempty(df_p) && continue
                sort!(df_p, :timestep)
                plot!(p, df_p.timestep, df_p.value;
                    label     = pname,
                    color     = profile_colors[pname],
                    linewidth = 1.5)
            end
            push!(subplots, p)
        end

        ncols = min(2, n_rp)
        nrows = ceil(Int, n_rp / ncols)

        gallery = plot(
            subplots...;
            layout             = (nrows, ncols),
            size               = (450 * ncols, 350 * nrows),
            plot_title         = "Represtantive Periods' profiles ",
            plot_titlefontsize = 13,
            legendfontsize     = 8,
            legend             = :topleft,
            left_margin        = 6mm,
            bottom_margin      = 6mm,
        )

        display(gallery)
        group_str = join(["$(k)=$(v)" for (k, v) in pairs(group_key)], "_")
        savefig(gallery, joinpath(output_dir, "rp_profiles_$(label)_$(group_str).pdf"))
    end

end



#///////////////////////////////////
function plot_profiles(clusters, original_profiles, wc, output_dir, label)
    original_profiles = transform(original_profiles,
        :timestep => (t -> ceil.(Int, t ./ 24)) => :period
    )
    AVAILABILITY_TECHS = ["wind_onshore", "wind_offshore", "solar", "hydro_inflow"]

    # Summarise original periods into (mean_demand, mean_availability) per period
    function summarise_periods(profiles)
        periods = unique(profiles.period)
        demands      = Float64[]
        availabilities = Float64[]
        for p in sort(periods)
            df_p = filter(r -> r.period == p, profiles)

            demand_rows = filter(r -> r.profile_name == "demand", df_p)
            avail_rows  = filter(r -> r.profile_name in AVAILABILITY_TECHS, df_p)

            isempty(demand_rows) && continue

            push!(demands,       mean(demand_rows.value))
            push!(availabilities, isempty(avail_rows) ? 0.0 : mean(
                combine(groupby(avail_rows, :timestep), :value => sum => :total).total
            ))
        end
        return demands, availabilities
    end

    # Summarise RP profiles — same logic but indexed by rep_period
    function summarise_rp_periods(rp_profiles)
        rep_periods = unique(rp_profiles.rep_period)
        demands      = Float64[]
        availabilities = Float64[]
        for rp in sort(rep_periods)
            df_rp = filter(r -> r.rep_period == rp, rp_profiles)

            demand_rows = filter(r -> r.profile_name == "demand", df_rp)
            avail_rows  = filter(r -> r.profile_name in AVAILABILITY_TECHS, df_rp)

            isempty(demand_rows) && continue

            push!(demands,        mean(demand_rows.value))
            push!(availabilities, isempty(avail_rows) ? 0.0 : mean(
                combine(groupby(avail_rows, :timestep), :value => sum => :total).total
            ))
        end
        return demands, availabilities
    end

    orig_demand, orig_avail = summarise_periods(original_profiles)

    for (group_key, clustering_result) in clusters

        n_cols   = size(clustering_result.weight_matrix, 2)
        n_wc_rps = wc == :none ? 0 : (wc == :local ? (n_cols ÷ 2) : 1)
        wc_start = n_cols - n_wc_rps + 1

        rep_periods = sort(unique(clustering_result.profiles.rep_period))

        regular_rps = rep_periods[1:wc_start - 1]
        wc_rps      = rep_periods[wc_start:end]

        reg_demand, reg_avail = summarise_rp_periods(
            filter(r -> r.rep_period in regular_rps, clustering_result.profiles)
        )
        wc_demand, wc_avail = isempty(wc_rps) ? (Float64[], Float64[]) :
            summarise_rp_periods(
                filter(r -> r.rep_period in wc_rps, clustering_result.profiles)
            )

        p = plot(
            xlabel     = "Mean Demand",
            ylabel     = "Mean Total Availability",
            title      = "Demand vs Availability space: $label",
            titlefontsize = 11,
            guidefontsize = 10,
            legend     = :topright,
        )

        scatter!(p, orig_demand, orig_avail;
            label      = "Original periods",
            color      = :black,
            markersize = 4,
            alpha      = 0.4,
            marker     = :circle)

        scatter!(p, reg_demand, reg_avail;
            label      = "Regular RPs",
            color      = :blue,
            markersize = 8,
            marker     = :diamond)

        if !isempty(wc_demand)
            scatter!(p, wc_demand, wc_avail;
                label      = "Worst-case RPs",
                color      = :red,
                markersize = 8,
                marker     = :star5)
        end

        display(p)
        group_str = join(["$(k)=$(v)" for (k, v) in pairs(group_key)], "_")
        #savefig(p, joinpath(output_dir, "demand_avail_scatter_$(label)_$(group_str).png"))
    end
end

const AVAILABILITY_TECHS = ["wind_onshore", "wind_offshore", "solar", "hydro_inflow"]

function summarise_rp_periods(rp_profiles)
    rep_periods    = sort(unique(rp_profiles.rep_period))
    demands        = Float64[]
    availabilities = Float64[]
    for rp in rep_periods
        df_rp       = filter(r -> r.rep_period == rp, rp_profiles)
        demand_rows = filter(r -> r.profile_name == "demand", df_rp)
        avail_rows  = filter(r -> r.profile_name in AVAILABILITY_TECHS, df_rp)
        isempty(demand_rows) && continue
        push!(demands, mean(demand_rows.value))
        push!(availabilities, isempty(avail_rows) ? 0.0 : mean(
            combine(groupby(avail_rows, :timestep), :value => sum => :total).total
        ))
    end
    return demands, availabilities
end

function plot_profiles_combined(all_reg_demand, all_reg_avail, all_wc_demand, all_wc_avail,
                                original_profiles, label; period_duration=24)

    # Split original profiles into periods
    original_profiles = transform(original_profiles,
        :timestep => (t -> ceil.(Int, t ./ period_duration)) => :period
    )

    orig_demand = Float64[]
    orig_avail  = Float64[]
    for p in sort(unique(original_profiles.period))
        df_p        = filter(r -> r.period == p, original_profiles)
        demand_rows = filter(r -> r.profile_name == "demand", df_p)
        avail_rows  = filter(r -> r.profile_name in AVAILABILITY_TECHS, df_p)
        isempty(demand_rows) && continue
        push!(orig_demand, mean(demand_rows.value))
        push!(orig_avail,  isempty(avail_rows) ? 0.0 : mean(
            combine(groupby(avail_rows, :timestep), :value => sum => :total).total
        ))
    end

    # shape and color per wc type for regular RPs
    wc_style = Dict(
        :none         => (:utriangle,   :blue,   "Normal RPs (None)", ""),
        :global       => (:diamond,  :blue,   "Normal RPs (Global)", "Worst-case RPs (Global)"),
        :local        => (:square,   :blue,   "Normal RPs (Local)", "Worst-case RPs (Local)"),
    )

    p = plot(
        xlabel        = "Mean Demand",
        ylabel        = "Mean Total Availability",
        title         = "Mean Demand vs Availability over all timesteps for k-means (k=6)",
        titlefontsize = 11,
        guidefontsize = 10,
        legend        = :topright,
    )

    scatter!(p, orig_demand, orig_avail;
        label      = "Original periods",
        color      = :black,
        markersize = 4,
        alpha      = 0.35,
        marker     = :circle)

    for (wc, reg_d) in all_reg_demand
        reg_a              = all_reg_avail[wc]
        marker, color, lbl, _ = wc_style[wc]
        isempty(reg_d) && continue
        scatter!(p, reg_d, reg_a;
            label      = lbl,
            color      = color,
            markersize = 5,
            alpha      = 0.9,
            marker     = marker)
    end

    for (wc, wc_d) in all_wc_demand
        wc_a = all_wc_avail[wc]
        isempty(wc_d) && continue
        _, _, _, lbl = wc_style[wc]
        scatter!(p, wc_d, wc_a;
            label      = "$(lbl)",
            color      = :red,
            markersize = 7,
            alpha      = 0.9,
            marker     = wc_style[wc][1])
    end
    output_dir = "my-awesome-energy-system/tutorial-9/result";
    display(p)
    #savefig(p, joinpath(output_dir, "profiles_avail_demand.pdf"))

end


#////////////////////////////////////////////////////////////////////////////////////////////////////////////



function plot_avgWCweight_vs_k(results, wc::Symbol, output_dir) #used
    weight_types = [
        ("dirac",           :circle,    colorant"#1f77b4"),
        ("convex",          :diamond,   colorant"#2ca02c"),
        ("conical_bounded", :square,    colorant"#d62728"),
        ("conical",         :utriangle, colorant"#9467bd"),   
    ]

    clustering_methods = ["kmedoids", "kmeans"]
    
    wc_suffix = wc == :local ? "local_wc" : "global_wc"
    wc_display = wc == :local ? "Local" : "Global"

    subplots = []
    y_min = 0.0
    y_max= 11.0
    
    for (idx, clustering_method) in enumerate(clustering_methods)
        is_First = idx == 1
        is_Last = !is_First
        method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"
        p = plot(
            title = method,
            titlefontsize = 14,
            ylabel         = is_First ? "Average worst-case RP weight (days)" : "",
            #yformatter     = is_first ? :auto : _ -> "",
            legend         = is_Last ? :topright : false,
            grid           = true,
            ylim = (y_min, y_max), yticks = y_min:1:y_max,
            top_margin     = 8Plots.mm,
            bottom_margin  = 4Plots.mm,
            left_margin    = is_First ? 6Plots.mm : 0Plots.mm,
        )
        for (wtype, marker, color) in weight_types
            method_label = "$(clustering_method)_$(wtype)_$(wc_suffix)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue
            sort!(df, :k)
            plot!(p, df.k, df.avg_weight_wc;
                label      = wtype,
                marker     = marker,
                color      = color,
                linewidth  = 2,
                markersize = 7)
        end
        push!(subplots, p)
    end 
    # Compute shared y range across both subplots
    all_vals = Float64[]
    for clustering_method in clustering_methods
        for (wtype, _, _) in weight_types
            method_label = "$(clustering_method)_$(wtype)_$(wc_suffix)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) || append!(all_vals, df.avg_weight_wc)
        end
    end
    y_min = floor(minimum(all_vals) * 0.95)
    y_max = ceil(maximum(all_vals) * 1.05)
    for p in subplots
        plot!(p, ylim = (y_min, y_max))
    end

    gallery = plot(subplots...;
                   layout             = (1, 2),
                   size               = (1000, 700),
                   plot_title         = "Average worst-case RP weight vs number of RPs (k) ($wc_display)",
                   plot_titlefontsize = 14,
                   guidefontsize      = 13,
                   legendfontsize     = 12,
                   legendmarkersize   = 180,
                   )

    display(gallery)
    savefig(gallery, joinpath(output_dir, "avgWCweight_vs_k_$(wc_suffix).png"))
end



function plot_maxWCweight_vs_k(results, wc::Symbol, output_dir) #used
    weight_types = [
        ("dirac",           :circle,    colorant"#1f77b4"),
        ("convex",          :diamond,   colorant"#d62728"),
        ("conical_bounded", :square,    colorant"#2ca02c"),
        ("conical",         :utriangle, colorant"#9467bd"),   
    ]

    clustering_methods = ["kmedoids", "kmeans"]
    
    wc_suffix = wc == :local ? "local_wc" : "global_wc"
    wc_display = wc == :local ? "Local" : "Global"

    subplots = []
    y_min = 0.0
    y_max= 11.0
    
    for (idx, clustering_method) in enumerate(clustering_methods)
        is_First = idx == 1
        is_Last = !is_First
        method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"
        p = plot(
            title = method,
            titlefontsize = 14,
            ylabel         = is_First ? "Worst-case RP weight (days)" : "",
            #yformatter     = is_first ? :auto : _ -> "",
            legend         = is_Last ? :topright : false,
            grid       = true,
            top_margin     = 8Plots.mm,
            bottom_margin  = 8Plots.mm,
            left_margin  = is_First ? 6Plots.mm : 0Plots.mm,
            ylim = (y_min, y_max), yticks = y_min:1:y_max,
            xtickfontsize    = 13,
            ytickfontsize    = 13,
            tickfontfamily   = "Times Bold",
            
        )
        for (wtype, marker, color) in weight_types
            method_label = "$(clustering_method)_$(wtype)_$(wc_suffix)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) && continue
            sort!(df, :k)
            plot!(p, df.k, df.max_weight_wc;
                label      = wtype,
                marker     = marker,
                color      = color,
                linewidth  = 2,
                markersize = 7)
        end
        push!(subplots, p)
    end 
    # Compute shared y range across both subplots
    all_vals = Float64[]
    for clustering_method in clustering_methods
        for (wtype, _, _) in weight_types
            method_label = "$(clustering_method)_$(wtype)_$(wc_suffix)_2"
            df = filter(r -> r.method == method_label, results)
            isempty(df) || append!(all_vals, df.max_weight_wc)
        end
    end
    y_min = floor(minimum(all_vals) * 0.95)
    y_max = ceil(maximum(all_vals) * 1.05)
    for p in subplots
        plot!(p, ylim = (y_min, y_max))
    end

    gallery = plot(subplots...;
                   layout             = (1, 2),
                   size               = (1000, 700),
                   plot_title         = "Worst-case RP weight vs number of RPs (k) ($wc_display)",
                   plot_titlefontsize = 14,
                   guidefontsize      = 14,
                   legendfontsize     = 12,
                   legendmarkersize   = 180,
                   )

    xlabel_text = "Number of representative periods (k)"

    annotate!(gallery[2], -20, -0.65, text(xlabel_text, 14, :center, :top))               
    display(gallery)
    savefig(gallery, joinpath(output_dir, "maxWCweight_vs_k_$(wc_suffix).pdf"))
end



function plot_avg_weights_vs_k(results, clustering_method, wc::Symbol, output_dir)
    weight_types = [
        ("dirac",           :circle,    colorant"#1f77b4"),
        ("convex",          :diamond,   colorant"#d62728"),
        ("conical_bounded", :utriangle, colorant"#2ca02c"),
        ("conical",         :square,    colorant"#9467bd"),
    ]
    wc_suffix = wc == :local ? "local_wc" : "global_wc"
    method_display = clustering_method == :kmedoids ? "k-medoids" : "k-means" 
    p_normal = plot(
        title      = "$method_display ($wc_suffix): Average mormal RP weight vs k",
        xlabel     = "Number of representative periods (k)",
        ylabel     = "Average normal RP weight (days)",
        legend     = :topright,
        grid       = true,
    )
    p_wc = plot(
        title      = "$method_display ($wc_suffix): Average worst-case weight vs k",
        xlabel     = "Number of representative periods (k)",
        ylabel     = "Average worst-case weight (days)",
        legend     = :topright,
        grid       = true,
    )

    for (wtype, marker, color) in weight_types
        method_label = "$(clustering_method)_$(wtype)_$(wc_suffix)_2"
        df = filter(r -> r.method == method_label, results)
        isempty(df) && continue
        sort!(df, :k)

        plot!(p_normal, df.k, df.avg_weight_normal;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)

        plot!(p_wc, df.k, df.avg_weight_wc;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
    end

    combined = plot(p_normal, p_wc;
        layout             = (1, 2),
        size               = (1400, 600),
        plot_title         = "$method_display: RP weights vs k ($wc_suffix)",
        plot_titlefontsize = 18,
        titlefontsize      = 14,
        guidefontsize      = 12,
        legendfontsize     = 10,
        margin             = 6Plots.mm)
    display(combined)
    savefig(combined, joinpath(output_dir,
        "avg_weights_vs_k_$(clustering_method)_$(wc_suffix).png"))
end


function plot_avg_local_wc_distance_vs_k(results, output_dir)
    clustering_methods = [
        ("kmedoids", :circle,  colorant"#1f77b4"),
        ("kmeans",   :diamond, colorant"#d62728"),
    ]

    p = plot(
        title      = "Average distance (local worst-case to centroid) vs k",
        xlabel     = "Number of representative periods (k)",
        ylabel     = "Average distance (feature space)",
        legend     = :topright,
        grid       = true,
    )

    for (clustering_method, marker, color) in clustering_methods
        method_label = "$(clustering_method)_dirac_local_wc_2"
        df = filter(r -> r.method == method_label, results)
        isempty(df) && continue
        sort!(df, :k)
        plot!(p, df.k, df.avg_local_wc_dist;
            label      = clustering_method,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
    end

    display(p)
    savefig(p, joinpath(output_dir, "avg_localWC_distance_vs_k.png"))
end














############################################################################################
function plot_investment_decisions(results_agg, ref_decisions, ref_inv_cost, output_dir;
                                   k_select=10,
                                   clustering_method="kmedoids",
                                   weight_type="dirac")

    # Filter for the specific k, method, weight type and global_fixed_wc
    df = filter(r -> r.k == k_select &&
                     startswith(r.method, "$(clustering_method)_$(weight_type)_global_fixed_wc") &&
                     r.worst_case == "global_fixed_wc", results_agg)

    # Sort by percentage
    sort!(df, :percentage)

    percentages   = df.percentage
    pct_labels    = String[string(p * 100) * "%" for p in percentages]
    push!(pct_labels, "Reference")
    


    assets        = ["ccgt", "solar", "ocgt", "wind", "wind_offshore", "battery", "electrolizer"]
    asset_cols    = [:inv_ccgt, :inv_solar, :inv_ocgt, :inv_wind, :inv_wind_offshore, :inv_battery, :inv_electrolizer]
    asset_labels  = ["CCGT", "Solar", "OCGT", "Wind", "Wind Offshore", "Battery", "Electrolyzer"]
    ref_vals      = [ref_decisions.ccgt, ref_decisions.solar, ref_decisions.ocgt,
                     ref_decisions.wind, ref_decisions.wind_offshore,
                     ref_decisions.battery, ref_decisions.electrolizer]

    n_pct    = length(percentages)
    n_bars   = n_pct + 1          # percentages + reference
    n_assets = length(assets)
    n_groups = n_assets + 1       # assets + total cost group

    # Color palette: one color per percentage + reference in gray
    colors = palette(:tab10, n_pct)
    ref_color = :gray40

    # Build bar positions
    group_width = n_bars + 1.5    # bars per group + gap
    bar_width   = 0.7

    fig = plot(
        size=(1400, 600),
        layout=@layout([a{0.75w} b{0.25w}]),
        margin=10mm,
        bottom_margin=15mm,
    )

    # ── Left panel: asset investments ──────────────────────────────────────
    xtick_pos    = Float64[]
    xtick_labels = String[]

    for (gi, (col, asset_label, ref_val)) in enumerate(zip(asset_cols, asset_labels, ref_vals))
        group_center = (gi - 1) * group_width + n_bars / 2.0

        for (bi, (pct_val, color)) in enumerate(zip(percentages, colors))
            x = (gi - 1) * group_width + bi
            row = filter(r -> isapprox(r.percentage, pct_val; rtol=1e-6), df)
            y = row[1, col]
            bar!(fig[1], [x], [y];
                bar_width=bar_width,
                color=color,
                label=(gi == 1 ? pct_labels[bi] : ""),
                legend=:topright,
                alpha=0.85,
            )
        end

        # Reference bar
        x_ref = (gi - 1) * group_width + n_pct + 1
        bar!(fig[1], [x_ref], [ref_val];
            bar_width=bar_width,
            color=ref_color,
            label=(gi == 1 ? "Reference" : ""),
            alpha=0.85,
        )

        push!(xtick_pos, group_center)
        push!(xtick_labels, asset_label)
    end

    plot!(fig[1];
        xticks=(xtick_pos, xtick_labels),
        xlabel="Technology",
        ylabel="Units invested",
        title="Investment decisions at k=$k_select ($(clustering_method) $(weight_type))",
        xrotation=30,
        grid=:y,
        framestyle=:box,
        legend=:outertopright,
    )

    # Reference horizontal lines per asset
    for (gi, (col, ref_val)) in enumerate(zip(asset_cols, ref_vals))
        x_start = (gi - 1) * group_width + 0.5
        x_end   = (gi - 1) * group_width + n_bars + 0.5
        plot!(fig[1], [x_start, x_end], [ref_val, ref_val];
            color=ref_color, linestyle=:dash, linewidth=1.5, label="")
    end

    # ── Right panel: total investment cost ─────────────────────────────────
    total_costs = df.inv_cost_reduced
    x_positions = collect(1:n_pct)

    bar!(fig[2], x_positions, total_costs;
        bar_width=bar_width,
        color=[colors[i] for i in 1:n_pct],
        label="",
        alpha=0.85,
    )

    # Reference bar
    bar!(fig[2], [n_pct + 1.5], [ref_inv_cost];
        bar_width=bar_width,
        color=ref_color,
        label="",
        alpha=0.85,
    )

    # Reference dashed line
    plot!(fig[2], [0.5, n_pct + 2], [ref_inv_cost, ref_inv_cost];
        color=ref_color, linestyle=:dash, linewidth=1.5, label="")

    all_labels = copy(pct_labels)
    xtick_positions = vcat(x_positions, [n_pct + 1.5])
    plot!(fig[2];
        xticks=(xtick_positions, all_labels),
        xlabel="Worst-case fixed weight %",
        ylabel="Total inv. cost (M€)",
        title="Total investment cost",
        xrotation=30,
        grid=:y,
        framestyle=:box,
        legend=false,
    )

    fname = joinpath(output_dir, "investment_decisions_$(clustering_method)_$(weight_type)_k$(k_select).png")
    savefig(fig, fname)
    display(fig)
    
end



function plot_totalWeight_Local(results_agg, clustering_method, output_dir)
    weight_types = [
        ("dirac",           :circle,    colorant"#1f77b4"),
        ("convex",          :diamond,   colorant"#d62728"),
        ("conical_bounded", :square,    colorant"#2ca02c"),
        ("conical",         :utriangle, colorant"#9467bd"),
    ]

    method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"

    p_normal = plot(
        title          = "Total normal RP weight ($method, Local)",
        titlefontsize  = 14,
        xlabel         = "Number of representative periods (k)",
        ylabel         = "Total normal RP weight (days)",
        legend         = :topleft,
        grid           = true,
        left_margin    = 8Plots.mm,
        bottom_margin  = 8Plots.mm,
        xtickfontsize  = 13,
        ytickfontsize  = 13,
        tickfontfamily = "Times Bold",
    )

    p_wc = plot(
        title          = "Total worst-case RP weight ($method, Local)",
        titlefontsize  = 14,
        xlabel         = "Number of representative periods (k)",
        ylabel         = "Total worst-case RP weight (days)",
        legend         = false,
        grid           = true,
        left_margin    = 8Plots.mm,
        bottom_margin  = 8Plots.mm,
        xtickfontsize  = 13,
        ytickfontsize  = 13,
        tickfontfamily = "Times Bold",
    )

    for (wtype, marker, color) in weight_types
        method_label = "$(clustering_method)_$(wtype)_local_wc_2"
        df = filter(r -> r.method == method_label, results_agg)
        isempty(df) && continue
        sort!(df, :k)
        total_normal = df.avg_weight_normal .* (df.k ./ 2)
        total_wc     = df.avg_weight_wc     .* (df.k ./ 2)
        plot!(p_normal, df.k, total_normal;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
        plot!(p_wc, df.k, total_wc;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
    end

    combined = plot(p_normal, p_wc;
        layout      = (1, 2),
        size        = (1400, 600),
    )
    display(combined)
    savefig(combined, joinpath(output_dir, "totalWeight_local_$(clustering_method).pdf"))
end



function plot_totalWeight_globalFixed(results_agg, clustering_method, output_dir)
    weight_types = [
        ("dirac",           :circle,    colorant"#1f77b4"),
        ("convex",          :diamond,   colorant"#d62728"),
        ("conical_bounded", :square,    colorant"#2ca02c"),
        ("conical",         :utriangle, colorant"#9467bd"),
    ]

    method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"

    p_normal = plot(
        title          = "Total normal RP weight ($method, global-fixed)",
        titlefontsize  = 14,
        xlabel         = "Number of representative periods (k)",
        ylabel         = "Total normal RP weight (days)",
        legend         = :topleft,
        grid           = true,
        left_margin    = 8Plots.mm,
        bottom_margin  = 8Plots.mm,
        xtickfontsize  = 13,
        ytickfontsize  = 13,
        tickfontfamily = "Times Bold",
    )

    p_wc = plot(
        title          = "Total worst-case RP weight ($method, global-fixed)",
        titlefontsize  = 14,
        xlabel         = "Number of representative periods (k)",
        ylabel         = "Total worst-case RP weight (days)",
        legend         = false,
        grid           = true,
        left_margin    = 8Plots.mm,
        bottom_margin  = 8Plots.mm,
        xtickfontsize  = 13,
        ytickfontsize  = 13,
        tickfontfamily = "Times Bold",
    )

    for (wtype, marker, color) in weight_types
        method_label = "$(clustering_method)_$(wtype)_global_fixed_wc_p10.0_2"
        df = filter(r -> r.method == method_label, results_agg)
        isempty(df) && continue
        sort!(df, :k)
        total_normal = df.avg_weight_normal .* (df.k .-1)
        total_wc     = df.avg_weight_wc    
        plot!(p_normal, df.k, total_normal;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
        plot!(p_wc, df.k, total_wc;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
    end

    combined = plot(p_normal, p_wc;
        layout      = (1, 2),
        size        = (1400, 600),
    )
    display(combined)
    savefig(combined, joinpath(output_dir, "totalWeight_global_fixed_$(clustering_method).pdf"))
end


function plot_totalWeight_global(results_agg, clustering_method, output_dir)
    weight_types = [
        ("dirac",           :circle,    colorant"#1f77b4"),
        ("convex",          :diamond,   colorant"#d62728"),
        ("conical_bounded", :square,    colorant"#2ca02c"),
        ("conical",         :utriangle, colorant"#9467bd"),
    ]

    method = clustering_method == "kmedoids" ? "k-medoids" : "k-means"

    p_normal = plot(
        title          = "Total normal RP weight ($method, Global)",
        titlefontsize  = 14,
        xlabel         = "Number of representative periods (k)",
        ylabel         = "Total normal RP weight (days)",
        legend         = :topleft,
        grid           = true,
        left_margin    = 8Plots.mm,
        bottom_margin  = 8Plots.mm,
        xtickfontsize  = 13,
        ytickfontsize  = 13,
        tickfontfamily = "Times Bold",
    )

    p_wc = plot(
        title          = "Total worst-case RP weight ($method, Global)",
        titlefontsize  = 14,
        xlabel         = "Number of representative periods (k)",
        ylabel         = "Total worst-case RP weight (days)",
        legend         = false,
        grid           = true,
        left_margin    = 8Plots.mm,
        bottom_margin  = 8Plots.mm,
        xtickfontsize  = 13,
        ytickfontsize  = 13,
        tickfontfamily = "Times Bold",
    )

    for (wtype, marker, color) in weight_types
        method_label = "$(clustering_method)_$(wtype)_global_wc_2"
        df = filter(r -> r.method == method_label, results_agg)
        isempty(df) && continue
        sort!(df, :k)
        total_normal = df.avg_weight_normal .* (df.k .- 1)
        total_wc     = df.avg_weight_wc     
        plot!(p_normal, df.k, total_normal;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
        plot!(p_wc, df.k, total_wc;
            label      = wtype,
            marker     = marker,
            color      = color,
            linewidth  = 2,
            markersize = 7)
    end

    combined = plot(p_normal, p_wc;
        layout      = (1, 2),
        size        = (1400, 600),
    )
    display(combined)
    savefig(combined, joinpath(output_dir, "totalWeight_global_$(clustering_method).pdf"))
end



















function plot_gallery_regret_globalLocal_byClusteringMethod(results, output_dir; cross_scenario=false)
    weight_types = [
        ("dirac",           :circle,    "dirac"),
        ("convex",          :diamond,   "convex"),
        ("conical_bounded", :square,    "conical_bounded"),
        ("conical",         :utriangle, "conical"),
    ]
    wc_options = [
        ("global_wc", "Global"),
        ("local_wc",  "Local"),
    ]
    colors = [:blue, :red, :green, :purple]

    panels = []  # 4 panels: kmedoids-Global, kmedoids-Local, kmeans-Global, kmeans-Local

    for (clustering_method, method_display) in [ ("kmeans", "k-means"), ("kmedoids", "k-medoids")]
        for (wc_label, wc_display) in wc_options
            is_first = clustering_method == "kmeans" && wc_label == "global_wc"

            p = plot(
                title         = "$wc_display ($method_display)",
                xlabel        = "",
                ylabel        = is_first ? "Regret (%)" : "",
                legend        = (clustering_method == "kmedoids" && wc_label == "local_wc") ? :topright : false,
                legendmarkersize = 18,
                titlefontsize = 16,
                grid          = true,
                left_margin   = is_first ? 17Plots.mm : 0Plots.mm,
                bottom_margin = 13Plots.mm,
                xtickfontsize = 18,
                ytickfontsize = 18,
                tickfontfamily = "Times Bold",
            )

            for ((wtype, marker, wlabel), color) in zip(weight_types, colors)
                method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
                df = filter(r -> r.method == method_label, results)
                isempty(df) && continue

                plot!(p, df.k, df.regret;
                    label     = wlabel,
                    marker    = marker,
                    color     = color,
                    linestyle = :solid,
                    ribbon    = hasproperty(df, :regret_std) ? df.regret_std : zeros(nrow(df)),
                    fillalpha = 0.17)
            end
            push!(panels, p)
        end
    end

    add = cross_scenario ? "_cross" : ""
    gallery = plot(panels...;
        layout             = (1, 4),
        size               = (2500, 1000),
        plot_title         = "Regret vs number of RPs (k)",
        plot_titlefontsize = 28,
        titlefontsize      = 24,
        guidefontsize      = 25,
        legendfontsize     = 20,
        legendmarkersize         = 12, 
        right_margin       = 0Plots.mm,
        top_margin         = 4Plots.mm,
        bottom_margin      = 15Plots.mm,
    )

    xlabel_text = "Number of representative periods (k)"
    annotate!(gallery[3], -24.0, -0.92, text(xlabel_text, 24, :center, :top))

    display(gallery)
    savefig(gallery, joinpath(output_dir, "gallery_regret_globalLocal_byMethod$(add).png"))
end


function plot_gallery_LOL_globalLocal_byClusteringMethod(results, output_dir, lol_ref; cross_scenario=false)
    weight_types = [
        ("dirac",           :circle,    "dirac"),
        ("convex",          :diamond,   "convex"),
        ("conical_bounded", :square,    "conical_bounded"),
        ("conical",         :utriangle, "conical"),
    ]
    wc_options = [
        ("global_wc", "Global"),
        ("local_wc",  "Local"),
    ]
    colors = [:blue, :red, :green, :purple]

    panels = []

    for (clustering_method, method_display) in [ ("kmeans", "k-means"), ("kmedoids", "k-medoids")]
        for (wc_label, wc_display) in wc_options
            is_first = clustering_method == "kmeans" && wc_label == "global_wc"

            p = plot(
                title         = "$wc_display ($method_display)",
                xlabel        = "",
                ylabel        = is_first ? "Loss of Load" : "",
                legend        = (clustering_method == "kmedoids" && wc_label == "local_wc") ? :topright : false,
                legendmarkersize = 18,
                titlefontsize = 16,
                grid          = true,
                left_margin   = is_first ? 17Plots.mm : 0Plots.mm,
                bottom_margin = 13Plots.mm,
                xtickfontsize = 18,
                ytickfontsize = 18,
                tickfontfamily = "Times Bold",
            )
            hline!(p, [lol_ref], linestyle=:dash, color=:black, label="reference")

            for ((wtype, marker, wlabel), color) in zip(weight_types, colors)
                method_label = "$(clustering_method)_$(wtype)_$(wc_label)_2"
                df = filter(r -> r.method == method_label, results)
                isempty(df) && continue

                plot!(p, df.k, df.lol_reduced;
                    label     = wlabel,
                    marker    = marker,
                    color     = color,
                    linestyle = :solid,
                    ribbon    = hasproperty(df, :lol_reduced_std) ? df.lol_reduced_std : zeros(nrow(df)),
                    fillalpha = 0.12)
            end
            push!(panels, p)
        end
    end

    add = cross_scenario ? "_cross" : ""
    gallery = plot(panels...;
        layout             = (1, 4),
        size               = (2500, 1000),
        plot_title         = "Loss of Load vs number of RPs (k)",
        plot_titlefontsize = 28,
        titlefontsize      = 24,
        guidefontsize      = 25,
        legendfontsize     = 18,
        
        right_margin       = 0Plots.mm,
        top_margin         = 4Plots.mm,
        bottom_margin      = 15Plots.mm,
    )

    xlabel_text = "Number of representative periods (k)"
    annotate!(gallery[3], -24.0, -2.35, text(xlabel_text, 24, :center, :top))
    display(gallery)
    savefig(gallery, joinpath(output_dir, "gallery_LOL_globalLocal_byMethod$(add).png"))
end