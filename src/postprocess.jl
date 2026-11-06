function postprocess(pf::PointForecasts{F, I}; method::Symbol, window::Integer, quantiles::Integer, start::Union{Nothing, Integer}=nothing, stop::Union{Nothing, Integer}=nothing, collect_weights::Bool=false) where {F, I}
    quantiles = [i/(quantiles + 1) for i in 1:quantiles]
    (window > 0 && window < length(pf)) || throw(ArgumentError("`window` must be greater than 0 and smaller than the length of `pf`"))
    first = isnothing(start) ? firstindex(pf)+window : findindex(pf, start)
    last = isnothing(stop) ? lastindex(pf) : findindex(pf, stop)
    first > window || throw(ArgumentError("there is less than $(window) timesteps before $(start)"))
    prob = Vector{F}(quantiles)
    model = getmodel(Val(method), window, npred(pf), prob)
    pred = zeros(F, last-first+1, length(prob))
    weights = collect_weights && model isa Union{QR, LassoQR, SQR} ? zeros(F, last-first+1, npred(pf)+1, length(prob)) : nothing
    pf = (nreg(model) == 1 && npred(pf) > 1) ? average(pf) : pf
    for t in first:last
        train(model, viewpred(pf, t-window:t-1), viewobs(pf, t-window:t-1))
        input = viewpred(pf, t)
        predict!(model, @view(pred[t-first+1, :]), input, prob)
        if !isnothing(weights)
            weights[t-first+1, :, :] .= getweights(model)
        end
    end
    return QuantForecasts(
        pred,
        getobs(pf, first:last),
        getid(pf, first:last),
        prob
    ), weights
end