function check_chronology!(sim::Simulation, key::Pair, sync::Synchronize)
    source_problem = get_problems(sim)[key.first]
    destination_problem = get_problems(sim)[key.second]
    source_problem_horizon = get_horizon(source_problem)
    destination_problem_horizon = get_horizon(destination_problem)
    sequence = get_sequence(sim)
    source_problem_interval = get_interval(sequence, key.first)
    destination_problem_interval = get_interval(sequence, key.second)

    source_problem_resolution = get_resolution(source_problem)
    @debug source_problem_resolution, destination_problem_interval
    # How many times the second problem executes per solution retireved from the source_problem.
    # E.g. source_problem_resolution = 1 Hour, destination_problem_interval = 5 minutes => 12 executions per solution
    destination_problem_executions_per_solution =
        Int(source_problem_resolution / destination_problem_interval)
    # Number of periods in the horizon that will be synchronized between the source_problem and the destination_problem
    source_problem_sync = sync.periods

    if source_problem_sync > source_problem_horizon
        throw(
            IS.ConflictingInputsError(
                "The lookahead length $(source_problem_horizon) in problem is insufficient to syncronize with $(source_problem_sync) feedforward periods",
            ),
        )
    end

    if (source_problem_sync % destination_problem_executions_per_solution) != 0
        throw(
            IS.ConflictingInputsError(
                "The current configuration implies $(source_problem_sync / destination_problem_executions_per_solution) executions of $(key.second) per execution of $(key.first). The number of Synchronize periods $(sync.periods) in problem $(key.first) needs to be a mutiple of the number of problem $(key.second) execution for every problem $(key.first) interval.",
            ),
        )
    end

    return
end

function check_chronology!(sim::Simulation, key::Pair, ::Consecutive)
    source_problem = get_problems(sim)[key.first]
    destination_problem = get_problems(sim)[key.second]
    source_problem_horizon = get_horizon(source_problem)
    destination_problem_horizon = get_horizon(destination_problem)
    if source_problem_horizon != source_problem_interval
        @warn(
            "Consecutive Chronology Requires the same interval and horizon, the parameter horizon = $(source_problem_horizon) in problem $(key.first) will be replaced with $(source_problem_interval). If this is not the desired behviour consider changing your chronology to RecedingHorizon"
        )
    end
    get_sequence(sim).horizons[key.first] = get_interval(sim, key.first)
    return
end

check_chronology!(sim::Simulation, key::Pair, ::RecedingHorizon) = nothing
check_chronology!(sim::Simulation, key::Pair, ::FullHorizon) = nothing
# TODO: Add missing check
check_chronology!(sim::Simulation, key::Pair, ::Range) = nothing

function check_chronology!(
    sim::Simulation,
    key::Pair,
    ::T,
) where {T <: FeedForwardChronology}
    error("Chronology $(T) not implemented")
    return
end

############################ FeedForward Definitions ########################################

