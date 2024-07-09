#! format: off
get_variable_binary(_, ::Type{PSY.TransmissionInterface}, ::ConstantMaxInterfaceFlow) = false
get_variable_lower_bound(::InterfaceFlowSlackUp, ::PSY.TransmissionInterface, ::ConstantMaxInterfaceFlow) = 0.0
get_variable_lower_bound(::InterfaceFlowSlackDown, ::PSY.TransmissionInterface, ::ConstantMaxInterfaceFlow) = 0.0

get_variable_multiplier(::InterfaceFlowSlackUp, ::PSY.TransmissionInterface, ::ConstantMaxInterfaceFlow) = 1.0
get_variable_multiplier(::InterfaceFlowSlackDown, ::PSY.TransmissionInterface, ::ConstantMaxInterfaceFlow) = -1.0

get_variable_multiplier(::InterfaceFlowSlackUp, ::PSY.TransmissionInterface, ::VariableMaxInterfaceFlow) = 1.0
get_variable_multiplier(::InterfaceFlowSlackDown, ::PSY.TransmissionInterface, ::VariableMaxInterfaceFlow) = -1.0

get_multiplier_value(::MinInterfaceFlowLimitParameter, d::PSY.TransmissionInterface, ::VariableMaxInterfaceFlow) = PSY.get_min_active_power_flow_limit(d)
get_multiplier_value(::MaxInterfaceFlowLimitParameter, d::PSY.TransmissionInterface, ::VariableMaxInterfaceFlow) = PSY.get_max_active_power_flow_limit(d)

#! format: On
function get_default_time_series_names(
    ::Type{PSY.TransmissionInterface},
    ::Type{ConstantMaxInterfaceFlow},
)
    return Dict{Type{<:TimeSeriesParameter}, String}()
end

function get_default_time_series_names(
    ::Type{PSY.TransmissionInterface},
    ::Type{VariableMaxInterfaceFlow},
)
    return Dict{Type{<:TimeSeriesParameter}, String}(
        MinInterfaceFlowLimitParameter => "min_active_power_flow_limit",
        MaxInterfaceFlowLimitParameter => "max_active_power_flow_limit",
    )
end

function get_default_attributes(
    ::Type{<:PSY.TransmissionInterface},
    ::Type{ConstantMaxInterfaceFlow})
    return Dict{String, Any}()
end

function get_default_attributes(
    ::Type{<:PSY.TransmissionInterface},
    ::Type{VariableMaxInterfaceFlow})
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

function add_constraints!(container::OptimizationContainer,
    ::Type{InterfaceFlowLimit},
    interface::T,
    model::ServiceModel{T, VariableMaxInterfaceFlow},
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
    param_container_min =
        get_parameter(container, MinInterfaceFlowLimitParameter(), PSY.TransmissionInterface, int_name)
    param_multiplier_min = get_parameter_multiplier_array(
        container,
        MinInterfaceFlowLimitParameter(),
        PSY.TransmissionInterface,
        int_name,
    )
    param_container_max =
        get_parameter(container, MaxInterfaceFlowLimitParameter(), PSY.TransmissionInterface, int_name)
    param_multiplier_max = get_parameter_multiplier_array(
        container,
        MaxInterfaceFlowLimitParameter(),
        PSY.TransmissionInterface,
        int_name,
    )
    param_min = get_parameter_column_refs(param_container_min, int_name)
    param_max = get_parameter_column_refs(param_container_max, int_name)
    for t in timesteps
        constraint_container_ub[int_name, t] =
            JuMP.@constraint(get_jump_model(container), expr[int_name, t] <= param_multiplier_max[int_name, t] * param_max[t])
        constraint_container_lb[int_name, t] =
            JuMP.@constraint(get_jump_model(container), expr[int_name, t] >= param_multiplier_min[int_name, t] * param_min[t])
    end
    return
end

function objective_function!(
    container::OptimizationContainer,
    service::T,
    model::ServiceModel{T, U},
) where {T <: PSY.TransmissionInterface, U <: Union{ConstantMaxInterfaceFlow, VariableMaxInterfaceFlow}}
    # At the moment the interfaces have no costs associated with them
    return
end
