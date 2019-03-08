function _remove_undef!(ExpressionArray::T) where T <: JuMPExpressionMatrix

    for j in 1:size(ExpressionArray)[2]

        for i in 1:size(ExpressionArray)[1]

            if !isassigned(ExpressionArray,i,j)
                 ExpressionArray[i,j] = zero(eltype(ExpressionArray))
            else
                continue
            end

        end

    end

    return

end


function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             var::JV,
                             sign::Int64) where {T <: JuMPExpressionMatrix, JV <: JuMP.AbstractVariableRef}

    if isassigned(expression,  ix, jx)
        JuMP.add_to_expression!(expression[ix,jx], sign*var)
    else
        expression[ix,jx] = sign*var
    end

    return

end

function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             var::JV) where {T <: JuMPExpressionMatrix, JV <: JuMP.AbstractVariableRef}

    if isassigned(expression,  ix, jx)
        JuMP.add_to_expression!(expression[ix,jx], var)
    else
        expression[ix,jx] = 1.0*var
    end

    return

end

function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             value::Float64) where T <: JuMPExpressionMatrix

    if isassigned(expression,  ix, jx)
        expression[ix,jx] += value
    else
        expression[ix,jx] = zero(eltype(expression)) + value
    end

    return

end
