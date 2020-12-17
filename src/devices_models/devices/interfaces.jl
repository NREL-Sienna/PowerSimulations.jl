########################### Interfaces ########################################################

get_variable_name(variabletype, d) = error("Not Implemented")
get_variable_binary(pv, d::PSY.Component) = get_variable_binary(pv, typeof(d))
get_variable_binary(pv, t::Type{<:PSY.Component}) = error("`get_variable_binary` must be implemented for $pv and $t")
get_variable_expression_name(_, ::Type{<:PSY.Component}) = nothing
get_variable_sign(_, ::Type{<:PSY.Component}) = 1.0
get_variable_initial_value(_, d::PSY.Component, _) = nothing
get_variable_lower_bound(_, d::PSY.Component, _) = nothing
get_variable_upper_bound(_, d::PSY.Component, _) = nothing
