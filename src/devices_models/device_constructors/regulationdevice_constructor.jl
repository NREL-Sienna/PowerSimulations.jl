"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(get_component_type(model), sys)

    if !validate_available_devices(T, devices)
        return
    end

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

    # Constraints
    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )

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
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(get_component_type(model), sys)

    if !validate_available_devices(T, devices)
        return
    end

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

    # Constraints
    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )

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
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, FixedOutput},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(get_component_type(model), sys)
    if !validate_available_devices(T, devices)
        return
    end
    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )
    return
end
