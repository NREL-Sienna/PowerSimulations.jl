######## Internal Simulation Object Structs ########
abstract type AbstractStage end

mutable struct _Stage <: AbstractStage
    key::Int64
    model::OperationModel
    executions::Int64
    execution_count::Int64
    optimizer::String
    chronology_ref::Dict{Int64, Type{<:Chronology}}
    ini_cond_chron::Union{Type{<:Chronology}, Nothing}
    cache::Dict{Type{<:AbstractCache}, AbstractCache}

    function _Stage(key::Int64,
                   model::OperationModel,
                   executions::Int64,
                   chronology_ref::Dict{Int64, Type{<:Chronology}},
                   cache::Vector{<:AbstractCache})

    ini_cond_chron = get(chronology_ref, 0, nothing)
    if !isempty(get_initial_conditions(model))
        if isnothing(ini_cond_chron)
            @warn("Initial Conditions chronology set for Stage $(key) which contains Initial conditions")
        end
    end

    pop!(chronology_ref, 0, nothing)

    cache_dict = Dict{Type{<:AbstractCache}, AbstractCache}()
    for c in cache
        cache_dict[typeof(c)] = c
    end


    new(key,
        model,
        executions,
        0,
        JuMP.solver_name(model.canonical.JuMPmodel),
        chronology_ref,
        ini_cond_chron,
        cache_dict
        )

    end

end

######## Exposed Structs to define a Simulation Object ########

mutable struct Stage <: AbstractStage
    model::ModelReference
    execution_count::Int64
    sys::PSY.System
    optimizer::JuMP.OptimizerFactory
    chronology_ref::Dict{Int64, Type{<:Chronology}}
    cache::Vector{<:AbstractCache}

    function Stage(model::ModelReference,
                execution_count::Int64,
                sys::PSY.System,
                optimizer::JuMP.OptimizerFactory,
                chronology_ref=Dict{Int, Type{<:Chronology}}(),
                cache::Vector{<:AbstractCache}=Vector{AbstractCache}())

        new(model,
            execution_count,
            sys,
            optimizer,
            chronology_ref,
            cache)
    end

end

function Stage(model::ModelReference,
                execution_count::Int64,
                sys::PSY.System,
                optimizer::JuMP.OptimizerFactory,
                chronology_ref::Dict{Int64, DataType},
                cache::AbstractCache)

    return Stage(model, execution_count, sys, optimizer, chronology_ref, [cache])

end

function Stage(;model::ModelReference,
                execution_count::Int64,
                sys::PSY.System,
                optimizer::JuMP.OptimizerFactory,
                chronology_ref::Dict{Int64, Type{<:Chronology}},
                cache::Vector{<:AbstractCache})

    return Stage(model, execution_count, sys, optimizer, chronology_ref, cache)

end

get_execution_count(s::S) where S <: AbstractStage = s.execution_count
get_sys(s::S) where S <: AbstractStage = s.sys
get_chronology_ref(s::S) where S <: AbstractStage = s.chronology_ref

get_model_ref(s::Stage) = s.model
