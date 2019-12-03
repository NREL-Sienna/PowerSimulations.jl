mutable struct SimulationSequence
    initial_time::Dates.DateTime
    horizons::Dict{String, Int64}
    intervals::Dict{String, <:Dates.TimePeriod}
    feed_forward_chronologies::Dict{Pair{String, String}, <:AbstractChronology}
    feedforward::Dict{Tuple{String, Symbol}, <:AbstractAffectFeedForward}
    ini_cond_chronology::Dict{String, <:AbstractChronology}
    cache::Dict{String, Vector{<:AbstractCache}}

    function SimulationSequence(;initial_time::Dates.DateTime = Dates.DateTime(2010, 1, 1),
                                 horizons::Dict{String, Int64},
                                 intervals::Dict{String, <:Dates.TimePeriod},
                                 stage_order::Dict{Int64, String},
                                 feed_forward_chronologies::Dict{Pair{String, String}, <:AbstractChronology} = Dict(),
                                 feedforward::Dict{Tuple{String, Symbol}, <:AbstractAffectFeedForward} = Dict(),
                                 ini_cond_chronology::Dict{String, <:AbstractChronology} = Dict(),
                                 cache::Dict{String, <:Vector{<:AbstractCache}} = Dict())
        new(
            initial_time,
            horizons,
            intervals,
            feed_forward_chronologies,
            feedforward,
            ini_cond_chronology,
            cache)

    end
end
