
function remove_undef!(ExpressionArray::T) where T <: JumpExpressionMatrix
    for j in 1:size(ExpressionArray)[2]
        for i in 1:size(ExpressionArray)[1]
            !isassigned(ExpressionArray,i,j) ? ExpressionArray[i,j] = AffExpr(0.0) : continue
        end
    end
    return ExpressionArray
end
