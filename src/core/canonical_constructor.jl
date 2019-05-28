
function _make_container_array(V::DataType, ax...; kwargs...)

    parameters = get(kwargs, :parameters, true)

    # While JuMP fixes the isassigned problems
     # While JuMP fixes the isassigned problems
    #=
    if parameters
            cont = JuMP.Containers.DenseAxisArray{PGAE{V}}(undef, ax...)
            _remove_undef!(cont.data)
        return cont
    else
            cont = JuMP.Containers.DenseAxisArray{GAE{V}}(undef, ax...)
            _remove_undef!(cont.data)
        return cont
    end
    =#

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

    return Dict{Symbol, JuMP.Containers.DenseAxisArray}(:nodal_balance_active =>  _make_container_array(V, bus_numbers, time_steps; kwargs...),
                                                        :nodal_balance_reactive => _make_container_array(V, bus_numbers, time_steps; kwargs...))
end

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractActivePowerFormulation}

    return Dict{Symbol, JuMP.Containers.DenseAxisArray}(:nodal_balance_active => _make_container_array(V, bus_numbers, time_steps; kwargs...))
end

"""
This function performs the same actions as the call to PowerModels.GenericPowerModel{T} but performs extra actions
    to instantiate partially the power model object
"""
function _powermodels_object_init(transmission::Type{S},
                                 buses::PSY.FlattenedVectorsIterator{PSY.Bus},
                                 base_power::Float64,
                                 time_steps::UnitRange{Int64},
                                 jump_model::JuMP.Model,
                                 V::DataType) where {S <: PM.AbstractPowerFormulation}

    is_activepower_only = (S <: PM.AbstractActivePowerFormulation)

    PM_data_dict = Dict{String,Any}(
        "bus"            => get_buses_to_pm(buses),
        "branch"         => Dict{String,Any}(),
        "baseMVA"        => base_power,
        "per_unit"       => true,
        "storage"        => Dict{String,Any}(),
        "dcline"         => Dict{String,Any}(),
        "gen"            => Dict{String,Any}(),
        "shunt"          => Dict{String,Any}(),
        "load"           => Dict{String,Any}(),
        )

    PM_data_dict = PM.replicate(PM_data_dict,time_steps[end]);

    ext = Dict{Symbol,Any}()
    setting = Dict{String,Any}()
    ref = PM.build_generic_ref(PM_data_dict)

    var = Dict{Symbol,Any}(:nw => Dict{Int,Any}())
    con = Dict{Symbol,Any}(:nw => Dict{Int,Any}())

    for (nw_id, nw) in ref[:nw]
        nw_var = var[:nw][nw_id] = Dict{Symbol,Any}()
        nw_con = con[:nw][nw_id] = Dict{Symbol,Any}()
        ref[:nw][nw_id][:arcs_from] = Vector{Tuple{Int64,Int64,Int64}}()
        ref[:nw][nw_id][:arcs_to] = Vector{Tuple{Int64,Int64,Int64}}()
        ref[:nw][nw_id][:arcs_from_dc] = Vector{Tuple{Int64,Int64,Int64}}()
        ref[:nw][nw_id][:arcs_to_dc] = Vector{Tuple{Int64,Int64,Int64}}()
        ref[:nw][nw_id][:arcs] = Vector{Tuple{Int64,Int64,Int64}}()
        ref[:nw][nw_id][:arcs_dc] = Vector{Tuple{Int64,Int64,Int64}}()

        nw_var[:cnd] = Dict{Int,Any}()
        nw_con[:cnd] = Dict{Int,Any}()

        for cnd_id in nw[:conductor_ids]
            nw_var[:cnd][cnd_id] = Dict{Symbol,Any}()
            nw_var[:cnd][cnd_id][:p] = Vector{V}()
            nw_var[:cnd][cnd_id][:p_dc] = Vector{V}()
            is_activepower_only ? nw_var[:cnd][cnd_id][:q] = Vector{V}() : true
            is_activepower_only ? nw_var[:cnd][cnd_id][:q_dc] = Vector{V}() : true
            nw_con[:cnd][cnd_id] = Dict{Symbol,Any}()
        end
    end

    cnw = minimum([k for k in keys(var[:nw])])
    ccnd = minimum([k for k in keys(var[:nw][cnw][:cnd])])

    pm_object = PM.GenericPowerModel{transmission}(
                                        jump_model,
                                        PM_data_dict,
                                        setting,
                                        Dict{String,Any}(), # solution
                                        ref,
                                        var,
                                        con,
                                        cnw,
                                        ccnd,
                                        ext
                                    )

    return pm_object

