mutable struct canonical_model
    JuMPmodel::JuMP.AbstractModel
    variables::Dict{String, JuMP.Containers.DenseAxisArray{VariableRef}}
    constraints::Dict{String, JuMP.Containers.DenseAxisArray}
    expressions::Dict{String, JumpExpressionMatrix}
    pm_model::Dict
end

