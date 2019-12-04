struct Consecutive <: AbstractChronology end

struct Synchronize <: AbstractChronology
    from_steps::Int64    #number of time periods to grab data from
    to_executions::Int64 #number of times to run using the same data
    function Synchronize(;from_steps, to_executions)
        new(from_steps, to_executions)
    end
end

struct RecedingHorizon <: AbstractChronology
    step::Int64
    function RecedingHorizon(;from_step::Int64=1)
        new(step)
    end
end

function validate_chronology(synch::Synchronize,
                             stages::Pair,
                             horizons::Dict{String, Int64})
    from_stage_horizon = horizons[stages.first]
    to_stage_synch = synch.to_executions
    from_stage_synch = synch.from_steps

    if from_stage_synch > from_stage_horizon
        error("The lookahead length $(from_stage_horizon) in stage is insufficient to synchronize with $(from_stage_synch) feed_forward steps")
    end

    if (from_stage_horizon % from_stage_synch) != 0
        error("The number of feed_forward steps $(from_stage_horizon) in stage
               needs to be a mutiple of the horizon length $(from_stage_horizon)
               of stage to use Synchronize with parameters ($(from_stage_synch), $(to_stage_synch))")
    end

    return
end

validate_chronology(sync::Consecutive, stages::Pair, horizons::Dict{String, Int64}) = nothing

validate_chronology(sync::RecedingHorizon, stages::Pair, horizons::Dict{String, Int64}) = nothing

function validate_chronology(::T, stages::Pair, horizons::Dict{String, Int64}) where T <: AbstractChronology
    error("Feedforward Model $(T) not implemented")
    return
end
