function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{V},
) where {V <: PSY.Component}
    for ff in get_feedforwards(model)
        @debug "constraints" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        add_feedforward_constraints!(container, model, devices, ff)
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::ServiceModel{V, <:AbstractReservesFormulation},
    ::V,
) where {V <: PSY.AbstractReserve}
    for ff in get_feedforwards(model)
        @debug "constraints" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        contributing_devices = get_contributing_devices(model)
        add_feedforward_constraints!(container, model, contributing_devices, ff)
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::ServiceModel,
    ::V,
) where {V <: PSY.Service}
    for ff in get_feedforwards(model)
        @debug "constraints" ff V _group = LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
        contributing_devices = get_contributing_devices(model)
        add_feedforward_constraints!(container, model, contributing_devices, ff)
    end
    return
end

function _add_feedforward_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    param::P,
    ::VariableKey{U, V},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel,
) where {
    T <: ConstraintType,
    P <: ParameterType,
    U <: VariableType,
    V <: PSY.Component,
}
    time_steps = get_time_steps(container)
    names = PSY.get_name.(devices)
    constraint_lb =
        add_constraints_container!(container, T(), V, names, time_steps; meta = "$(U)_lb")
    constraint_ub =
        add_constraints_container!(container, T(), V, names, time_steps; meta = "$(U)_ub")
    array = get_variable(container, U(), V)
    upper_bound_range_with_parameter!(
        container,
        constraint_ub,
        array,
        param,
        devices,
        model,
    )
    lower_bound_range_with_parameter!(
        container,
        constraint_lb,
        array,
        param,
        devices,
        model,
    )
    return
end

function _add_sc_feedforward_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::P,
    ::VariableKey{U, V},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: FeedforwardSemiContinuousConstraint,
    P <: OnStatusParameter,
    U <: Union{ActivePowerVariable, PowerAboveMinimumVariable},
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = PSY.get_name.(devices)
    constraint_lb =
        add_constraints_container!(container, T(), V, names, time_steps; meta = "$(U)_lb")
    constraint_ub =
        add_constraints_container!(container, T(), V, names, time_steps; meta = "$(U)_ub")
    array_lb = get_expression(container, ActivePowerRangeExpressionLB(), V)
    array_ub = get_expression(container, ActivePowerRangeExpressionUB(), V)
    parameter = get_parameter_array(container, P(), V)
    mult_ub = DenseAxisArray(zeros(length(devices), time_steps[end]), names, time_steps)
    mult_lb = DenseAxisArray(zeros(length(devices), time_steps[end]), names, time_steps)
    jump_model = get_jump_model(container)
    _upper_bound_range_with_parameter!(
        jump_model,
        constraint_ub,
        array_ub,
        mult_ub,
        parameter,
        devices,
    )
    _lower_bound_range_with_parameter!(
        jump_model,
        constraint_lb,
        array_lb,
        mult_lb,
        parameter,
        devices,
    )
    return
end

function _add_sc_feedforward_constraints!(
    container::OptimizationContainer,
    ::Type{T},
    ::P,
    ::VariableKey{U, V},
    devices::IS.FlattenIteratorWrapper{V},
    model::DeviceModel{V, W},
) where {
    T <: FeedforwardSemiContinuousConstraint,
    P <: ParameterType,
    U <: VariableType,
    V <: PSY.Component,
    W <: AbstractDeviceFormulation,
}
    time_steps = get_time_steps(container)
    names = PSY.get_name.(devices)
    constraint_lb =
        add_constraints_container!(container, T(), V, names, time_steps; meta = "$(U)_lb")
    constraint_ub =
        add_constraints_container!(container, T(), V, names, time_steps; meta = "$(U)_ub")
    variable = get_variable(container, U(), V)
    parameter = get_parameter_array(container, P(), V)
    upper_bounds = [get_variable_upper_bound(U(), d, W()) for d in devices]
    lower_bounds = [get_variable_lower_bound(U(), d, W()) for d in devices]
    if any(isnothing.(upper_bounds)) || any(isnothing.(lower_bounds))
        throw(IS.InvalidValueError("Bounds for variable $U $V not defined correctly"))
    end
    mult_ub = DenseAxisArray(repeat(upper_bounds, 1, time_steps[end]), names, time_steps)
    mult_lb = DenseAxisArray(repeat(lower_bounds, 1, time_steps[end]), names, time_steps)
    jump_model = get_jump_model(container)
    _upper_bound_range_with_parameter!(
        jump_model,
        constraint_ub,
        variable,
        mult_ub,
        parameter,
        devices,
    )
    _lower_bound_range_with_parameter!(
        jump_model,
        constraint_lb,
        variable,
        mult_lb,
        parameter,
        devices,
    )
    return
