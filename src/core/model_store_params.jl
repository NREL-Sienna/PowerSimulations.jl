struct ModelStoreParams <: ISOPT.AbstractModelStoreParams
    num_executions::Int
    horizon_count::Int
    interval::Dates.Millisecond
    resolution::Dates.Millisecond
    base_power::Float64
    system_uuid::Base.UUID
    container_metadata::ISOPT.OptimizationContainerMetadata

    function ModelStoreParams(
        num_executions::Int,
        horizon_count::Int,
        interval::Dates.Millisecond,
        resolution::Dates.Millisecond,
        base_power::Float64,
        system_uuid::Base.UUID,
        container_metadata = ISOPT.OptimizationContainerMetadata(),
    )
        new(
            num_executions,
            horizon_count,
            Dates.Millisecond(interval),
            Dates.Millisecond(resolution),
            base_power,
            system_uuid,
            container_metadata,
        )
    end
end

function ModelStoreParams(
    num_executions::Int,
    horizon::Dates.Millisecond,
    interval::Dates.Millisecond,
    resolution::Dates.Millisecond,
    base_power::Float64,
    system_uuid::Base.UUID,
    container_metadata = ISOPT.OptimizationContainerMetadata(),
)
    return ModelStoreParams(
        num_executions,
        horizon ÷ resolution,
        Dates.Millisecond(interval),
        Dates.Millisecond(resolution),
        base_power,
        system_uuid,
        container_metadata,
    )
end

get_num_executions(params::ModelStoreParams) = params.num_executions
get_horizon_count(params::ModelStoreParams) = params.horizon_count
get_interval(params::ModelStoreParams) = params.interval
get_resolution(params::ModelStoreParams) = params.resolution
get_base_power(params::ModelStoreParams) = params.base_power
get_system_uuid(params::ModelStoreParams) = params.system_uuid
deserialize_key(params::ModelStoreParams, name) =
    deserialize_key(params.container_metadata, name)
