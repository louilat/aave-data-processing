"""ETL for computing HF"""

using Printf
using DataFrames
using Dates
using CSV
using Minio
using AWSS3
using DotEnv

include("src/users_positions/data_extraction.jl")
include("src/users_positions/data_preprocessing.jl")
include("src/users_positions/users_snapshots.jl")

DotEnv.load!()

# Run parameters
balances_input_path::String = "aave-data/data-prod/aave-v3/users-positions-combined/"
hourly_prices_input_path::String = "aave-data/data-prod/aave-v3/messari-prices/hourly_prices_2024_12.csv"
ltv_input_path::String = "aaveV3-live-data/configuration/reserve_configuration_2025-01-20.csv"
snapshot_date::DateTime = DateTime(2024, 12)
save_to_s3::Bool = false


AWS_ACCESS_KEY_ID = ENV["AWS_ACCESS_KEY_ID"]
AWS_SECRET_ACCESS_KEY = ENV["AWS_SECRET_ACCESS_KEY"]
TOKEN = ENV["TOKEN"]

cfig = MinioConfig(
    "https://minio.lab.sspcloud.fr";
    region="us-east-1",
    username=AWS_ACCESS_KEY_ID,
    password=AWS_SECRET_ACCESS_KEY,
    token=TOKEN, user_arn="",
)

println("STEP 1: Extracting users balances...")
abalances::Dict, vbalances::Dict = fetch_users_balances(
    cfig,
    "llatournerie",
    balances_input_path,
    snapshot_date,
)

println("STEP 2: Extracting hourly prices...")
prices::DataFrame = fetch_assets_prices(
    cfig,
    "llatournerie",
    hourly_prices_input_path,
    snapshot_date,
)

println("STEP 3: Extracting ltv/lt data...")
ltv::DataFrame = fetch_loan_to_values(
    cfig,
    "llatournerie",
    ltv_input_path,
)

println("STEP 4: Computing users' balances...")
all_abalances::DataFrame = concat_all_balances(abalances)
all_vbalances::DataFrame = concat_all_balances(vbalances)
combined_balances::DataFrame = compute_users_balances_snapshot(
    all_abalances,
    all_vbalances,
    snapshot_date,
)

println("STEP 5: Matching balances with prices...")
combined_balances = match_balances_with_prices(combined_balances, prices)

println("STEP 6: Computing health factors...")
health_factors::DataFrame = compute_users_health_factor_snapshot(combined_balances, ltv)

if save_to_s3
    println("STEP 7: Generating and saving output to s3...")
    buffer = IOBuffer()
    CSV.write(buffer, health_factors)
    s3_put(cfig, "llatournerie", "aave-data/experiments/health_factors.csv", take!(buffer))
end

println("Done!")