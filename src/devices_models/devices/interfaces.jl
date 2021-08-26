########################### Interfaces ########################################################

get_variable_key(variabletype, d) = error("Not Implemented")
get_variable_binary(pv, t::Type{<:PSY.Component}, _) =
    error("`get_variable_binary` must be implemented for $pv and $t")
get_variable_initial_value(_, ::PSY.Component, __) = nothing
get_variable_lower_bound(_, ::PSY.Component, __) = nothing
get_variable_upper_bound(_, ::PSY.Component, __) = nothing
get_multiplier_value(_, ::PSY.Component, __) = NaN
