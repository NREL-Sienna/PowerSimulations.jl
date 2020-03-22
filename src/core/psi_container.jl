mutable struct InitialCondition{T <: Union{PJ.ParameterRef, Float64}}
    device::PSY.Device
    update_ref::UpdateRef
    value::T
    cache_type::Union{Nothing, Type{<:AbstractCache}}
end

function InitialCondition(
    device::PSY.Device,
    update_ref::UpdateRef,
    value::T,
) where {T <: Union{PJ.ParameterRef, Float64}}
    return InitialCondition(device, update_ref, value, nothing)
end

struct ICKey{IC <: InitialConditionType, D <: PSY.Device}
    ic_type::Type{IC}
    device_type::Type{D}
end

const InitialConditionsContainer = Dict{ICKey, Array{InitialCondition}}
#Defined here because of dependencies in psi_container

struct PSISettings
    horizon::Base.RefValue{Int}
    initial_conditions::Union{Nothing, InitialConditionsContainer}
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
    initial_time::Union{Nothing, Dates.DateTime} = nothing,
    use_parameters::Bool = false,
    use_forecast_data::Bool = true,
    initial_conditions = InitialConditionsContainer(),
    use_warm_start::Bool = true,
    horizon::Int = 0,
    PTDF::Union{Nothing, PSY.PTDF} = nothing,
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes} = nothing,
    constraint_duals::Vector{Symbol} = Vector{Symbol}(),
    ext::Dict{String, Any} = Dict{String, Any}(),
)

    if isnothing(initial_time)
        initial_time = PSY.get_forecasts_initial_time(sys)
    end

    if horizon == 0
        horizon = PSY.get_forecasts_horizon(sys)
    end

    return PSISettings(
        Ref(horizon),
        initial_conditions,
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

function check_warm_start_support(JuMPmodel::JuMP.AbstractModel, warm_start_enabled::Bool)
    !warm_start_enabled && return warm_start_enabled
    solver_supports_warm_start =
        MOI.supports(JuMP.backend(JuMPmodel), MOI.VariablePrimalStart(), MOI.VariableIndex)
    if !solver_supports_warm_start
        solver_name = JuMP.solver_name(JuMPmodel)
        @warn("$(solver_name) does not support warm start")
    end
    return solver_supports_warm_start
end

function _make_jump_model!(
    settings::PSISettings,
    JuMPmodel::Union{Nothing, JuMP.AbstractModel},
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes},
)
    parameters = get_use_parameters(settings)
    if !isnothing(JuMPmodel)
        if parameters
            if !haskey(JuMPmodel.ext, :params)
                @info("Model doesn't have Parameters enabled. Parameters will be enabled")
                PJ.enable_parameters(JuMPmodel)
                warm_start_enabled = get_use_warm_start(settings)
                solver_supports_warm_start =
                    check_warm_start_support(JuMPmodel, warm_start_enabled)
                set_use_warm_start!(settings, solver_supports_warm_start)
            end
        end
        return JuMPmodel
    end
    if isa(optimizer, Nothing)
        @debug "The optimization model has no optimizer attached"
    end
    @debug "Instantiating the JuMP model"
    if !isnothing(optimizer)
        JuMPmodel = JuMP.Model(optimizer)
        warm_start_enabled = get_use_warm_start(settings)
        solver_supports_warm_start = check_warm_start_support(JuMPmodel, warm_start_enabled)
        set_use_warm_start!(settings, solver_supports_warm_start)
    else
        JuMPmodel = JuMP.Model()
    end
    if parameters
        PJ.enable_parameters(JuMPmodel)
    end
    return JuMPmodel
end

function _make_container_array(V::DataType, parameters::Bool, ax...)
    if parameters
        return JuMP.Containers.DenseAxisArray{PGAE{V}}(undef, ax...)
    else
        return JuMP.Containers.DenseAxisArray{GAE{V}}(undef, ax...)
    end
    return
end

