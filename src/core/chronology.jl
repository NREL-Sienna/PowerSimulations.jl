struct Consecutive <: AbstractChronology end

struct Synchronize <: AbstractChronology
    from_periods::Int64    #number of time periods to grab data from
    function Synchronize(;from_periods)
        new(from_periods)
    end
end

struct RecedingHorizon <: AbstractChronology
    step::Int64
    function RecedingHorizon(;from_step::Int64=1)
        new(from_step)
    end
end

function check_chronology(sync::Synchronize,
                             stages::Pair,
                             horizons::Dict{String, Int64})
    from_stage_horizon = horizons[stages.first]
    from_stage_sync = sync.from_periods

    if from_stage_sync > from_stage_horizon
        throw(IS.ConflictingInputsError("The lookahead length $(from_stage_horizon) in stage is insufficient to syncronize with $(from_stage_sync) feed_forward steps"))
    end

    if (from_stage_horizon % from_stage_sync) != 0
        throw(IS.ConflictingInputsError("The number of feed_forward steps $(from_stage_horizon) in stage
               needs to be a mutiple of the horizon length $(from_stage_horizon)
               of stage to use Synchronize with parameters ($(from_stage_sync))"))
    end

    return
end

check_chronology(sync::Consecutive, stages::Pair, horizons::Dict{String, Int64}) = nothing

check_chronology(sync::RecedingHorizon, stages::Pair, horizons::Dict{String, Int64}) = nothing

function check_chronology(::T, stages::Pair, horizons::Dict{String, Int64}) where T <: AbstractChronology
    error("Feedforward Model $(T) not implemented")
    return
end
