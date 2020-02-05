"""
Defines a logical sequence for simulation within one stage.
"""
struct Consecutive <: AbstractChronology end

@doc raw"""
    Synchronize(periods::Int64)
Defines the co-ordination of time between Two stages.

# Arguments
- `periods::Int64`: Number of time periods to grab data from
"""
struct Synchronize <: AbstractChronology
    periods::Int64
    function Synchronize(; periods)
        new(periods)
    end
end

"""
    RecedingHorizon(period::Int64)
""" # TODO: Add DocString
struct RecedingHorizon <: AbstractChronology
    period::Int64
    function RecedingHorizon(; period::Int64 = 1)
        new(period)
    end
end

function check_chronology(sync::Synchronize, stages::Pair, horizons::Pair, intervals::Pair)
    from_stage_horizon = horizons.first
    from_stage_resolution =
        IS.time_period_conversion(PSY.get_forecasts_resolution(stages.first.sys))
    @debug from_stage_resolution
    to_stage_interval = IS.time_period_conversion(intervals.second)
    @debug to_stage_interval
    to_stage_sync = Int(from_stage_resolution / to_stage_interval)
    from_stage_sync = sync.periods

    if from_stage_sync > from_stage_horizon
        throw(IS.ConflictingInputsError("The lookahead length $(from_stage_horizon) in stage is insufficient to syncronize with $(from_stage_sync) feed_forward periods"))
    end

    if (from_stage_horizon % from_stage_sync) != 0
        throw(IS.ConflictingInputsError("The number of feed_forward periods $(from_stage_horizon) in stage
               needs to be a mutiple of the horizon length $(from_stage_horizon)
               of stage to use Synchronize with parameters ($(from_stage_sync), $(to_stage_sync))"))
    end

    return
end

function get_ini_cond_from_stage(order::Dict{String, Int64}, sync::Consecutive)



    @warn("The chronoly Consecutive does not make use of the horizons parameter")
end

function check_chronology(sync::Consecutive, stages::Pair, horizons::Pair, intervals::Pair)
    @warn("The chronoly Consecutive does not make use of the horizons parameter")
    return
end

check_chronology(sync::RecedingHorizon, stages::Pair, horizons::Pair, intervals::Pair) =
    nothing

function check_chronology(
    ::T,
    stages::Pair,
    horizons::Pair,
    intervals::Pair,
) where {T<:AbstractChronology}
    error("Chronology $(T) not implemented")
    return
end
