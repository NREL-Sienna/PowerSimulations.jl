function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
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
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, InterruptiblePowerLoad())
    add_variables!(container, ReactivePowerVariable, devices, InterruptiblePowerLoad())
    add_variables!(container, OnVariable, devices, InterruptiblePowerLoad())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
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
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
        return
    end

    # Variables
    add_variables!(container, ActivePowerVariable, devices, InterruptiblePowerLoad())
    add_variables!(container, OnVariable, devices, InterruptiblePowerLoad())

    # Constraints
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(container, devices, model, S)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S},
) where {L <: PSY.ElectricLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
        return
    end

    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )
    nodal_expression!(
        container,
        devices,
        ReactivePowerTimeSeriesParameter("max_active_power"),
    )

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S},
) where {L <: PSY.ElectricLoad, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(L, sys)

    if !validate_available_devices(L, devices)
        return
    end

    nodal_expression!(
        container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.StaticLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    if D != StaticPowerLoad
        @warn(
            "The Formulation $(D) only applies to FormulationControllable Loads, \n Consider Changing the Device Formulation to StaticPowerLoad"
        )
    end

    construct_device!(container, sys, DeviceModel(L, StaticPowerLoad), S)
    return
end
