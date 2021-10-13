########################### Interfaces ########################################################

get_variable_key(variabletype, d) = error("Not Implemented")
get_variable_binary(pv, t::Type{<:PSY.Component}, _) =
    error("`get_variable_binary` must be implemented for $pv and $t")
get_variable_warm_start_value(_, ::PSY.Component, __) = nothing
get_variable_lower_bound(_, ::PSY.Component, __) = nothing
get_variable_upper_bound(_, ::PSY.Component, __) = nothing
get_multiplier_value(x, y::PSY.Component, z) =
    error("Unable to get parameter $x for device $y for formulation $z")
get_expression_type_for_reserve(_, y::Type{<:PSY.Component}, z) =
    error("`get_expression_type_for_reserve` must be implemented for $y and $z")
get_initial_conditions_device_model(
    ::DeviceModel{T, D},
) where {T <: PSY.Device, D <: AbstractDeviceFormulation} =
    error("`get_initial_conditions_device_model` must be implemented for $T and $D")
requires_initialization(::AbstractDeviceFormulation) = false
_get_initial_condition_type(
    X::Type{<:ConstraintType},
    Y::Type{<:PSY.Component},
    Z::Type{<:AbstractDeviceFormulation},
) = error("`_get_initial_condition_type` must be implemented for $X , $Y and $Z")
