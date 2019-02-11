function create_affine_expression_array(var_type::Type{V}, nbus, ntimes) where V <: JuMP.AbstractVariableRef
    
    return JumpAffineExpressionArray{V}(undef, nbus, ntimes)
    
end

function instantiate_network(network::Type{N}, var_type::Type{V}, sys::PowerSystems.PowerSystem; args...) where {N <: AbstractDCPowerModel, V <: JuMP.AbstractVariableRef}

    #d_netinjection_p =  JumpAffineExpressionArray(undef, length(sys.buses), sys.time_periods)
    d_netinjection_p = create_affine_expression_array(var_type, length(sys.buses), sys.time_periods)

    ts_active = active_timeseries_netinjection(sys)

    netinjection = (var_active = d_netinjection_p, var_reactive = nothing, timeseries_active = ts_active, timeseries_reactive = nothing)

    return netinjection

end

function instantiate_network(network::Type{N}, var_type::Type{V}, sys::PowerSystems.PowerSystem; args...) where {N <: AbstractACPowerModel, V <: JuMP.AbstractVariableRef}

    # d_netinjection_p =  JumpAffineExpressionArray{var_type}(undef, length(sys.buses), sys.time_periods)
    d_netinjection_p = create_affine_expression_array(var_type, length(sys.buses), sys.time_periods)

    ts_active = active_timeseries_netinjection(sys)

    # d_netinjection_q =  JumpAffineExpressionArray{var_type}(undef, length(sys.buses), sys.time_periods)
    d_netinjection_q = create_affine_expression_array(var_type, length(sys.buses), sys.time_periods)

    ts_reactive = reactive_timeseries_netinjection(sys)

    netinjection = (var_active = d_netinjection_p, var_reactive = d_netinjection_q, timeseries_active = ts_active, timeseries_reactive = ts_reactive)

    return netinjection

end

function instantiate_network(network::Type{N}, var_type::Type{V}, sys::PowerSystems.PowerSystem; args...) where {N <: CopperPlatePowerModel, V <: JuMP.AbstractVariableRef}

    return instantiate_network(AbstractDCPowerModel, var_type, sys)

end

function instantiate_network(network::Type{N}, var_type::Type{V}, sys::PowerSystems.PowerSystem; args...) where {N <: AbstractFlowForm, V <: JuMP.AbstractVariableRef}

    return instantiate_network(AbstractDCPowerModel, var_type, sys)

end
