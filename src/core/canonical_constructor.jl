const DSDA = Dict{Symbol, JuMP.Containers.DenseAxisArray}

function _make_container_array(V::DataType, ax...; kwargs...)

    parameters = get(kwargs, :parameters, true)

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
                                time_steps::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractPowerFormulation}

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
                                time_steps::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractActivePowerFormulation}

    return DSDA(:nodal_balance_active =>  _make_container_array(V,
                                                                bus_numbers,
                                                                time_steps; kwargs...))
end


function _canonical_model_init(bus_numbers::Vector{Int64},
                              optimizer::Union{Nothing,JuMP.OptimizerFactory},
                              transmission::Type{S},
                              time_steps::UnitRange{Int64},
                              resolution::Dates.Period; kwargs...) where
                                    {S <: PM.AbstractPowerFormulation}

    parameters = get(kwargs, :parameters, true)
    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)

    # TODO: Instantiate the PM Object here

    ps_model = CanonicalModel(jump_model,
                              parameters,
                              false,
                              time_steps,
                              resolution,
                              DSDA(),
                              DSDA(),
                              zero(JuMP.GenericAffExpr{Float64, V}),
                              _make_expressions_dict(transmission,
                                                     V,
                                                     bus_numbers,
                                                     time_steps; kwargs...),
                              parameters ? DSDA() : nothing,
                              Dict{Symbol,Array{InitialCondition}}(),
                              nothing);

    return ps_model

end

function _canonical_model_init(bus_numbers::Vector{Int64},
                               optimizer::Union{Nothing,JuMP.OptimizerFactory},
                               transmission::Type{S},
                               time_steps::UnitRange{Int64},
                               resolution::Dates.Period; kwargs...) where
                                       {S <: Union{StandardPTDFForm, CopperPlatePowerModel}}

    parameters = get(kwargs, :parameters, true)
    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)

    ps_model = CanonicalModel(jump_model,
                              parameters,
                              false,
                              time_steps,
                              resolution,
                              DSDA(),
                              DSDA(),
                              zero(JuMP.GenericAffExpr{Float64, V}),
                              _make_expressions_dict(transmission,
                                                     V,
                                                     bus_numbers,
                                                     time_steps; kwargs...),
                              parameters ? DSDA() : nothing,
                              Dict{Symbol,Array{InitialCondition}}(),
                              nothing);

    return ps_model

end

function  build_canonical_model(transmission::Type{T},
                                devices::Dict{Symbol, DeviceModel},
                                branches::Dict{Symbol, DeviceModel},
                                services::Dict{Symbol, ServiceModel},
                                sys::PSY.System,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {T <: PM.AbstractPowerFormulation}


    forecast = get(kwargs, :forecast, true)

    if forecast
        horizon = PSY.get_forecasts_horizon(sys)
        time_steps = 1:horizon
        resolution = PSY.get_forecasts_resolution(sys)
    else
        resolution = Dates.Hour(1)
        time_steps = 1:1
    end

    bus_numbers = sort([b.number for b in PSY.get_components(PSY.Bus, sys)])

    ps_model = _canonical_model_init(bus_numbers,
                                     optimizer,
                                     transmission,
                                     time_steps,
                                     resolution; kwargs...)

    # Build Injection devices
    for mod in devices
        @info "Building $(mod[2].device) with $(mod[2].formulation) formulation"
        construct_device!(ps_model, mod[2], transmission, sys; kwargs...)
    end

    # Build Network
    @info "Building $(transmission) network formulation"
    construct_network!(ps_model, transmission, sys; kwargs...)

    # Build Branches
    for mod in branches
        @info "Building $(mod[2].device) with $(mod[2].formulation) formulation"
        construct_device!(ps_model, mod[2], transmission, sys; kwargs...)
    end

    #Build Service
    for mod in services
        #construct_service!(ps_model, mod[2], transmission, sys, time_steps, resolution; kwargs...)
    end

    # Objective Function
    @info "Building Objective"
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)

    return ps_model

end