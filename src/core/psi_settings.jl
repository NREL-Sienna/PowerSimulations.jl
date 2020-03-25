struct PSISettings
    horizon::Base.RefValue{Int}
    use_forecast_data::Bool
    use_parameters::Bool
    use_warm_start::Base.RefValue{Bool}
    initial_time::Base.RefValue{Dates.DateTime}
    PTDF::Union{Nothing, PSY.PTDF}
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes}
    constraint_duals::Vector{Symbol}
    ext::Dict{String, Any}
end

function PSISettings(
    sys;
    initial_time::Dates.DateTime = UNSET_INI_TIME,
    use_parameters::Bool = false,
    use_forecast_data::Bool = true,
    use_warm_start::Bool = true,
    horizon::Int = UNSET_HORIZON,
    PTDF::Union{Nothing, PSY.PTDF} = nothing,
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes} = nothing,
    constraint_duals::Vector{Symbol} = Vector{Symbol}(),
    ext::Dict{String, Any} = Dict{String, Any}(),
)
    return PSISettings(
        Ref(horizon),
        use_forecast_data,
        use_parameters,
        Ref(use_warm_start),
        Ref(initial_time),
        PTDF,
        optimizer,
        constraint_duals,
        ext,
    )
end

function copy_for_serialization(settings::PSISettings)
    vals = []
    for name in fieldnames(PSISettings)
        if name == :optimizer
            # Cannot guarantee that the optimizer can be serialized.
            val = nothing
        else
            val = getfield(settings, name)
        end

        push!(vals, val)
    end

    return deepcopy(PSISettings(vals...))
end

function restore_from_copy(
    settings::PSISettings;
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes},
)
    vals = []
    for name in fieldnames(PSISettings)
        if name == :optimizer
            val = optimizer
        else
            val = getfield(settings, name)
        end

        push!(vals, val)
    end

    return PSISettings(vals...)
end

function set_horizon!(settings::PSISettings, horizon::Int)
    settings.horizon[] = horizon
    return
end
get_horizon(settings::PSISettings)::Int = settings.horizon[]
get_initial_conditions(settings::PSISettings) = settings.initial_conditions
get_use_forecast_data(settings::PSISettings) = settings.use_forecast_data
get_use_parameters(settings::PSISettings) = settings.use_parameters
function set_initial_time!(settings::PSISettings, initial_time::Dates.DateTime)
    settings.initial_time[] = initial_time
    return
end
get_initial_time(settings::PSISettings)::Dates.DateTime = settings.initial_time[]
get_PTDF(settings::PSISettings) = settings.PTDF
get_optimizer(settings::PSISettings) = settings.optimizer
get_ext(settings::PSISettings) = settings.ext
function set_use_warm_start!(settings::PSISettings, use_warm_start::Bool)
    settings.use_warm_start[] = use_warm_start
    return
end
get_use_warm_start(settings::PSISettings) = settings.use_warm_start[]
get_constraint_duals(settings::PSISettings) = settings.constraint_duals
