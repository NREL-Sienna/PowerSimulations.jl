mutable struct CanonicalModel
    JuMPmodel::JuMP.AbstractModel
    variables::Dict{String, JuMP.Containers.DenseAxisArray}
    constraints::Dict{String, JuMP.Containers.DenseAxisArray}
    cost_function::Union{Nothing,JuMP.AbstractJuMPScalar}
    expressions::Dict{String, JumpAffineExpressionArray}
    pm_model::Any
end

