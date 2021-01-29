mutable struct OptimizationContainer
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
    base_power::Float64

    function OptimizationContainer(
        sys::PSY.System,
        settings::PSISettings,
        jump_model::Union{Nothing, JuMP.AbstractModel},
    )
        resolution = PSY.get_time_series_resolution(sys)
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
            PSY.get_base_power(sys),
        )
    end
end

function OptimizationContainer(
    ::Type{T},
    sys::PSY.System,
    settings::PSISettings,
    jump_model::Union{Nothing, JuMP.AbstractModel},
) where {T <: PM.AbstractPowerModel}
    container = OptimizationContainer(sys, settings, jump_model)
    optimization_container_init!(container, T, sys)
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

function _make_jump_model!(optimization_container::OptimizationContainer)
    settings = optimization_container.settings
    parameters = get_use_parameters(settings)
    optimizer = get_optimizer(settings)
    if !(optimization_container.JuMPmodel === nothing)
        if parameters
            if !haskey(optimization_container.JuMPmodel.ext, :params)
                @info("Model doesn't have Parameters enabled. Parameters will be enabled")
                PJ.enable_parameters(optimization_container.JuMPmodel)
                warm_start_enabled = get_warm_start(settings)
                solver_supports_warm_start =
                    _check_warm_start_support(optimization_container.JuMPmodel, warm_start_enabled)
                set_warm_start!(settings, solver_supports_warm_start)
            end
        end
        return
    end
    @debug "Instantiating the JuMP model"
    if !(optimizer === nothing)
        JuMPmodel = JuMP.Model(optimizer)
        warm_start_enabled = get_warm_start(settings)
        solver_supports_warm_start =
            _check_warm_start_support(JuMPmodel, warm_start_enabled)
        set_warm_start!(settings, solver_supports_warm_start)
        parameters && PJ.enable_parameters(JuMPmodel)
        optimization_container.JuMPmodel = JuMPmodel
    else
        @debug "The optimization model has no optimizer attached"
        JuMPmodel = JuMP.Model()
        parameters && PJ.enable_parameters(JuMPmodel)
        optimization_container.JuMPmodel = JuMPmodel
    end
    if get_optimizer_log_print(settings)
        @debug "optimizer set to silent"
        JuMP.set_silent(optimization_container.JuMPmodel)
    else
        JuMP.unset_silent(optimization_container.JuMPmodel)
        @debug "optimizer unset to silent"
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
    optimization_container::OptimizationContainer,
    bus_numbers::Vector{Int},
    transmission::Type{S},
) where {S <: PM.AbstractPowerModel}
    settings = optimization_container.settings
    parameters = get_use_parameters(settings)
    time_steps = 1:get_horizon(settings)
    optimization_container.expressions = DenseAxisArrayContainer(
        :nodal_balance_active =>
            _make_container_array(parameters, bus_numbers, time_steps),
        :nodal_balance_reactive =>
            _make_container_array(parameters, bus_numbers, time_steps),
    )
    return
end

function _make_expressions_dict!(
    optimization_container::OptimizationContainer,
    bus_numbers::Vector{Int},
    transmission::Type{S},
) where {S <: PM.AbstractActivePowerModel}
    settings = optimization_container.settings
    parameters = get_use_parameters(settings)
    time_steps = 1:get_horizon(settings)
    optimization_container.expressions = DenseAxisArrayContainer(
        :nodal_balance_active =>
            _make_container_array(parameters, bus_numbers, time_steps),
    )
    return
end

function optimization_container_init!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    sys::PSY.System,
) where {T <: PM.AbstractPowerModel}
    PSY.set_units_base_system!(sys, "SYSTEM_BASE")
    # The order of operations matter
    settings = optimization_container.settings
    _make_jump_model!(optimization_container)
    @assert !(optimization_container.JuMPmodel === nothing)
    make_parameters_container = get_use_parameters(settings)
    make_parameters_container && (optimization_container.parameters = ParametersContainer())

    use_forecasts = get_use_forecast_data(settings)
    if make_parameters_container && !use_forecasts
        throw(
            IS.ConflictingInputsError(
                "enabling parameters without forecasts is not supported",
            ),
        )
    end

    if get_initial_time(settings) == UNSET_INI_TIME
        set_initial_time!(settings, PSY.get_forecast_initial_timestamp(sys))
    end

    if get_horizon(settings) == UNSET_HORIZON
        set_horizon!(settings, PSY.get_forecast_horizon(sys))
    end

    if use_forecasts
        total_number_of_devices = length(get_available_components(PSY.Device, sys))
        optimization_container.time_steps = 1:get_horizon(settings)
        # The 10e6 limit is based on the sizes of the lp benchmark problems http://plato.asu.edu/ftp/lpcom.html
        # The maximum numbers of constraints and variables in the benchmark problems is 1,918,399 and 1,259,121,
        # respectively. See also https://prod-ng.sandia.gov/techlib-noauth/access-control.cgi/2013/138847.pdf
        variable_count_estimate = length(optimization_container.time_steps) * total_number_of_devices
        if variable_count_estimate > 10e6
            @warn(
                "The estimated total number of variables that will be created in the model is $(variable_count_estimate). The total number of variables might be larger than 10e6 and could lead to large build or solve times."
            )
        end
    end

    bus_numbers = sort([PSY.get_number(b) for b in PSY.get_components(PSY.Bus, sys)])
    _make_expressions_dict!(optimization_container, bus_numbers, T)
    return
