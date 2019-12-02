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
