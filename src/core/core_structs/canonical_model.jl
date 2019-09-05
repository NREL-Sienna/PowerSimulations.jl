const DSDA = Dict{Symbol, JuMP.Containers.DenseAxisArray}

"""Reference for parameters update when present"""
struct UpdateRef{T}
    access_ref::Symbol
end

const DRDA = Dict{UpdateRef, JuMP.Containers.DenseAxisArray}

function _pass_abstract_jump(optimizer::Union{Nothing, JuMP.OptimizerFactory},
                              parameters::Bool,
                              JuMPmodel::Union{JuMP.AbstractModel,Nothing})

    if isa(optimizer, Nothing)
        @info("The optimization model has no optimizer attached")
    end

    if !isnothing(JuMPmodel) && parameters

        if !haskey(JuMPmodel.ext, :params)
            @info("Model doesn't have Parameters enabled. Parameters will be enabled")
        end

        PJ.enable_parameters(JuMPmodel)

        return JuMPmodel

    end

    JuMPmodel = JuMP.Model(optimizer)

    if parameters
        PJ.enable_parameters(JuMPmodel)
    end

    return JuMPmodel

end

function _make_container_array(V::DataType, parameters::Bool, ax...)

    if parameters
        return JuMP.Containers.DenseAxisArray{PGAE{V}}(undef, ax...)
    else
        return JuMP.Containers.DenseAxisArray{GAE{V}}(undef, ax...)
    end

    return

end

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64},
                                parameters::Bool) where {S<:PM.AbstractPowerFormulation}

    return DSDA(:nodal_balance_active =>  _make_container_array(V,
                                                                parameters,
                                                                bus_numbers,
                                                                time_steps),
                :nodal_balance_reactive => _make_container_array(V,
                                                                 parameters,
                                                                 bus_numbers,
                                                                 time_steps))

end

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64},
                                parameters::Bool) where {S<:PM.AbstractActivePowerFormulation}

    return DSDA(:nodal_balance_active =>  _make_container_array(V,
                                                                parameters,
                                                                bus_numbers,
                                                                time_steps))
end


function _canonical_init(bus_numbers::Vector{Int64},
                        jump_model::JuMP.AbstractModel,
                        optimizer::Union{Nothing,JuMP.OptimizerFactory},
                        transmission::Type{S},
                        time_steps::UnitRange{Int64},
                        resolution::Dates.Period,
                        initial_time::Dates.DateTime,
                        parameters::Bool,
                        sequential_runs::Bool,
                        ini_con::Dict{Symbol,Array{InitialCondition}}) where {S<:PM.AbstractPowerFormulation}

    V = JuMP.variable_type(jump_model)

    canonical = CanonicalModel(jump_model,
                              optimizer,
                              parameters,
                              sequential_runs,
                              time_steps,
                              resolution,
                              initial_time,
                              DSDA(),
                              DSDA(),
                              zero(JuMP.GenericAffExpr{Float64, V}),
                              _make_expressions_dict(transmission,
                                                     V,
                                                     bus_numbers,
                                                     time_steps,
                                                     parameters),
                              parameters ? DRDA() : nothing,
                              ini_con,
                              nothing);

    return canonical

end

