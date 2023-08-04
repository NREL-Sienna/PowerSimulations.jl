function get_default_time_series_names(
    ::Type{PSY.StaticReserveGroup{T}},
    ::Type{GroupReserve}) where {T <: PSY.ReserveDirection}
    return Dict{String, Any}()
end

function get_default_attributes(
    ::Type{PSY.StaticReserveGroup{T}},
    ::Type{GroupReserve}) where {T <: PSY.ReserveDirection}
    return Dict{String, Any}()
end
