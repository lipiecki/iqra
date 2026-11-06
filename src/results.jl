using PostForecasts, Statistics

const METHODS = [:hs, :cp, :idr, :qra, :sqra, :qrm, :sqrm, :lqra, :iqra, :isqra]
const LABELS = ["HS", "CP", "IDR", "QRA", "SQRA", "QRM", "SQRM", "LQRA", "iQRA", "iSQRA"]
const ROOT = normpath(joinpath(@__DIR__, ".."))

quantpath(method, model, market, size, h) = joinpath(ROOT, "outputs", "postprocess", "$method-$model-$market-r$size-h$h")
pointpath(model, market, size, h) = joinpath(ROOT, "inputs", "$model-$market-r$size-h$h")

function loadpanel(model, market, size)
    Dict(method => [loadquantf(quantpath(method, model, market, size, h)) for h in 1:24] for method in METHODS)
end

function arrays(results, start=20200101, stop=20251231)
    sample = results[METHODS[1]][1](start, stop)
    obs = zeros(length(sample), 24)
    forecasts = zeros(length(sample), 24, 99, length(METHODS))
    ids = getid(sample)
    for (m, method) in enumerate(METHODS), h in 1:24
        qf = results[method][h](start, stop)
        getid(qf) == ids || error("date mismatch for $method hour $h")
        if m == 1
            obs[:, h] = getobs(qf)
        else
            getobs(qf) == obs[:, h] || error("observation mismatch for $method hour $h")
        end
        forecasts[:, h, :, m] = qf.pred
    end
    obs, forecasts
end

function printtable(title, header, rows)
    data = [string.(header), (string.(row) for row in rows)...]
    widths = [maximum(textwidth(data[r][c]) for r in eachindex(data)) for c in eachindex(header)]
    println("\n$title")
    for (r, row) in enumerate(data)
        println(join([rpad(row[c], widths[c]) for c in eachindex(row)], "  "))
        r == 1 && println(join([repeat("-", widths[c]) for c in eachindex(row)], "  "))
    end
end
