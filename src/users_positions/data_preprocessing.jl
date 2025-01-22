using Printf
using DataFrames
using Dates
using CSV
using Base.Threads


function match_balances_with_prices(balances::Dict{Any, Any}, prices::Dict{Any, Any})
    combined_balances = Dict()
    for date_month in collect(keys(balances))
        combined_balances[date_month] = match_balances_with_prices(balances[date_month], prices[date_month])
    end
    return combined_balances
end


function match_balances_with_prices(balances::DataFrame, prices::DataFrame)
    combined_balances = copy(balances)
    closest_datetime_column = Vector{DateTime}(undef, nrow(balances))
    prices_column = Vector{Float64}(undef, nrow(balances))
    Threads.@threads for index in 1:nrow(balances)
        reserve_name = balances.reserve_name[index]
        snapshot_date = balances.datetime[index]
        dates_delta = abs.(Dates.value.(prices.datetime .- snapshot_date) ./ 1000)
        _, best_index = findmin(i->prices.reserve_name[i]==reserve_name ? dates_delta[i] : Inf, 1:nrow(prices))
        closest_datetime_column[index] = prices.datetime[best_index]
        prices_column[index] = prices.inputTokenPriceUSD[best_index]
    end
    combined_balances[!, :closest_price_datetime] = closest_datetime_column
    combined_balances[!, :asset_price] = prices_column
    return combined_balances
end


function concat_all_balances(balances::Dict{Any, Any})::DataFrame
    dates = collect(keys(balances))
    concat_balances::DataFrame = balances[dates[1]]
    for date in dates[2:end]
        concat_balances = vcat(concat_balances, balances[date])
    end
    return concat_balances
end