using PostForecasts, Statistics

function strategy(method::Symbol, model::AbstractString, market::AbstractString, ensemble::Int, threshold::AbstractFloat; efficiency::AbstractFloat=0.9, cost::AbstractFloat=0.0)
    qf = Vector{QuantForecasts}(undef, 24)
    for h in 1:24
        qf[h] = loadquantf(joinpath(@__DIR__, "..", "outputs", "postprocess", "$method-$model-$market-r$ensemble-h$h"))
    end
    baseline_profit = 0.0
    baseline_trades = 0
    total_profit = 0.0
    num_trades = 0
    total_loss_count = 0
    loss_avoidance_count = 0
    for t in 1:length(qf[begin])
        hour_buy = nothing
        hour_sell = nothing
        max_profit = 0.0
        total_addition = 0.0
        baseline_addition = 0.0
        for hb in 1:23
            for hs in hb+1:24
                profit = efficiency * qf[hs].pred[t, 50] - (1/efficiency) * qf[hb].pred[t, 50] - cost
                if profit > max_profit
                    max_profit = profit
                    hour_buy = hb
                    hour_sell = hs
                end
            end
        end
        if hour_buy === nothing || hour_sell === nothing
            continue
        else
            riskbuy = (1/efficiency) * (mean(qf[hour_buy].pred[t, 51:end]) - qf[hour_buy].pred[t, 50])
            risksell = efficiency * (qf[hour_sell].pred[t, 50] - mean(qf[hour_sell].pred[t, 1:49]))

            if max_profit > threshold * (riskbuy + risksell)
                total_addition = efficiency * qf[hour_sell].obs[t] - (1/efficiency) * qf[hour_buy].obs[t] - cost
                total_profit += total_addition
                num_trades += 1
            end

            if max_profit > 0
                baseline_addition = efficiency * qf[hour_sell].obs[t] - (1/efficiency) * qf[hour_buy].obs[t] - cost 
                baseline_profit += baseline_addition
                baseline_trades += 1
                if baseline_addition < 0
                    total_loss_count += 1
                    if total_addition > -1e-6
                        loss_avoidance_count += 1
                    end
                end
            end
        end
    end
    avoidance = total_loss_count == 0 ? NaN : loss_avoidance_count/total_loss_count
    return total_profit, num_trades, baseline_profit, baseline_trades, avoidance
end
