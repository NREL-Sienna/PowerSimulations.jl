"""
Defines a logical sequence for simulation within one stage.
"""
struct Consecutive <: AbstractChronology end

@doc raw"""
    Synchronize(from_steps::Int64)
Defines the co-ordination of time between Two stages.

# Arguments
- `from_steps::Int64`: Number of time periods to grab data from
"""
struct Synchronize <: AbstractChronology
    steps::Int64
    function Synchronize(;steps)
        new(steps)
    end
end

"""
    RecedingHorizon(step::Int64)
""" # TODO: Add DocString
struct RecedingHorizon <: AbstractChronology
    step::Int64
    function RecedingHorizon(;step::Int64=1)
        new(step)
    end
end

function check_chronology(sync::Synchronize,
                          stages::Pair,
                          horizons::Pair,
                          intervals::Pair)
    from_stage_horizon = horizons.first
    from_stage_resolution = IS.time_period_conversion(PSY.get_forecasts_resolution(stages.first.sys))
    @debug from_stage_resolution
    to_stage_interval = IS.time_period_conversion(intervals.second)
    @debug to_stage_interval
    to_stage_sync = Int(from_stage_resolution/to_stage_interval)
    from_stage_sync = sync.steps

    if from_stage_sync > from_stage_horizon
        throw(IS.ConflictingInputsError("The lookahead length $(from_stage_horizon) in stage is insufficient to syncronize with $(from_stage_sync) feed_forward steps"))
    end

    if (from_stage_horizon % from_stage_sync) != 0
        throw(IS.ConflictingInputsError("The number of feed_forward steps $(from_stage_horizon) in stage
               needs to be a mutiple of the horizon length $(from_stage_horizon)
               of stage to use Synchronize with parameters ($(from_stage_sync), $(to_stage_sync))"))
    end

    return
end

check_chronology(sync::Consecutive, stages::Pair, horizons::Pair, intervals::Pair) = nothing
check_chronology(sync::RecedingHorizon, stages::Pair, horizons::Pair, intervals::Pair) = nothing

function check_chronology(::T, stages::Pair, horizons::Pair, intervals::Pair) where T <: AbstractChronology
    error("Feedforward Model $(T) not implemented")
    return
end