struct UpperBoundFF <: AbstractAffectFeedForward
    variable_source_problem::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function UpperBoundFF(
        variable_source_problem::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(Symbol(variable_source_problem), Symbol.(affected_variables), cache)
    end
end

function UpperBoundFF(; variable_source_problem, affected_variables)
    return UpperBoundFF(variable_source_problem, affected_variables, nothing)
end

get_variable_source_problem(p::UpperBoundFF) = p.variable_source_problem

struct RangeFF <: AbstractAffectFeedForward
    variable_source_problem_ub::Symbol
    variable_source_problem_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function RangeFF(
        variable_source_problem_ub::AbstractString,
        variable_source_problem_lb::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(
            Symbol(variable_source_problem_ub),
            Symbol(variable_source_problem_lb),
            Symbol.(affected_variables),
            cache,
        )
    end
end

function RangeFF(;
    variable_source_problem_ub,
    variable_source_problem_lb,
    affected_variables,
)
    return RangeFF(
        variable_source_problem_ub,
        variable_source_problem_lb,
        affected_variables,
        nothing,
    )
end

get_bounds_source_problem(p::RangeFF) =
    (p.variable_source_problem_lb, p.variable_source_problem_lb)

struct SemiContinuousFF <: AbstractAffectFeedForward
    binary_source_problem::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function SemiContinuousFF(
        binary_source_problem::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(Symbol(binary_source_problem), Symbol.(affected_variables), cache)
    end
end

function SemiContinuousFF(; binary_source_problem, affected_variables)
    return SemiContinuousFF(binary_source_problem, affected_variables, nothing)
end

get_binary_source_problem(p::SemiContinuousFF) = p.binary_source_problem
get_affected_variables(p::AbstractAffectFeedForward) = p.affected_variables

struct IntegralLimitFF <: AbstractAffectFeedForward
    variable_source_problem::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function IntegralLimitFF(
        variable_source_problem::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(Symbol(variable_source_problem), Symbol.(affected_variables), cache)
    end
end

function IntegralLimitFF(; variable_source_problem, affected_variables)
    return IntegralLimitFF(variable_source_problem, affected_variables, nothing)
end

get_variable_source_problem(p::IntegralLimitFF) = p.variable_source_problem

struct PowerCommitmentFF <: AbstractAffectFeedForward
    variable_source_problem::Symbol
    affected_variables::Vector{Symbol}
    affected_time_periods::Int
    cache::Union{Nothing, Type{<:AbstractCache}}
    function PowerCommitmentFF(
        variable_source_problem::AbstractString,
        affected_variables::Vector{<:AbstractString},
        affected_time_periods::Int,
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(
            Symbol(variable_source_problem),
            Symbol.(affected_variables),
            affected_time_periods,
            cache,
        )
    end
end

function PowerCommitmentFF(;
    variable_source_problem,
    affected_variables,
    affected_time_periods,
)
    return PowerCommitmentFF(
        variable_source_problem,
        affected_variables,
        affected_time_periods,
        nothing,
    )
end

get_variable_source_problem(p::PowerCommitmentFF) = p.variable_source_problem

struct ParameterFF <: AbstractAffectFeedForward
    variable_source_problem::Symbol
    affected_parameters::Any
    function ParameterFF(variable_source_problem::AbstractString, affected_parameters)
        new(Symbol(variable_source_problem), affected_parameters)
    end
end

function ParameterFF(; variable_source_problem, affected_parameters)
    return ParameterFF(variable_source_problem, affected_parameters)
end

####################### Feed Forward Affects ###############################################

@doc raw"""
        ub_ff(optimization_container::OptimizationContainer,
              cons_name::Symbol,
              constraint_infos::Vector{DeviceRangeConstraintInfo},
              param_reference::UpdateRef,
              var_name::Symbol)

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
* var_name::Symbol : the name of the continuous variable
"""
function ub_ff(
    optimization_container::OptimizationContainer,
    cons_name::Symbol,
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(optimization_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    variable = get_variable(optimization_container, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps
    container = add_param_container!(optimization_container, param_reference, set_name)
    param_ub = get_parameter_array(container)
    multiplier_ub = get_multiplier_array(container)
    con_ub = add_cons_container!(optimization_container, ub_name, set_name, time_steps)

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
                        var_name::Symbol)

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
* var_name::Symbol : the name of the continuous variable
"""
function range_ff(
    optimization_container::OptimizationContainer,
    cons_name::Symbol,
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    param_reference::NTuple{2, UpdateRef},
    var_name::Symbol,
)
    time_steps = model_time_steps(optimization_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")

    variable = get_variable(optimization_container, var_name)
    # Used to make sure the names are consistent between the variable and the infos
    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps

    # Create containers for the constraints
    container_lb =
        add_param_container!(optimization_container, param_reference[1], set_name)
    param_lb = get_parameter_array(container_lb)
    multiplier_lb = get_multiplier_array(container_lb)
    container_ub =
        add_param_container!(optimization_container, param_reference[2], set_name)
    param_ub = get_parameter_array(container_ub)
    multiplier_ub = get_multiplier_array(container_ub)
    # Create containers for the parameters
    con_lb = add_cons_container!(optimization_container, lb_name, set_name, time_steps)
    con_ub = add_cons_container!(optimization_container, ub_name, set_name, time_steps)

    for constraint_info in constraint_infos
        name = get_component_name(constraint_info)
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
            expression_ub = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in constraint_info.additional_terms_ub
                JuMP.add_to_expression!(expression_ub, variable[name, t])
            end
            expression_lb = JuMP.AffExpr(0.0, variable[name, t] => 1.0)
            for val in constraint_info.additional_terms_lb
                JuMP.add_to_expression!(expression_lb, variable[name, t], -1.0)
            end
            con_ub[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                expression_ub <= param_ub[name] * multiplier_ub[name]
            )
            con_lb[name, t] = JuMP.@constraint(
                optimization_container.JuMPmodel,
                expression_lb >= param_lb[name] * multiplier_lb[name]
            )
        end
    end

    return
end

@doc raw"""
            semicontinuousrange_ff(optimization_container::OptimizationContainer,
                                    cons_name::Symbol,
                                    var_name::Symbol,
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
* var_name::Symbol : the name of the continuous variable
* param_reference::UpdateRef : UpdateRef of the parameter
"""
function semicontinuousrange_ff(
    optimization_container::OptimizationContainer,
    cons_name::Symbol,
    constraint_infos::Vector{DeviceRangeConstraintInfo},
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(optimization_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")
    variable = get_variable(optimization_container, var_name)
    # Used to make sure the names are consistent between the variable and the infos
    axes = JuMP.axes(variable)
    set_name = [get_component_name(ci) for ci in constraint_infos]
    @assert axes[2] == time_steps
    container = add_param_container!(optimization_container, param_reference, set_name)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    con_ub = add_cons_container!(optimization_container, ub_name, set_name, time_steps)
    con_lb = add_cons_container!(optimization_container, lb_name, set_name, time_steps)

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
                        var_name::Symbol)

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
* var_name::Symbol : the name of the continuous variable
"""
function integral_limit_ff(
    optimization_container::OptimizationContainer,
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(optimization_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "integral_limit")
    variable = get_variable(optimization_container, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]

    @assert axes[2] == time_steps
    container_ub = add_param_container!(optimization_container, param_reference, set_name)
    param_ub = get_parameter_array(container_ub)
    multiplier_ub = get_multiplier_array(container_ub)
    con_ub = add_cons_container!(optimization_container, ub_name, set_name)

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

function power_commitment_ff(
    optimization_container::OptimizationContainer,
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_names::Tuple{Symbol, Symbol},
    affected_time_periods::Int,
)
    time_steps = model_time_steps(optimization_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "integral_limit")
    variable = get_variable(optimization_container, var_names[1])
    varslack = get_variable(optimization_container, var_names[2])

    axes = JuMP.axes(variable)
    set_name = axes[1]

    @assert axes[2] == time_steps
    container_ub = add_param_container!(optimization_container, param_reference, set_name)
    param_ub = get_parameter_array(container_ub)
    multiplier_ub = get_multiplier_array(container_ub)
    con_ub = add_cons_container!(optimization_container, ub_name, set_name)

    for name in axes[1]
        value = JuMP.upper_bound(variable[name, 1])
        param_ub[name] = add_parameter(optimization_container.JuMPmodel, value)
        # default set to 1.0, as this implementation doesn't use multiplier
        multiplier_ub[name] = 1.0
        con_ub[name] = JuMP.@constraint(
            optimization_container.JuMPmodel,
            sum(variable[name, t] for t in 1:affected_time_periods) /
            length(affected_time_periods) + varslack[name, 1] >=
            param_ub[name] * multiplier_ub[name]
        )
        add_to_cost_expression!(
            optimization_container,
            varslack[name, 1] * FEEDFORWARD_SLACK_COST,
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
    for prefix in get_affected_variables(ff_model)
        var_name = make_variable_name(prefix, T)
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_name)
        ub_ff(
            optimization_container,
            make_constraint_name(FEEDFORWARD_UB, T),
            constraint_infos,
            parameter_ref,
            var_name,
        )
    end
end

function feedforward!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, <:AbstractDeviceFormulation},
    ff_model::SemiContinuousFF,
) where {T <: PSY.StaticInjection}
    bin_var = make_variable_name(get_binary_source_problem(ff_model), T)
    parameter_ref = UpdateRef{JuMP.VariableRef}(bin_var)
    constraint_infos = Vector{DeviceRangeConstraintInfo}(undef, length(devices))
    for (ix, d) in enumerate(devices)
        name = PSY.get_name(d)
        limits = PSY.get_active_power_limits(d)
        constraint_info = DeviceRangeConstraintInfo(name, limits)
        add_device_services!(constraint_info, d, model)
        constraint_infos[ix] = constraint_info
    end
    for prefix in get_affected_variables(ff_model)
        var_name = make_variable_name(prefix, T)
        semicontinuousrange_ff(
            optimization_container,
            make_constraint_name(FEEDFORWARD_BIN, T),
            constraint_infos,
            parameter_ref,
            var_name,
        )
    end
end

function feedforward!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, <:AbstractDeviceFormulation},
    ff_model::IntegralLimitFF,
) where {T <: PSY.StaticInjection}
    for prefix in get_affected_variables(ff_model)
        var_name = make_variable_name(prefix, T)
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_name)
        integral_limit_ff(
            optimization_container,
            make_constraint_name(FEEDFORWARD_INTEGRAL_LIMIT, T),
            parameter_ref,
            var_name,
        )
    end
end

function feedforward!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    ::DeviceModel{T, D},
    ff_model::PowerCommitmentFF,
) where {T <: PSY.HybridSystem, D <: AbstractDeviceFormulation}
    PSI.add_variables!(
        optimization_container,
        PSI.ActivePowerShortageVariable,
        devices,
        D(),
    )
    # slack_var_name = make_variable_name(ActivePowerShortageVariable, T)
    # slack_variable = add_var_container!(
    #     optimization_container,
    #     slack_var_name,
    #     [PSY.get_name(d) for d in devices],
    # )
    # for d in devices
    #     name = PSY.get_name(d)
    #     slack_variable[name] = JuMP.@variable(
    #         optimization_container.JuMPmodel,
    #         base_name = "$(slack_var_name)_{$(name)}",
    #     )
    #     JuMP.set_lower_bound(slack_variable[name], 0.0)
    # end
    for prefix in get_affected_variables(ff_model)
        var_name = make_variable_name(prefix, T)
        varslack_name = PSI.make_variable_name(PSI.ACTIVE_POWER_SHORTAGE, T)
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_name)
        power_commitment_ff(
            optimization_container,
            make_constraint_name(FEEDFORWARD_POWER_COMMITMENT, T),
            parameter_ref,
            (var_name, varslack_name),
            ff_model.affected_time_periods,
        )
    end
end

######################### FeedForward Variables Updating #####################################
# This makes the choice in which variable to get from the results.
function get_problem_variable(
    chron::RecedingHorizon,
    problems::Pair{OperationsProblem{T}, OperationsProblem{U}},
    device_name::AbstractString,
    var_ref::UpdateRef;
    kwargs...,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    idx = get_index(device_name, chron.periods, get(kwargs, :sub_component, nothing))
    var = variable[idx]
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
    var_ref::UpdateRef;
    kwargs...,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    idx = get_index(
        device_name,
        get_end_of_interval_step(problems.first),
        get(kwargs, :sub_component, nothing),
    )
    var = variable[idx]
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
    var_ref::UpdateRef;
    kwargs...,
) where {T, U <: AbstractOperationsProblem}
    variable =
        get_variable(problems.first.internal.optimization_container, var_ref.access_ref)
    e_count = get_execution_count(problems.second)
    wait_count = get_execution_wait_count(get_trigger(chron))
    index = (floor(e_count / wait_count) + 1)
    idx = get_index(device_name, Int(index), get(kwargs, :sub_component, nothing))
    var = variable[idx]
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
    var_ref::UpdateRef;
    kwargs...,
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
    var_ref::UpdateRef;
    kwargs...,
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
