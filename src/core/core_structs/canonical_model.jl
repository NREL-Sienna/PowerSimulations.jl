mutable struct CanonicalModel
    JuMPmodel::JuMP.AbstractModel
    parametrized::Bool
    sequential_runs::Bool
    time_steps::UnitRange{Int64}
    resolution::Dates.Period
    variables::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    parameters::Union{Nothing,Dict{Symbol, JuMP.Containers.DenseAxisArray}}
    initial_conditions::Dict{Symbol, Array{InitialCondition}}
    pm_model::Union{Nothing,PM.GenericPowerModel}
end

_variable_type(cm::CanonicalModel) = JuMP.variable_type(cm.JuMPmodel)

model_time_steps(ps_m::CanonicalModel) = ps_m.time_steps
model_resolution(ps_m::CanonicalModel) = ps_m.resolution
model_has_parameters(ps_m::CanonicalModel) = ps_m.parametrized
model_runs_sequentially(ps_m::CanonicalModel) = ps_m.sequential_runs