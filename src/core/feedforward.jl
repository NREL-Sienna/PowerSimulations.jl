############################Chronologies For FeedForward###################################
@doc raw"""
    Synchronize(periods::Int)
Defines the co-ordination of time between Two stages.

# Arguments
- `periods::Int`: Number of time periods to grab data from
"""
struct Synchronize <: FeedForwardChronology
    periods::Int
    function Synchronize(; periods)
        new(periods)
    end
end
# TODO: Add DocString
"""
    RecedingHorizon(period::Int)
"""
struct RecedingHorizon <: FeedForwardChronology
    period::Int
    function RecedingHorizon(; period::Int = 1)
        new(period)
    end
end

struct Consecutive <: FeedForwardChronology end

function check_chronology!(sim::Simulation, key::Pair, sync::Synchronize)
    from_stage = get_stage(sim, key.first)
    to_stage = get_stage(sim, key.second)
    from_stage_horizon = sim.sequence.horizons[key.first]
    to_stage_horizon = sim.sequence.horizons[key.second]
    from_stage_interval = get_stage_interval(sim, key.first)
    to_stage_interval = get_stage_interval(sim, key.second)

    from_stage_resolution =
        IS.time_period_conversion(PSY.get_forecasts_resolution(from_stage.sys))
    @debug from_stage_resolution, to_stage_interval
    # How many times the second stages executes per solution retireved from the from_stage.
    # E.g. from_stage_resolution = 1 Hour, to_stage_interval = 5 minutes => 12 executions per solution
    to_stage_executions_per_solution = Int(from_stage_resolution / to_stage_interval)
    # Number of periods in the horizon that will be synchronized between the from_stage and the to_stage
    from_stage_sync = sync.periods

    if from_stage_sync > from_stage_horizon
        throw(IS.ConflictingInputsError("The lookahead length $(from_stage_horizon) in stage is insufficient to syncronize with $(from_stage_sync) feedforward periods"))
    end

    if (from_stage_sync % to_stage_executions_per_solution) != 0
        throw(IS.ConflictingInputsError("The current configuration implies $(from_stage_sync / to_stage_executions_per_solution) executions of $(key.second) per execution of $(key.first). The number of Synchronize periods $(sync.periods) in stage $(key.first) needs to be a mutiple of the number of stage $(key.second) execution for every stage $(key.first) interval."))
    end

    return
end

function check_chronology!(sim::Simulation, key::Pair, ::Consecutive)
    from_stage_horizon = sim.sequence.horizons[key.first]
    from_stage_interval = get_stage_interval(sim, key.first)
    if from_stage_horizon != from_stage_interval
        @warn("Consecutive Chronology Requires the same interval and horizon, the parameter horizon = $(from_stage_horizon) in stage $(key.first) will be replaced with $(from_stage_interval). If this is not the desired behviour consider changing your chronology to RecedingHorizon")
    end
    sim.sequence.horizons[key.first] = get_stage_interval(sim, key.first)
    return
end

check_chronology!(sim::Simulation, key::Pair, ::RecedingHorizon) = nothing

function check_chronology!(
    sim::Simulation,
    key::Pair,
    ::T,
) where {T <: FeedForwardChronology}
    error("Chronology $(T) not implemented")
    return
end

############################FeedForward Definitions########################################