end

function has_initial_conditions(optimization_container::OptimizationContainer, key::ICKey)
    return has_initial_conditions(optimization_container.initial_conditions, key)
end

function iterate_initial_conditions(optimization_container::OptimizationContainer)
    return iterate_initial_conditions(optimization_container.initial_conditions)
end

function get_initial_conditions(
    optimization_container::OptimizationContainer,
    ::Type{T},
    ::Type{D},
) where {T <: InitialConditionType, D <: PSY.Device}
    return get_initial_conditions(optimization_container, ICKey(T, D))
end

function get_initial_conditions(optimization_container::OptimizationContainer, key::ICKey)
    return get_initial_conditions(optimization_container.initial_conditions, key)
end

function set_initial_conditions!(optimization_container::OptimizationContainer, key::ICKey, value)
    set_initial_conditions!(optimization_container.initial_conditions, key, value)
end

_variable_type(cm::OptimizationContainer) = JuMP.variable_type(cm.JuMPmodel)
model_time_steps(optimization_container::OptimizationContainer) = optimization_container.time_steps
model_resolution(optimization_container::OptimizationContainer) = optimization_container.resolution
model_has_parameters(optimization_container::OptimizationContainer) =
    get_use_parameters(optimization_container.settings)
model_uses_forecasts(optimization_container::OptimizationContainer) =
    get_use_forecast_data(optimization_container.settings)
model_initial_time(optimization_container::OptimizationContainer) = get_initial_time(optimization_container.settings)
# Internal Variables, Constraints and Parameters accessors
get_variables(optimization_container::OptimizationContainer) = optimization_container.variables
get_constraints(optimization_container::OptimizationContainer) = optimization_container.constraints
get_parameters(optimization_container::OptimizationContainer) = optimization_container.parameters
get_expression(optimization_container::OptimizationContainer, name::Symbol) = optimization_container.expressions[name]
get_initial_conditions(optimization_container::OptimizationContainer) = optimization_container.initial_conditions
get_PTDF(optimization_container::OptimizationContainer) = get_PTDF(optimization_container.settings)
get_settings(optimization_container::OptimizationContainer) = optimization_container.settings
get_jump_model(optimization_container::OptimizationContainer) = optimization_container.JuMPmodel
get_base_power(optimization_container::OptimizationContainer) = optimization_container.base_power

