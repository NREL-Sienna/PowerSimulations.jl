struct StoreModelRequirements
    duals::Dict{ConstraintKey, Dict{String, Any}}
    parameters::Dict{ParameterKey, Dict{String, Any}}
    variables::Dict{VariableKey, Dict{String, Any}}
end

function StoreModelRequirements()
    return StoreModelRequirements(
        Dict{ConstraintKey, Dict{String, Any}}(),
        Dict{ParameterKey, Dict{String, Any}}(),
        Dict{VariableKey, Dict{String, Any}}(),
    )
end

struct StoreModelParams
    num_executions::Int
    horizon::Int
    interval::Dates.Period
    resolution::Dates.Period
    end_of_interval_step::Int
    base_power::Float64
    system_uuid::Base.UUID
    container_metadata::OptimizationContainerMetadata

    function StoreModelParams(
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

get_num_executions(params::StoreModelParams) = params.num_executions
get_horizon(params::StoreModelParams) = params.horizon
get_interval(params::StoreModelParams) = params.interval
get_resolution(params::StoreModelParams) = params.resolution
get_end_of_interval_step(params::StoreModelParams) = params.end_of_interval_step
get_base_power(params::StoreModelParams) = params.base_power
get_system_uuid(params::StoreModelParams) = params.system_uuid
deserialize_key(params::StoreModelParams, name) =
    deserialize_key(params.container_metadata, name)
