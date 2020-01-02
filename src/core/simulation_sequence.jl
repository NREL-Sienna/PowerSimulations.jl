@doc raw"""
    SimulationSequence(initial_time::Union{Dates.DateTime, Nothing}
                        horizons::Dict{String, Int64}
                        intervals::Dict{String, <:Dates.TimePeriod}
                        order::Dict{Int64, String}
                        intra_stage_chronologies::Dict{Pair{String, String}, <:AbstractChronology}
                        feed_forward::Dict{Tuple{String, Symbol, Symbol}, <:AbstractAffectFeedForward}
                        ini_cond_chronology::Dict{String, <:AbstractChronology}
                        cache::Dict{String, Vector{<:AbstractCache}}
                        )                               
""" # TODO: Add DocString  
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
        intervals = IS.time_period_conversion(intervals)                                 
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
get_horizon(s::SimulationSequence, stage::String) = get(s.horizons, stage, nothing)
get_interval(s::SimulationSequence, stage::String) = get(s.intervals, stage, nothing)
get_order(s::SimulationSequence, number::Int64) = get(s.order, number, nothing)
get_name(s::SimulationSequence ,stage::Stage) = get(s.order, get_number(stage), nothing)
