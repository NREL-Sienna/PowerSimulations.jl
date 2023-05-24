function get_default_time_series_names(
    ::Type{PSY.TransmissionInterface},
    ::Type{ConstantMaxInterfaceFlow},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_attributes(
    ::Type{<:PSY.TransmissionInterface},
    ::Type{ConstantMaxInterfaceFlow})
    return Dict{String, Any}()
end

function get_initial_conditions_service_model(
    ::OperationModel,
    ::ServiceModel{T, D},
) where {T <: PSY.TransmissionInterface, D <: ConstantMaxInterfaceFlow}
    return ServiceModel(T, D)
end

function add_constraints!(container::OptimizationContainer,
    ::Type{InterfaceFlowLimit},
    interface::T,
    model::ServiceModel{T, ConstantMaxInterfaceFlow},
) where {T <: PSY.TransmissionInterface}
    expr = get_expression(container, InterfaceTotalFlow(), T)
    interfaces, timesteps = axes(expr)
    constraint_container_ub = lazy_container_addition!(
        container,
        InterfaceFlowLimit(),
        T,
        interfaces,
        timesteps;
        meta = "ub",
    )
    constraint_container_lb = lazy_container_addition!(
        container,
        InterfaceFlowLimit(),
        T,
        interfaces,
        timesteps;
        meta = "lb",
    )
    int_name = PSY.get_name(interface)
    min_flow, max_flow = PSY.get_active_power_flow_limits(interface)
    for t in timesteps
        constraint_container_ub[int_name, t] =
            JuMP.@constraint(get_jump_model(container), expr[int_name, t] <= max_flow)
        constraint_container_lb[int_name, t] =
            JuMP.@constraint(get_jump_model(container), expr[int_name, t] >= min_flow)
    end
    return
end