end


function _canonical_model_init(buses::PSY.FlattenedVectorsIterator{PSY.Bus},
                              base_power::Float64,
                              optimizer::Union{Nothing,JuMP.OptimizerFactory},
                              transmission::Type{S},
                              time_steps::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractPowerFormulation}


    bus_numbers = [b.number for b in buses]
    parameters = get(kwargs, :parameters, true)
    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)
    pm_object = _powermodels_object_init(transmission,
                                                buses,
                                            base_power,
                                            time_steps,
                                            jump_model,
                                            V; kwargs ...)

    ps_model = CanonicalModel(jump_model,
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                            zero(JuMP.GenericAffExpr{Float64, V}),
                            _make_expressions_dict(transmission, V, bus_numbers, time_steps; kwargs...),
                            parameters ? Dict{Symbol,JuMP.Containers.DenseAxisArray}() : nothing,
                            Dict{Symbol,Array{InitialCondition}}(),
                            pm_object);

    return ps_model

end

function _canonical_model_init(buses::PSY.FlattenedVectorsIterator{PSY.Bus},
                               base_power::Float64,
                               optimizer::Union{Nothing,JuMP.OptimizerFactory},
                               transmission::Type{S},
                               time_steps::UnitRange{Int64}; kwargs...) where {S <: Union{StandardPTDFForm, CopperPlatePowerModel}}

    bus_numbers = [b.number for b in buses]
    parameters = get(kwargs, :parameters, true)
    jump_model = _pass_abstract_jump(optimizer; kwargs...)
    V = JuMP.variable_type(jump_model)

    ps_model = CanonicalModel(jump_model,
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              Dict{Symbol, JuMP.Containers.DenseAxisArray}(),
                              zero(JuMP.GenericAffExpr{Float64, V}),
                              _make_expressions_dict(transmission, V, bus_numbers, time_steps; kwargs...),
                              parameters ? Dict{Symbol,JuMP.Containers.DenseAxisArray}() : nothing,
                              Dict{Symbol,Array{InitialCondition}}(),
                              nothing);

    return ps_model

end

function  build_canonical_model(transmission::Type{T},
                                devices::Dict{Symbol, DeviceModel},
                                branches::Dict{Symbol, DeviceModel},
                                services::Dict{Symbol, ServiceModel},
                                sys::PSY.System,
                                resolution::Dates.Period,
                                optimizer::Union{Nothing,JuMP.OptimizerFactory}=nothing;
                                kwargs...) where {T <: PM.AbstractPowerFormulation}


    forecast = get(kwargs, :forecast, true)

    if forecast
        first_key = PSY.get_forecasts_initial_time(sys)
        horizon = PSY.get_forecasts_horizon(sys)
        time_steps = 1:horizon
    else
        time_steps = 1:1
    end

    buses = PSY.get_components(PSY.Bus, sys)

    ps_model = _canonical_model_init(buses, sys.basepower, optimizer, transmission, time_steps; kwargs...)

    # Build Injection devices
    for mod in devices
        construct_device!(ps_model, mod[2], transmission, sys, time_steps, resolution; kwargs...)
    end

    # Build Branches
    for mod in branches
        construct_device!(ps_model, mod[2], transmission, sys, time_steps, resolution; kwargs...)
    end

    # Build Network
    construct_network!(ps_model, transmission, sys, time_steps; kwargs...)

    #Build Service
    for mod in services
        #construct_service!(ps_model, mod[2], transmission, sys, time_steps, resolution; kwargs...)
    end

    # Objective Function
    JuMP.@objective(ps_model.JuMPmodel, Min, ps_model.cost_function)

    return ps_model

end