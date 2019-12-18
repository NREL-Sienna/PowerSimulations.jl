struct UpperBoundFF <: AbstractAffectFeedForward
    variable_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, CacheKey}
end

function UpperBoundFF(;variable_from_stage, affected_variables)
    return UpperBoundFF(variable_from_stage, affected_variables, nothing)
end

get_variable_from_stage(p::UpperBoundFF) = p.variable_from_stage

struct RangeFF <: AbstractAffectFeedForward
    variable_from_stage_ub::Symbol
    variable_from_stage_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, CacheKey}
end

function RangeFF(;variable_from_stage_ub, variable_from_stage_lb, affected_variables)
    return RangeFF(variable_from_stage_ub, variable_from_stage_lb, affected_variables, nothing)
end

get_bounds_from_stage(p::RangeFF) = (p.variable_from_stage_ub, p.variable_from_stage_lb)

struct SemiContinuousFF <: AbstractAffectFeedForward
    binary_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, CacheKey}
end

function SemiContinuousFF(;binary_from_stage, affected_variables)
    return SemiContinuousFF(binary_from_stage, affected_variables, nothing)
end

get_binary_from_stage(p::SemiContinuousFF) = p.binary_from_stage
get_affected_variables(p::AbstractAffectFeedForward) = p.affected_variables

####################### Feed Forward Cache Creation ###############################################
function add_ff_cache!(ff_model::RangeFF, device::Type{I}) where {I<:PSY.StaticInjection}
    prefix = get_variable_from_stage(ff_model)
    cache_ub = DeviceLevel(UpdateRef{JuMP.VariableRef}(Symbol(prefix[1], "_$(I)")))
    cache_lb = DeviceLevel(UpdateRef{JuMP.VariableRef}(Symbol(prefix[2], "_$(I)")))
    return (cache_ub, cache_lb)
end

function add_ff_cache!(ff_model::UpperBoundFF, device::Type{I}) where {I<:PSY.StaticInjection}
    prefix = get_bounds_from_stage(ff_model)
    cache = DeviceLevel(UpdateRef{JuMP.VariableRef}(Symbol(prefix, "_$(I)")))
    return cache
end

function add_ff_cache!(ff_model::SemiContinuousFF, device::Type{I}) where {I<:PSY.StaticInjection}
    prefix = get_binary_from_stage(ff_model)
    cache = DeviceCommitment(UpdateRef{JuMP.VariableRef}(Symbol(prefix, "_$(I)")))
    return cache
end
####################### Feed Forward Affects ###############################################

@doc raw"""
        ub_ff(psi_container::PSIContainer,
              cons_name::Symbol,
              param_reference::UpdateRef,
              var_name::Symbol)

Constructs a parametrized upper bound constraint to implement feed_forward from other models.
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
function ub_ff(psi_container::PSIContainer,
               cons_name::Symbol,
               param_reference::UpdateRef,
               var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    ub_name = _middle_rename(cons_name, "_", "ub")
    variable = get_variable(psi_container, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]

    @assert axes[2] == time_steps
    param_ub = _add_param_container!(psi_container, param_reference, set_name, time_steps)
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)

    for name in axes[1]
        value = JuMP.upper_bound(variable[name, 1])
        param_ub[name] = PJ.add_parameter(psi_container.JuMPmodel, value)
        for t in axes[2]
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                                variable[name, t] <= param_ub[name, t])
        end
    end

    return

end

@doc raw"""
        range_ff(psi_container::PSIContainer,
                        cons_name::Symbol,
                        param_reference::NTuple{2, UpdateRef},
                        var_name::Symbol)

