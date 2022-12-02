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
    if !isempty(get_duals(model))
        service = PSY.get_component(T, sys, model.service_name)
        for constraint_type in get_duals(model)
            assign_dual_variable!(container, constraint_type, service, D)
        end
    end
    return
end

function assign_dual_variable!(
    container::OptimizationContainer,
    constraint_type::Type{<:ConstraintType},
    service::D,
    ::Type{<:AbstractServiceFormulation},
) where {D <: PSY.Service}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    add_dual_container!(
        container,
        constraint_type,
        D,
        [service_name],
        time_steps;
        meta=service_name,
    )
    return
end

function assign_dual_variable!(
    container::OptimizationContainer,
    constraint_type::Type{<:ConstraintType},
    devices::U,
    ::Type{<:AbstractDeviceFormulation},
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Device}
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
    devices::U,
    ::Type{<:PM.AbstractPowerModel},
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Bus}
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
    ::U,
    formulation::Type{<:PM.AbstractPowerModel},
) where {U <: PSY.System}
    time_steps = get_time_steps(container)
    add_dual_container!(container, constraint_type, U, time_steps)
    return
end
