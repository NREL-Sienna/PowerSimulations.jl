"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, DeviceLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(model.device_type, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    add_variables!(DeltaActivePowerUpVariable, psi_container, devices)
    add_variables!(DeltaActivePowerDownVariable, psi_container, devices)
    add_variables!(AdditionalDeltaActivePowerUpVariable, psi_container, devices)
    add_variables!(AdditionalDeltaActivePowerDownVariable, psi_container, devices)

    #Constraints
    nodal_expression!(psi_container, devices, S)
    add_constraints!(
        RangeConstraint,
        DeltaActivePowerUpVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        RangeConstraint,
        DeltaActivePowerDownVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    ramp_constraints!(psi_container, devices, model, S, get_feedforward(model))
    participation_assignment!(psi_container, devices, model, S, nothing)
    regulation_cost!(psi_container, devices, model)
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, ReserveLimitedRegulation},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(model.device_type, sys)

    if !validate_available_devices(T, devices)
        return
    end

    #Variables
    add_variables!(DeltaActivePowerUpVariable, psi_container, devices)
    add_variables!(DeltaActivePowerDownVariable, psi_container, devices)
    add_variables!(AdditionalDeltaActivePowerUpVariable, psi_container, devices)
    add_variables!(AdditionalDeltaActivePowerDownVariable, psi_container, devices)

    #Constraints
    nodal_expression!(psi_container, devices, S)
    add_constraints!(
        RangeConstraint,
        DeltaActivePowerUpVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        RangeConstraint,
        DeltaActivePowerDownVariable,
        psi_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    participation_assignment!(psi_container, devices, model, S, nothing)
    regulation_cost!(psi_container, devices, model)
    return
end

"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{PSY.RegulationDevice{T}, FixedOutput},
    ::Type{S},
) where {T <: PSY.StaticInjection, S <: PM.AbstractPowerModel}
    if S != AreaBalancePowerModel
        throw(ArgumentError("AGC is only compatible with AreaBalancePowerModel"))
    end

    devices = get_available_components(model.device_type, sys)
    if !validate_available_devices(T, devices)
        return
    end
    nodal_expression!(psi_container, devices, S)
    return
end