function get_variable(
    optimization_container::OptimizationContainer,
    var_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    return get_variable(optimization_container, make_variable_name(var_type, T))
end

function get_variable(
    optimization_container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
) where {T <: VariableType, U <: PSY.Component}
    return get_variable(optimization_container, make_variable_name(T, U))
end

function get_variable(optimization_container::OptimizationContainer, var_type::AbstractString)
    return get_variable(optimization_container, make_variable_name(var_type))
end

function get_variable(optimization_container::OptimizationContainer, update_ref::UpdateRef)
    return get_variable(optimization_container, update_ref.access_ref)
end

function get_variable(optimization_container::OptimizationContainer, name::Symbol)
    var = get(optimization_container.variables, name, nothing)
    if var === nothing
        @error "$name is not stored" sort!(get_variable_names(optimization_container))
        throw(IS.InvalidValue("variable $name is not stored"))
    end

    return var
end

function get_variable_names(optimization_container::OptimizationContainer)
    return collect(keys(optimization_container.variables))
end

function assign_variable!(
    optimization_container::OptimizationContainer,
    variable_type::AbstractString,
    ::Type{T},
    value,
) where {T <: PSY.Component}
    assign_variable!(optimization_container, make_variable_name(variable_type, T), value)
    return
end

function assign_variable!(optimization_container::OptimizationContainer, variable_type::AbstractString, value)
    assign_variable!(optimization_container, make_variable_name(variable_type), value)
    return
end

function assign_variable!(optimization_container::OptimizationContainer, name::Symbol, value)
    @debug "assign_variable" name

    if haskey(optimization_container.variables, name)
        @error "variable $name is already stored" sort!(get_variable_names(optimization_container))
        throw(IS.InvalidValue("variable $name is already stored"))
    end

    optimization_container.variables[name] = value
    return
end

function add_var_container!(
    optimization_container::OptimizationContainer,
    var_name::Symbol,
    axs...;
    sparse = false,
)
    if sparse
        container = sparse_container_spec(optimization_container.JuMPmodel, axs...)
    else
        container = container_spec(optimization_container.JuMPmodel, axs...)
    end
    assign_variable!(optimization_container, var_name, container)
    return container
end

function get_constraint(
    optimization_container::OptimizationContainer,
    constraint_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    return get_constraint(optimization_container, make_constraint_name(constraint_type, T))
end

function get_constraint(optimization_container::OptimizationContainer, constraint_type::AbstractString)
    return get_constraint(optimization_container, make_constraint_name(constraint_type))
end

function get_constraint(optimization_container::OptimizationContainer, name::Symbol)
    var = get(optimization_container.constraints, name, nothing)
    if var === nothing
        @error "$name is not stored" sort!(get_constraint_names(optimization_container))
        throw(IS.InvalidValue("constraint $name is not stored"))
    end

    return var
end

function get_constraint_names(optimization_container::OptimizationContainer)
    return collect(keys(optimization_container.constraints))
end

function assign_constraint!(
    optimization_container::OptimizationContainer,
    constraint_type::AbstractString,
    ::Type{T},
    value,
) where {T <: PSY.Component}
    assign_constraint!(optimization_container, make_constraint_name(constraint_type, T), value)
    return
end

function assign_constraint!(
    optimization_container::OptimizationContainer,
    constraint_type::AbstractString,
    value,
)
    assign_constraint!(optimization_container, make_constraint_name(constraint_type), value)
    return
end

function assign_constraint!(optimization_container::OptimizationContainer, name::Symbol, value)
    @debug "set_constraint" name
    optimization_container.constraints[name] = value
    return
end

function add_cons_container!(
    optimization_container::OptimizationContainer,
    cons_name::Symbol,
    axs...;
    sparse = false,
)
    if sparse
        container = sparse_container_spec(optimization_container.JuMPmodel, axs...)
    else
        container = JuMPConstraintArray(undef, axs...)
    end
    assign_constraint!(optimization_container, cons_name, container)
    return container
end

function get_parameter_names(optimization_container::OptimizationContainer)
    return collect(keys(optimization_container.parameters))
end

function get_parameter_container(optimization_container::OptimizationContainer, name::AbstractString)
    return get_parameter_container(optimization_container, Symbol(name))
end

function get_parameter_container(optimization_container::OptimizationContainer, name::Symbol)
    container = get(optimization_container.parameters, name, nothing)
    if container === nothing
        @error "$name is not stored" sort!(get_parameter_names(optimization_container))
        throw(IS.InvalidValue("parameter $name is not stored"))
    end
    return container
end

function get_parameter_container(
    optimization_container::OptimizationContainer,
    name::Symbol,
    ::Type{T},
) where {T <: PSY.Component}
    return get_parameter_container(optimization_container, encode_symbol(T, name))
end

function get_parameter_container(optimization_container::OptimizationContainer, ref::UpdateRef)
    return get_parameter_container(optimization_container, ref.access_ref)
end

function get_parameter_array(optimization_container::OptimizationContainer, ref)
    return get_parameter_array(get_parameter_container(optimization_container, ref))
end

function assign_parameter!(optimization_container::OptimizationContainer, container::ParameterContainer)
    @debug "assign_parameter" container.update_ref
    name = container.update_ref.access_ref
    if name isa AbstractString
        name = Symbol(name)
    end

    if haskey(optimization_container.parameters, name)
        @error "parameter $name is already stored" sort!(get_parameter_names(optimization_container))
        throw(IS.InvalidValue("parameter $name is already stored"))
    end

    optimization_container.parameters[name] = container
    return
end

function add_param_container!(
    optimization_container::OptimizationContainer,
    param_reference::UpdateRef,
    axs...,
)
    container = ParameterContainer(
        param_reference,
        JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, axs...),
        fill!(JuMP.Containers.DenseAxisArray{Float64}(undef, axs...), NaN),
    )
    assign_parameter!(optimization_container, container)
    return container
end

function iterate_parameter_containers(optimization_container::OptimizationContainer)
    Channel() do channel
        for container in values(optimization_container.parameters)
            put!(channel, container)
        end
    end
end

function assign_expression!(optimization_container::OptimizationContainer, name::Symbol, value)
    @debug "set_expression" name
    optimization_container.expressions[name] = value
    return
end

function add_expression_container!(optimization_container::OptimizationContainer, exp_name::Symbol, axs...)
    container = JuMP.Containers.DenseAxisArray{JuMP.GenericAffExpr}(undef, axs...)
    assign_expression!(optimization_container, exp_name, container)
    return container
end

function is_milp(container::OptimizationContainer)
    type_of_optimizer = typeof(container.JuMPmodel.moi_backend.optimizer.model)
    supports_milp = hasfield(type_of_optimizer, :last_solved_by_mip)
    !supports_milp && return false
    return container.JuMPmodel.moi_backend.optimizer.model.last_solved_by_mip
end

function export_optimizer_log(
    optimizer_log::Dict{Symbol, Any},
    optimization_container::OptimizationContainer,
    path::String,
)
    optimizer_log[:termination_status] =
        Int(JuMP.termination_status(optimization_container.JuMPmodel))
    optimizer_log[:primal_status] = Int(JuMP.primal_status(optimization_container.JuMPmodel))
    optimizer_log[:dual_status] = Int(JuMP.dual_status(optimization_container.JuMPmodel))

    if optimizer_log[:primal_status] == MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        optimizer_log[:obj_value] = JuMP.objective_value(optimization_container.JuMPmodel)
    else
        optimizer_log[:obj_value] = Inf
    end

    try
        optimizer_log[:solve_time] = MOI.get(optimization_container.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by the Solver")
        optimizer_log[:solve_time] = NaN # "Not Supported by solver"
    end
    write_optimizer_log(optimizer_log, path)
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function write_optimization_container(optimization_container::OptimizationContainer, save_path::String)
    MOF_model = MOPFM(format = MOI.FileFormats.FORMAT_MOF)
    MOI.copy_to(MOF_model, JuMP.backend(optimization_container.JuMPmodel))
    MOI.write_to_file(MOF_model, save_path)
    return
end

function read_variables(optimization_container::OptimizationContainer)
    return Dict(k => axis_array_to_dataframe(v) for (k, v) in get_variables(optimization_container))
end

function read_duals(optimization_container::OptimizationContainer)
    cons = get_constraint_duals(optimization_container.settings)
    return read_duals(optimization_container, cons)
end

function read_duals(op::OptimizationContainer, cons::Vector{Symbol})
    results_dict = Dict{Symbol, DataFrames.DataFrame}()
    isempty(cons) && return results_dict
    for c in cons
        v = get_constraint(op, c)
        results_dict[c] = axis_array_to_dataframe(v)
    end
    return results_dict
end

function read_parameters(optimization_container::OptimizationContainer)
    # TODO: Still not obvious implementation since it needs to get the multipliers from
    # the system
    params_dict = Dict{Symbol, DataFrames.DataFrame}()
    parameters = get_parameters(optimization_container)
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

function add_to_setting_ext!(optimization_container::OptimizationContainer, key::String, value)
    settings = get_settings(optimization_container)
    push!(get_ext(settings), key => value)
    @debug "Add to settings ext" key value
    return
end

function check_optimization_container(optimization_container::OptimizationContainer)
    valid = true
    # Check for parameter invalid values
    if model_has_parameters(optimization_container)
        for param_array in values(optimization_container.parameters)
            valid = !all(isnan.(param_array.multiplier_array.data))
        end
    end
    if !valid
        error("The model container has invalid values")
    end
    return
end

function _build!(
    optimization_container::OptimizationContainer,
    template::OperationsProblemTemplate,
    sys::PSY.System,
)
    transmission = template.transmission
    # Order is required
    # The container is initialized here because this build! call for optimization_container takes the
    # information from the template with cached PSISettings. It allows having the same build! call for operations problems
    # specified with template and simulation stage.
    optimization_container_init!(optimization_container, transmission, sys)
    construct_services!(optimization_container, sys, template.services, template.devices)
    for device_model in values(template.devices)
        @debug "Building $(device_model.device_type) with $(device_model.formulation) formulation"
        construct_device!(optimization_container, sys, device_model, transmission)
        @debug check_problem_size(optimization_container)
    end
    @debug "Building $(transmission) network formulation"
    construct_network!(optimization_container, sys, transmission)
    @debug check_problem_size(optimization_container)

    for branch_model in values(template.branches)
        @debug "Building $(branch_model.device_type) with $(branch_model.formulation) formulation"
        construct_device!(optimization_container, sys, branch_model, transmission)
        @debug check_problem_size(optimization_container)
    end

    @debug "Building Objective"
    JuMP.@objective(optimization_container.JuMPmodel, MOI.MIN_SENSE, optimization_container.cost_function)
    @debug "Total operation count $(optimization_container.JuMPmodel.operator_counter)"

    check_optimization_container(optimization_container)
    return
end
