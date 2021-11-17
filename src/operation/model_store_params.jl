struct SimulationModelStoreRequirements
    duals::Dict{ConstraintKey, Dict{String, Any}}
    parameters::Dict{ParameterKey, Dict{String, Any}}
    variables::Dict{VariableKey, Dict{String, Any}}
    aux_variables::Dict{AuxVarKey, Dict{String, Any}}
    expressions::Dict{ExpressionKey, Dict{String, Any}}
end

function SimulationModelStoreRequirements()
    return SimulationModelStoreRequirements(
        Dict{ConstraintKey, Dict{String, Any}}(),
        Dict{ParameterKey, Dict{String, Any}}(),
        Dict{VariableKey, Dict{String, Any}}(),
        Dict{AuxVarKey, Dict{String, Any}}(),
        Dict{ExpressionKey, Dict{String, Any}}(),
    )
end

struct ModelStoreParams
    num_executions::Int
    horizon::Int
    interval::Dates.Period
    resolution::Dates.Period
    end_of_interval_step::Int
    base_power::Float64
    system_uuid::Base.UUID
    container_metadata::OptimizationContainerMetadata

    function ModelStoreParams(
        num_executions,
        horizon,
        interval,
        resolution,
        end_of_interval_step,
        base_power,
        system_uuid,
        container_metadata = OptimizationContainerMetadata(),
    )
        new(
            num_executions,
            horizon,
            Dates.Millisecond(interval),
            Dates.Millisecond(resolution),
            end_of_interval_step,
            base_power,
            system_uuid,
            container_metadata,
        )
    end
end

get_num_executions(params::ModelStoreParams) = params.num_executions
get_horizon(params::ModelStoreParams) = params.horizon
get_interval(params::ModelStoreParams) = params.interval
get_resolution(params::ModelStoreParams) = params.resolution
get_end_of_interval_step(params::ModelStoreParams) = params.end_of_interval_step
get_base_power(params::ModelStoreParams) = params.base_power
get_system_uuid(params::ModelStoreParams) = params.system_uuid
deserialize_key(params::ModelStoreParams, name) =
    deserialize_key(params.container_metadata, name)
