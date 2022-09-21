"""
DeviceModel
"""
mutable struct DeviceModel <: AbstractApiType
    device_type::String
    formulation::String
end

StructTypes.StructType(::Type{DeviceModel}) = StructTypes.Mutable()
DeviceModel(; device_type="unknown", formulation="unknown") = DeviceModel(device_type, formulation)

"""
Network model
"""
mutable struct NetworkModel <: AbstractApiType
    network_type::String
    use_slacks::Bool
end

StructTypes.StructType(::Type{NetworkModel}) = StructTypes.Mutable()
NetworkModel(; network_type="unknown", use_slacks=false) = NetworkModel(network_type, use_slacks)

"""
Service model
"""
mutable struct ServiceModel <: AbstractApiType
    service_type::String
    formulation::String
end

StructTypes.StructType(::Type{ServiceModel}) = StructTypes.Mutable()
ServiceModel(; service_type="unknown", formulation="unknown") = ServiceModel(service_type, formulation)

"""
Base model for all templates
"""
mutable struct ProblemTemplate <: AbstractApiType
    network::NetworkModel
    devices::Vector{DeviceModel}
    services::Vector{ServiceModel}
end

StructTypes.StructType(::Type{ProblemTemplate}) = StructTypes.Mutable()
ProblemTemplate(; network=NetworkModel(), devices=[], services=[]) = ProblemTemplate(network, devices, services)

"""
DecisionModel definition
"""
mutable struct DecisionModel <: AbstractApiType
    decision_problem_type::String
    name::String
    template::ProblemTemplate
    system_path::String
    optimizer::Union{Nothing, AbstractOptimizer}
    horizon::Int
    warm_start::Bool
    system_to_file::Bool
    initialize_model::Bool
    initialization_file::String
    deserialize_initial_conditions::Bool
    export_pwl_vars::Bool
    allow_fails::Bool
    optimizer_solve_log_print::Bool
    detailed_optimizer_stats::Bool
    calculate_conflict::Bool
    direct_mode_optimizer::Bool
    check_numerical_bounds::Bool
    initial_time::String
    time_series_cache_size::Int
end

StructTypes.StructType(::Type{DecisionModel}) = StructTypes.Mutable()
StructTypes.excludes(::Type{DecisionModel}) = (:system,)

function DecisionModel(;
    decision_problem_type="unknown",
    name="unknown",
    template=ProblemTemplate(),
    system_path="unknown",
    optimizer=nothing,
    horizon=PSI.UNSET_HORIZON,
    warm_start=true,
    system_to_file=true,
    initialize_model=true,
    initialization_file="",
    deserialize_initial_conditions=false,
    export_pwl_vars=false,
    allow_fails=false,
    optimizer_solve_log_print=false,
    detailed_optimizer_stats=false,
    calculate_conflict=false,
    direct_mode_optimizer=false,
    check_numerical_bounds=true,
    initial_time=string(PSI.UNSET_INI_TIME),
    time_series_cache_size::Int=IS.TIME_SERIES_CACHE_SIZE_BYTES,
)
    return DecisionModel(
        decision_problem_type,
        name,
        template,
        system_path,
        optimizer,
        horizon,
        warm_start,
        system_to_file,
        initialize_model,
        initialization_file,
        deserialize_initial_conditions,
        export_pwl_vars,
        allow_fails,
        optimizer_solve_log_print,
        detailed_optimizer_stats,
        calculate_conflict,
        direct_mode_optimizer,
        check_numerical_bounds,
        initial_time,
        time_series_cache_size,
    )
end

mutable struct EmulationModel <: AbstractApiType end  # TODO: fields

StructTypes.StructType(::Type{EmulationModel}) = StructTypes.Mutable()

mutable struct SimulationModels <: AbstractApiType
    decision_models::Vector{DecisionModel}
    emulation_model::Union{Nothing, EmulationModel}
end

StructTypes.StructType(::Type{SimulationModels}) = StructTypes.Mutable()

SimulationModels(; decision_models=[], emulation_model=nothing) =
    SimulationModels(decision_models, emulation_model)

"""
Base model for all feedforwards
"""
abstract type AbstractFeedforward <: AbstractApiType end

mutable struct EnergyLimitFeedforward <: AbstractFeedforward
    component_type::String
    source::String
    affected_values::Vector{String}
    number_of_periods::Int
    type::String
end

StructTypes.StructType(::Type{EnergyLimitFeedforward}) = StructTypes.Mutable()

function EnergyLimitFeedforward(;
    component_type="unknown",
    source="unknown",
    affected_values=[],
    number_of_periods=0,
    type="EnergyLimitFeedforward",
)
    EnergyLimitFeedforward(component_type, source, affected_values, number_of_periods, type)
end

mutable struct SemiContinuousFeedforward <: AbstractFeedforward
    component_type::String
    source::String
    affected_values::Vector{String}
    type::String
end

StructTypes.StructType(::Type{SemiContinuousFeedforward}) = StructTypes.Mutable()

function SemiContinuousFeedforward(;
    component_type="unknown",
    source="unknown",
    affected_values=[],
    type="SemiContinuousFeedforward",
)
    SemiContinuousFeedforward(component_type, source, affected_values, type)
end

mutable struct Feedforwards <: AbstractApiType
    model_name::String
    feedforwards::Vector{AbstractFeedforward}
end

StructTypes.StructType(::Type{Feedforwards}) = StructTypes.Mutable()
Feedforwards(; model_name="unknown", feedforwards=[]) = Feedforwards(model_name, feedforwards)

"""
Controls the sequence of problems in a simulation.
"""
mutable struct SimulationSequence <: AbstractApiType
    initial_condition_chronology_type::String
    feedforwards_by_model::Vector{Feedforwards}
end

StructTypes.StructType(::Type{SimulationSequence}) = StructTypes.Mutable()

function SimulationSequence(;
    initial_condition_chronology_type="IntraProblemChronology",
    feedforwards_by_model=[],
)
    SimulationSequence(initial_condition_chronology_type, feedforwards_by_model)
end

"""
Simulation definition
"""
mutable struct Simulation <: AbstractApiType
    name::String
    models::SimulationModels
    sequence::SimulationSequence
    num_steps::Int

    function Simulation(; name="unknown", models=SimulationModels(), sequence=SimulationSequence(), num_steps=0)
        model_names = Set((x.name for x in models.decision_models))
        for ff in sequence.feedforwards_by_model
            if !in(ff.model_name, model_names)
                error(
                    "feedforward model_name=$(ff.model_name) is not stored in decision_models",
                )
            end
        end

        new(name, models, sequence, num_steps)
    end
end

StructTypes.StructType(::Type{Simulation}) = StructTypes.Mutable()

# function Simulation(;
#     name="unknown",
#     models=SimulationModels(),
#     sequence=SimulationSequence(),
#     num_steps=1,
# )
#     Simulation(name, models, sequence, num_steps)
# end
