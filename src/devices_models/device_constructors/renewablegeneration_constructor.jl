function initialize_timeseries_names(
    ::Type{<:PSY.RenewableGen},
    ::Type{<:Union{FixedOutput, AbstractRenewableFormulation}},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        ActivePowerTimeSeriesParameter => "max_active_power",
        ReactivePowerTimeSeriesParameter => "max_active_power",
    )
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, D},
    ::Type{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(R, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())

    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_parameters!(container, ReactivePowerTimeSeriesParameter, devices, model)

    # Expression
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerVariable,
        devices,
        model,
        S,
    )
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{R, D},
    ::Type{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(R, sys)
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

    add_constraint_dual!(container, sys, model)
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, D},
    ::Type{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(R, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    # Expression
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        S,
    )
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{R, D},
    ::Type{S},
) where {
    R <: PSY.RenewableGen,
    D <: AbstractRenewableDispatchFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(R, sys)

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

    add_constraint_dual!(container, sys, model)

    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    ::DeviceModel{R, FixedOutput},
    ::Type{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerModel}
    devices = get_available_components(R, sys)

    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_parameters!(container, ReactivePowerTimeSeriesParameter, devices, model)

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance,
        ReactivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{R, FixedOutput},
    ::Type{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(R, sys)
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerTimeSeriesParameter,
        devices,
        model,
        S,
    )
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{R, FixedOutput},
    ::Type{S},
) where {R <: PSY.RenewableGen, S <: PM.AbstractPowerModel}
    # FixedOutput doesn't add any constraints to the model. This function covers
    # AbstractPowerModel and AbtractActivePowerModel
    return
end
