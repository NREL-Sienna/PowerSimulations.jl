function initialize_timeseries_labels(
    ::Type{D},
    ::Type{EnergyTarget},
) where {D <: PSY.Storage}
    return Dict{Type{<:TimeSeriesParameter}, String}(
        EnergyTargetTimeSeriesParameter => "storage_target",
    )
end

function initialize_attributes(
    ::Type{D},
    ::Type{T},
) where {D <: PSY.Storage, T <: AbstractStorageFormulation}
    return Dict{String, Any}("reservation" => true)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, D},
    ::Type{S},
) where {St <: PSY.Storage, D <: AbstractStorageFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if apply_reservations(model)
        add_variables!(container, ReservationVariable, devices, D())
    end
    # Initial Conditions
    initial_conditions!(container, devices, D())

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    return
end

function construct_device!(
    container::OptimizationContainer,
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
    add_variables!(container, ActivePowerInVariable, devices, D())
    add_variables!(container, ActivePowerOutVariable, devices, D())
    add_variables!(container, EnergyVariable, devices, D())
    if apply_reservations(model)
        add_variables!(container, ReservationVariable, devices, D())
    end
    # Initial Conditions
    initial_conditions!(container, devices, D())

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(container, ReactivePowerVariable, devices, EnergyTarget())
    add_variables!(container, EnergyVariable, devices, EnergyTarget())
    add_variables!(container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(container, EnergySurplusVariable, devices, EnergyTarget())
    if apply_reservations(model)
        add_variables!(container, ReservationVariable, devices, EnergyTarget())
    end

    # Parameters
    add_parameters!(container, EnergyTargetTimeSeriesParameter, devices, model)

    # Initial Conditions
    initial_conditions!(container, devices, EnergyTarget())

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        EnergyTargetConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, EnergyTarget},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, EnergyTarget())
    add_variables!(container, ActivePowerOutVariable, devices, EnergyTarget())
    add_variables!(container, EnergyVariable, devices, EnergyTarget())
    add_variables!(container, EnergyShortageVariable, devices, EnergyTarget())
    add_variables!(container, EnergySurplusVariable, devices, EnergyTarget())
    if apply_reservations(model)
        add_variables!(container, ReservationVariable, devices, EnergyTarget())
    end

    # Parameters
    add_parameters!(container, EnergyTargetTimeSeriesParameter, devices, model)

    # Initial Conditions
    initial_conditions!(container, devices, EnergyTarget())

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        EnergyTargetConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Cost Function
    cost_function!(container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, BatteryAncillaryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractPowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ActivePowerOutVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ReactivePowerVariable, devices, BatteryAncillaryServices())
    add_variables!(container, EnergyVariable, devices, BatteryAncillaryServices())
    if apply_reservations(model)
        add_variables!(container, ReservationVariable, devices, BatteryAncillaryServices())
    end
    # Initial Conditions
    initial_conditions!(container, devices, BatteryAncillaryServices())

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    reserve_contribution_constraint!(container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{St, BatteryAncillaryServices},
    ::Type{S},
) where {St <: PSY.Storage, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(St, sys)

    if !validate_available_devices(St, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerInVariable, devices, BatteryAncillaryServices())
    add_variables!(container, ActivePowerOutVariable, devices, BatteryAncillaryServices())
    add_variables!(container, EnergyVariable, devices, BatteryAncillaryServices())
    if apply_reservations(model)
        add_variables!(container, ReservationVariable, devices, BatteryAncillaryServices())
    end
    # Initial Conditions
    initial_conditions!(container, devices, BatteryAncillaryServices())

    # Constraints
    add_constraints!(
        container,
        OutputActivePowerVariableLimitsConstraint,
        ActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        container,
        InputActivePowerVariableLimitsConstraint,
        ActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    energy_capacity_constraints!(container, devices, model, S, get_feedforward(model))
    feedforward!(container, devices, model, get_feedforward(model))

    # Energy Balanace limits
    add_constraints!(
        container,
        EnergyBalanceConstraint,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    reserve_contribution_constraint!(container, devices, model, S, get_feedforward(model))

    return
end
