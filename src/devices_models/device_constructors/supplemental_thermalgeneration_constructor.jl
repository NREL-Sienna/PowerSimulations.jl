"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, SupplementalThermalStandardUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalStandardUnitCommitment}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))
    
    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, SupplementalThermalStandardUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalStandardUnitCommitment}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end
"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, SupplementalThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalBasicUnitCommitment}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, SupplementalThermalBasicUnitCommitment},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalBasicUnitCommitment}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, SupplementalThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerModel}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalRampLimited}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, SupplementalThermalRampLimited},
    ::Type{S},
) where {T <: PSY.ThermalGen, S <: PM.AbstractActivePowerModel}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalRampLimited}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: SupplementalThermalDispatch,
    S <: PM.AbstractPowerModel,
}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalDispatch}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: SupplementalThermalDispatch,
    S <: PM.AbstractActivePowerModel,
}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalDispatch}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: SupplementalThermalDispatchNoMin,
    S <: PM.AbstractPowerModel,
}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalDispatchNoMin}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.ThermalGen,
    D <: SupplementalThermalDispatchNoMin,
    S <: PM.AbstractActivePowerModel,
}
    construct_device!(
        psi_container,
        sys,
        DeviceModel{T, ThermalDispatchNoMin}(),
        Type{S}
    )
    devices = get_available_components(T, sys)
    offline_activepower_constraints!(psi_container, devices, model, S, get_feedforward(model))

    return
end
