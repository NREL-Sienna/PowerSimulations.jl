mutable struct SimulationSequence
    initial_time::Dates.DateTime
    horizons::Dict{Int64, Int64}
    intervals::Dict{Int64, <:Dates.TimePeriod}
    feed_forward_chronologies::Dict{Pair{Int64,Int64}, <:AbstractChronology}
    feedforward::Dict{Tuple{Symbol, Int64}, <:AbstractAffectFeedForward}
    ini_cond_chronology::Union{Dict{Int64, <:AbstractChronology}, Nothing}
    cache::Dict{Int64, Vector{<:AbstractCache}}

    function SimulationSequence(;initial_time::Dates.DateTime = Dates.DateTime(2010, 1, 1),
                                 horizons::Dict{Int64, Int64},
                                 intervals::Dict{Int64, <:Dates.TimePeriod},
                                 feed_forward_chronologies::Dict{Pair{Int64,Int64}, <:AbstractChronology} = Dict(),
                                 feedforward::Dict{Tuple{Symbol, Int64}, <:AbstractAffectFeedForward} = Dict(),
                                 ini_cond_chronology::Dict{Int64, <:AbstractChronology} = Dict(),
                                 cache::Dict{Int64, <:Vector{<:AbstractCache}} = Dict())
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
