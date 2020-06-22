###### Operations for JuMPExpressionMatrix ######

function _remove_undef!(expression_array::T) where {T <: JuMPExpressionMatrix}
    for j in 1:size(expression_array)[2]
        for i in 1:size(expression_array)[1]
            if !isassigned(expression_array, i, j)
                expression_array[i, j] = zero(eltype(expression_array))
            else
                continue
            end
        end
    end

    return
end

###### Operations for JuMPDenseAxisExpressionMatrix ######

function _remove_undef!(axis_expression_array::JuMP.Containers.DenseAxisArray)
    _remove_undef!(axis_expression_array.data)
    return
end

function add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
    else
        expression_array[ix, jx] = multiplier * var
    end

    return
end

function add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    var::JV,
    multiplier::Float64,
    constant::Float64,
) where {T, JV <: JuMP.AbstractVariableRef}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], multiplier, var)
        JuMP.add_to_expression!(expression_array[ix, jx], constant)
    else
        expression_array[ix, jx] = multiplier * var + constant
    end

    return
end

function add_to_expression!(expression_array::T, ix::Int, jx::Int, value::Float64) where {T}
    if isassigned(expression_array, ix, jx)
        expression_array[ix, jx].constant += value
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + value
    end

    return
end

function add_to_expression!(
    expression_array::T,
    ix::Int,
    jx::Int,
    parameter::PJ.ParameterRef,
) where {T}
    if isassigned(expression_array, ix, jx)
        JuMP.add_to_expression!(expression_array[ix, jx], 1.0, parameter)
    else
        expression_array[ix, jx] = zero(eltype(expression_array)) + parameter
    end

    return
end
