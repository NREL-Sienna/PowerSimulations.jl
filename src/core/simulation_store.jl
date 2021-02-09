const STORE_CONTAINER_DUALS = :duals
const STORE_CONTAINER_PARAMETERS = :parameters
const STORE_CONTAINER_VARIABLES = :variables
const STORE_CONTAINERS =
    Set((STORE_CONTAINER_DUALS, STORE_CONTAINER_PARAMETERS, STORE_CONTAINER_VARIABLES))

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

    function SimulationStoreStageParams(
        num_executions,
        horizon,
        interval,
        resolution,
        base_power,
        system_uuid,
    )
        new(
            num_executions,
            horizon,
            Dates.Millisecond(interval),
            Dates.Millisecond(resolution),
            base_power,
            system_uuid,
        )
    end
end

get_num_executions(params::SimulationStoreStageParams) = params.num_executions
get_horizon(params::SimulationStoreStageParams) = params.horizon
get_interval(params::SimulationStoreStageParams) = params.interval
get_resolution(params::SimulationStoreStageParams) = params.resolution
get_base_power(params::SimulationStoreStageParams) = params.base_power
get_system_uuid(params::SimulationStoreStageParams) = params.system_uuid

struct SimulationStoreParams
    initial_time::Dates.DateTime
    step_resolution::Dates.Period
    num_steps::Int
    # The key order is the stage execution order.
    stages::OrderedDict{Symbol, SimulationStoreStageParams}

    function SimulationStoreParams(initial_time, step_resolution, num_steps, stages)
        new(initial_time, Dates.Millisecond(step_resolution), num_steps, stages)
    end
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

get_initial_time(store_params::SimulationStoreParams) = store_params.initial_time
get_stages(store_params::SimulationStoreParams) = store_params.stages
