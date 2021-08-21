function add_constraint_dual!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::DeviceModel{T, D},
) where {T <: PSY.Component, D <: AbstractDeviceFormulation}
    if !isempty(get_duals(model))
        devices = get_available_components(T, sys)
        for constraint_type in get_duals(model)
            assign_dual_variable!(container, constraint_type, devices, D)
        end
    end
    return
end

function add_constraint_dual!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
) where {T <: PM.AbstractPowerModel}
    if !isempty(get_duals(model))
        devices = PSY.get_components(PSY.Bus, sys)
        for constraint_type in get_duals(model)
            assign_dual_variable!(container, constraint_type, devices, T)
        end
    end
    return
end

function add_constraint_dual!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
) where {T <: Union{CopperPlatePowerModel, StandardPTDFModel}}
    if !isempty(get_duals(model))
        for constraint_type in get_duals(model)
            assign_dual_variable!(container, constraint_type, sys, T)
        end
    end
    return
end

function add_constraint_dual!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::ServiceModel{T, D},
) where {T <: PSY.Service, D <: AbstractServiceFormulation}
    return
end

function assign_dual_variable!(
    container::OptimizationContainer,
    constraint_type::Type{<:ConstraintType},
    devices::U,
    formulation,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    add_dual_container!(
        container,
        constraint_type,
        D,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )
    return
end

function assign_dual_variable!(
    container::OptimizationContainer,
    constraint_type::Type{<:ConstraintType},
    sys::U,
    formulation,
) where {U <: PSY.System}
    time_steps = get_time_steps(container)
    add_dual_container!(container, constraint_type, U, time_steps)
    return
end

function _calculate_dual_variable_value!(
    container::OptimizationContainer,
    key::ConstraintKey{CopperPlateBalanceConstraint, D},
    ::PSY.System,
) where {D <: Union{PSY.Component, PSY.System}}
    constraint_container = get_constraint(container, key)
    dual_var_container = get_duals(container)[key]

    for t in constraint_container.axes[1]
        dual_var_container[t] = JuMP.dual(constraint_container[t])
    end
    return
end

function _calculate_dual_variable_value!(
    container::OptimizationContainer,
    key,
    ::PSY.System,
)
    constraint_container = get_constraint(container, key)
    dual_var_container = get_duals(container)[key]

    for name in constraint_container.axes[1], t in constraint_container.axes[2]
        dual_var_container[name, t] = JuMP.dual(constraint_container[name, t])
    end
    return
end
