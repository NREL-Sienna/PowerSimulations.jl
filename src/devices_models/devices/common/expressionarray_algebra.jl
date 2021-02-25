###### Operations for JuMPExpressionMatrix ######

function remove_undef!(expression_array::T) where {T}
    for ix in eachindex(expression_array)
        expression_array[ix] = zero(eltype(expression_array))
    end
    return
end

###### Operations for JuMPDenseAxisExpressionMatrix ######

function remove_undef!(axis_expression_array::JuMP.Containers.DenseAxisArray)
    remove_undef!(axis_expression_array.data)
    return
end

function add_to_expression!(
    expression_array::T,
    var::JV,
    multiplier::Float64,
    ixs::Int...,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ixs...)
        JuMP.add_to_expression!(expression_array[ixs...], multiplier, var)
    else
        expression_array[ixs...] = multiplier * var
    end

    return
end

function add_to_expression!(
    expression_array::T,
    var::JV,
    multiplier::Float64,
    constant::Float64,
    ixs::Int...,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ixs...)
        JuMP.add_to_expression!(expression_array[ixs...], multiplier, var)
        JuMP.add_to_expression!(expression_array[ixs...], constant)
    else
        expression_array[ixs...] = multiplier * var + constant
    end

    return
end

function add_to_expression!(expression_array::T, value::Float64, ixs::Int...) where {T}
    if isassigned(expression_array, ixs...)
        expression_array[ixs...].constant += value
    else
        expression_array[ixs...] = zero(eltype(expression_array)) + value
    end

    return
end

function add_to_expression!(
    expression_array::T,
    parameter::PJ.ParameterRef,
    ixs::Int...,
) where {T}
    if isassigned(expression_array, ixs...)
        JuMP.add_to_expression!(expression_array[ixs...], 1.0, parameter)
    else
        expression_array[ixs...] = zero(eltype(expression_array)) + parameter
    end

    return
end
