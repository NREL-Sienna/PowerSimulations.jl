function construct_device!(
    psi_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, PhysicalCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices, PhysicalCoupling())
    add_variables!(psi_container, ActivePowerOutVariable, devices, PhysicalCoupling())

    add_variables!(
        psi_container,
        SubComponentActivePowerInVariable,
        devices,
        PhysicalCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerOutVariable,
        devices,
        PhysicalCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerVariable,
        devices,
        PhysicalCoupling(),
    )
    add_variables!(psi_container, SubComponentEnergyVariable, devices, PhysicalCoupling())

    # Initial Conditions
    initial_conditions!(psi_container, devices, PhysicalCoupling())

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
        ThermalRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    add_constraints!(
        psi_container,
        EnergyBalanceConstraint,
        SubComponentEnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, PhysicalCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices, PhysicalCoupling())
    add_variables!(psi_container, ActivePowerOutVariable, devices, PhysicalCoupling())
    add_variables!(psi_container, ReactivePowerVariable, devices, PhysicalCoupling())

    add_variables!(
        psi_container,
        SubComponentActivePowerInVariable,
        devices,
        PhysicalCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerOutVariable,
        devices,
        PhysicalCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerVariable,
        devices,
        PhysicalCoupling(),
    )
    add_variables!(psi_container, SubComponentEnergyVariable, devices, PhysicalCoupling())

    add_variables!(
        psi_container,
        SubComponentReactivePowerVariable,
        devices,
        PhysicalCoupling(),
    )
    # Initial Conditions
    initial_conditions!(psi_container, devices, PhysicalCoupling())

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
        ThermalRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentActivePowerVariable,
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
        ThermalRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        StorageRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Constraints
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    add_constraints!(
        psi_container,
        EnergyBalanceConstraint,
        SubComponentEnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S, get_feedforward(model))
    invertor_rating_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, FinancialCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices, FinancialCoupling())
    add_variables!(psi_container, ActivePowerOutVariable, devices, FinancialCoupling())

    add_variables!(
        psi_container,
        SubComponentActivePowerInVariable,
        devices,
        FinancialCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerOutVariable,
        devices,
        FinancialCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerVariable,
        devices,
        FinancialCoupling(),
    )
    add_variables!(psi_container, SubComponentEnergyVariable, devices, FinancialCoupling())
    # Initial Conditions
    initial_conditions!(psi_container, devices, FinancialCoupling())

    # Constraints
    add_constraints!(
        psi_container,
        ThermalRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Constraints
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    add_constraints!(
        psi_container,
        EnergyBalanceConstraint,
        SubComponentEnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, FinancialCoupling},
    ::Type{S},
) where {T <: PSY.HybridSystem, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices, FinancialCoupling())
    add_variables!(psi_container, ActivePowerOutVariable, devices, FinancialCoupling())
    add_variables!(psi_container, ReactivePowerVariable, devices, FinancialCoupling())

    add_variables!(
        psi_container,
        SubComponentActivePowerInVariable,
        devices,
        FinancialCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerOutVariable,
        devices,
        FinancialCoupling(),
    )
    add_variables!(
        psi_container,
        SubComponentActivePowerVariable,
        devices,
        FinancialCoupling(),
    )
    add_variables!(psi_container, SubComponentEnergyVariable, devices, FinancialCoupling())

    add_variables!(
        psi_container,
        SubComponentReactivePowerVariable,
        devices,
        FinancialCoupling(),
    )

    # Initial Conditions
    initial_conditions!(psi_container, devices, FinancialCoupling())

    # Constraints
    add_constraints!(
        psi_container,
        ThermalRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentActivePowerVariable,
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
        ThermalRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        StorageRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Constraints
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    add_constraints!(
        psi_container,
        EnergyBalanceConstraint,
        SubComponentEnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {
    T <: PSY.HybridSystem,
    D <: AbstractHybridFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices, D())
    add_variables!(psi_container, ActivePowerOutVariable, devices, D())

    add_variables!(psi_container, SubComponentActivePowerInVariable, devices, D())
    add_variables!(psi_container, SubComponentActivePowerOutVariable, devices, D())
    add_variables!(psi_container, SubComponentActivePowerVariable, devices, D())
    add_variables!(psi_container, SubComponentEnergyVariable, devices, D())
    # Initial Conditions
    initial_conditions!(psi_container, devices, D())

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
        ThermalRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    add_constraints!(
        psi_container,
        EnergyBalanceConstraint,
        SubComponentEnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end

function construct_device!(
    psi_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
    ::Type{S},
) where {T <: PSY.HybridSystem, D <: AbstractHybridFormulation, S <: PM.AbstractPowerModel}
    devices = get_available_components(T, sys)

    if !validate_available_devices(T, devices)
        return
    end

    # Variables
    add_variables!(psi_container, ActivePowerInVariable, devices, D())
    add_variables!(psi_container, ActivePowerOutVariable, devices, D())
    add_variables!(psi_container, ReactivePowerVariable, devices, D())

    add_variables!(psi_container, SubComponentActivePowerInVariable, devices, D())
    add_variables!(psi_container, SubComponentActivePowerOutVariable, devices, D())
    add_variables!(psi_container, SubComponentActivePowerVariable, devices, D())
    add_variables!(psi_container, SubComponentEnergyVariable, devices, D())

    add_variables!(psi_container, SubComponentReactivePowerVariable, devices), D()

    # Initial Conditions
    initial_conditions!(psi_container, devices, D())

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
        ThermalRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerInVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RangeConstraint,
        SubComponentActivePowerOutVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentActivePowerVariable,
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
        ThermalRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        ElectricLoadRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        StorageRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        psi_container,
        RenewableGenRangeConstraint,
        SubComponentReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )

    # Constraints
    energy_capacity_constraints!(psi_container, devices, model, S, get_feedforward(model))
    add_constraints!(
        psi_container,
        EnergyBalanceConstraint,
        SubComponentEnergyVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    power_inflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    power_outflow_constraints!(psi_container, devices, model, S, get_feedforward(model))
    reactive_power_constraints!(psi_container, devices, model, S, get_feedforward(model))
    invertor_rating_constraints!(psi_container, devices, model, S, get_feedforward(model))
    feedforward!(psi_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(psi_container, devices, model, S, get_feedforward(model))

    return
end
