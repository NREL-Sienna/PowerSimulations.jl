""" Data Container to construct range constraints"""
struct DeviceRange
    names::Vector{String}
    values::Vector{MinMax}
    additional_terms_ub::Vector{Vector{Symbol}}
    additional_terms_lb::Vector{Vector{Symbol}}
end

function DeviceRange(count::Int64)
    names = Vector{String}(undef, count)
    limit_values = Vector{MinMax}(undef, count)
    additional_terms_ub = fill(Vector{Symbol}(), count)
    additional_terms_lb = fill(Vector{Symbol}(), count)
    return DeviceRange(names, limit_values, additional_terms_ub, additional_terms_lb)
end

struct DeviceTimeSeries
    names::Vector{String}
    bus_numbers::Vector{Int64}
    multipliers::Vector{Float64}
    ts_vectors::Vector{Vector{Float64}}
end

function DeviceTimeSeries(count::Int64)
    names = Vector{String}(undef, count)
    bus_numbers = Vector{Int64}(undef, count)
    multipliers = Vector{Float64}(undef, count)
    ts_vectors = Vector{Vector{Float64}}(undef, count)
    return DeviceTimeSeries(names, bus_numbers, multipliers, ts_vectors)
end
    