function _make_expressions_dict(
    transmission::Type{S},
    V::DataType,
    bus_numbers::Vector{Int},
    time_steps::UnitRange{Int},
    parameters::Bool,
) where {S <: PM.AbstractPowerModel}
    return DenseAxisArrayContainer(
        :nodal_balance_active =>
            _make_container_array(V, parameters, bus_numbers, time_steps),
        :nodal_balance_reactive =>
            _make_container_array(V, parameters, bus_numbers, time_steps),
    )
end

function _make_expressions_dict(
    transmission::Type{S},
    V::DataType,
    bus_numbers::Vector{Int},
    time_steps::UnitRange{Int},
    parameters::Bool,
) where {S <: PM.AbstractActivePowerModel}
    return DenseAxisArrayContainer(
        :nodal_balance_active =>
            _make_container_array(V, parameters, bus_numbers, time_steps),
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

function _psi_container_init(
    bus_numbers::Vector{Int},
    jump_model::JuMP.AbstractModel,
    transmission::Type{S},
    time_steps::UnitRange{Int},
    resolution::Dates.TimePeriod,
    settings::PSISettings,
) where {S <: PM.AbstractPowerModel}
    V = JuMP.variable_type(jump_model)
    make_parameters_container = get_use_parameters(settings)
    psi_container = PSIContainer(
        jump_model,
        time_steps,
        resolution,
        settings,
        DenseAxisArrayContainer(),
        DenseAxisArrayContainer(),
        zero(JuMP.GenericAffExpr{Float64, V}),
        _make_expressions_dict(
            transmission,
            V,
            bus_numbers,
            time_steps,
            make_parameters_container,
        ),
        make_parameters_container ? ParametersContainer() : nothing,
        #This will be improved with the implementation of inicond passing
        get_initial_conditions(settings),
        nothing,
    )
    return psi_container
end

mutable struct PSIContainer
    JuMPmodel::JuMP.AbstractModel
    time_steps::UnitRange{Int}
    resolution::Dates.TimePeriod
    settings::PSISettings
    settings_copy::PSISettings
    variables::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    parameters::Union{Nothing, ParametersContainer}
    initial_conditions::InitialConditionsContainer
    pm::Union{Nothing, PM.AbstractPowerModel}

    function PSIContainer(
        JuMPmodel::JuMP.AbstractModel,
        time_steps::UnitRange{Int},
        resolution::Dates.TimePeriod,
        settings::PSISettings,
        variables::Dict{Symbol, JuMP.Containers.DenseAxisArray},
        constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray},
        cost_function::JuMP.AbstractJuMPScalar,
        expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray},
        parameters::Union{Nothing, ParametersContainer},
        initial_conditions::InitialConditionsContainer,
        pm::Union{Nothing, PM.AbstractPowerModel},
    )
        resolution = IS.time_period_conversion(resolution)
        new(
            JuMPmodel,
            time_steps,
            resolution,
            settings,
            copy_for_serialization(settings),
            variables,
            constraints,
            cost_function,
            expressions,
            parameters,
            initial_conditions,
            pm,
        )
    end
end

