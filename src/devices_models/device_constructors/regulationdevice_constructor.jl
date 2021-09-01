function initialize_timeseries_names(
    ::Type{<:PSY.RegulationDevice{T}},
    ::Type{<:AbstractRegulationFormulation},
) where {T <: PSY.StaticInjection}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
    )
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}

    # TODO: why not dispatch on AreaBalancePowerModel instead?
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
    # Variables
    add_variables!(
        container,
        DeltaActivePowerUpVariable,
        devices,
        DeviceLimitedRegulation(),
    )
    add_variables!(
        container,
        DeltaActivePowerDownVariable,
        devices,
        DeviceLimitedRegulation(),
    )
    add_variables!(
        container,
        AdditionalDeltaActivePowerUpVariable,
        devices,
        DeviceLimitedRegulation(),
    )
    add_variables!(
        container,
        AdditionalDeltaActivePowerDownVariable,
        devices,
        DeviceLimitedRegulation(),
    )
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(get_component_type(model), sys)
    # Constraints
    add_constraints!(
        container,
        DeltaActivePowerUpVariableLimitsConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        DeltaActivePowerDownVariableLimitsConstraint,
        DeltaActivePowerDownVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(container, devices, model, S, get_feedforward(model))
    participation_assignment!(container, devices, model, S, nothing)
    regulation_cost!(container, devices, model)
    add_constraint_dual!(container, sys, model)
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
    # Variables
    add_variables!(
        container,
        DeltaActivePowerUpVariable,
        devices,
        ReserveLimitedRegulation(),
    )
    add_variables!(
        container,
        DeltaActivePowerDownVariable,
        devices,
        ReserveLimitedRegulation(),
    )
    add_variables!(
        container,
        AdditionalDeltaActivePowerUpVariable,
        devices,
        ReserveLimitedRegulation(),
    )
    add_variables!(
        container,
        AdditionalDeltaActivePowerDownVariable,
        devices,
        ReserveLimitedRegulation(),
    )
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(get_component_type(model), sys)
    # Constraints

    add_constraints!(
        container,
        DeltaActivePowerUpVariableLimitsConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        DeltaActivePowerDownVariableLimitsConstraint,
        DeltaActivePowerDownVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    participation_assignment!(container, devices, model, S, nothing)
    regulation_cost!(container, devices, model)
    add_constraint_dual!(container, sys, model)
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, FixedOutput},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    devices = get_available_components(get_component_type(model), sys)
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{PSY.RegulationDevice{T}, FixedOutput},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(get_component_type(model), sys)
    add_constraint_dual!(container, sys, model)
    return
end
