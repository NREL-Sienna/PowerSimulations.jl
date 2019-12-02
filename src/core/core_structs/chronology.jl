abstract type AbstractChronology end

struct Synchronize <: AbstractChronology
    from_horizon::Int64 #number of time periods to grab data from
    to_steps::Int64 #number of times to run using the same data
end

struct RecedingHorizon <: AbstractChronology
    step::Int64
end

RecedingHorizon() = RecedingHorizon(1)

struct Consecutive <: AbstractChronology end
