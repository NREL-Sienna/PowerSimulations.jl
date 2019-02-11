function remove_undef!(ExpressionArray::T) where T <: JumpExpressionMatrix
    expr_type = eltype(ExpressionArray)
    for j in 1:size(ExpressionArray)[2]
        for i in 1:size(ExpressionArray)[1]
            !isassigned(ExpressionArray,i,j) ? ExpressionArray[i,j] = expr_type() : continue
        end
    end
end
