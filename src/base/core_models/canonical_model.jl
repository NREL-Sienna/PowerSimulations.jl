mutable struct CanonicalModel
    JuMPmodel::JuMP.AbstractModel
    variables::Dict{String, JuMP.Containers.DenseAxisArray}
    constraints::Dict{String, JuMP.Containers.DenseAxisArray}
    expressions::Dict{String, JumpAffineExpressionArray}
    pm_model::Dict
end

