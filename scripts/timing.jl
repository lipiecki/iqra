# Measure one forecast day (24 hours, 99 quantiles):
# julia --project=. scripts/timing.jl ENSEMBLE_SIZE
using PostForecasts, TimerOutputs, JLD2, Statistics, Random

set_hyperparam(:nlambdas, 20)
set_hyperparam(:highs_nthreads, 1)

const ROOT = normpath(joinpath(@__DIR__, ".."))
const WINDOW = 364
const QUANTILES = 99
const REPETITIONS = 10

function run_timing(size)
    pf = [loadpointf(joinpath(ROOT, "inputs", "narx-DE-r$size-h$h")) for h in 1:24]
    pfm = average.(pf)
    firstday, lastday = findindex(pf[1], 20200101), findindex(pf[1], 20251231)
    compileday = getid(pf[1], firstday)

    point2quant(pfm[1], method=:cp, window=WINDOW, quantiles=QUANTILES, start=compileday, stop=compileday)
    point2quant(pfm[1], method=:hs, window=WINDOW, quantiles=QUANTILES, start=compileday, stop=compileday)
    point2quant(pf[1], method=:idr, window=WINDOW, quantiles=QUANTILES, start=compileday, stop=compileday)
    for method in [:qr, :sqr, :iqr, :isqr, :lassoqr]
        point2quant(pf[1], method=method, window=WINDOW, quantiles=QUANTILES, start=compileday, stop=compileday)
    end

    timers = Dict(name => Float64[] for name in ["hs", "cp", "idr", "qrm", "sqrm", "qra", "sqra", "lqra", "iqra", "isqra"])
    for _ in 1:REPETITIONS
        date = getid(pf[1], rand(firstday:lastday))
        to = TimerOutput()
        @timeit to "hs" for h in 1:24; point2quant(pfm[h], method=:hs, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "cp" for h in 1:24; point2quant(pfm[h], method=:cp, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "idr" for h in 1:24; point2quant(pf[h], method=:idr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "qrm" for h in 1:24; point2quant(pfm[h], method=:qr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "sqrm" for h in 1:24; point2quant(pfm[h], method=:sqr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "qra" for h in 1:24; point2quant(pf[h], method=:qr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "sqra" for h in 1:24; point2quant(pf[h], method=:sqr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "lqra" for h in 1:24; point2quant(pf[h], method=:lassoqr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "iqra" for h in 1:24; point2quant(pf[h], method=:iqr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        @timeit to "isqra" for h in 1:24; point2quant(pf[h], method=:isqr, window=WINDOW, quantiles=QUANTILES, start=date, stop=date); end
        for (name, timer) in to.inner_timers
            push!(timers[name], TimerOutputs.time(timer) / 1e9)
        end
    end
    mkpath(joinpath(ROOT, "outputs", "timers"))
    path = joinpath(ROOT, "outputs", "timers", "ensemble$(size).jld2")
    save(path, "timers", timers)
    for name in sort(collect(keys(timers)))
        println(rpad(name, 6), " ", round(mean(timers[name]), digits=2), " ± ", round(std(timers[name]), digits=2), " s")
    end
    println("Saved $path")
end

length(ARGS) == 1 || error("usage: julia --project=. scripts/timing.jl ENSEMBLE_SIZE")
ensemble = parse(Int, ARGS[1])
ensemble in [10, 25, 50] || error("ENSEMBLE_SIZE must be 10, 25, or 50")
run_timing(ensemble)
