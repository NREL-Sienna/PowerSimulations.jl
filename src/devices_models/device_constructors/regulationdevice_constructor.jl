"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(model.component_type, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, DeltaActivePowerUpVariable, devices)
    add_variables!(optimization_container, DeltaActivePowerDownVariable, devices)
    add_variables!(optimization_container, AdditionalDeltaActivePowerUpVariable, devices)
    add_variables!(optimization_container, AdditionalDeltaActivePowerDownVariable, devices)

    # Constraints
    nodal_expression!(optimization_container, devices, S)
    add_constraints!(
        optimization_container,
        RangeConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        DeltaActivePowerDownVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    participation_assignment!(optimization_container, devices, model, S, nothing)
    regulation_cost!(optimization_container, devices, model)
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(model.component_type, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, DeltaActivePowerUpVariable, devices)
    add_variables!(optimization_container, DeltaActivePowerDownVariable, devices)
    add_variables!(optimization_container, AdditionalDeltaActivePowerUpVariable, devices)
    add_variables!(optimization_container, AdditionalDeltaActivePowerDownVariable, devices)

    # Constraints
    nodal_expression!(optimization_container, devices, S)
    add_constraints!(
        optimization_container,
        RangeConstraint,
        DeltaActivePowerUpVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        DeltaActivePowerDownVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    participation_assignment!(optimization_container, devices, model, S, nothing)
    regulation_cost!(optimization_container, devices, model)
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, FixedOutput},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(model.component_type, sys)
    if !validate_available_devices(T, devices)
        return
    end
    nodal_expression!(optimization_container, devices, S)
    return
end
