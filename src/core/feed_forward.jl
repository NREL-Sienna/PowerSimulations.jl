struct UpperBoundFF <: AbstractAffectFeedForward
    name::Symbol
    variable_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function UpperBoundFF(name, ;variable_from_stage, affected_variables)
    return UpperBoundFF(name, variable, affected_variables, nothing)
end

get_variable_from_stage(p::UpperBoundFF) = p.binary_from_stage

struct RangeFF <: AbstractAffectFeedForward
    name::Symbol
    variable_from_stage_ub::Symbol
    variable_from_stage_lb::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function RangeFF(name ;variable_from_stage_ub, affected_variables_lb, affected_variables)
    return RangeFF(name, binary_from_stage, affected_variables, nothing)
end

get_bounds_from_stage(p::RangeFF) = (p.variable_from_stage_lb, p.variable_from_stage_lb)

struct SemiContinuousFF <: AbstractAffectFeedForward
    name::Symbol
    binary_from_stage::Symbol
    affected_variables::Vector{Symbol}
    cache::Union{Nothing, Type{<:AbstractCache}}
end

function SemiContinuousFF(name ;binary_from_stage, affected_variables)
    return SemiContinuousFF(name, binary_from_stage, affected_variables, nothing)
end

get_binary_from_stage(p::SemiContinuousFF) = p.binary_from_stage

get_affected_variables(p::AbstractAffectFeedForward) = p.affected_variables

function feed_forward_rule_check(synch::Synchronize,
                                 stage_number_from::Int64,
                                 from_stage::Stage,
                                 stage_number_to::Int64,
                                 to_stage::Stage)
    #Don't check for same Stage.
    stage_number_from == stage_number_to && return
    from_stage_horizon = PSY.get_forecasts_horizon(from_stage.sys)
    to_stage_count = get_execution_count(to_stage)
    to_stage_synch = synch.to_steps
    from_stage_synch = synch.from_horizon

    if from_stage_synch > from_stage_horizon
        error("The lookahead length $(from_stage_horizon) in stage is insufficient to synchronize with $(from_stage_synch) feed_forward steps")
    end

    if to_stage_synch*from_stage_synch != to_stage_count
        error("The execution total in stage is inconsistent with a chronology
                of $(from_stage_synch) feed_forward steps and $(to_stage_synch) runs. The expected
                number of executions is $(to_stage_synch*from_stage_synch)")
    end

    if (from_stage_horizon % from_stage_synch) != 0
        error("The number of feed_forward steps $(from_stage_horizon) in stage
               needs to be a mutiple of the horizon length $(from_stage_horizon)
               of stage to use Synchronize with parameters ($(from_stage_synch), $(to_stage_synch))")
    end

    return
end

feed_forward_rule_check(sync::Consecutive,
                        stage_number_from::Int64,
                        from_stage::Stage,
                        stage_number_to::Int64,
                        to_stage::Stage) = nothing

 feed_forward_rule_check(sync::RecedingHorizon,
                         stage_number_from::Int64,
                         from_stage::Stage,
                         stage_number_to::Int64,
                         to_stage::Stage) = nothing
