######## Internal Simulation Object Structs ########
mutable struct StageInternal
    number::Int64
    executions::Int64
    execution_count::Int64
    psi_container::Union{Nothing, PSIContainer}
    cache_dict::Dict{CacheKey, <:AbstractCache}
    # Can probably be eliminated and use getter functions from
    # Simulation object. Need to determine if its always available in the stage update steps.
    chronolgy_dict::Dict{Int64, <:AbstractChronology}
    function StageInternal(number, executions, execution_count, psi_container)
        new(number, executions, execution_count, psi_container,
        Dict{CacheKey, AbstractCache}(),
        Dict{Int64, AbstractChronology}())
    end
end

mutable struct Stage{M<:AbstractOperationsProblem}
    template::OperationsProblemTemplate
    sys::PSY.System
    optimizer::JuMP.OptimizerFactory
    internal::Union{Nothing, StageInternal}

    function Stage(::Type{M},
                   template::OperationsProblemTemplate,
                   sys::PSY.System,
                   optimizer::JuMP.OptimizerFactory) where M<:AbstractOperationsProblem

    new{M}(template,
           sys,
           optimizer,
           nothing)

    end

end

function Stage(template::OperationsProblemTemplate,
               sys::PSY.System,
               optimizer::JuMP.OptimizerFactory) where M<:AbstractOperationsProblem
    return Stage(number, GenericOpProblem, sys, optimizer)
end

get_execution_count(s::Stage) = s.internal.execution_count
get_executions(s::Stage) = s.internal.executions
get_sys(s::Stage) = s.sys
get_template(s::Stage) = s.template
get_number(s::Stage) = s.internal.number
get_psi_container(s::Stage) = s.internal.psi_container
get_cache_dict(s::Stage, key::UpdateRef) = s.internal.cache_dict

# This makes the choice in which variable to get from the results.
function get_stage_variable(::Type{RecedingHorizon},
                           from_stage::Stage,
                           device_name::String,
                           var_ref::UpdateRef,
                           to_stage_execution_count::Int64)
    variable = get_value(from_stage.internal.psi_container, var_ref)
    step = axes(variable)[2][1]
    return JuMP.value(variable[device_name, step])
end

function get_stage_variable(::Type{Consecutive},
                             from_stage::Stage,
                             device_name::String,
                             var_ref::UpdateRef,
                             to_stage_execution_count::Int64)
    variable = get_value(from_stage.internal.psi_container, var_ref)
    step = axes(variable)[2][end]
    return JuMP.value(variable[device_name, step])
end

function get_stage_variable(chron::Type{Synchronize},
                            from_stage::Stage,
                            device_name::String,
                            var_ref::UpdateRef,
                            to_stage_execution_count::Int64)
    if haskey(from_stage.internal.cache_dict,CacheKey(FeedForwardCache, var_ref))
        cache = from_stage.internal.cache_dict[CacheKey(FeedForwardCache, var_ref)]
        step = axes(cache.value)[2][to_stage_execution_count]
        return cache_value(cache, device_name, step)
    else
        variable = get_value(from_stage.internal.psi_container, var_ref)
        step = axes(variable)[2][to_stage_execution_count]
        return JuMP.value(variable[device_name, step])
    end
end

#Defined here because it requires Stage to defined

initial_condition_update!(initial_condition_key::ICKey,
                          ::Nothing,
                          ini_cond_vector::Vector{InitialCondition},
                          to_stage::Stage,
                          from_stage::Stage) = nothing

function initial_condition_update!(initial_condition_key::ICKey,
                                    sync::Chron,
                                    ini_cond_vector::Vector{InitialCondition},
                                    to_stage::Stage,
                                    from_stage::Stage) where Chron <: AbstractChronology
    to_stage_execution_count = to_stage.internal.execution_count
    for ic in ini_cond_vector
        name = device_name(ic)
        update_ref = ic.update_ref
        var_value = get_stage_variable(Chron, from_stage, name, update_ref, to_stage_execution_count)
        cache = get(from_stage.internal.cache_dict, ic.cache, nothing)
        quantity = calculate_ic_quantity(initial_condition_key, ic, var_value, cache)
        PJ.fix(ic.value, quantity)
    end

    return
end