mutable struct CanonicalModel
    JuMPmodel::JuMP.AbstractModel
    optimizer_factory::Union{Nothing, JuMP.OptimizerFactory}
    parametrized::Bool
    sequential_runs::Bool
    time_steps::UnitRange{Int64}
    resolution::Dates.Period
    initial_time::Dates.DateTime
    variables::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    parameters::Union{Nothing, Dict{UpdateRef, JuMP.Containers.DenseAxisArray}}
    initial_conditions::Dict{Symbol, Array{InitialCondition}}
    pm_model::Union{Nothing, PM.GenericPowerModel}

    function CanonicalModel(JuMPmodel::JuMP.AbstractModel,
                            optimizer_factory::Union{Nothing, JuMP.OptimizerFactory},
                            parametrized::Bool,
                            sequential_runs::Bool,
                            time_steps::UnitRange{Int64},
                            resolution::Dates.Period,
                            initial_time::Dates.DateTime,
                            variables::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                            constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                            cost_function::JuMP.AbstractJuMPScalar,
                            expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                            parameters::Union{Nothing, Dict{UpdateRef, JuMP.Containers.DenseAxisArray}},
                            initial_conditions::Dict{Symbol, Array{InitialCondition}},
                            pm_model::Union{Nothing, PM.GenericPowerModel})

        #prevents having empty parameters and parametrized canonical model
        @assert isnothing(parameters) == !parametrized

        if (sequential_runs && sequential_runs != parametrized)
            throw(ArgumentError("Sequential simulations can't run when the specified OperationModel
                                 is not parametrized"))
        end

        new(JuMPmodel,
            optimizer_factory,
            parametrized,
            sequential_runs,
            time_steps,
            resolution,
            initial_time,
            variables,
            constraints,
            cost_function,
            expressions,
            parameters,
            initial_conditions,
            pm_model)

    end

end

function CanonicalModel(::Type{T},
                         sys::PSY.System,
                         optimizer::Union{Nothing,JuMP.OptimizerFactory};
                         kwargs...) where {T<:PM.AbstractPowerFormulation}

    sequential_runs = get(kwargs, :sequential_runs, false)
    user_defined_model = get(kwargs, :JuMPmodel, nothing)
    ini_con = get(kwargs, :initial_conditions, Dict{Symbol,Array{InitialCondition}}())
    parameters = get(kwargs, :parameters, false)
    forecast = get(kwargs, :forecast, true)
    jump_model = _pass_abstract_jump(optimizer, parameters, user_defined_model)
    initial_time = get(kwargs,
                       :initial_time,
                       PSY.get_forecasts_initial_time(sys))

    if forecast
        horizon = PSY.get_forecasts_horizon(sys)
        time_steps = 1:horizon
        resolution = PSY.get_forecasts_resolution(sys)
    else
        resolution = PSY.get_forecasts_resolution(sys)
        time_steps = 1:1
    end

    bus_numbers = sort([PSY.get_number(b) for b in PSY.get_components(PSY.Bus, sys)])

    return _canonical_init(bus_numbers,
                           jump_model,
                           optimizer,
                           T,
                           time_steps,
                           resolution,
                           initial_time,
                           parameters,
                           sequential_runs,
                           ini_con)

end

_variable_type(cm::CanonicalModel) = JuMP.variable_type(cm.JuMPmodel)
model_time_steps(canonical_model::CanonicalModel) = canonical_model.time_steps
model_resolution(canonical_model::CanonicalModel) = canonical_model.resolution
model_has_parameters(canonical_model::CanonicalModel) = canonical_model.parametrized
model_runs_sequentially(canonical_model::CanonicalModel) = canonical_model.sequential_runs
model_initial_time(canonical_model::CanonicalModel) = canonical_model.initial_time
vars(canonical_model::CanonicalModel) = canonical_model.variables
cons(canonical_model::CanonicalModel) = canonical_model.constraints
var(canonical_model::CanonicalModel, name::Symbol) = canonical_model.variables[name]
con(canonical_model::CanonicalModel, name::Symbol) = canonical_model.constraints[name]
par(canonical_model::CanonicalModel, param_reference::UpdateRef) = canonical_model.parameters[param_reference]
exp(canonical_model::CanonicalModel, name::Symbol) = canonical_model.expressions[name]

# This function is added here because Canonical Model hasn't been defined until now.

function InitialCondition(canonical::CanonicalModel,
                          device::PSY.Device,
                          value::Float64)

    if model_has_parameters(canonical)
        return InitialCondition(device, PJ.add_parameter(canonical.JuMPmodel, value))
    else
        return InitialCondition(device, value)
    end

end

function  get_ini_cond(canonical_model::CanonicalModel, name::Symbol)
    return get(canonical_model.initial_conditions, name, Vector{InitialCondition}())
end

device_name(ini_cond::InitialCondition) = PSY.get_name(ini_cond.device)
