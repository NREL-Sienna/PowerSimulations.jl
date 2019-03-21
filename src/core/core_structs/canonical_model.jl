mutable struct CanonicalModel
    JuMPmodel::JuMP.AbstractModel
    variables::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    cost_function::Union{Nothing, JuMP.AbstractJuMPScalar}
    expressions::Dict{Symbol, JuMPParamAffineExprArray}
    parameters::Dict{Symbol, Any}
    initial_conditions::Dict{Symbol, Any}
    pm_model::Union{Nothing,PM.GenericPowerModel}
end

_variable_type(cm::CanonicalModel) = JuMP.variable_type(cm.JuMPmodel)
