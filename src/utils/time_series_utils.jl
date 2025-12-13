apply_maybe_across_time_series(fn::Function, ts_data::AbstractVector) =
    fn.(ts_data)

apply_maybe_across_time_series(fn::Function, ts_data::TimeSeries.TimeArray) =
    fn.(values(ts_data))

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

# success case
_validate_eltype_helper(::Type{T}, element::T) where {T} = true

# failure case
_validate_eltype_helper(_, _) = false

"""
Validate that the eltype of the time series, or the field itself if it's not a time series,
is of the type given
"""
_validate_eltype(
    ::Type{T},
    component::PSY.Component,
    ts_key::IS.TimeSeriesKey,
    msg = "",
) where {T} =
    apply_maybe_across_time_series(component, ts_key) do x
        result = _validate_eltype_helper(T, x)
        result || throw(
            ArgumentError(
                "Expected element type $T but got $(typeof(x)) in time series $(get_name(ts_key)) for $(get_name(component))" *
                msg,
            ),
        )
    end

function _validate_eltype(::Type{T}, component::PSY.Component, element, msg = "") where {T}
    component_name = get_name(component)
    result = _validate_eltype_helper(T, element)
    result || throw(
        ArgumentError(
            "Expected element type $T but got $(typeof(element)) for $(get_name(component))" *
            msg,
        ),
    )
end
