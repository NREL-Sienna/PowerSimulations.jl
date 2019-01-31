function constructnetwork!(m::JuMP.AbstractModel, branch_models::Array{NamedTuple{(:device, :formulation), Tuple{DataType,DataType}}}, netinjection::BalanceNamedTuple, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: CopperPlatePowerModel}

    devices_netinjection = _remove_undef!(netinjection.var_active)
    timeseries_netinjection = sum(netinjection.timeseries_active, dims=1)

    cpn = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef,time_periods), 1:time_periods)

    for t in 1:time_periods
        # TODO: Check is sum() is the best way to do this in terms of speed.
        cpn[t] = JuMP.@constraint(m, sum(netinjection.var_active[:,t]) == timeseries_netinjection[t])
    end

    JuMP.register_object(m, :CopperPlateBalance, cpn)

    return m

end

