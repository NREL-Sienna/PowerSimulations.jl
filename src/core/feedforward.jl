####################### Feed Forward Affects ###############################################

@doc raw"""
        ub_ff(optimization_container::OptimizationContainer,
              cons_name::Symbol,
              constraint_infos::Vector{DeviceRangeConstraintInfo},
              param_reference::UpdateRef,
              var_key::VariableKey)

Constructs a parametrized upper bound constraint to implement feedforward from other models.
The Parameters are initialized using the uppper boundary values of the provided variables.

# Constraints
``` variable[var_name, t] <= param_reference[var_name] ```

# LaTeX

`` x \leq param^{max}``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the PJ.ParameterRef used to determine the upperbound
* var_key::VariableKey : the name of the continuous variable
"""
function ub_ff(
    optimization_container::OptimizationContainer,
    cons_type::ConstraintType,
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    parameter_type::VariableValueParameter,
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    variable = get_variable(optimization_container, var_type, T)

    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps
    container = add_param_container!(optimization_container, parameter_type, T, set_name)
    param_ub = get_parameter_array(container)
    multiplier_ub = get_multiplier_array(container)
    con_ub = add_cons_container!(optimization_container, cons_type, T, set_name, time_steps)

    for constraint_info in constraint_infos
        name = get_component_name(constraint_info)
        value = JuMP.upper_bound(variable[name, 1])
        param_ub[name] = add_parameter(optimization_container.JuMPmodel, value)
        # default set to 1.0, as this implementation doesn't use multiplier
        multiplier_ub[name] = 1.0
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in constraint_info.additional_terms_ub
                JuMP.add_to_expression!(expression_ub, variable[name, t])
            end
            con_ub[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                expression_ub <= param_ub[name] * multiplier_ub[name]
            )
        end
    end
    return
end

@doc raw"""
        range_ff(optimization_container::OptimizationContainer,
                        cons_name::Symbol,
                        param_reference::NTuple{2, UpdateRef},
                        var_key::VariableKey)

Constructs min/max range parametrized constraint from device variable to include feedforward.

# Constraints

``` param_reference[1][var_name] <= variable[var_name, t] ```
``` variable[var_name, t] <= param_reference[2][var_name] ```

where r in range_data.

# LaTeX

`` param^{min} \leq x ``
`` x \leq param^{max}``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* param_reference::NTuple{2, UpdateRef} : Tuple with the lower bound and upper bound parameter reference
* cons_name::Symbol : name of the constraint
* var_key::VariableKey : the name of the continuous variable
"""
function range_ff(
    optimization_container::OptimizationContainer,
    cons_type_lb::ConstraintType,
    cons_type_ub::ConstraintType,
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    param_reference::NTuple{2, <:VariableValueParameter},
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    variable = get_variable(optimization_container, var_type)
    # Used to make sure the names are consistent between the variable and the infos
    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps

    # Create containers for the constraints
    container_lb =
        add_param_container!(optimization_container, param_reference[1], T, set_name)
    param_lb = get_parameter_array(container_lb)
    multiplier_lb = get_multiplier_array(container_lb)
    container_ub =
        add_param_container!(optimization_container, param_reference[2], T, set_name)
    param_ub = get_parameter_array(container_ub)
    multiplier_ub = get_multiplier_array(container_ub)
    # Create containers for the parameters
    con_lb =
        add_cons_container!(optimization_container, cons_type_lb, T, set_name, time_steps)
    con_ub =
        add_cons_container!(optimization_container, cons_type_ub, T, set_name, time_steps)

    for name in set_name
        param_lb[name] = add_parameter(
            optimization_container.JuMPmodel,
            JuMP.lower_bound(variable[name, 1]),
        )
        param_ub[name] = add_parameter(
            optimization_container.JuMPmodel,
            JuMP.upper_bound(variable[name, 1]),
        )
        # default set to 1.0, as this implementation doesn't use multiplier
        multiplier_ub[name] = 1.0
        multiplier_lb[name] = 1.0
        for t in time_steps
            con_ub[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                variable[name, t] <= param_ub[name] * multiplier_ub[name]
            )
            con_lb[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                variable[name, t] >= param_lb[name] * multiplier_lb[name]
            )
        end
    end

    return
end

@doc raw"""
            semicontinuousrange_ff(optimization_container::OptimizationContainer,
                                    cons_name::Symbol,
                                    var_key::VariableKey,
                                    param_reference::UpdateRef)

Constructs min/max range constraint from device variable with parameter setting.

# Constraints
If device min = 0:

``` variable[var_name, t] <= r[2].max*param_reference[var_name] ```

Otherwise:

``` variable[var_name, t] <= r[2].max*param_reference[var_name] ```

``` variable[var_name, t] >= r[2].min*param_reference[var_name] ```

where r in range_data.

# LaTeX

`` 0.0 \leq x^{var} \leq r^{max} x^{param}, \text{ for } r^{min} = 0 ``

`` r^{min} x^{param} \leq x^{var} \leq r^{min} x^{param}, \text{ otherwise } ``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* var_key::VariableKey : the name of the continuous variable
* param_reference::UpdateRef : UpdateRef of the parameter
"""
function semicontinuousrange_ff(
    optimization_container::OptimizationContainer,
    constraint_type::ConstraintType,
    ::Type{T},
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    param_type::VariableValueParameter,
    variable_type::VariableType,
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    variable = get_variable(optimization_container, variable_type, T)
    # Used to make sure the names are consistent between the variable and the infos
    axes = JuMP.axes(variable)
    set_name = [get_component_name(ci) for ci in constraint_infos]
    @assert axes[2] == time_steps
    container = add_param_container!(optimization_container, param_reference, T, set_name)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    con_ub = add_cons_container!(
        optimization_container,
        constraint_type,
        T,
        set_name,
        time_steps,
        meta = "up",
    )
    con_lb = add_cons_container!(
        optimization_container,
        constraint_type,
        T,
        set_name,
        time_steps,
        meta = "lb",
    )

    for constraint_info in constraint_infos
        name = get_component_name(constraint_info)
        ub_value = JuMP.upper_bound(variable[name, 1])
        lb_value = JuMP.lower_bound(variable[name, 1])
        @debug "SemiContinuousFF" name ub_value lb_value
        # default set to 1.0, as this implementation doesn't use multiplier
        multiplier[name] = 1.0
        param[name] = add_parameter(optimization_container.JuMPmodel, 1.0)
        for t in time_steps
            expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in constraint_info.additional_terms_ub
                JuMP.add_to_expression!(
                    expression_ub,
                    get_variable(optimization_container, val)[name, t],
                )
            end
            expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in constraint_info.additional_terms_lb
                JuMP.add_to_expression!(
                    expression_lb,
                    get_variable(optimization_container, val)[name, t],
                    -1.0,
                )
            end
            mul_ub = ub_value * multiplier[name]
            mul_lb = lb_value * multiplier[name]
            con_ub[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                expression_ub <= mul_ub * param[name]
            )
            con_lb[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                expression_lb >= mul_lb * param[name]
            )
        end
    end

    # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
    for v in variable
        if JuMP.has_lower_bound(v)
            @debug "lb reset" v
            JuMP.set_lower_bound(v, 0.0)
        end
    end

    return
end

@doc raw"""
        integral_limit_ff(optimization_container::OptimizationContainer,
                        cons_name::Symbol,
                        param_reference::UpdateRef,
                        var_key::VariableKey)

Constructs a parametrized integral limit constraint to implement feedforward from other models.
The Parameters are initialized using the upper boundary values of the provided variables.

# Constraints
``` sum(variable[var_name, t] for t in time_steps)/length(time_steps) <= param_reference[var_name] ```

# LaTeX

`` \sum_{t} x \leq param^{max}``
`` \sum_{t} x * DeltaT_lower \leq param^{max} * DeltaT_upper ``
    `` P_LL - P_max * ON_upper <= 0.0 ``
    `` P_LL - P_min * ON_upper >= 0.0 ``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the PJ.ParameterRef used to determine the upperbound
* var_key::VariableKey : the name of the continuous variable
"""
function integral_limit_ff(
    optimization_container::OptimizationContainer,
    constraint_type::ConstraintType,
    ::Type{T},
    param_type::VariableValueParameter,
    variable_type::VariableType,
) where {T <: PSY.Component}
    time_steps = model_time_steps(optimization_container)
    variable = get_variable(optimization_container, variable_type, T)

    axes = JuMP.axes(variable)
    set_name = axes[1]

    @assert axes[2] == time_steps
    container_ub = add_param_container!(optimization_container, param_type, T, set_name)
    param_ub = get_parameter_array(container_ub)
    multiplier_ub = get_multiplier_array(container_ub)
    con_ub = add_cons_container!(optimization_container, constraint_type, T, set_name)

    for name in axes[1]
        value = JuMP.upper_bound(variable[name, 1])
        param_ub[name] = add_parameter(optimization_container.JuMPmodel, value)
        # default set to 1.0, as this implementation doesn't use multiplier
        multiplier_ub[name] = 1.0
        con_ub[name] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            sum(variable[name, t] for t in time_steps) / length(time_steps) <=
            param_ub[name] * multiplier_ub[name]
        )
    end
end

########################## FeedForward Constraints #########################################
function feedforward!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractDeviceFormulation},
    ff_model::Nothing,
) where {T <: PSY.Component}
    return