end

function _lower_bound_range_with_parameter!(
    jump_model::JuMP.Model,
    constraint_container::JuMPConstraintArray,
    lhs_array,
    param_multiplier::JuMPFloatArray,
    param_array::Union{JuMPVariableArray, JuMPFloatArray},
    devices::IS.FlattenIteratorWrapper{V},
) where {V <: PSY.Component}
    time_steps = axes(constraint_container)[2]
    for device in devices
        if hasmethod(PSY.get_must_run, Tuple{V})
            PSY.get_must_run(device) && continue
        end
        name = PSY.get_name(device)
        for t in time_steps
            constraint_container[name, t] = JuMP.@constraint(
                jump_model,
                lhs_array[name, t] >= param_multiplier[name, t] * param_array[name, t]
            )
        end
    end
    return
end

function _upper_bound_range_with_parameter!(
    jump_model::JuMP.Model,
    constraint_container::JuMPConstraintArray,
    lhs_array,
    param_multiplier::JuMPFloatArray,
    param_array::Union{JuMPVariableArray, JuMPFloatArray},
    devices::IS.FlattenIteratorWrapper{V},
) where {V <: PSY.Component}
    time_steps = axes(constraint_container)[2]
    for device in devices
        if hasmethod(PSY.get_must_run, Tuple{V})
            PSY.get_must_run(device) && continue
        end
        name = PSY.get_name(device)
        for t in time_steps
            constraint_container[name, t] = JuMP.@constraint(
                jump_model,
                lhs_array[name, t] <= param_multiplier[name, t] * param_array[name, t]
            )
        end
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::SemiContinuousFeedforward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    time_steps = get_time_steps(container)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        axes = JuMP.axes(variable)
        @assert issetequal(axes[1], PSY.get_name.(devices))
        IS.@assert_op axes[2] == time_steps
        # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
        for v in variable
            if JuMP.has_lower_bound(v) && JuMP.lower_bound(v) > 0.0
                @debug "lb reset" JuMP.lower_bound(v) v _group =
                    LOG_GROUP_FEEDFORWARDS_CONSTRUCTION
                JuMP.set_lower_bound(v, 0.0)
            end
        end
        _add_sc_feedforward_constraints!(
            container,
            FeedforwardSemiContinuousConstraint,
            parameter_type(),
            var,
            devices,
            model,
        )
    end
    return
end

@doc raw"""
        ub_ff(container::OptimizationContainer,
              cons_name::Symbol,
              constraint_infos,
              param_reference,
              var_key::VariableKey)

Constructs a parameterized upper bound constraint to implement feedforward from other models.
The Parameters are initialized using the uppper boundary values of the provided variables.


``` variable[var_name, t] <= param_reference[var_name] ```

# LaTeX

`` x \leq param^{max}``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the JuMP.VariableRef used to determine the upperbound
* var_key::VariableKey : the name of the continuous variable
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::IS.FlattenIteratorWrapper{T},
    ff::UpperBoundFeedforward,
) where {T <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type(), T)
    multiplier_ub = get_parameter_multiplier_array(container, parameter_type(), T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        @assert issetequal(set_name, PSY.get_name.(devices))
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardUpperBoundConstraint(),
            T,
            set_name,
            time_steps;
            meta = "$(var_type)ub",
        )

        for t in time_steps, name in set_name
            con_ub[name, t] = JuMP.@constraint(
                container.JuMPmodel,
                variable[name, t] <= param_ub[name, t] * multiplier_ub[name, t]
            )
        end
    end
    return
end

@doc raw"""
        lb_ff(container::OptimizationContainer,
              cons_name::Symbol,
              constraint_infos,
              param_reference,
              var_key::VariableKey)

Constructs a parameterized upper bound constraint to implement feedforward from other models.
The Parameters are initialized using the uppper boundary values of the provided variables.


``` variable[var_name, t] <= param_reference[var_name] ```

# LaTeX