function PSIContainer(
    ::Type{T},
    sys::PSY.System,
    settings::PSISettings,
    jump_model::Union{Nothing, JuMP.AbstractModel},
) where {T <: PM.AbstractPowerModel}
    PSY.check_forecast_consistency(sys)
    #This will be improved with the implementation of inicond passing
    ini_con = get_initial_conditions(settings)
    optimizer = get_optimizer(settings)
    use_parameters = get_use_parameters(settings)
    jump_model = _make_jump_model!(settings, jump_model, optimizer)
    if get_use_forecast_data(settings)
        time_steps = 1:get_horizon(settings)
        if length(time_steps) > 100
            @warn("The number of time steps in the model specification is over 100. This will result in
                  large multiperiod optimization problem")
        end
        resolution = PSY.get_forecasts_resolution(sys)
    else
        resolution = PSY.get_forecasts_resolution(sys)
        time_steps = 1:1
    end

    bus_numbers = sort([PSY.get_number(b) for b in PSY.get_components(PSY.Bus, sys)])

    return _psi_container_init(bus_numbers, jump_model, T, time_steps, resolution, settings)

end

function InitialCondition(
    psi_container::PSIContainer,
    device::T,
    update_ref::UpdateRef,
    value::Float64,
    cache_type::Union{Nothing, Type{<:AbstractCache}} = nothing,
) where {T <: PSY.Component}
    if model_has_parameters(psi_container)
        return InitialCondition(
            device,
            update_ref,
            PJ.add_parameter(psi_container.JuMPmodel, value),
            cache_type,
        )
    end

    return InitialCondition(device, update_ref, value, cache_type)
end

function has_initial_conditions(psi_container::PSIContainer, key::ICKey)
    return key in keys(psi_container.initial_conditions)
end

function get_initial_conditions(
    psi_container::PSIContainer,
    ::Type{T},
    ::Type{D},
) where {T <: InitialConditionType, D <: PSY.Device}
    return get_initial_conditions(psi_container, ICKey(T, D))
end

function get_initial_conditions(psi_container::PSIContainer, key::ICKey)
    initial_conditions = get(psi_container.initial_conditions, key, nothing)
    if isnothing(initial_conditions)
        throw(IS.InvalidValue("initial conditions are not stored for $(key)"))
    end

    return initial_conditions
end

function set_initial_conditions!(psi_container::PSIContainer, key::ICKey, value)
    @debug "set_initial_condition" key
    psi_container.initial_conditions[key] = value
end

function encode_symbol(::Type{T}, name1::AbstractString, name2::AbstractString) where {T}
    return Symbol(join((name1, name2, T), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name1::Symbol, name2::Symbol) where {T}
    return encode_symbol(T, string(name1), string(name2))
end

function encode_symbol(::Type{T}, name::AbstractString) where {T}
    return Symbol(join((name, T), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name::Symbol) where {T}
    return Symbol(join((string(name), T), PSI_NAME_DELIMITER))
end

function encode_symbol(name::AbstractString)
    return Symbol(name)
end

function encode_symbol(name::Symbol)
    return name
end

function decode_symbol(name::Symbol)
    return split(String(name), PSI_NAME_DELIMITER)
end

constraint_name(cons_type, device_type) = encode_symbol(device_type, cons_type)
constraint_name(cons_type) = encode_symbol(cons_type)
variable_name(var_type, device_type) = encode_symbol(device_type, var_type)
variable_name(var_type) = encode_symbol(var_type)

_variable_type(cm::PSIContainer) = JuMP.variable_type(cm.JuMPmodel)
model_time_steps(psi_container::PSIContainer) = psi_container.time_steps
model_resolution(psi_container::PSIContainer) = psi_container.resolution
model_has_parameters(psi_container::PSIContainer) =
    get_use_parameters(psi_container.settings)
model_uses_forecasts(psi_container::PSIContainer) =
    get_use_forecast_data(psi_container.settings)
model_initial_time(psi_container::PSIContainer) = get_initial_time(psi_container.settings)
#Internal Variables, Constraints and Parameters accessors
get_variables(psi_container::PSIContainer) = psi_container.variables
get_constraints(psi_container::PSIContainer) = psi_container.constraints
get_parameters(psi_container::PSIContainer) = psi_container.parameters
get_expression(psi_container::PSIContainer, name::Symbol) = psi_container.expressions[name]
get_initial_conditions(psi_container::PSIContainer) = psi_container.initial_conditions
get_PTDF(psi_container::PSIContainer) = get_PTDF(psi_container.settings)
get_settings(psi_container::PSIContainer) = psi_container.settings

function get_variable(
    psi_container::PSIContainer,
    var_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    return get_variable(psi_container, variable_name(var_type, T))
end

function get_variable(psi_container::PSIContainer, var_type::AbstractString)
    return get_variable(psi_container, variable_name(var_type))
end

function get_variable(psi_container::PSIContainer, update_ref::UpdateRef)
    return get_variable(psi_container, update_ref.access_ref)
end

function get_variable(psi_container::PSIContainer, name::Symbol)
    var = get(psi_container.variables, name, nothing)
    if isnothing(var)
        @error "$name is not stored" sort!(get_variable_names(psi_container))
        throw(IS.InvalidValue("variable $name is not stored"))
    end

    return var
end

function get_variable_names(psi_container::PSIContainer)
    return collect(keys(psi_container.variables))
end

function assign_variable!(
    psi_container::PSIContainer,
    variable_type::AbstractString,
    ::Type{T},
    value,
) where {T <: PSY.Component}
    assign_variable!(psi_container, variable_name(variable_type, T), value)
    return
end

function assign_variable!(psi_container::PSIContainer, variable_type::AbstractString, value)
    assign_variable!(psi_container, variable_name(variable_type), value)
    return
end

function assign_variable!(psi_container::PSIContainer, name::Symbol, value)
    @debug "assign_variable" name

    if haskey(psi_container.variables, name)
        @error "variable $name is already stored" sort!(get_variable_names(psi_container))
        throw(IS.InvalidValue("variable $name is already stored"))
    end

    psi_container.variables[name] = value
    return
end

function add_var_container!(psi_container::PSIContainer, var_name::Symbol, axs...)
    container = container_spec(psi_container.JuMPmodel, axs...)
    assign_variable!(psi_container, var_name, container)
    return container
end

function get_constraint(
    psi_container::PSIContainer,
    constraint_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    return get_constraint(psi_container, constraint_name(constraint_type, T))
end

function get_constraint(psi_container::PSIContainer, constraint_type::AbstractString)
    return get_constraint(psi_container, constraint_name(constraint_type))
end

function get_constraint(psi_container::PSIContainer, name::Symbol)
    var = get(psi_container.constraints, name, nothing)
    if isnothing(var)
        @error "$name is not stored" sort!(get_constraint_names(psi_container))
        throw(IS.InvalidValue("constraint $name is not stored"))
    end

    return var
end

function get_constraint_names(psi_container::PSIContainer)
    return collect(keys(psi_container.constraints))
end

function assign_constraint!(
    psi_container::PSIContainer,
    constraint_type::AbstractString,
    ::Type{T},
    value,
) where {T <: PSY.Component}
    assign_constraint!(psi_container, constraint_name(constraint_type, T), value)
    return
end

function assign_constraint!(
    psi_container::PSIContainer,
    constraint_type::AbstractString,
    value,
)
    assign_constraint!(psi_container, constraint_name(constraint_type), value)
    return
end

function assign_constraint!(psi_container::PSIContainer, name::Symbol, value)
    @debug "set_constraint" name
    psi_container.constraints[name] = value
    return
end

function add_cons_container!(psi_container::PSIContainer, cons_name::Symbol, axs...)
    container = JuMPConstraintArray(undef, axs...)
    assign_constraint!(psi_container, cons_name, container)
    return container
end

function get_parameter_names(psi_container::PSIContainer)
    return collect(keys(psi_container.parameters))
end

function get_parameter_container(psi_container::PSIContainer, name::AbstractString)
    return get_parameter_container(psi_container, Symbol(name))
end

function get_parameter_container(psi_container::PSIContainer, name::Symbol)
    container = get(psi_container.parameters, name, nothing)
    if isnothing(container)
        @error "$name is not stored" sort!(get_parameter_names(psi_container))
        throw(IS.InvalidValue("parameter $name is not stored"))
    end
    return container
end

function get_parameter_container(
    psi_container::PSIContainer,
    name::Symbol,
    ::Type{T},
) where {T <: PSY.Component}
    return get_parameter_container(psi_container, encode_symbol(T, name))
end

function get_parameter_container(psi_container::PSIContainer, ref::UpdateRef)
    return get_parameter_container(psi_container, ref.access_ref)
end

function get_parameter_array(psi_container::PSIContainer, ref)
    return get_parameter_array(get_parameter_container(psi_container, ref))
end

function assign_parameter!(psi_container::PSIContainer, container::ParameterContainer)
    @debug "assign_parameter" container.update_ref
    name = container.update_ref.access_ref
    if name isa AbstractString
        name = Symbol(name)
    end

    if haskey(psi_container.parameters, name)
        @error "parameter $name is already stored" sort!(get_parameter_names(psi_container))
        throw(IS.InvalidValue("parameter $name is already stored"))
    end

    psi_container.parameters[name] = container
    return
end

function add_param_container!(
    psi_container::PSIContainer,
    param_reference::UpdateRef,
    axs...,
)
    container = ParameterContainer(
        param_reference,
        JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, axs...),
        JuMP.Containers.DenseAxisArray{Float64}(undef, axs...),
    )
    assign_parameter!(psi_container, container)
    return container
end

function iterate_parameter_containers(psi_container::PSIContainer)
    Channel() do channel
        for container in values(psi_container.parameters)
            put!(channel, container)
        end
    end
end

function get_parameters_value(psi_container::PSIContainer)
    # TODO: Still not obvious implementation since it needs to get the multipliers from
    # the system
    params_dict = Dict{Symbol, DataFrames.DataFrame}()
    parameters = get_parameters(psi_container)
    (isnothing(parameters) || isempty(parameters)) && return params_dict
    for (k, v) in parameters
        !isa(v.update_ref, UpdateRef{<:PSY.Component}) && continue
        params_key_tuple = decode_symbol(k)
        params_dict_key = Symbol(params_key_tuple[1], "_", params_key_tuple[3])
        param_array = axis_array_to_dataframe(get_parameter_array(v))
        multiplier_array = axis_array_to_dataframe(get_multiplier_array(v))
        params_dict[params_dict_key] = param_array .* multiplier_array
    end
    return params_dict
end

function is_milp(container::PSIContainer)
    type_of_optimizer = typeof(container.JuMPmodel.moi_backend.optimizer.model)
    supports_milp = hasfield(type_of_optimizer, :last_solved_by_mip)
    !supports_milp && return false
    return container.JuMPmodel.moi_backend.optimizer.model.last_solved_by_mip
end

function _export_optimizer_log(
    optimizer_log::Dict{Symbol, Any},
    psi_container::PSIContainer,
    path::String,
)
    optimizer_log[:obj_value] = JuMP.objective_value(psi_container.JuMPmodel)
    optimizer_log[:termination_status] =
        Int(JuMP.termination_status(psi_container.JuMPmodel))
    optimizer_log[:primal_status] = Int(JuMP.primal_status(psi_container.JuMPmodel))
    optimizer_log[:dual_status] = Int(JuMP.dual_status(psi_container.JuMPmodel))
    try
        optimizer_log[:solve_time] = MOI.get(psi_container.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by the Solver")
        optimizer_log[:solve_time] = NaN # "Not Supported by solver"
    end
    write_optimizer_log(optimizer_log, path)
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function _write_psi_container(psi_container::PSIContainer, save_path::String)
    MOF_model = MOPFM(format = MOI.FileFormats.FORMAT_MOF)
    MOI.copy_to(MOF_model, JuMP.backend(psi_container.JuMPmodel))
    MOI.write_to_file(MOF_model, save_path)
    return
end

function get_dual_values(psi_container::PSIContainer)
    cons = get_constraint_duals(psi_container.settings)
    return get_dual_values(psi_container, cons)
end

function get_dual_values(op::PSIContainer, cons::Vector{Symbol})
    results_dict = Dict{Symbol, DataFrames.DataFrame}()
    isempty(cons) && return results_dict
    for c in cons
        v = get_constraint(op, c)
        results_dict[c] = axis_array_to_dataframe(v)
    end
    return results_dict
end
