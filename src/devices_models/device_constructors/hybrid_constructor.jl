"""
This function creates the model for a full thermal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, NoCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices)
    add_variables!(psi_container, ActivePowerOutVariable, devices)

    add_variables!(psi_container, ActivePowerVariableThermal, devices)
    add_variables!(psi_container, ActivePowerVariableLoad, devices)
    add_variables!(psi_container, ActivePowerInVariableStorage, devices)
    add_variables!(psi_container, ActivePowerOutVariableStorage, devices)
    add_variables!(psi_container, ActivePowerVariableRenewable, devices)
    add_variables!(psi_container, EnergyVariable, devices)
    # Initial Conditions
    initial_conditions!(psi_container, devices, NoCoupling)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableThermal,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableLoad,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableRenewable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_balance_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end


function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, NoCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, S <: PM.AbstractPowerModel}
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
    add_variables!(psi_container, EnergyVariable, devices)

    add_variables!(psi_container, ReactivePowerVariableThermal, devices)
    add_variables!(psi_container, ReactivePowerVariableLoad, devices)
    add_variables!(psi_container, ReactivePowerVariableStorage, devices)
    add_variables!(psi_container, ReactivePowerVariableRenewable, devices)

    # Initial Conditions
    initial_conditions!(psi_container, devices, NoCoupling)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableThermal,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableLoad,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableRenewable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Reactive power Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableThermal,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableLoad,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableRenewable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_balance_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, PhysicalCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices)
    add_variables!(psi_container, ActivePowerOutVariable, devices)

    add_variables!(psi_container, ActivePowerVariableThermal, devices)
    add_variables!(psi_container, ActivePowerVariableLoad, devices)
    add_variables!(psi_container, ActivePowerInVariableStorage, devices)
    add_variables!(psi_container, ActivePowerOutVariableStorage, devices)
    add_variables!(psi_container, ActivePowerVariableRenewable, devices)
    add_variables!(psi_container, EnergyVariable, devices)
    # Initial Conditions
    initial_conditions!(psi_container, devices, PhysicalCoupling)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableThermal,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableLoad,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableRenewable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_balance_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    invertor_rating_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::PSIContainer,
    sys::PSY.System,
    model::DeviceModel{T, PhysicalCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, D <: Union{PhysicalCoupling, StandardHybridFormulation}, S <: PM.AbstractPowerModel}
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
    add_variables!(psi_container, EnergyVariable, devices)

    add_variables!(psi_container, ReactivePowerVariableThermal, devices)
    add_variables!(psi_container, ReactivePowerVariableLoad, devices)
    add_variables!(psi_container, ReactivePowerVariableStorage, devices)
    add_variables!(psi_container, ReactivePowerVariableRenewable, devices)
    # Initial Conditions
    initial_conditions!(psi_container, devices, PhysicalCoupling)

    # Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableThermal,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableLoad,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerInVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerOutVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ActivePowerVariableRenewable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Reactive power Constraints
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableThermal,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableLoad,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableStorage,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        ReactivePowerVariableRenewable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    energy_balance_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S, get_feedforward(model))
    invertor_rating_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end
