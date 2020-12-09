const CONTAINER_TYPE_DUALS = :duals
const CONTAINER_TYPE_PARAMETERS = :parameters
const CONTAINER_TYPE_VARIABLES = :variables
const CONTAINER_TYPES =
    Set((CONTAINER_TYPE_DUALS, CONTAINER_TYPE_PARAMETERS, CONTAINER_TYPE_VARIABLES))

"""
Provides storage of simulation data
"""
abstract type SimulationStore end

# Required methods:
# - initialize_stage_storage!
# - read_array

struct SimulationStoreStageRequirements
    duals::Dict{Symbol, Dict{String, Any}}
    parameters::Dict{Symbol, Dict{String, Any}}
    variables::Dict{Symbol, Dict{String, Any}}
end

function SimulationStoreStageRequirements()
    return SimulationStoreStageRequirements(
        Dict{Symbol, Dict{String, Any}}(),
        Dict{Symbol, Dict{String, Any}}(),
        Dict{Symbol, Dict{String, Any}}(),
    )
end

struct SimulationStoreStageParams
    num_executions::Int
    horizon::Int
    interval::Dates.Period
    resolution::Dates.Period
    base_power::Float64
    system_uuid::Base.UUID
end

struct SimulationStoreParams
    initial_time::Dates.DateTime
    step_resolution::Dates.Period
    num_steps::Int
    # The key order is the stage execution order.
    stages::OrderedDict{Symbol, SimulationStoreStageParams}
end

function SimulationStoreParams(initial_time, step_resolution, num_steps)
    return SimulationStoreParams(
        initial_time,
        step_resolution,
        num_steps,
        OrderedDict{Symbol, SimulationStoreStageParams}(),
    )
end

function SimulationStoreParams()
    return SimulationStoreParams(
        Dates.DateTime("1970-01-01T00:00:00"),
        Dates.Millisecond(0),
        0,
        OrderedDict{Symbol, SimulationStoreStageParams}(),
    )
end

get_stages(store_params::SimulationStoreParams) = store_params.stages
