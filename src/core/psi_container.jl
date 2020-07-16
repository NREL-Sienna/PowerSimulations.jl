mutable struct PSIContainer
    JuMPmodel::Union{Nothing, JuMP.AbstractModel}
    time_steps::UnitRange{Int}
    resolution::Dates.TimePeriod
    settings::PSISettings
    settings_copy::PSISettings
    variables::Dict{Symbol, AbstractArray}
    constraints::Dict{Symbol, AbstractArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    parameters::Union{Nothing, ParametersContainer}
    initial_conditions::InitialConditions
    pm::Union{Nothing, PM.AbstractPowerModel}

    function PSIContainer(
        sys::PSY.System,
        settings::PSISettings,
        jump_model::Union{Nothing, JuMP.AbstractModel},
    )
        PSY.check_forecast_consistency(sys)
        resolution = PSY.get_forecasts_resolution(sys)
        resolution = IS.time_period_conversion(resolution)
        new(
            jump_model,
            1:1,
            resolution,
            settings,
            copy_for_serialization(settings),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}(),
            zero(JuMP.GenericAffExpr{Float64, JuMP.VariableRef}),
            DenseAxisArrayContainer(),
            nothing,
            InitialConditions(use_parameters = get_use_parameters(settings)),
            nothing,
        )
    end
end

function PSIContainer(
    ::Type{T},
    sys::PSY.System,
    settings::PSISettings,
    jump_model::Union{Nothing, JuMP.AbstractModel},
) where {T <: PM.AbstractPowerModel}

    container = PSIContainer(sys, settings, jump_model)
    psi_container_init!(container, T, sys)
    return container
end

function _check_warm_start_support(JuMPmodel::JuMP.AbstractModel, warm_start_enabled::Bool)
    !warm_start_enabled && return warm_start_enabled
    solver_supports_warm_start =
        MOI.supports(JuMP.backend(JuMPmodel), MOI.VariablePrimalStart(), MOI.VariableIndex)
    if !solver_supports_warm_start
        solver_name = JuMP.solver_name(JuMPmodel)
        @warn("$(solver_name) does not support warm start")
    end
    return solver_supports_warm_start
end

function _make_jump_model!(psi_container::PSIContainer)
    settings = psi_container.settings
    parameters = get_use_parameters(settings)
    optimizer = get_optimizer(settings)
    if !isnothing(psi_container.JuMPmodel)
        if parameters
            if !haskey(psi_container.JuMPmodel.ext, :params)
                @info("Model doesn't have Parameters enabled. Parameters will be enabled")
                PJ.enable_parameters(psi_container.JuMPmodel)
                warm_start_enabled = get_warm_start(settings)
                solver_supports_warm_start =
                    _check_warm_start_support(psi_container.JuMPmodel, warm_start_enabled)
                set_warm_start!(settings, solver_supports_warm_start)
            end
        end
        return
    end
    @debug "Instantiating the JuMP model"
    if !isnothing(optimizer)
        JuMPmodel = JuMP.Model(optimizer)
        warm_start_enabled = get_warm_start(settings)
        solver_supports_warm_start =
            _check_warm_start_support(JuMPmodel, warm_start_enabled)
        set_warm_start!(settings, solver_supports_warm_start)
        parameters && PJ.enable_parameters(JuMPmodel)
        psi_container.JuMPmodel = JuMPmodel
    else
        @debug "The optimization model has no optimizer attached"
        JuMPmodel = JuMP.Model()
        parameters && PJ.enable_parameters(JuMPmodel)
        psi_container.JuMPmodel = JuMPmodel
    end
    return
end

function _make_container_array(parameters::Bool, ax...)
    if parameters
        return JuMP.Containers.DenseAxisArray{PGAE}(undef, ax...)
    else
        return JuMP.Containers.DenseAxisArray{GAE}(undef, ax...)
    end
    return
end

function _make_expressions_dict!(
    psi_container::PSIContainer,
    bus_numbers::Vector{Int},
    transmission::Type{S},
) where {S <: PM.AbstractPowerModel}
    settings = psi_container.settings
    parameters = get_use_parameters(settings)
    time_steps = 1:get_horizon(settings)
    psi_container.expressions = DenseAxisArrayContainer(
        :nodal_balance_active =>
            _make_container_array(parameters, bus_numbers, time_steps),
        :nodal_balance_reactive =>
            _make_container_array(parameters, bus_numbers, time_steps),
    )
    return
end

