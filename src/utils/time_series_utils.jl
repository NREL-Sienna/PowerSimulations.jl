apply_maybe_across_time_series(fn::Function, ts_data::AbstractVector) =
    fn.(ts_data)

apply_maybe_across_time_series(fn::Function, ts_data::AbstractDict) =
    apply_maybe_across_time_series.(Ref(fn), values(ts_data))

apply_maybe_across_time_series(fn::Function, ts_data::IS.TimeSeriesData) =
    apply_maybe_across_time_series(fn, PSY.get_data(ts_data))

"""
Helper function to look up a time series if necessary then apply a function (typically a
validation routine in a `do` block) to every element in it
"""
apply_maybe_across_time_series(
    fn::Function,
    component::PSY.Component,
    ts_key::IS.TimeSeriesKey,
) =
    apply_maybe_across_time_series(fn, PSY.get_time_series(component, ts_key))

# case where the element isn't a time series
apply_maybe_across_time_series(fn::Function, ::PSY.Component, elem) = fn(elem)

_validate_eltype(::Type{T}, element::T, _, _) where {T} = nothing
_validate_eltype(::Type{T}, element::U, location, component_name, msg = "") where {T, U} =
    throw(ArgumentError("Expected element type $T but got $U$location for $component_name"))
"""
Validate that the eltype of the time series, or the field itself if it's not a time series,
is of the type given
"""
function _validate_eltype(
    ::Type{T},
    component::PSY.Component,
    ts_key::IS.TimeSeriesKey,
    _ = "",
) where {T}
    ts_name = get_name(ts_key)
    component_name = get_name(component)
    apply_maybe_across_time_series(component, ts_key) do x
        _validate_eltype(T, x, " in time series $ts_name", component_name)
    end
end
function _validate_eltype(::Type{T}, component::PSY.Component, element, msg = "") where {T}
    component_name = get_name(component)
    _validate_eltype(T, element, msg, component_name)
end
