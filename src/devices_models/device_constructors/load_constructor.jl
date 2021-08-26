function initialize_timeseries_names(
    ::Type{<:PSY.ElectricLoad},
    ::Type{<:AbstractLoadFormulation},
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
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(L, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, ReactivePowerVariable, devices, D())
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(L, sys)

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
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(L, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, D())
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.ControllableLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractActivePowerModel,
}
    devices = get_available_components(L, sys)

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
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, InterruptiblePowerLoad())
    add_variables!(container, ReactivePowerVariable, devices, InterruptiblePowerLoad())
    add_variables!(container, OnVariable, devices, InterruptiblePowerLoad())

    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)

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
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(L, sys)

    # Variables
    add_variables!(container, ActivePowerVariable, devices, InterruptiblePowerLoad())
    add_variables!(container, OnVariable, devices, InterruptiblePowerLoad())
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, InterruptiblePowerLoad},
    ::Type{S},
) where {L <: PSY.ControllableLoad, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(L, sys)

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
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S},
) where {L <: PSY.ElectricLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_parameters!(container, ReactivePowerTimeSeriesParameter, devices, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S},
) where {L <: PSY.ElectricLoad, S <: PM.AbstractPowerModel}
    devices = get_available_components(L, sys)
    add_to_expression!(
        container,
        ActivePowerBalance(),
        devices,
        ActivePowerTimeSeriesParameter(),
        S,
    )
    add_to_expression!(
        container,
        ReactivePowerBalance(),
        devices,
        ReactivePowerTimeSeriesParameter(),
        S,
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S},
) where {L <: PSY.ElectricLoad, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(L, sys)
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{L, StaticPowerLoad},
    ::Type{S},
) where {L <: PSY.ElectricLoad, S <: PM.AbstractActivePowerModel}
    devices = get_available_components(L, sys)
    add_to_expression!(
        container,
        ActivePowerBalance(),
        devices,
        ActivePowerTimeSeriesParameter(),
        S,
    )
    return
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{L, D},
    ::Type{S},
) where {
    L <: PSY.StaticLoad,
    D <: AbstractControllablePowerLoadFormulation,
    S <: PM.AbstractPowerModel,
}
    devices = get_available_components(L, sys)
    # Parameters
    add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    add_parameters!(container, ReactivePowerTimeSeriesParameter, devices, model)
end

function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ccs::ModelConstructStage,
    ::DeviceModel{L, D},
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

    construct_device!(container, sys, ccs, DeviceModel(L, StaticPowerLoad), S)
    return
end
