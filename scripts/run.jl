# Generate postprocessed forecasts:
# julia --project=. scripts/run.jl METHOD MODEL MARKET SIZE HOUR
include(joinpath(@__DIR__, "..", "src", "main.jl"))

const METHODS = [:hs, :cp, :idr, :qra, :sqra, :qrm, :sqrm, :lqra, :iqra, :isqra]
const MODELS = ["narx", "xgb"]
const MARKETS = ["DE", "FR"]
const SIZES = [10, 25, 50]

function generate(method, model, market, ensemble, hour)
    target = output("postprocess", "$method-$model-$market-r$ensemble-h$hour.quantf")
    valid = if isfile(target)
        try
            qf = loadquantf(target)
            Base.size(qf.pred) == (2192, 99) && getid(qf, 1) == START && getid(qf, length(qf)) == STOP
        catch
            false
        end
    else
        false
    end
    if valid
        println("Skipping existing $target")
    else
        println("Generating $method $model $market r=$ensemble h=$hour")
        run(Val(method), model, market, ensemble, hour)
    end
end

if length(ARGS) == 5
    method, model, market = Symbol(ARGS[1]), lowercase(ARGS[2]), uppercase(ARGS[3])
    ensemble, hour = parse(Int, ARGS[4]), parse(Int, ARGS[5])
    method in METHODS || error("METHOD must be one of $(join(METHODS, ", "))")
    model in MODELS || error("MODEL must be narx or xgb")
    market in MARKETS || error("MARKET must be DE or FR")
    ensemble in SIZES || error("SIZE must be 10, 25, or 50")
    hour in 1:24 || error("HOUR must be between 1 and 24")
    generate(method, model, market, ensemble, hour)
else
    error("usage: julia --project=. scripts/run.jl METHOD MODEL MARKET SIZE HOUR")
end
