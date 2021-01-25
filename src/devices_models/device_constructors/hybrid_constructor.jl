"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices)
    add_variables!(psi_container, ActivePowerOutVariable, devices)
    add_variables!(psi_container, ReactivePowerVariable, devices)

    add_variables!(psi_container, ActivePowerVariableThermal, devices)
    add_variables!(psi_container, ActivePowerVariableLoad, devices)
    add_variables!(psi_container, ActivePowerInVariableStorage, devices)
    add_variables!(psi_container, ActivePowerOutVariableStorage, devices)
    add_variables!(psi_container, ActivePowerVariableRenewable, devices)

    # Initial Conditions
    initial_conditions!(psi_container, devices, D)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    commitment_constraints!(psi_container, devices, model, S, get_feedforward(model))
    ramp_constraints!(psi_container, devices, model, S, get_feedforward(model))
    time_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end
