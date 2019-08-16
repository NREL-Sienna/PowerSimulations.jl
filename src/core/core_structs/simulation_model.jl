######## Structs for Inter-Model feedforward ########
abstract type FeedForwardSequence end

struct Synchronize <: FeedForwardSequence end
struct RecedingHorizon <: FeedForwardSequence end

######## Internal Simulation Object Structs ########
abstract type AbstractStage end

mutable struct _Stage <: AbstractStage
    key::Int64
    model::OperationModel
    execution_count::Int64
    optimizer::String
    feedforward_ref::Dict{Int64, Type{<:FeedForwardSequence}}
    update::Bool

    function _Stage(key::Int64,
                   model::OperationModel,
                   execution_count::Int64,
                   feedforward_ref::Dict{Int64, Type{<:FeedForwardSequence}},
                   update::Bool)

    new(key,
        model,
        execution_count,
        JuMP.solver_name(model.canonical.JuMPmodel),
        feedforward_ref,
        update
        )

    end

end

mutable struct SimulationRef
    raw::String
    models::String
    results::String
    run_count::Dict{Int64, Dict{Int64, Int64}}
    date_ref::Dict{Int64, Dates.DateTime}
    current_time::Dates.DateTime
    reset::Bool
end

function _initialize_sim_ref(steps::Int64, stages_keys::Base.KeySet)

    count_dict = Dict{Int64, Dict{Int64, Int64}}()

    for s in 1:steps
        count_dict[s] = Dict{Int64, Int64}()
        for st in stages_keys
            count_dict[s][st] = 0
        end
    end

    return sim_ref = SimulationRef("init",
                                   "init",
                                   "init",
                                   count_dict,
                                   Dict{Int64, Dates.DateTime}(),
                                   Dates.now(),
                                   true
                                   )

end

######## Exposed Structs to define a Simulation Object ########

mutable struct Stage <: AbstractStage
    model::ModelReference
    execution_count::Int64
    sys::PSY.System
    optimizer::JuMP.OptimizerFactory
    feedforward_ref::Dict{Int64, Type{<:FeedForwardSequence}}
end

function Stage(model::ModelReference,
            execution_count::Int64,
            sys::PSY.System,
            optimizer::JuMP.OptimizerFactory)

    return Stage(model,
                execution_count,
                sys,
                optimizer,
                Dict{Int, DataType}())

end

get_execution_count(s::S) where S <: AbstractStage = s.execution_count
get_sys(s::S) where S <: AbstractStage = s.sys
get_feedforward_ref(s::S) where S <: AbstractStage = s.feedforward_ref

get_model_ref(s::Stage) = s.model

mutable struct Simulation
    steps::Int64
    stages::Vector{_Stage}
    valid_timeseries::Bool
    daterange::NTuple{2, Dates.DateTime} #Inital Time of the first forecast and Inital Time of the last forecast
    ref::SimulationRef


    function Simulation(base_name::String,
                        steps::Int64,
                        stages::Dict{Int64, Stage},
                        simulation_folder::String;
                        verbose::Bool = false, kwargs...)


    sim_ref = _initialize_sim_ref(steps, keys(stages))

    dates, validation, stages_vector = build_simulation!(sim_ref,
                                                        base_name,
                                                        steps,
                                                        stages,
                                                        simulation_folder;
                                                        verbose = verbose, kwargs...)

    new(steps,
        stages_vector,
        validation,
        dates,
        sim_ref)

    end

end

################# accessor functions ####################

get_steps(s::Simulation) = s.steps
get_daterange(s::Simulation) = s.daterange
