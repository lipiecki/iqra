# Print the numerical results from the paper:
# julia --project=. scripts/eval.jl [crps|ensemble|mcs|intervals|mae|trading|timing]
using PostForecasts, TestForecasts, Statistics, JLD2, Random
include(joinpath(@__DIR__, "..", "src", "results.jl"))
include(joinpath(@__DIR__, "..", "src", "strategy.jl"))

fmt(x; digits=3) = string(round(x, digits=digits))

function yearly_crps(model)
    for market in ["DE", "FR"]
        results = loadpanel(model, market, 25)
        rows = [[LABELS[i]; [fmt(mean(mean(PostForecasts.pinball(results[METHODS[i]][h](year*10000+101, year*10000+1231)) for h in 1:24))) for year in 2020:2025]] for i in eachindex(METHODS)]
        printtable("CRPS: $(uppercase(model)), $market, 25 members", ["Method"; string.(2020:2025)], rows)
    end
end

function ensemble_crps(model)
    for market in ["DE", "FR"]
        panels = Dict(size => loadpanel(model, market, size) for size in [10, 25, 50])
        rows = [[LABELS[i]; [fmt(mean(mean(PostForecasts.pinball(panels[size][METHODS[i]][h]) for h in 1:24))) for size in [10, 25, 50]]] for i in eachindex(METHODS)]
        printtable("CRPS by ensemble size: $(uppercase(model)), $market", ["Method", "10", "25", "50"], rows)
    end
end

function intervals(model)
    bounds = [(1, 99), (2, 98), (5, 95), (10, 90)]
    for market in ["DE", "FR"]
        results = loadpanel(model, market, 25)
        ace, pips = Vector{Vector{String}}(), Vector{Vector{String}}()
        for (i, method) in enumerate(METHODS)
            push!(ace, [LABELS[i]; [fmt((u-l) - 100 * mean(mean((q.pred[:, l] .< q.obs) .& (q.obs .< q.pred[:, u])) for q in results[method])) for (l, u) in bounds]])
            push!(pips, [LABELS[i]; [fmt(mean(mean(PostForecasts.pinball(q)[[l, u]]) for q in results[method])) for (l, u) in bounds]])
        end
        header = ["Method", "1-99%", "2-98%", "5-95%", "10-90%"]
        printtable("ACE (% points): $(uppercase(model)), $market", header, ace)
        printtable("PIPS: $(uppercase(model)), $market", header, pips)
    end
end

function confidence_sets(model)
    for market in ["DE", "FR"], size in [10, 25, 50]
        obs, forecasts = arrays(loadpanel(model, market, size))
        Random.seed!(42)
        retained99 = mcs(obs, forecasts; loss=(y, x)->TestForecasts.crps(y, x, 99), bootstraps=10_000, alpha=0.01)
        retained95 = mcs(obs, forecasts; loss=(y, x)->TestForecasts.crps(y, x, 99), bootstraps=10_000, alpha=0.05)
        rows = [[LABELS[i], i in retained99 ? "yes" : "", i in retained95 ? "yes" : ""] for i in eachindex(METHODS)]
        printtable("MCS: $(uppercase(model)), $market, $size members", ["Method", "99%", "95%"], rows)
    end
end

function point_mae()
    for market in ["DE", "FR"], model in ["narx", "xgb"]
        rows = Vector{Vector{String}}()
        for size in [10, 25, 50]
            vals = [fmt(mean(PostForecasts.mae(average(loadpointf(pointpath(model, market, size, h)))(year*10000+101, year*10000+1231))[1] for h in 1:24), digits=2) for year in 2020:2025]
            push!(rows, ["$(uppercase(model)) $size"; vals])
        end
        printtable("Point-forecast MAE: $market", ["Model"; string.(2020:2025)], rows)
    end
end

function trading()
    for model in ["narx", "xgb"]
        rows = Vector{Vector{String}}()
        for (i, method) in enumerate(METHODS)
            values = [strategy(method, model, "DE", 25, threshold; efficiency=0.9, cost=100.0) for threshold in [1/3, 2/3, 1.0]]
            push!(rows, [LABELS[i]; string.([v[2] for v in values]); [fmt(v[1]/v[2], digits=1) for v in values]])
        end
        printtable("Trading results: $(uppercase(model)), DE, 25 members", ["Method", "N(1/3)", "N(2/3)", "N(1)", "EUR(1/3)", "EUR(2/3)", "EUR(1)"], rows)
        _, _, profit, trades, _ = strategy(:cp, model, "DE", 25, 0.0; efficiency=0.9, cost=100.0)
        println("Baseline profit per trade: ", fmt(profit/trades, digits=1), " EUR")
    end
end

function timing_table()
    for size in [10, 25, 50]
        path = joinpath(@__DIR__, "..", "outputs", "timers", "ensemble$(size).jld2")
        isfile(path) || (println("Missing $path; run scripts/timing.jl $size"); continue)
        timers = load(path, "timers")
        rows = [[name, fmt(mean(timers[name]), digits=2), fmt(std(timers[name]), digits=2)] for name in ["hs", "cp", "idr", "qrm", "sqrm", "qra", "sqra", "lqra", "iqra", "isqra"]]
        lqra = timers["lqra"] ./ 20
        push!(rows, ["lqra (per lambda)", fmt(mean(lqra), digits=2), fmt(std(lqra), digits=2)])
        printtable("Runtime in seconds: $size members", ["Method", "Mean", "SD"], rows)
    end
end

task = ARGS[1]
task in ["crps", "ensemble", "mcs", "intervals", "mae", "trading", "timing"] || error(" input: $task")
task == "mae" && point_mae()
task == "trading" && trading()
task == "timing" && timing_table()
for model in ["narx", "xgb"]
    task == "crps" && yearly_crps(model)
    task == "ensemble" && ensemble_crps(model)
    task == "intervals" && intervals(model)
    task == "mcs" && confidence_sets(model)
end
