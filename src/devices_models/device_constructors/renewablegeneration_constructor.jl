function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{R, D},
    ::Type{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(R, sys)

    if !validate_available_devices(R, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices, D())
    add_variables!(optimization_container, ReactivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    add_constraints!(
        optimization_container,
        ReactivePowerVariableLimitsConstraint,
        ReactivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S)

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{R, D},
    ::Type{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(R, sys)

    if !validate_available_devices(R, devices)
        return
    end

    # Variables
    add_variables!(optimization_container, ActivePowerVariable, devices, D())

    # Constraints
    add_constraints!(
        optimization_container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerVariable,
        devices,
        model,
        S,
        get_feedforward(model),
    )
    feedforward!(optimization_container, devices, model, get_feedforward(model))

    # Cost Function
    cost_function!(optimization_container, devices, model, S)

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::DeviceModel{R, FixedOutput},
    ::Type{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(R, sys)

    if !validate_available_devices(R, devices)
        return
    end

    nodal_expression!(
        optimization_container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )
    nodal_expression!(
        optimization_container,
        devices,
        ReactivePowerTimeSeriesParameter("max_active_power"),
    )

    return
end

function construct_device!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::DeviceModel{R, FixedOutput},
    ::Type{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(R, sys)

    if !validate_available_devices(R, devices)
        return
    end

    nodal_expression!(
        optimization_container,
        devices,
        ActivePowerTimeSeriesParameter("max_active_power"),
    )

    return
end
