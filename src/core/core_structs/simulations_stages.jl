######## Internal Simulation Object Structs ########
abstract type AbstractStage end

mutable struct _Stage{M<:AbstractOperationModel} <: AbstractStage
    key::Int64
    op_model::Type{M}
    sys::PSY.System
    canonical::CanonicalModel
    executions::Int64
    execution_count::Int64
    optimizer::String
    chronology_ref::Dict{Int64, Type{<:Chronology}}
    ini_cond_chron::Union{Type{<:Chronology}, Nothing}
    cache::Dict{Type{<:AbstractCache}, AbstractCache}

    function _Stage(key::Int64,
                    op_model::Type{M},
                    sys::PSY.System,
                    canonical::CanonicalModel,
                    executions::Int64,
                    chronology_ref::Dict{Int64, Type{<:Chronology}},
                    cache::Vector{<:AbstractCache}) where M <: AbstractOperationModel

    ini_cond_chron = get(chronology_ref, 0, nothing)
    if !isempty(get_initial_conditions(canonical))
        if isnothing(ini_cond_chron)
            @warn("Initial Conditions chronology set for Stage $(key) which contains Initial conditions")
        end
    end

    pop!(chronology_ref, 0, nothing)

    cache_dict = Dict{Type{<:AbstractCache}, AbstractCache}()
    for c in cache
        cache_dict[typeof(c)] = c
    end


    new{M}(key,
           op_model,
           sys,
           canonical,
           executions,
           0,
           JuMP.solver_name(canonical.JuMPmodel),
           chronology_ref,
           ini_cond_chron,
           cache_dict)

    end

end

######## Exposed Structs to define a Simulation Object ########

mutable struct Stage <: AbstractStage
    op_model::Type{<:AbstractOperationModel}
    model::ModelReference
    execution_count::Int64
    sys::PSY.System
    optimizer::JuMP.OptimizerFactory
    chronology_ref::Dict{Int64, Type{<:Chronology}}
    cache::Vector{<:AbstractCache}

    function Stage(::Type{M},
                   model::ModelReference,
                   execution_count::Int64,
                   sys::PSY.System,
                   optimizer::JuMP.OptimizerFactory,
                   chronology_ref=Dict{Int, Type{<:Chronology}}(),
                   cache::Vector{<:AbstractCache}=Vector{AbstractCache}()) where M<:AbstractOperationModel

        new(M,
            model,
            execution_count,
            sys,
            optimizer,
            chronology_ref,
            cache)
    end

end

function Stage(::Type{M},
                model::ModelReference,
                execution_count::Int64,
                sys::PSY.System,
                optimizer::JuMP.OptimizerFactory,
                chronology_ref::Dict{Int64, DataType},
                cache::Union{Nothing, AbstractCache}=nothing) where M<:AbstractOperationModel

    cacheinput = isnothing(cache) ? Vector{AbstractCache}() : [cache]
    return Stage(M, model, execution_count, sys, optimizer, chronology_ref, cacheinput)

end

function Stage(model::ModelReference,
               execution_count::Int64,
               sys::PSY.System,
               optimizer::JuMP.OptimizerFactory,
               chronology_ref::Dict{Int64, DataType},
               cache::Union{Nothing, AbstractCache}=nothing)

    return Stage(DefaultOpModel, model, execution_count, sys, optimizer, chronology_ref, cache)

end

get_execution_count(s::S) where S <: AbstractStage = s.execution_count
get_sys(s::S) where S <: AbstractStage = s.sys
get_chronology_ref(s::S) where S <: AbstractStage = s.chronology_ref

get_model_ref(s::Stage) = s.model