end

function feedforward!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractDeviceFormulation},
    ff_model::UpperBoundFF,
) where {T <: PSY.StaticInjection}
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_active_power_limits(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end
    for var_key in get_affected_variables(ff_model)
        var_type = get_entry_type(var_key)
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_key)
        ub_ff(
            optimization_container,
            FeedforwardUBConstraint(),
            constraint_infos,
            parameter_ref,
            var_type,
            T,
        )
    end
end

function feedforward!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractDeviceFormulation},
    ff_model::SemiContinuousFF,
) where {T <: PSY.StaticInjection}
    bin_var = VariableKey(get_binary_source_problem(ff_model), T)
    parameter_ref = UpdateRef{JuMP.VariableRef}(bin_var)
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_active_power_limits(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end
    for var_key in get_affected_variables(ff_model)
        semicontinuousrange_ff(
            optimization_container,
            FeedforwardBinConstraint,
            T,
            constraint_infos,
            parameter_ref,
            get_entry_type(var_key),  # TODO DT: Jose, the old code was creating a new key; not sure why
        )
    end
end

function feedforward!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractDeviceFormulation},
    ff_model::IntegralLimitFF,
) where {T <: PSY.StaticInjection}
    for var_key in get_affected_variables(ff_model)
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_key)
        integral_limit_ff(
            optimization_container,
            FeedforwardIntegralLimitConstraint,
            T,
            parameter_ref,
            get_entry_type(var_key),  # TODO DT: Jose, the old code was creating a new key; not sure why
        )
    end
