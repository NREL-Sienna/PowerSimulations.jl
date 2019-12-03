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

mutable struct SimulationSequence
    initial_time::Dates.DateTime
    horizons::Dict{Int64, Int64}
    intervals::Dict{Int64, Dates.Period}
    chronologies::Dict{Pair{Int64,Int64}, <:AbstractChronology}
    feedforward::Dict{Int64, Any}
    ini_cond_chronology::Union{Dict{Int64, <:AbstractChronology}, Nothing}
    cache::Dict{Int64, Vector{<:AbstractCache}}
end
