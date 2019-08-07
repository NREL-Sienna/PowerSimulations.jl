const DSDA = Dict{Symbol, JuMP.Containers.DenseAxisArray}

"""Reference for parameters update when present"""
struct RefParam{T}
    access_ref::Symbol
end

const DRDA = Dict{RefParam, JuMP.Containers.DenseAxisArray}

function _pass_abstract_jump(optimizer::Union{Nothing, JuMP.OptimizerFactory}; kwargs...)

    if isa(optimizer, Nothing)
        @info("The optimization model has no optimizer attached")
    end

    parameters = get(kwargs, :parameters, false)

    if :JuMPmodel in keys(kwargs) && parameters

        if !haskey(kwargs[:JuMPmodel].ext, :params)
            @info("Model doesn't have Parameters enabled. Parameters will be enabled")
        end

        PJ.enable_parameters(kwargs[:JuMPmodel])

        return kwargs[:JuMPmodel]

    end

    JuMPmodel = JuMP.Model(optimizer)

    if parameters
        PJ.enable_parameters(JuMPmodel)
    end

    return JuMPmodel

end

function _make_container_array(V::DataType, ax...; kwargs...)

    parameters = get(kwargs, :parameters, false)

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
                                time_steps::UnitRange{Int64};
                                kwargs...) where {S<:PM.AbstractPowerFormulation}

    return DSDA(:nodal_balance_active =>  _make_container_array(V,
                                                                bus_numbers,
                                                                time_steps; kwargs...),
                :nodal_balance_reactive => _make_container_array(V,
                                                                 bus_numbers,
                                                                 time_steps; kwargs...))

end

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64};
                                kwargs...) where {S<:PM.AbstractActivePowerFormulation}

    return DSDA(:nodal_balance_active =>  _make_container_array(V,
                                                                bus_numbers,
                                                                time_steps; kwargs...))
end


function _canonical_init(bus_numbers::Vector{Int64},
                        optimizer::Union{Nothing,JuMP.OptimizerFactory},
                        transmission::Type{S},
                        time_steps::UnitRange{Int64},
                        resolution::Dates.Period,
                        initial_time::Dates.DateTime;
                        kwargs...) where {S<:PM.AbstractPowerFormulation}

    parameters = get(kwargs, :parameters, false)
    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)

    canonical = CanonicalModel(jump_model,
                              optimizer,
                              parameters,
                              get(kwargs, :sequential_runs, false),
                              time_steps,
                              resolution,
                              initial_time,
                              DSDA(),
                              DSDA(),
                              zero(JuMP.GenericAffExpr{Float64, V}),
                              _make_expressions_dict(transmission,
                                                     V,
                                                     bus_numbers,
                                                     time_steps; kwargs...),
                              parameters ? DRDA() : nothing,
                              Dict{Symbol,Array{InitialCondition}}(),
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
    parameters::Union{Nothing, Dict{RefParam, JuMP.Containers.DenseAxisArray}}
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
                            parameters::Union{Nothing, Dict{RefParam, JuMP.Containers.DenseAxisArray}},
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

function  CanonicalModel(::Type{T},
                         sys::PSY.System,
                         optimizer::Union{Nothing,JuMP.OptimizerFactory};
                         kwargs...) where {T<:PM.AbstractPowerFormulation}


    forecast = get(kwargs, :forecast, true)
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
                           optimizer,
                           T,
                           time_steps,
                           resolution,
                           initial_time;
                           kwargs...)

end

_variable_type(cm::CanonicalModel) = JuMP.variable_type(cm.JuMPmodel)
model_time_steps(ps_m::CanonicalModel) = ps_m.time_steps
model_resolution(ps_m::CanonicalModel) = ps_m.resolution
model_has_parameters(ps_m::CanonicalModel) = ps_m.parametrized
model_runs_sequentially(ps_m::CanonicalModel) = ps_m.sequential_runs
model_initial_time(ps_m::CanonicalModel) = ps_m.initial_time
vars(ps_m::CanonicalModel) = ps_m.variables
cons(ps_m::CanonicalModel) = ps_m.constraints
var(ps_m::CanonicalModel, name::Symbol) = ps_m.variables[name]
con(ps_m::CanonicalModel, name::Symbol) = ps_m.constraints[name]
par(ps_m::CanonicalModel, param_reference::RefParam) = ps_m.parameters[param_reference]
exp(ps_m::CanonicalModel, name::Symbol) = ps_m.expressions[name]
ini_cond(ps_m::CanonicalModel, name::Symbol) = ps_m.initial_conditions[name]


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
