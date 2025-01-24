using Printf
using DataFrames
using Dates
using CSV
using Minio
using AWSS3


function fetch_users_balances(config::MinioConfig, bucket::String, key::String, until::DateTime)
    atoken_balances = Dict()
    vtoken_balances = Dict()
    current_date = DateTime(2023, 1, 1)

    while current_date <= until
        println("Fetching data for current date = $current_date")
        current_year = Dates.year(current_date)
        current_month = Dates.month(current_date)
        atoken_path = key * "combined_atoken_balances_$current_year-$current_month.csv"
        vtoken_path = key * "combined_vtoken_balances_$current_year-$current_month.csv"
        atoken_bytes = AWSS3.s3_get(config, bucket, atoken_path)
        vtoken_bytes = AWSS3.s3_get(config, bucket, vtoken_path)
        monthly_atoken_balances = CSV.read(atoken_bytes, DataFrame)
        monthly_vtoken_balances = CSV.read(vtoken_bytes, DataFrame)
        transform!(monthly_atoken_balances, :timestamp => ByRow(unix2datetime) => :datetime)
        transform!(monthly_vtoken_balances, :timestamp => ByRow(unix2datetime) => :datetime)
        atoken_balances[current_date] = monthly_atoken_balances
        vtoken_balances[current_date] = monthly_vtoken_balances
        current_date += Dates.Month(1)
    end
    return atoken_balances, vtoken_balances
end


# function fetch_assets_prices(config::MinioConfig, bucket::String, key::String, until::DateTime)
#     asset_prices_output = Dict()
#     current_date = DateTime(2023, 1, 1)

#     while current_date <= until
#         println("Fetching data for current date = $current_date")
#         current_year = Dates.year(current_date)
#         current_month = Dates.month(current_date)
#         prices_path = key * "hourly_prices_$current_year" * "_" * "$current_month.csv"
#         prices_bytes = AWSS3.s3_get(config, bucket, prices_path)
#         month_prices = CSV.read(prices_bytes, DataFrame)
#         transform!(month_prices, :timestamp => ByRow(unix2datetime) => :datetime)
#         asset_prices_output[current_date] = dropmissing!(month_prices, :reserve_name)
#         current_date += Dates.Month(1)
#     end
#     return asset_prices_output
# end


function fetch_assets_prices(config::MinioConfig, bucket::String, key::String, snapshot_date::DateTime)
    prices_bytes = AWSS3.s3_get(config, bucket, key)
    month_prices = CSV.read(prices_bytes, DataFrame)
    dropmissing!(month_prices, :reserve_name)
    transform!(month_prices, :timestamp_hours => (t -> 3600 .* t) => :datetime)
    transform!(month_prices, :datetime => ByRow(unix2datetime) => :datetime)
    transform!(month_prices, :datetime => (dt -> abs.(Dates.value.(dt .- snapshot_date))) => :delta_time)
    transform!(groupby(month_prices, :reserve_name), :delta_time => minimum => :min_delta_time)
    return month_prices[month_prices.delta_time .== month_prices.min_delta_time, [:reserve_name, :datetime, :inputTokenPriceUSD]]
end


function fetch_loan_to_values(config::MinioConfig, bucket::String, key::String)::DataFrame
    configuration_bytes = AWSS3.s3_get(config, bucket, key)
    configuration::DataFrame = CSV.read(configuration_bytes, DataFrame)
    ltv::DataFrame = select(
        unique(configuration, :name),
        :name => :reserve_name,
        :usageAsCollateralEnabled => :collateral_enabled,
        :reserveLiquidationThreshold => (lt -> lt/10000) => :liquidation_threshold,
    )
    return ltv
end