end

function feedforward!(
    optimization_container::OptimizationContainer,
    devices::Vector{T},
    ::ServiceModel{SR, <:AbstractServiceFormulation},
    ff_model::RangeFF,
) where {SR <: PSY.Service, T <: PSY.Device}
    parameter_ref_ub =
        UpdateRef{JuMP.VariableRef}(ff_model.variable_source_problem_ub, "ub")
    parameter_ref_lb =
        UpdateRef{JuMP.VariableRef}(ff_model.variable_source_problem_lb, "lb")
    for var_name in get_affected_variables(ff_model)
        # TODO: This function isn't implemented correctly needs review to use keys
        range_ff(
            optimization_container,
            Symbol("RANGE_FF_" * "$var_name"),
            devices,
            (parameter_ref_lb, parameter_ref_ub),
            var_name,
        )
    end
end

######################### FeedForward Variables Updating #####################################
# This makes the choice in which variable to get from the results.
function get_problem_variable(
    chron::RecedingHorizon,
    problems::Pair{OperationsProblem{T}, OperationsProblem{U}},
    device_name::AbstractString,
    var_ref::UpdateRef,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    step = axes(variable)[2][chron.periods]
    var = variable[device_name, step]
    if JuMP.is_binary(var)
        return round(JuMP.value(var))
    else
        return JuMP.value(var)
    end
end

function get_problem_variable(
    ::Consecutive,
    problems::Pair{OperationsProblem{T}, OperationsProblem{U}},
    device_name::String,
    var_ref::UpdateRef,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    step = axes(variable)[2][get_end_of_interval_step(problems.first)]
    var = variable[device_name, step]
    if JuMP.is_binary(var)
        return round(JuMP.value(var))
    else
        return JuMP.value(var)
    end
end

function get_problem_variable(
    chron::Synchronize,
    problems::Pair{OperationsProblem{T}, OperationsProblem{U}},
    device_name::String,
    var_ref::UpdateRef,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    e_count = get_execution_count(problems.second)
    wait_count = get_execution_wait_count(get_trigger(chron))
    index = (floor(e_count / wait_count) + 1)
    step = axes(variable)[2][Int(index)]
    var = variable[device_name, step]
    if JuMP.is_binary(var)
        return round(JuMP.value(var))
    else
        return JuMP.value(var)
    end
end

function get_problem_variable(
    ::FullHorizon,
    problems::Pair{OperationsProblem{T}, OperationsProblem{U}},
    device_name::String,
    var_ref::UpdateRef,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    vars = variable[device_name, :]
    if JuMP.is_binary(first(vars))
        return round.(JuMP.value(vars))
    else
        return JuMP.value.(vars)
    end
end

function get_problem_variable(
    chron::Range,
    problems::Pair{OperationsProblem{T}, OperationsProblem{U}},
    device_name::String,
    var_ref::UpdateRef,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    vars = variable[device_name, chron.range]
    if JuMP.is_binary(first(vars))
        return round.(JuMP.value(vars))
    else
        return JuMP.value.(vars)
    end
end

function feedforward_update!(
    destination_problem::OperationsProblem,
    source_problem::OperationsProblem,
    chronology::FeedForwardChronology,
    param_reference::UpdateRef{JuMP.VariableRef},
    param_array::JuMPParamArray,
    current_time::Dates.DateTime,
)
    trigger = get_trigger(chronology)
    if trigger_update(trigger)
        for device_name in axes(param_array)[1]
            var_value = get_problem_variable(
                chronology,
                (source_problem => destination_problem),
                device_name,
                param_reference,
            )
            previous_value = PJ.value(param_array[device_name])
            PJ.set_value(param_array[device_name], var_value)
            IS.@record :simulation FeedForwardUpdateEvent(
                "FeedForward",
                current_time,
                param_reference,
                device_name,
                var_value,
                previous_value,
                destination_problem,
                source_problem,
            )
        end
        reset_trigger_count!(trigger)
    end
    update_count!(trigger)
    return
end

function attach_feedforward(model, ff::AbstractAffectFeedForward)
    model.feedforward = ff
    return
end
