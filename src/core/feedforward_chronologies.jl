mutable struct UpdateTrigger
    execution_wait_count::Int
    current_count::Int
end

function set_execution_wait_count!(trigger::UpdateTrigger, val::Int)
    trigger.execution_wait_count = val
    return
end

function update_count!(trigger::UpdateTrigger)
    trigger.current_count += 1
    return
end

function trigger_update(trigger::UpdateTrigger)
    return trigger.current_count == trigger.execution_wait_count
end

function reset_trigger_count!(trigger::UpdateTrigger)
    trigger.current_count = 0
    return
end

function initialize_trigger_count!(trigger::UpdateTrigger)
    trigger.current_count = trigger.execution_wait_count
    return
end

function get_execution_wait_count(trigger::UpdateTrigger)
    return trigger.execution_wait_count
end

############################ Chronologies For FeedForward ###################################
@doc raw"""
    Synchronize(periods::Int)
Defines the co-ordination of time between Two problems.

# Arguments
- `periods::Int`: Number of time periods to grab data from
"""
mutable struct Synchronize <: FeedForwardChronology
    periods::Int
    current::Int
    trigger::UpdateTrigger
    function Synchronize(; periods)
        new(periods, 0, UpdateTrigger(-1, -1))
    end
end
# TODO: Add DocString
"""
    RecedingHorizon(period::Int)
"""
mutable struct RecedingHorizon <: FeedForwardChronology
    periods::Int
    trigger::UpdateTrigger
    function RecedingHorizon(; periods::Int = 1)
        new(periods, UpdateTrigger(-1, -1))
    end
end

mutable struct Consecutive <: FeedForwardChronology
    trigger::UpdateTrigger
    function Consecutive()
        new(UpdateTrigger(-1, -1))
    end
end

mutable struct FullHorizon <: FeedForwardChronology
    trigger::UpdateTrigger
    function FullHorizon()
        new(UpdateTrigger(-1, -1))
    end
end

mutable struct Range <: FeedForwardChronology
    range::UnitRange{Int}
    trigger::UpdateTrigger
    function Range(; range::UnitRange{Int})
        new(range, UpdateTrigger(-1, -1))
    end
end