struct UpperBoundFF <: AbstractAffectFeedForward
    variable_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function UpperBoundFF(
        variable_from_stage::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(Symbol(variable_from_stage), Symbol.(affected_variables), cache)
    end
end

function UpperBoundFF(; variable_from_stage, affected_variables)
    return UpperBoundFF(variable_from_stage, affected_variables, nothing)
end

get_variable_from_stage(p::UpperBoundFF) = p.binary_from_stage

struct RangeFF <: AbstractAffectFeedForward
    variable_from_stage_ub::Symbol
    variable_from_stage_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function RangeFF(
        variable_from_stage_ub::AbstractString,
        variable_from_stage_lb::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(
            Symbol(variable_from_stage_ub),
            Symbol(variable_from_stage_ub),
            Symbol.(affected_variables),
            cache,
        )
    end
end

function RangeFF(; variable_from_stage_ub, variable_from_stage_lb, affected_variables)
    return RangeFF(
        variable_from_stage_ub,
        variable_from_stage_lb,
        affected_variables,
        nothing,
    )
end

get_bounds_from_stage(p::RangeFF) = (p.variable_from_stage_lb, p.variable_from_stage_lb)

struct SemiContinuousFF <: AbstractAffectFeedForward
    binary_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function SemiContinuousFF(
        binary_from_stage::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(Symbol(binary_from_stage), Symbol.(affected_variables), cache)
    end
end

function SemiContinuousFF(; binary_from_stage, affected_variables)
    return SemiContinuousFF(binary_from_stage, affected_variables, nothing)
end

get_binary_from_stage(p::SemiContinuousFF) = p.binary_from_stage
get_affected_variables(p::AbstractAffectFeedForward) = p.affected_variables

struct IntegralLimitFF <: AbstractAffectFeedForward
    variable_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
    function IntegralLimitFF(
        variable_from_stage::AbstractString,
        affected_variables::Vector{<:AbstractString},
        cache::Union{Nothing, Type{<:AbstractCache}},
    )
        new(Symbol(variable_from_stage), Symbol.(affected_variables), cache)
    end
end

function IntegralLimitFF(; variable_from_stage, affected_variables)
    return IntegralLimitFF(variable_from_stage, affected_variables, nothing)
end

get_variable_from_stage(p::IntegralLimitFF) = p.variable_from_stage

####################### Feed Forward Affects ###############################################

@doc raw"""
        ub_ff(psi_container::PSIContainer,
              cons_name::Symbol,
              param_reference::UpdateRef,
              var_name::Symbol)

Constructs a parametrized upper bound constraint to implement feedforward from other models.
The Parameters are initialized using the uppper boundary values of the provided variables.

# Constraints
``` variable[var_name, t] <= param_reference[var_name] ```

# LaTeX

`` x \leq param^{max}``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the PJ.ParameterRef used to determine the upperbound
* var_name::Symbol : the name of the continuous variable
"""
function ub_ff(
    psi_container::PSIContainer,
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    variable = get_variable(psi_container, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]

    @assert axes[2] == time_steps
    container = add_param_container!(psi_container, param_reference, set_name)
    param_ub = get_parameter_array(container)
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)

    for name in axes[1]
        value = JuMP.upper_bound(variable[name, 1])
        param_ub[name] = PJ.add_parameter(psi_container.JuMPmodel, value)
        for t in axes[2]
            con_ub[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                variable[name, t] <= param_ub[name]
            )
        end
    end

    return
end

@doc raw"""
        range_ff(psi_container::PSIContainer,
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
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* param_reference::NTuple{2, UpdateRef} : Tuple with the lower bound and upper bound parameter reference
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
"""
function range_ff(
    psi_container::PSIContainer,
    cons_name::Symbol,
    param_reference::NTuple{2, UpdateRef},
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")

    variable = get_variable(psi_container, var_name)
    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps

    #Create containers for the constraints
    container_lb = add_param_container!(psi_container, param_reference[1], set_name)
    param_lb = get_parameter_array(container_lb)
    container_ub = add_param_container!(psi_container, param_reference[2], set_name)
    param_ub = get_parameter_array(container_ub)

    #Create containers for the parameters
    con_lb = add_cons_container!(psi_container, lb_name, set_name, time_steps)
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)

    for name in axes[1]
        param_lb[name] =
            PJ.add_parameter(psi_container.JuMPmodel, JuMP.lower_bound(variable[name, 1]))
        param_ub[name] =
            PJ.add_parameter(psi_container.JuMPmodel, JuMP.upper_bound(variable[name, 1]))
        for t in axes[2]
            con_ub[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                variable[name, t] <= param_ub[name]
            )
            con_lb[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                variable[name, t] >= param_lb[name]
            )
        end
    end

    return
end

@doc raw"""
            semicontinuousrange_ff(psi_container::PSIContainer,
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
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* var_name::Symbol : the name of the continuous variable
* param_reference::UpdateRef : UpdateRef of the parameter
"""
function semicontinuousrange_ff(
    psi_container::PSIContainer,
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "ub")
    lb_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "lb")

    variable = get_variable(psi_container, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps
    container = add_param_container!(psi_container, param_reference, set_name)
    multiplier = get_multiplier_array(container)
    param = get_parameter_array(container)
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, set_name, time_steps)

    for name in axes[1]
        ub_value = JuMP.upper_bound(variable[name, 1])
        lb_value = JuMP.lower_bound(variable[name, 1])
        param[name] = PJ.add_parameter(psi_container.JuMPmodel, 1.0)
        for t in axes[2]
            con_ub[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                variable[name, t] <= ub_value * param[name]
            )
            con_lb[name, t] = JuMP.@constraint(
                psi_container.JuMPmodel,
                variable[name, t] >= lb_value * param[name]
            )
        end
    end

    # If the variable was a lower bound != 0, not removing the LB can cause infeasibilities
    for v in variable
        if JuMP.has_lower_bound(v)
            JuMP.set_lower_bound(v, 0.0)
        end
    end

    return
end

@doc raw"""
        integral_limit_ff(psi_container::PSIContainer,
                        cons_name::Symbol,
                        param_reference::UpdateRef,
                        var_name::Symbol)

Constructs a parametrized integral limit constraint to implement feedforward from other models.
The Parameters are initialized using the upper boundary values of the provided variables.

# Constraints
``` sum(variable[var_name, t] for t in time_steps)/length(time_steps) <= param_reference[var_name] ```

# LaTeX

`` \sum_{t} x \leq param^{max}``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* cons_name::Symbol : name of the constraint
* param_reference : Reference to the PJ.ParameterRef used to determine the upperbound
* var_name::Symbol : the name of the continuous variable
"""
function integral_limit_ff(
    psi_container::PSIContainer,
    cons_name::Symbol,
    param_reference::UpdateRef,
    var_name::Symbol,
)
    time_steps = model_time_steps(psi_container)
    ub_name = middle_rename(cons_name, PSI_NAME_DELIMITER, "integral_limit")
    variable = get_variable(psi_container, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]

    @assert axes[2] == time_steps
    container_ub = add_param_container!(psi_container, param_reference, set_name)
    param_ub = get_parameter_array(container_ub)
    con_ub = add_cons_container!(psi_container, ub_name, set_name)

    for name in axes[1]
        value = JuMP.upper_bound(variable[name, 1])

        param_ub[name] = PJ.add_parameter(psi_container.JuMPmodel, value)
        con_ub[name] = JuMP.@constraint(
            psi_container.JuMPmodel,
            sum(variable[name, t] for t in time_steps) / length(time_steps) <=
            param_ub[name]
        )
    end
end

########################## FeedForward Constraints #########################################
function feedforward!(
    psi_container::PSIContainer,
    device_type::Type{T},
    ff_model::Nothing,
) where {T <: PSY.Component}
    return
end

function feedforward!(
    psi_container::PSIContainer,
    device_type::Type{I},
    ff_model::UpperBoundFF,
) where {I <: PSY.StaticInjection}
    for prefix in get_affected_variables(ff_model)
        var_name = variable_name(prefix, I)
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_name)
        ub_ff(psi_container, constraint_name(feedforward, I), parameter_ref, var_name)
    end
end

function feedforward!(
    psi_container::PSIContainer,
    ::Type{T},
    ff_model::SemiContinuousFF,
) where {T <: PSY.StaticInjection}
    bin_var = variable_name(get_binary_from_stage(ff_model), T)
    parameter_ref = UpdateRef{JuMP.VariableRef}(bin_var)
    for prefix in get_affected_variables(ff_model)
        var_name = variable_name(prefix, T)
        semicontinuousrange_ff(
            psi_container,
            constraint_name(FEEDFORWARD_BIN, T),
            parameter_ref,
            var_name,
        )
    end
end

function feedforward!(
    psi_container::PSIContainer,
    ::Type{T},
    ff_model::IntegralLimitFF,
) where {T <: PSY.StaticInjection}
    for prefix in get_affected_variables(ff_model)
        var_name = variable_name(prefix, T)
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_name)
        integral_limit_ff(
            psi_container,
            constraint_name(FEEDFORWARD, T),
            parameter_ref,
            var_name,
        )
    end
