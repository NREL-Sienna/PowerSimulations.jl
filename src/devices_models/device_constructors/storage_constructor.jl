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
    add_variables!(optimization_container, ActivePowerInVariable, devices, D())
    add_variables!(optimization_container, ActivePowerOutVariable, devices, D())
    add_variables!(optimization_container, ReactivePowerVariable, devices, D())
    add_variables!(optimization_container, EnergyVariable, devices, D())

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

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
    add_variables!(optimization_container, ActivePowerInVariable, devices, D())
    add_variables!(optimization_container, ActivePowerOutVariable, devices, D())
    add_variables!(optimization_container, EnergyVariable, devices, D())

    # Initial Conditions
    initial_conditions!(optimization_container, devices, D())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
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
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerInVariable,
        devices,
        BookKeepingwReservation(),
    )
    add_variables!(
        optimization_container,
        ActivePowerOutVariable,
        devices,
        BookKeepingwReservation(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        BookKeepingwReservation(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        BookKeepingwReservation(),
    )
    add_variables!(
        optimization_container,
        ReserveVariable,
        devices,
        BookKeepingwReservation(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, BookKeepingwReservation())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
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
    add_variables!(
        optimization_container,
        ActivePowerInVariable,
        devices,
        BookKeepingwReservation(),
    )
    add_variables!(
        optimization_container,
        ActivePowerOutVariable,
        devices,
        BookKeepingwReservation(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        BookKeepingwReservation(),
    )
    add_variables!(
        optimization_container,
        ReserveVariable,
        devices,
        BookKeepingwReservation(),
    )

    # Initial Conditions
    initial_conditions!(optimization_container, devices, BookKeepingwReservation())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables

    add_variables!(optimization_container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(optimization_container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(optimization_container, ReactivePowerVariable, devices, EnergyTarget())
    add_variables!(optimization_container, EnergyVariable, devices, EnergyTarget())
    add_variables!(optimization_container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(optimization_container, EnergySurplusVariable, devices, EnergyTarget())
    add_variables!(optimization_container, ReserveVariable, devices, EnergyTarget())
    # Initial Conditions
    initial_conditions!(optimization_container, devices, EnergyTarget())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(
        optimization_container,
        devices,
        model,
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
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(optimization_container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(optimization_container, EnergyVariable, devices, EnergyTarget())
    add_variables!(optimization_container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(optimization_container, EnergySurplusVariable, devices, EnergyTarget())
    add_variables!(optimization_container, ReserveVariable, devices, EnergyTarget())
    # Initial Conditions
    initial_conditions!(optimization_container, devices, EnergyTarget())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_target_constraint!(
        optimization_container,
        devices,
        model,
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
    model::DeviceModel{St, BatteryAncialliryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerInVariable,
        devices,
        BatteryAncialliryServices(),
    )
    add_variables!(
        optimization_container,
        ActivePowerOutVariable,
        devices,
        BatteryAncialliryServices(),
    )
    add_variables!(
        optimization_container,
        ReactivePowerVariable,
        devices,
        BatteryAncialliryServices(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        BatteryAncialliryServices(),
    )
    add_variables!(
        optimization_container,
        ReserveVariable,
        devices,
        BatteryAncialliryServices(),
    )
    # Initial Conditions
    initial_conditions!(optimization_container, devices, BatteryAncialliryServices())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    reserve_contribution_constraint!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, BatteryAncialliryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(
        optimization_container,
        ActivePowerInVariable,
        devices,
        BatteryAncialliryServices(),
    )
    add_variables!(
        optimization_container,
        ActivePowerOutVariable,
        devices,
        BatteryAncialliryServices(),
    )
    add_variables!(
        optimization_container,
        EnergyVariable,
        devices,
        BatteryAncialliryServices(),
    )
    add_variables!(
        optimization_container,
        ReserveVariable,
        devices,
        BatteryAncialliryServices(),
    )
    # Initial Conditions
    initial_conditions!(optimization_container, devices, BatteryAncialliryServices())

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
    energy_capacity_constraints!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        optimization_container,
        EnergyBalanceConstraint,
        EnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    reserve_contribution_constraint!(
        optimization_container,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    return
end