Constructs min/max range parametrized constraint from device variable to include feed_forward.

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
function range_ff(psi_container::PSIContainer,
                  cons_name::Symbol,
                  param_reference::NTuple{2, UpdateRef},
                  var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    variable = get_variable(psi_container, var_name)
    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps

    #Create containers for the constraints
    param_lb =_add_param_container!(psi_container, param_reference[1], set_name, time_steps)
    param_ub =_add_param_container!(psi_container, param_reference[2], set_name, time_steps)

    #Create containers for the parameters
    con_lb =add_cons_container!(psi_container, lb_name, set_name, time_steps)
    con_ub =add_cons_container!(psi_container, ub_name, set_name, time_steps)

    for name in axes[1]
        for t in axes[2]
            param_lb[name] = PJ.add_parameter(psi_container.JuMPmodel,
                                          JuMP.lower_bound(variable[name, t]))
            param_ub[name] = PJ.add_parameter(psi_container.JuMPmodel,
                                          JuMP.upper_bound(variable[name, t]))
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                            variable[name, t] <= param_ub[name,t])
            con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                            variable[name, t] >= param_lb[name,t])
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
function semicontinuousrange_ff(psi_container::PSIContainer,
                                cons_name::Symbol,
                                param_reference::UpdateRef,
                                var_name::Symbol)
    time_steps = model_time_steps(psi_container)
    ub_name = _middle_rename(cons_name, "_", "ub")
    lb_name = _middle_rename(cons_name, "_", "lb")

    variable = get_variable(psi_container, var_name)

    axes = JuMP.axes(variable)
    set_name = axes[1]
    @assert axes[2] == time_steps
    param = _add_param_container!(psi_container, param_reference, set_name, time_steps)
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, set_name, time_steps)

    for name in axes[1]
        ub_value = JuMP.upper_bound(variable[name, 1])
        lb_value = JuMP.lower_bound(variable[name, 1])
        
        for t in axes[2]
            param[name,t] = PJ.add_parameter(psi_container.JuMPmodel, 1.0)
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                            variable[name, t] <= ub_value*param[name,t])
            con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                        variable[name, t] >= lb_value*param[name,t])
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

########################## FeedForward Constraints #########################################

function feed_forward!(psi_container::PSIContainer,
                     device_type::Type{T},
                     ff_model::Nothing) where {T<:PSY.Component}
    return
end

function feed_forward!(psi_container::PSIContainer,
                     device_type::Type{I},
                     ff_model::UpperBoundFF) where {I<:PSY.StaticInjection}

    for prefix in get_vars_prefix(ff_model)
        var_name = Symbol(prefix, "_$(I)")
        parameter_ref = UpdateRef{JuMP.VariableRef}(var_name)
        ub_ff(psi_container,
              Symbol("FF_$(I)"),
                     parameter_ref,
                     var_name)
    end

    return

end

function feed_forward!(psi_container::PSIContainer,
                     device_type::Type{I},
                     ff_model::SemiContinuousFF) where {I<:PSY.StaticInjection}
    bin_var = Symbol(get_binary_from_stage(ff_model), "_$(I)")
    parameter_ref = UpdateRef{JuMP.VariableRef}(bin_var)
    for prefix in get_affected_variables(ff_model)
        var_name = Symbol(prefix, "_$(I)")
        semicontinuousrange_ff(psi_container,
                               Symbol("FFbin_$(I)"),
                               parameter_ref,
                               var_name)
    end

    return
end

#########################FeedForward Variables Updating#####################################
function feed_forward_update(sync::Chron,
                            param_reference::UpdateRef{JuMP.VariableRef},
                            param_array::JuMPParamArray,
                            to_stage::Stage,
                            from_stage::Stage,
                            to_interval::T) where {Chron <: AbstractChronology,
                                                   T<:Dates.TimePeriod}

    execution_count = get_execution_count(to_stage) 
    from_stage_res = PSY.get_forecasts_resolution(PSI.get_sys(from_stage))
    to_stage_res = PSY.get_forecasts_resolution(PSI.get_sys(to_stage))
    for device_name in axes(param_array)[1] , time in axes(param_array)[2]
        remainder = (time*to_stage_res + (execution_count)*to_interval) % from_stage_res
        if remainder == Dates.Millisecond(0)
            var_count = Int((time*to_stage_res + (execution_count)*to_interval) / from_stage_res )
        else
            var_count = Int(ceil((time*to_stage_res + (execution_count)*to_interval) / from_stage_res))
        end
        var_value = get_stage_variable(Chron, from_stage, device_name, param_reference, var_count)
        PJ.fix(param_array[device_name,time], var_value)
    end

    return
end
