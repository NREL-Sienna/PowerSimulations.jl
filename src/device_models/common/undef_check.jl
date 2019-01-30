function _remove_undef!(ExpressionArray::T) where T <: JumpExpressionMatrix
    for j in 1:size(ExpressionArray)[2]
        for i in 1:size(ExpressionArray)[1]
            !isassigned(ExpressionArray,i,j) ? ExpressionArray[i,j] = AffExpr(0.0) : continue
        end
    end
end


function _add_to_expression!(expression::JumpExpressionMatrix, ix::Int64, jx::Int64, var::JuMP.VariableRef, sign::Int64)

    isassigned(expression,  ix, jx) ? JuMP.add_to_expression!(expression[ix,jx], sign*var) : expression[ix,jx] = sign*var

end

function _add_to_expression!(expression::JumpExpressionMatrix, ix::Int64, jx::Int64, var::JuMP.VariableRef)

    isassigned(expression,  ix, jx) ? JuMP.add_to_expression!(expression[ix,jx], var) : expression[ix,jx] = var

end

function _add_to_expression!(expression::JumpExpressionMatrix, ix::Int64, jx::Int64, value::Float64)

    isassigned(expression,  ix, jx) ? expression[ix,jx] = value : expression[ix,jx] += value

end