function _make_expressions_dict!(
    psi_container::PSIContainer,
    bus_numbers::Vector{Int},
    transmission::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    settings = psi_container.settings
    parameters = get_use_parameters(settings)
    time_steps = 1:get_horizon(settings)
    psi_container.expressions = DenseAxisArrayContainer(
        :nodal_balance_active =>
            _make_container_array(parameters, bus_numbers, time_steps),
    )
    return
end

function psi_container_init!(
    psi_container::PSIContainer,
    ::Type{T},
    sys::PSY.System,
) where {T <: PM.AbstractPowerModel}
    PSY.set_units_base_system!(sys, "system_base")
    # The order of operations matter
    settings = psi_container.settings
    _make_jump_model!(psi_container)
    @assert !isnothing(psi_container.JuMPmodel)
    make_parameters_container = get_use_parameters(settings)
    make_parameters_container && (psi_container.parameters = ParametersContainer())

    use_forecasts = get_use_forecast_data(settings)
    if make_parameters_container && !use_forecasts
        throw(IS.ConflictingInputsError("enabling parameters without forecasts is not supported"))
    end

    if get_initial_time(settings) == UNSET_INI_TIME
        set_initial_time!(settings, PSY.get_forecasts_initial_time(sys))
    end

    if get_horizon(settings) == UNSET_HORIZON
        set_horizon!(settings, PSY.get_forecasts_horizon(sys))
    end

    if use_forecasts
        total_number_of_devices = length(get_available_components(PSY.Device, sys))
        psi_container.time_steps = 1:get_horizon(settings)
        # The 10e6 limit is based on the sizes of the lp benchmark problems http://plato.asu.edu/ftp/lpcom.html
        # The maximum numbers of constraints and variables in the benchmark problems is 1,918,399 and 1,259,121,
        # respectively. See also https://prod-ng.sandia.gov/techlib-noauth/access-control.cgi/2013/138847.pdf
        variable_count_estimate = length(psi_container.time_steps) * total_number_of_devices
        if variable_count_estimate > 10e6
            @warn("The estimated total number of variables that will be created in the model is $(variable_count_estimate). The total number of variables might be larger than 10e6 and could lead to large build or solve times.")
        end
    end

    bus_numbers = sort([PSY.get_number(b) for b in PSY.get_components(PSY.Bus, sys)])
    _make_expressions_dict!(psi_container, bus_numbers, T)
    return
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

# TODO: remove once all references are changed
constraint_name(cons_type, device_type) = encode_symbol(device_type, cons_type)
constraint_name(cons_type) = encode_symbol(cons_type)
make_constraint_name(cons_type, device_type) = encode_symbol(device_type, cons_type)
make_constraint_name(cons_type) = encode_symbol(cons_type)

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
get_jump_model(psi_container::PSIContainer) = psi_container.JuMPmodel

function get_variable(
    psi_container::PSIContainer,
    var_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    return get_variable(psi_container, make_variable_name(var_type, T))
end

function get_variable(psi_container::PSIContainer, var_type::AbstractString)
    return get_variable(psi_container, make_variable_name(var_type))
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
    assign_variable!(psi_container, make_variable_name(variable_type, T), value)
    return
end

function assign_variable!(psi_container::PSIContainer, variable_type::AbstractString, value)
    assign_variable!(psi_container, make_variable_name(variable_type), value)
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

function add_var_container!(
    psi_container::PSIContainer,
    var_name::Symbol,
    axs...;
    sparse = false,
)
    if sparse
        container = sparse_container_spec(psi_container.JuMPmodel, axs...)
    else
        container = container_spec(psi_container.JuMPmodel, axs...)
    end
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

function add_cons_container!(
    psi_container::PSIContainer,
    cons_name::Symbol,
    axs...;
    sparse = false,
)
    if sparse
        container = sparse_container_spec(psi_container.JuMPmodel, axs...)
    else
        container = JuMPConstraintArray(undef, axs...)
    end
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

function assign_expression!(psi_container::PSIContainer, name::Symbol, value)
    @debug "set_expression" name
    psi_container.expressions[name] = value
    return
end

function add_expression_container!(psi_container::PSIContainer, exp_name::Symbol, axs...)
    container = JuMP.Containers.DenseAxisArray{JuMP.GenericAffExpr}(undef, axs...)
    assign_expression!(psi_container, exp_name, container)
    return container
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

function add_to_setting_ext!(psi_container::PSIContainer, key::String, value)
    settings = get_settings(psi_container)
    push!(get_ext(settings), key => value)
    @debug "Add to settings ext" key value
    return
end