`` x \leq param^{max}``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the JuMP.VariableRef used to determine the upperbound
* var_key::VariableKey : the name of the continuous variable
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel{T, U},
    devices::IS.FlattenIteratorWrapper{T},
    ff::LowerBoundFeedforward,
) where {T <: PSY.Component, U <: AbstractDeviceFormulation}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type(), T)
    multiplier_ub = get_parameter_multiplier_array(container, parameter_type(), T)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        @assert issetequal(set_name, PSY.get_name.(devices))
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_ub = add_constraints_container!(
            container,
            FeedforwardLowerBoundConstraint(),
            T,
            set_name,
            time_steps;
            meta = "$(var_type)lb",
        )

        use_slacks = get_slacks(ff)
        for t in time_steps, name in set_name
            if use_slacks
                slack_var =
                    get_variable(container, LowerBoundFeedForwardSlack(), T, "$(var_type)")
                con_ub[name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    variable[name, t] + slack_var[name, t] >=
                    param_ub[name, t] * multiplier_ub[name, t]
                )
            else
                con_ub[name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    variable[name, t] >= param_ub[name, t] * multiplier_ub[name, t]
                )
            end
        end
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::ServiceModel{T, U},
    contributing_devices::Vector{V},
    ff::LowerBoundFeedforward,
) where {T <: PSY.Service, U <: AbstractServiceFormulation, V <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param_ub = get_parameter_array(container, parameter_type(), T, get_service_name(model))
    service_name = get_service_name(model)
    multiplier_ub = get_parameter_multiplier_array(
        container,
        parameter_type(),
        T,
        service_name,
    )
    use_slacks = get_slacks(ff)
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == [PSY.get_name(d) for d in contributing_devices]
        IS.@assert_op set_time == time_steps

        var_type = get_entry_type(var)
        con_lb = add_constraints_container!(
            container,
            FeedforwardLowerBoundConstraint(),
            T,
            set_name,
            time_steps;
            meta = "$(var_type)_$(service_name)",
        )

        for t in time_steps, name in set_name
            if use_slacks
                slack_var = get_variable(
                    container,
                    LowerBoundFeedForwardSlack(),
                    T,
                    "$(var_type)_$(service_name)",
                )
                slack_var[name, t]
                con_lb[name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    variable[name, t] + slack_var[name, t] >=
                    param_ub[name, t] * multiplier_ub[name, t]
                )
            else
                con_lb[name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    variable[name, t] >= param_ub[name, t] * multiplier_ub[name, t]
                )
            end
        end
    end
    return
end

@doc raw"""
        add_feedforward_constraints(
            container::OptimizationContainer,
            ::DeviceModel,
            devices::IS.FlattenIteratorWrapper{T},
            ff::FixValueFeedforward,
        ) where {T <: PSY.Component}

Constructs a equality constraint to a fix a variable in one model using the variable value from other model results.


``` variable[var_name, t] == param[var_name, t] ```

# LaTeX

`` x == param``

# Arguments
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* model::DeviceModel : the device model
* devices::IS.FlattenIteratorWrapper{T} : list of devices
* ff::FixValueFeedforward : a instance of the FixValue Feedforward
"""
function add_feedforward_constraints!(
    container::OptimizationContainer,
    ::DeviceModel,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ff::FixValueFeedforward,
) where {T <: PSY.Component}
    parameter_type = get_default_parameter_type(ff, T)
    source_key = get_optimization_container_key(ff)
    var_type = get_entry_type(source_key)
    param = get_parameter_array(container, parameter_type(), T, "$var_type")
    multiplier = get_parameter_multiplier_array(container, parameter_type(), T, "$var_type")
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        IS.@assert_op set_name == PSY.get_name.(devices)

        for t in set_time, name in set_name
            JuMP.fix(variable[name, t], param[name, t] * multiplier[name, t]; force = true)
        end
    end
    return
end

function add_feedforward_constraints!(
    container::OptimizationContainer,
    model::ServiceModel{T, U},
    devices::Vector{V},
    ff::FixValueFeedforward,
) where {T, U, V <: PSY.Component}
    time_steps = get_time_steps(container)
    parameter_type = get_default_parameter_type(ff, T)
    param = get_parameter_array(container, parameter_type(), T, get_service_name(model))
    multiplier = get_parameter_multiplier_array(
        container,
        parameter_type(),
        T,
        get_service_name(model),
    )
    for var in get_affected_values(ff)
        variable = get_variable(container, var)
        set_name, set_time = JuMP.axes(variable)
        @assert issetequal(set_name, PSY.get_name.(devices))
        IS.@assert_op set_time == time_steps
        for t in time_steps, name in set_name
            JuMP.fix(variable[name, t], param[name, t] * multiplier[name, t]; force = true)
        end
    end
    return
end
