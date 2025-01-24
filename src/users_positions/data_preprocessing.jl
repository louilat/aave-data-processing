using Printf
using DataFrames
using Dates
using CSV
using Base.Threads


function match_balances_with_prices(balances::Dict{Any, Any}, prices::Dict{Any, Any})
    combined_balances = Dict()
    for date_month in collect(keys(balances))
        println(date_month)
        combined_balances[date_month] = match_balances_with_prices(balances[date_month], prices[date_month])
    end
    return combined_balances
end


# function match_balances_with_prices(balances::DataFrame, prices::DataFrame)
#     combined_balances = copy(balances)
#     closest_datetime_column = Vector{Union{DateTime, Missing}}(undef, nrow(balances))
#     prices_column = Vector{Union{Float64, Missing}}(undef, nrow(balances))
#     Threads.@threads for index in 1:nrow(balances)
#         reserve_name = balances.reserve_name[index]
#         snapshot_date = balances.datetime[index]
#         valid_indexes = findall((Dates.day.(prices.datetime) .== Dates.day(snapshot_date)) .& (prices.reserve_name .== reserve_name))
#         if !isempty(valid_indexes)
#             dates_delta = abs.(Dates.value.(prices.datetime .- snapshot_date) ./ 1000)
#             _, best_index = findmin(dates_delta[valid_indexes])
#             closest_datetime_column[index] = prices.datetime[best_index]
#             prices_column[index] = prices.inputTokenPriceUSD[best_index]
#         else
#             closest_datetime_column[index] = missing
#             prices_column[index] = missing
#         end
#     end
#     combined_balances[!, :closest_price_datetime] = closest_datetime_column
#     combined_balances[!, :asset_price] = prices_column
#     return combined_balances
# end

# function match_balances_with_prices(balances::DataFrame, prices::DataFrame)
#     combined_balances = copy(balances)
#     closest_datetime_column = Vector{Union{DateTime, Missing}}(undef, nrow(balances))
#     prices_column = Vector{Union{Float64, Missing}}(undef, nrow(balances))
#     Threads.@threads for index in 1:nrow(balances)
#         reserve_name = balances.reserve_name[index]
#         snapshot_date = balances.datetime[index]
#         reserve_indexes = (prices.reserve_name .== reserve_name) .& (Dates.day.(prices.datetime) .== Dates.day(snapshot_date))
#         # println(sum(reserve_indexes))
#         if sum(reserve_indexes) != 0
#             # println("Juju")
#             dates_delta = abs.(Dates.value.(prices.datetime[reserve_indexes] .- snapshot_date) ./ 1000)
#             argmin_index = argmin(dates_delta)
#             closest_datetime_column[index] = prices.datetime[reserve_indexes][argmin_index]
#             prices_column[index] = prices.inputTokenPriceUSD[reserve_indexes][argmin_index]
#         else
#             closest_datetime_column[index] = missing
#             prices_column[index] = missing
#         end
#     end
#     combined_balances[!, :closest_price_datetime] = closest_datetime_column
#     combined_balances[!, :asset_price] = prices_column
#     return combined_balances
# end

function match_balances_with_prices(balances::DataFrame, prices::DataFrame)::DataFrame
    combined_balances::DataFrame = leftjoin(balances, prices, on=:reserve_name)
    rename!(combined_balances, :datetime => :price_snapshot_datetime, :inputTokenPriceUSD => :asset_price)
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