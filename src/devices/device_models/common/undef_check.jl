function _remove_undef!(ExpressionArray::T) where T <: JumpExpressionMatrix

    for j in 1:size(ExpressionArray)[2]

        for i in 1:size(ExpressionArray)[1]

            if !isassigned(ExpressionArray,i,j) 
                 ExpressionArray[i,j] = JuMP.GenericAffExpr{Float64, JuMP.VariableRef}(0.0) 
            else
                continue
            end

        end

    end

    return nothing

end


function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             var::JV,
                             sign::Int64) where {T <: JumpExpressionMatrix, JV <: JuMP.AbstractVariableRef}

    if isassigned(expression,  ix, jx) 
        JuMP.add_to_expression!(expression[ix,jx], sign*var) 
    else 
        expression[ix,jx] = sign*var
    end

    return nothing

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

    return nothing

end

function _add_to_expression!(expression::T,
                             ix::Int64,
                             jx::Int64,
                             value::Float64) where T <: JumpExpressionMatrix

    if isassigned(expression,  ix, jx)  
        expression[ix,jx] += value 
    else 
        expression[ix,jx] = JuMP.AffExpr(value)
    end

    return nothing

end