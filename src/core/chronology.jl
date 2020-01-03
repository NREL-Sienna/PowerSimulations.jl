"""
Defines a logical sequence for simulation within one stage.
"""
struct Consecutive <: AbstractChronology end

@doc raw"""
    Synchronize(from_steps::Int64, 
                to_executions::Int64
                )
Defines the co-ordination of time between Two stages.  

# Arguments
- `from_steps::Int64`: Number of time periods to grab data from
- `to_executions::Int64`: Number of times to run using the same data
"""
struct Synchronize <: AbstractChronology
    from_steps::Int64    
    to_executions::Int64 
    function Synchronize(;from_steps, to_executions)
        new(from_steps, to_executions)
    end
end


@doc raw"""
    SynchronizeTime(from_steps::Int64, 
                to_blocks::Int64
                )
""" # TODO: Add DocString  
struct SynchronizeTime <: AbstractChronology
    from_steps::Int64    
    to_blocks::Int64 
    function SynchronizeTime(;from_steps, to_blocks)
        new(from_steps, to_blocks)
    end
end


"""
    RecedingHorizon(step::Int64
                    )                             
""" # TODO: Add DocString    
struct RecedingHorizon <: AbstractChronology
    step::Int64
    function RecedingHorizon(;step::Int64=1)
        new(step)
    end
end

function check_chronology(sync::Synchronize,
                             stages::Pair,
                             horizons::Dict{String, Int64})
    from_stage_horizon = horizons[stages.first]
    to_stage_sync = sync.to_executions
    from_stage_sync = sync.from_steps

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

function check_chronology(sync::SynchronizeTime,
                             stages::Pair,
                             horizons::Dict{String, Int64})
    from_stage_horizon = horizons[stages.first]
    to_stage_sync = sync.to_blocks
    from_stage_sync = sync.from_steps

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

check_chronology(sync::Consecutive, stages::Pair, horizons::Dict{String, Int64}) = nothing

check_chronology(sync::RecedingHorizon, stages::Pair, horizons::Dict{String, Int64}) = nothing

function check_chronology(::T, stages::Pair, horizons::Dict{String, Int64}) where T <: AbstractChronology
    error("Feedforward Model $(T) not implemented")
    return
end
