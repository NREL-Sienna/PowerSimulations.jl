#Defined here because of dependencies in psi_container
function _make_jump_model(
    JuMPmodel::Union{Nothing, JuMP.AbstractModel},
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes},
    parameters::Bool,
)
    if !isnothing(JuMPmodel)
        if parameters
            if !haskey(JuMPmodel.ext, :params)
                @info("Model doesn't have Parameters enabled. Parameters will be enabled")
                PJ.enable_parameters(JuMPmodel)
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
    initial_conditions::Union{Nothing, InitialConditionsContainer} = nothing,
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

    if isnothing(initial_conditions)
        initial_conditions = InitialConditionsContainer(use_parameters = use_parameters)
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
    # TODO: If we want to support reset!(Stage) then this needs to be a deepcopy.
    initial_conditions = get_initial_conditions(settings)

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
        initial_conditions,
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
    built::Bool

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
            false,
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
    optimizer = get_optimizer(settings)
    use_parameters = get_use_parameters(settings)
    jump_model = _make_jump_model(jump_model, optimizer, use_parameters)
    if get_use_forecast_data(settings)
        time_steps = 1:get_horizon(settings)
        if length(time_steps) > 100
            @warn("The number of time steps in the model is over 100. This will result in
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

function _build!(
    psi_container::PSIContainer,
    template::OperationsProblemTemplate,
    sys::PSY.System,
)
    if psi_container.built
        error("Rebuilding a PSIContainer is not supported")
    end
    transmission = template.transmission
    # Order is required
    construct_services!(psi_container, sys, template.services, template.devices)
    for device_model in values(template.devices)
        @debug "Building $(device_model.device_type) with $(device_model.formulation) formulation"
        construct_device!(psi_container, sys, device_model, transmission)
    end
    @debug "Building $(transmission) network formulation"
    construct_network!(psi_container, sys, transmission)
    for branch_model in values(template.branches)
        @debug "Building $(branch_model.device_type) with $(branch_model.formulation) formulation"
        construct_device!(psi_container, sys, branch_model, transmission)
    end

    if model_has_parameters(psi_container)
        _add_initial_condition_parameters(psi_container)
    end

    @debug "Building Objective"
    JuMP.@objective(psi_container.JuMPmodel, MOI.MIN_SENSE, psi_container.cost_function)

    psi_container.built = true
    return
end

function _add_initial_condition_parameters(psi_container::PSIContainer)
    @info "run _add_initial_condition_parameters"
    for (_, initial_conditions) in iterate_initial_conditions(psi_container)
        for (i, ic) in enumerate(initial_conditions)
            val = PJ.add_parameter(psi_container.JuMPmodel, get_value(ic))
            initial_conditions[i] = InitialCondition(ic.device, ic.update_ref, val, ic.cache_type)
        end
    end
end

function has_initial_conditions(psi_container::PSIContainer, key::ICKey)
    return has_initial_conditions(psi_container.initial_conditions, key)
end

function iterate_initial_conditions(psi_container::PSIContainer)
    return iterate_initial_conditions(psi_container.initial_conditions)
end

function get_initial_conditions(
    psi_container::PSIContainer,
    ::Type{T},
    ::Type{D},
) where {T <: InitialConditionType, D <: PSY.Device}
    return get_initial_conditions(psi_container, ICKey(T, D))
end

function get_initial_conditions(psi_container::PSIContainer, key::ICKey)
    return get_initial_conditions(psi_container.initial_conditions, key)
end

function set_initial_conditions!(psi_container::PSIContainer, key::ICKey, value)
    set_initial_conditions!(psi_container.initial_conditions, key, value)
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
container_built(psi_container::PSIContainer) = psi_container.built

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
