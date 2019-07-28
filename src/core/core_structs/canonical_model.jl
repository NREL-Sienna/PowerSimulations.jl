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
    parameters::Union{Nothing, Dict{Symbol, JuMP.Containers.DenseAxisArray}}
    initial_conditions::Dict{Symbol, Array{InitialCondition}}
    pm_model::Union{Nothing, PM.GenericPowerModel}

    function CanonicalModel(JuMPmodel::JuMP.AbstractModel,
                            parametrized::Bool,
                            sequential_runs::Bool,
                            time_steps::UnitRange{Int64},
                            resolution::Dates.Period,
                            variables::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                            constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                            cost_function::JuMP.AbstractJuMPScalar,
                            expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                            parameters::Union{Nothing, Dict{Symbol, JuMP.Containers.DenseAxisArray}},
                            initial_conditions::Dict{Symbol, Array{InitialCondition}},
                            pm_model::Union{Nothing, PM.GenericPowerModel})

        #prevents having empty parameters and parametrized canonical model
        @assert isnothing(parameters) == !parametrized

        if (sequential_runs && sequential_runs != parametrized)
            throw(ArgumentError("Sequential Models can't run when the specified operational Models are not parametrized"))
        end

        new(JuMPmodel,
            parametrized,
            sequential_runs,
            time_steps,
            resolution,
            variables,
            constraints,
            cost_function,
            expressions,
            parameters,
            initial_conditions,
            pm_model)

    end

end

_variable_type(cm::CanonicalModel) = JuMP.variable_type(cm.JuMPmodel)

model_time_steps(ps_m::CanonicalModel) = ps_m.time_steps
model_resolution(ps_m::CanonicalModel) = ps_m.resolution
model_has_parameters(ps_m::CanonicalModel) = ps_m.parametrized
model_runs_sequentially(ps_m::CanonicalModel) = ps_m.sequential_runs
vars(ps_m::CanonicalModel) = ps_m.variables
cons(ps_m::CanonicalModel) = ps_m.constraints
var(ps_m::CanonicalModel, name::Symbol) = ps_m.variables[name]
con(ps_m::CanonicalModel, name::Symbol) = ps_m.constraints[name]
par(ps_m::CanonicalModel, name::Symbol) = ps_m.parameters[name]
exp(ps_m::CanonicalModel, name::Symbol) = ps_m.expressions[name]
ini_cond(ps_m::CanonicalModel, name::Symbol) = ps_m.initial_conditions[name]
