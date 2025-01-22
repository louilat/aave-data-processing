using Printf
using DataFrames
using Dates
using CSV


function compute_users_balances_snapshot(
    atoken_balances::DataFrame,
    vtoken_balances::DataFrame,
    snapshot_date::DateTime,
)::DataFrame
    atoken_balances_ = atoken_balances[
        atoken_balances.datetime.<=snapshot_date,
        [:user_address, :reserve_name, :datetime, :asset_price, :user_current_atoken_balance]
    ]
    vtoken_balances_ = vtoken_balances[
        vtoken_balances.datetime.<=snapshot_date,
        [:user_address, :reserve_name, :datetime, :asset_price, :user_current_vtoken_balance]
    ]

    transform!(groupby(atoken_balances_, [:user_address, :reserve_name]), :datetime => maximum => :last_datetime)
    transform!(groupby(vtoken_balances_, [:user_address, :reserve_name]), :datetime => maximum => :last_datetime)

    atoken_balances_ = select(
        unique(
            atoken_balances_[atoken_balances_.datetime.==atoken_balances_.last_datetime, :],
            [:user_address, :reserve_name]
        ),
        :user_address, :reserve_name, :user_current_atoken_balance, :asset_price => :atoken_asset_price
    )
    vtoken_balances_ = select(
        unique(
            vtoken_balances_[vtoken_balances_.datetime.==vtoken_balances_.last_datetime, :],
            [:user_address, :reserve_name]
        ),
        :user_address, :reserve_name, :user_current_vtoken_balance, :asset_price => :vtoken_asset_price
    )

    combined_balances::DataFrame = outerjoin(
        atoken_balances_,
        vtoken_balances_,
        on=[:user_address, :reserve_name],
    )
    return coalesce.(combined_balances, 0)
end


function compute_users_health_factor_snapshot(combined_balances::DataFrame, loan_to_values::DataFrame)::DataFrame
    loan_to_values_::DataFrame = transform(
        loan_to_values,
        [:collateral_enabled, :liquidation_threshold] => ByRow((b, lt) -> b ? lt : 0) => :liquidation_threshold
    )
    combined_balances_ = leftjoin(combined_balances, loan_to_values_, on=:reserve_name)

    transform!(
        combined_balances_,
        [
            :user_current_atoken_balance,
            :liquidation_threshold,
            :atoken_asset_price
        ] => ((bal, lt, ap) -> bal .* lt .* ap) => :hf_numerator,
        [
            :user_current_vtoken_balance,
            :vtoken_asset_price
        ] => ((bal, ap) -> bal .* ap) => :hf_denominator,
    )

    combined_balances_ = combine(
        groupby(combined_balances_, :user_address),
        :hf_numerator => sum => :hf_numerator,
        :hf_denominator => sum => :hf_denominator,
    )
    transform!(
        combined_balances_,
        [
            :hf_numerator,
            :hf_denominator,
        ] => ByRow((num, den) -> den == 0 ? Inf : num ./ den) => :health_factor)

    return combined_balances_
end