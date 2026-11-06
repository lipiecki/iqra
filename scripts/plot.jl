# Generate result figures with `julia --project=. scripts/plot.jl {3|4|5|6|7}`.
# The argument matches the figure number in the paper.
using PostForecasts, TestForecasts, Plots, Statistics, JLD2, Measures
include(joinpath(@__DIR__, "..", "src", "results.jl"))
include(joinpath(@__DIR__, "..", "src", "strategy.jl"))

const FIGURES = joinpath(@__DIR__, "..", "figures")
mkpath(FIGURES)

function gw(model)
    panels = []
    for market in ["DE", "FR"]
        results = loadpanel(model, market, 25)
        wins = zeros(Int, length(METHODS), length(METHODS))
        for year in 2020:2025
            obs, forecasts = arrays(results, year*10000+101, year*10000+1231)
            for i in eachindex(METHODS), j in eachindex(METHODS)
                if i == j
                    wins[i, j] = -1
                    continue
                end
                p = giacominiwhite(obs, forecasts[:, :, :, j], forecasts[:, :, :, i]; loss=(y, x)->TestForecasts.crps(y, x, 99))
                wins[i, j] += p < 0.01
            end
        end
        colormap = cgrad(vcat([:white, :black], cgrad(:greens, 6, categorical=true)[:]), categorical=true)
        p = heatmap(wins, xticks=(eachindex(METHODS), LABELS), yticks=(eachindex(METHODS), LABELS), 
            c=colormap, clims=(-1, 6), grid=false, framestyle=:box, tickdirection=:out, colorbar=false, size=(650, 600))
        annotate!(p, [(j, i, text(Int(wins[i, j]), 10 ,:black)) for i in eachindex(METHODS) for j in eachindex(METHODS) if wins[i, j] > 0])
        push!(panels, p)
    end
    file = model == "narx" ? "narx-gw.png" : "xgb-gw.png"
    savefig(plot(panels...; layout=(1, 2), size=(1300, 600), dpi=300, bottom_margin=5mm, left_margin=5mm), joinpath(FIGURES, file))
end

function trading_plot(model)
    colors = cgrad(:Blues, 7, categorical=true)[end-1:-1:end-3]
    thresholds = [1/3, 2/3, 1.0]
    profits, avoidance = zeros(3, length(METHODS)), zeros(3, length(METHODS))
    baseline = 0.0
    for (i, method) in enumerate(METHODS), (j, threshold) in enumerate(thresholds)
        profit, trades, baseprofit, basetrades, avoided = strategy(method, model, "DE", 25, threshold; efficiency=0.9, cost=100.0)
        profits[j, i], avoidance[j, i] = profit/trades, 100 * avoided
        method == :cp && (baseline = baseprofit/basetrades)
    end
    x = repeat(1:length(METHODS), inner=3) + repeat([-0.3, 0.0, 0.3], length(METHODS))
    p1 = bar(x, vec(profits); color=repeat(colors, length(METHODS)), bar_width=0.25, lw=0,
        label=false, ylabel="Profit per trade (EUR)", ylims = (35, 80), yticks = 35:5:80, legend_columns=3, legend=:topleft)
    hline!(p1, [baseline]; color=:black, linestyle=:dash, label=false)
    p2 = bar(x, vec(avoidance); color=repeat(colors, length(METHODS)), bar_width=0.25, lw=0,
        label=false, ylabel="Loss avoidance (%)", ylims = (0, 100), yticks = 0:20:100, legend=false)
    for p in [p1, p2]
        plot!(p; xticks=(1:length(LABELS), LABELS), xrotation=45, framestyle=:box)
    end
    for (j, label) in enumerate(["π = 1/3", "π = 2/3", "π = 1"])
        bar!(p1, [], []; color=colors[j], label=label, lw=0)
    end
    savefig(plot(p1, p2; layout=(2, 1), size=(800, 650), dpi=300, left_margin=4mm, bottom_margin=5mm), joinpath(FIGURES, "strategy_$model.png"))
end

function weights_plot()
    plots, shares = [], Float64[]
    for (method, label) in zip([:lqra, :iqra, :isqra], ["LQRA", "iQRA", "iSQRA"])
        counts, total = zeros(26, 99), 0
        for h in 1:24
            path = joinpath(@__DIR__, "..", "outputs", "weights", "$method-narx-DE-r25-h$h-weights.jld2")
            weights = load(path, "weights")
            counts .+= dropdims(sum(abs.(weights) .> 1e-8, dims=1), dims=1)
            total += size(weights, 1)
        end
        push!(shares, sum(counts[1:25, :]) / (total*99*25))
        push!(plots, heatmap((counts[1:25, :] ./ total)'; title=label, xticks=[1, 13, 25],
            yticks=([1, 25, 50, 75, 99], ["1%", "25%", "50%", "75%", "99%"]),
            clims=(0, 0.7), c=:Blues, framestyle=:box, colorbar=label == "iSQRA"))
    end
    println("Selected-variable shares: ", join(["$(label)=$(round(100 * share, digits=1))%" for (label, share) in zip(["LQRA", "iQRA", "iSQRA"], shares)], ", "))
    savefig(plot(plots...; layout=(1, 3), size=(1500, 600), dpi=500, left_margin=3mm, bottom_margin=3mm), joinpath(FIGURES, "weights.png"))
end

length(ARGS) == 1 || error("usage: julia --project=. scripts/plot.jl {3|4|5|6|7}")
if ARGS[1] == "3"; gw("narx")
elseif ARGS[1] == "4"; trading_plot("narx")
elseif ARGS[1] == "5"; weights_plot()
elseif ARGS[1] == "6"; gw("xgb")
elseif ARGS[1] == "7"; trading_plot("xgb")
else error("figure must be 3, 4, 5, 6, or 7")
end