end

#########################FeedForward Variables Updating#####################################
# This makes the choice in which variable to get from the results.
function get_stage_variable(
    ::RecedingHorizon,
    stages::Pair{Stage{T}, Stage{T}},
    device_name::AbstractString,
    var_ref::UpdateRef,
) where {T <: AbstractOperationsProblem}
    variable = get_variable(stages.first.internal.psi_container, var_ref.access_ref)
    step = axes(variable)[2][1]
    return JuMP.value(variable[device_name, step])
end

function get_stage_variable(
    ::Consecutive,
    stages::Pair{Stage{T}, Stage{T}},
    device_name::String,
    var_ref::UpdateRef,
) where {T <: AbstractOperationsProblem}
    variable = get_variable(stages.first.internal.psi_container, var_ref.access_ref)
    step = axes(variable)[2][get_end_of_interval_step(stages.first)]
    return JuMP.value(variable[device_name, step])
end

function get_stage_variable(
    ::Synchronize,
    stages::Pair{Stage{T}, Stage{T}},
    device_name::String,
    var_ref::UpdateRef,
) where {T <: AbstractOperationsProblem}
    variable = get_variable(stages.first.internal.psi_container, var_ref.access_ref)
    step = axes(variable)[2][stages.second.internal.execution_count + 1]
    return JuMP.value(variable[device_name, step])
end

function feedforward_update(
    sync::FeedForwardChronology,
    param_reference::UpdateRef{JuMP.VariableRef},
    param_array::JuMPParamArray,
    to_stage::Stage,
    from_stage::Stage,
)
    for device_name in axes(param_array)[1]
        var_value =
            get_stage_variable(sync, (from_stage => to_stage), device_name, param_reference)
        PJ.fix(param_array[device_name], var_value)
    end
end
