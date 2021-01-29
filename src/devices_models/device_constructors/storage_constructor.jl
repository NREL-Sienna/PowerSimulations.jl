function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, D},
    ::Type{S},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerInVariable, devices)
    add_variables!(optimization_container, ActivePowerOutVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    add_variables!(optimization_container, EnergyVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(optimization_container, devices, D, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, D},
    ::Type{S},
) where {
    St <: PSY.Storage,
    D <: AbstractStorageFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerInVariable, devices)
    add_variables!(optimization_container, ActivePowerOutVariable, devices)
    add_variables!(optimization_container, EnergyVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(optimization_container, devices, D, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, BookKeepingwReservation},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerInVariable, devices)
    add_variables!(optimization_container, ActivePowerOutVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    add_variables!(optimization_container, EnergyVariable, devices)
    add_variables!(optimization_container, ReserveVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(
        optimization_container,
        devices,
        model.formulation,
        S,
        get_feedforward(model),
    )

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, BookKeepingwReservation},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerInVariable, devices)
    add_variables!(optimization_container, ActivePowerOutVariable, devices)
    add_variables!(optimization_container, EnergyVariable, devices)
    add_variables!(optimization_container, ReserveVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(
        optimization_container,
        devices,
        model.formulation,
        S,
        get_feedforward(model),
    )

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, EndOfPeriodEnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerInVariable, devices)
    add_variables!(optimization_container, ActivePowerOutVariable, devices)
    add_variables!(optimization_container, ReactivePowerVariable, devices)
    add_variables!(optimization_container, EnergyVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(
        optimization_container,
        devices,
        model.formulation,
        S,
        get_feedforward(model),
    )

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, EndOfPeriodEnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerInVariable, devices)
    add_variables!(optimization_container, ActivePowerOutVariable, devices)
    add_variables!(optimization_container, EnergyVariable, devices)

    # Initial Conditions
    initial_conditions!(optimization_container, devices, model.formulation)

    # Constraints
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        RangeConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(optimization_container, devices, model, S, get_feedforward(model))
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    energy_balance_constraint!(
        optimization_container,
        devices,
        model.formulation,
        S,
        get_feedforward(model),
    )

    # Cost Function
    cost_function!(optimization_container, devices, model, S, get_feedforward(model))

    return
end
