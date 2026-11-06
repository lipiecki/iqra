using PostForecasts
using JLD2

const START = 20200101  # first date of the testing period
const STOP = 20251231   # last date of the testing period
const WINDOW = 364      # size of the rolling window for quantile regression
const QUANTILES = 99    # number of quantiles to compute

# set the grid of lambda values for the lasso quantile regression
set_hyperparam(:nlambdas, 20)
set_hyperparam(:highs_nthreads, 1)

include("postprocess.jl")

const ROOT = normpath(joinpath(@__DIR__, ".."))
input(model, market, ensemble, h) = joinpath(ROOT, "inputs", "$model-$market-r$ensemble-h$h")
output(kind, name) = joinpath(ROOT, "outputs", kind, name)

foreach(dir -> mkpath(joinpath(ROOT, "outputs", dir)), ["postprocess", "weights"])

function run(::Val{:cp}, model::String, market::String, ensemble::Int, h::Int)
    pf = average(loadpointf(input(model, market, ensemble, h)))
    results, _ = postprocess(pf, method=:cp, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP)
    saveforecasts(results, output("postprocess", "cp-$model-$market-r$ensemble-h$h"))
end

function run(::Val{:hs}, model::String, market::String, ensemble::Int, h::Int)
    pf = average(loadpointf(input(model, market, ensemble, h)))
    results, _ = postprocess(pf, method=:hs, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP)
    saveforecasts(results, output("postprocess", "hs-$model-$market-r$ensemble-h$h"))
end

function run(::Val{:idr}, model::String, market::String, ensemble::Int, h::Int)
    pf = loadpointf(input(model, market, ensemble, h))
    results, _ = postprocess(pf, method=:idr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP)
    saveforecasts(results, output("postprocess", "idr-$model-$market-r$ensemble-h$h"))
end

function run(::Val{:qrm}, model::String, market::String, ensemble::Int, h::Int)
    pf = average(loadpointf(input(model, market, ensemble, h)))
    results, _ = postprocess(pf, method=:qr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP)
    saveforecasts(results, output("postprocess", "qrm-$model-$market-r$ensemble-h$h"))
end

function run(::Val{:sqrm}, model::String, market::String, ensemble::Int, h::Int)
    pf = average(loadpointf(input(model, market, ensemble, h)))
    results, _ = postprocess(pf, method=:sqr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP)
    saveforecasts(results, output("postprocess", "sqrm-$model-$market-r$ensemble-h$h"))
end

function run(::Val{:qra}, model::String, market::String, ensemble::Int, h::Int)
    pf = loadpointf(input(model, market, ensemble, h))
    sort!(pf.pred, dims=2)
    results, _ = postprocess(pf, method=:qr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP)
    saveforecasts(results, output("postprocess", "qra-$model-$market-r$ensemble-h$h"))
end

function run(::Val{:sqra}, model::String, market::String, ensemble::Int, h::Int)
    pf = loadpointf(input(model, market, ensemble, h))
    sort!(pf.pred, dims=2)
    results, _ = postprocess(pf, method=:sqr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP)
    saveforecasts(results, output("postprocess", "sqra-$model-$market-r$ensemble-h$h"))
end

function run(::Val{:iqra}, model::String, market::String, ensemble::Int, h::Int)
    pf = loadpointf(input(model, market, ensemble, h))
    sort!(pf.pred, dims=2)
    collect_weights = market == "DE" && ensemble == 25 && model == "narx"
    results, weights = postprocess(pf, method=:iqr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP, collect_weights=collect_weights)
    saveforecasts(results, output("postprocess", "iqra-$model-$market-r$ensemble-h$h"))
    collect_weights && save(output("weights", "iqra-$model-$market-r$ensemble-h$h-weights.jld2"), "weights", weights)
end

function run(::Val{:isqra}, model::String, market::String, ensemble::Int, h::Int)
    pf = loadpointf(input(model, market, ensemble, h))
    sort!(pf.pred, dims=2)
    collect_weights = market == "DE" && ensemble == 25 && model == "narx"
    results, weights = postprocess(pf, method=:isqr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP, collect_weights=collect_weights)
    saveforecasts(results, output("postprocess", "isqra-$model-$market-r$ensemble-h$h"))
    collect_weights && save(output("weights", "isqra-$model-$market-r$ensemble-h$h-weights.jld2"), "weights", weights)
end

function run(::Val{:lqra}, model::String, market::String, ensemble::Int, h::Int)
    pf = loadpointf(input(model, market, ensemble, h))
    sort!(pf.pred, dims=2)
    collect_weights = market == "DE" && ensemble == 25 && model == "narx"
    results, weights = postprocess(pf, method=:lassoqr, window=WINDOW, quantiles=QUANTILES, start=START, stop=STOP, collect_weights=collect_weights)
    saveforecasts(results, output("postprocess", "lqra-$model-$market-r$ensemble-h$h"))
    collect_weights && save(output("weights", "lqra-$model-$market-r$ensemble-h$h-weights.jld2"), "weights", weights)
end
