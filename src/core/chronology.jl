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
