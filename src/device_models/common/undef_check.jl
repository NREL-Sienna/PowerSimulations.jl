function _remove_undef!(ExpressionArray::T) where T <: JumpExpressionMatrix

    for j in 1:size(ExpressionArray)[2]

        for i in 1:size(ExpressionArray)[1]

            !isassigned(ExpressionArray,i,j) ? ExpressionArray[i,j] = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}(0.0) : continue

        end

    end

end


function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             var::JV,
                             sign::Int64) where {T <: JumpExpressionMatrix, JV <: JuMP.AbstractVariableRef}

    isassigned(expression,  ix, jx) ? JuMP.add_to_expression!(expression[ix,jx], sign*var) : expression[ix,jx] = sign*var

end

function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             var::JV) where {T <: JumpExpressionMatrix, JV <: JuMP.AbstractVariableRef}

    if isassigned(expression,  ix, jx)
        JuMP.add_to_expression!(expression[ix,jx], var)
    else
        expression[ix,jx] = 1.0*var
    end

end

function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             value::Float64) where T <: JumpExpressionMatrix

    isassigned(expression,  ix, jx) ? expression[ix,jx] += value : expression[ix,jx] = value

end