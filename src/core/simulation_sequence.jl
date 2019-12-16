mutable struct SimulationSequence
    initial_time::Union{Dates.DateTime, Nothing}
    horizons::Dict{String, Int64}
    intervals::Dict{String, <:Dates.TimePeriod}
    order::Dict{Int64, String}
    intra_stage_chronologies::Dict{Pair{String, String}, <:AbstractChronology}
    feed_forward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward}
    ini_cond_chronology::Dict{String, <:AbstractChronology}
    cache::Dict{String, Vector{<:AbstractCache}}

    function SimulationSequence(;initial_time::Union{Dates.DateTime, Nothing} = nothing,
                                 horizons::Dict{String, Int64},
                                 intervals::Dict{String, <:Dates.TimePeriod},
                                 order::Dict{Int64, String},
                                 intra_stage_chronologies = Dict{Pair{String, String}, AbstractChronology}(),
                                 feed_forward = Dict{Tuple{String, Symbol, Symbol}, AbstractAffectFeedForward}(),
                                 ini_cond_chronology = Dict{String, AbstractChronology}(),
                                 cache = Dict{String, Vector{AbstractCache}}())
        for (k, interval) in intervals
            intervals[k] = IS.time_period_conversion(interval)
        end
        new(
            initial_time,
            horizons,
            intervals,
            order,
            intra_stage_chronologies,
            feed_forward,
            ini_cond_chronology,
            cache)

    end
end

get_initial_time(s::SimulationSequence) = s.initial_time
get_horizon(s::SimulationSequence, name::String) = get(s.horizons, name, nothing)
get_interval(s::SimulationSequence, name::String) = get(s.intervals, name, nothing)
get_order(s::SimulationSequence, number::Int64) = get(s.order, number, nothing)
