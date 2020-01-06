struct UpperBoundFF <: AbstractAffectFeedForward
    variable_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function UpperBoundFF(;variable_from_stage, affected_variables)
    return UpperBoundFF(variable_from_stage, affected_variables, nothing)
end

get_variable_from_stage(p::UpperBoundFF) = p.binary_from_stage

struct RangeFF <: AbstractAffectFeedForward
    variable_from_stage_ub::Symbol
    variable_from_stage_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function RangeFF(;variable_from_stage_ub, variable_from_stage_lb, affected_variables)
    return RangeFF(variable_from_stage_ub, variable_from_stage_lb, affected_variables, nothing)
end

get_bounds_from_stage(p::RangeFF) = (p.variable_from_stage_lb, p.variable_from_stage_lb)

struct SemiContinuousFF <: AbstractAffectFeedForward
    binary_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function SemiContinuousFF(;binary_from_stage, affected_variables)
    return SemiContinuousFF(binary_from_stage, affected_variables, nothing)
end

get_binary_from_stage(p::SemiContinuousFF) = p.binary_from_stage
get_variable_from_stage(p::SemiContinuousFF) = p.binary_from_stage
get_affected_variables(p::AbstractAffectFeedForward) = p.affected_variables

####################### Feed Forward Affects ###############################################

function _add_parameter_value(psi_container::PSIContainer, 
                                param_array::P, value,
                                axs...) where {P<:JuMP.Containers.DenseAxisArray}
    @assert length(param_array.axes) == length(axs)
    isassigned(param_array, axs...) && return param_array[axs...]
    param_array[axs...] = PJ.add_parameter(psi_container.JuMPmodel, value)
    return param_array[axs...]
end

function _add_parameter_value(psi_container::PSIContainer,
                                param_array::P, value,
                                axs...) where { P<:JuMP.Containers.DenseAxisArray{PJ.ParameterRef,1}}
    @assert length(param_array.axes) == 1
    isassigned(param_array, first(axs)) && return param_array[first(axs)]
    param_array[first(axs)] = PJ.add_parameter(psi_container.JuMPmodel, value)
    return param_array[first(axs)]
end

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
    param_ub = get_parameters(psi_container, param_reference) 
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)

    for name in axes[1]
        value = JuMP.upper_bound(variable[name, 1])
        for t in axes[2]
            # Create Parameter & store it in the DenseAxisArray
            p_ub = _add_parameter_value(psi_container, param_ub, value, name, t)
            # Use the Parameter in the constraint
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                                variable[name, t] <= p_ub)
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
    param_lb = add_param_container!(psi_container, param_reference[1], set_name)
    param_ub = add_param_container!(psi_container, param_reference[2], set_name)

    #Create containers for the parameters
    con_lb = add_cons_container!(psi_container, lb_name, set_name, time_steps)
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)

    for name in axes[1]
        for t in axes[2]
            # Create Parameter & store it in the DenseAxisArray
            p_ub = _add_parameter_value(psi_container, param_ub, 
                                        JuMP.upper_bound(variable[name, 1]),
                                        name, t)
            p_lb = _add_parameter_value(psi_container, param_lb, 
                                        JuMP.lower_bound(variable[name, 1]),
                                        name, t)
            # Use the Parameter in the constraint
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                            variable[name, t] <= p_ub)
            con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                            variable[name, t] >= p_lb)
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
    param = get_parameters(psi_container, param_reference) 
    con_ub = add_cons_container!(psi_container, ub_name, set_name, time_steps)
    con_lb = add_cons_container!(psi_container, lb_name, set_name, time_steps)

    for name in axes[1]
        ub_value = JuMP.upper_bound(variable[name, 1])
        lb_value = JuMP.lower_bound(variable[name, 1])
        for t in axes[2]
            # Create Parameter & store it in the DenseAxisArray
            p = _add_parameter_value(psi_container, param,
                                    1.0, name, t)
            # Use the Parameter in the constraint
            con_ub[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                            variable[name, t] <= ub_value * p)
            con_lb[name, t] = JuMP.@constraint(psi_container.JuMPmodel,
                                        variable[name, t] >= lb_value * p)
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

    for prefix in get_variable_from_stage(ff_model)
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
                            from_stage::Stage) where Chron <: AbstractChronology

    !(get_execution_count(to_stage) % sync.to_executions == 0) && return

    var_count = get_execution_count(to_stage) ÷ sync.to_executions

    for device_name in axes(param_array)[1]
        var_value = get_stage_variable(Chron, from_stage, device_name, param_reference, var_count)
        PJ.fix(param_array[device_name], var_value)
    end
    return
end

function feed_forward_update(sync::SynchronizeTime,
                            variable_reference::UpdateRef{JuMP.VariableRef},
                            param_array::JuMPParamArray,
                            to_stage::Stage,
                            from_stage::Stage)

    variable_map = get_variable_map(to_stage)
    execution_count = get_execution_count(to_stage) 
    for device_name in axes(param_array, 1) , time in axes(param_array, 2)
        var_count = variable_map[(execution_count+1,time)]
        var_value = get_stage_variable(typeof(sync), from_stage, device_name, variable_reference, var_count)
        PJ.fix(param_array[device_name, time], var_value)
    end

    return
end
