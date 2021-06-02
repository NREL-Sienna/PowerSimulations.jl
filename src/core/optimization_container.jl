abstract type AbstractModelContainer end

mutable struct OptimizationContainer <: AbstractModelContainer
    JuMPmodel::JuMP.Model
    time_steps::UnitRange{Int}
    resolution::Dates.TimePeriod
    settings::Settings
    settings_copy::Settings
    variables::Dict{VariableKey, AbstractArray}
    aux_variables::Dict{AuxVarKey, AbstractArray}
    constraints::Dict{Symbol, AbstractArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::DenseAxisArrayContainer
    parameters::ParametersContainer
    initial_conditions::InitialConditions
    pm::Union{Nothing, PM.AbstractPowerModel}
    base_power::Float64
    solve_timed_log::Dict{Symbol, Any}

    function OptimizationContainer(
        sys::PSY.System,
        settings::Settings,
        jump_model::Union{Nothing, JuMP.Model},
    )
        resolution = PSY.get_time_series_resolution(sys)
        resolution = IS.time_period_conversion(resolution)
        use_parameters = get_use_parameters(settings)

        new(
            jump_model === nothing ? _make_jump_model(settings) :
            _prepare_external_jump_model!(jump_model, settings),
            1:1,
            resolution,
            settings,
            copy_for_serialization(settings),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}(),
            Dict{Symbol, AbstractArray}(),
            zero(JuMP.GenericAffExpr{Float64, JuMP.VariableRef}),
            DenseAxisArrayContainer(),
            ParametersContainer(),
            InitialConditions(use_parameters = use_parameters),
            nothing,
            PSY.get_base_power(sys),
            Dict{Symbol, Any}(),
        )
    end
end

function _validate_warm_start_support(JuMPmodel::JuMP.Model, warm_start_enabled::Bool)
    !warm_start_enabled && return warm_start_enabled
    solver_supports_warm_start =
        MOI.supports(JuMP.backend(JuMPmodel), MOI.VariablePrimalStart(), MOI.VariableIndex)
    if !solver_supports_warm_start
        solver_name = JuMP.solver_name(JuMPmodel)
        @warn("$(solver_name) does not support warm start")
    end
    return solver_supports_warm_start
end

function _finalize_jump_model!(JuMPmodel::JuMP.Model, settings::Settings)
    warm_start_enabled = get_warm_start(settings)
    solver_supports_warm_start = _validate_warm_start_support(JuMPmodel, warm_start_enabled)
    set_warm_start!(settings, solver_supports_warm_start)

    if get_optimizer_log_print(settings)
        JuMP.unset_silent(JuMPmodel)
        @debug "optimizer unset to silent"
    else
        JuMP.set_silent(JuMPmodel)
        @debug "optimizer set to silent"
    end
end

function _prepare_external_jump_model!(JuMPmodel::JuMP.Model, settings::Settings)
    parameters = get_use_parameters(settings)
    optimizer = get_optimizer(settings)
    if get_direct_mode_optimizer(settings)
        throw(
            IS.ConflictingInputsError(
                "Externally provided JuMP models are not compatible with the direct model keyword argument. Use JuMP.direct_model before passing the custom model",
            ),
        )
    end

    if parameters
        if !haskey(JuMPmodel.ext, :ParameterJuMP)
            @info("Model doesn't have Parameters enabled. Parameters will be enabled")
            PJ.enable_parameters(JuMPmodel)
            JuMP.set_optimizer(JuMPmodel, optimizer)
        end
    end
    _finalize_jump_model!(JuMPmodel, settings)
    return JuMPmodel
end

function _make_jump_model(settings::Settings)
    @debug "Instantiating the JuMP model"
    parameters = get_use_parameters(settings)
    optimizer = get_optimizer(settings)
    if get_direct_mode_optimizer(settings)
        JuMPmodel = JuMP.direct_model(MOI.instantiate(optimizer))
    elseif optimizer === nothing
        JuMPmodel = JuMP.Model()
        @debug "The optimization model has no optimizer attached"
    else
        JuMPmodel = JuMP.Model(optimizer)
    end
    parameters && PJ.enable_parameters(JuMPmodel)
    _finalize_jump_model!(JuMPmodel, settings)

    return JuMPmodel
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
    ::Type{<:PM.AbstractPowerModel},
)
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
    ::Type{<:PM.AbstractActivePowerModel},
)
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
    @assert !(optimization_container.JuMPmodel === nothing)
    PSY.set_units_base_system!(sys, "SYSTEM_BASE")
    # The order of operations matter
    settings = get_settings(optimization_container)
    use_parameters = get_use_parameters(settings)
    use_forecasts = get_use_forecast_data(settings)

    if use_parameters
        if !use_forecasts
            throw(
                IS.ConflictingInputsError(
                    "enabling parameters without forecasts is not supported",
                ),
            )
        end
        set_use_parameters!(get_initial_conditions(optimization_container), use_parameters)
    end

    if get_initial_time(settings) == UNSET_INI_TIME
        set_initial_time!(settings, PSY.get_forecast_initial_timestamp(sys))
    end

    if use_forecasts
        if get_horizon(settings) == UNSET_HORIZON
            set_horizon!(settings, PSY.get_forecast_horizon(sys))
        end
        total_number_of_devices = length(get_available_components(PSY.Device, sys))
        optimization_container.time_steps = 1:get_horizon(settings)
        # The 10e6 limit is based on the sizes of the lp benchmark problems http://plato.asu.edu/ftp/lpcom.html
        # The maximum numbers of constraints and variables in the benchmark problems is 1,918,399 and 1,259,121,
        # respectively. See also https://prod-ng.sandia.gov/techlib-noauth/access-control.cgi/2013/138847.pdf
        variable_count_estimate =
            length(optimization_container.time_steps) * total_number_of_devices
        if variable_count_estimate > 10e6
            @warn(
                "The estimated total number of variables that will be created in the model is $(variable_count_estimate). The total number of variables might be larger than 10e6 and could lead to large build or solve times."
            )
        end
    else
        set_horizon!(settings, 1)
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

function set_initial_conditions!(
    optimization_container::OptimizationContainer,
    key::ICKey,
    value,
)
    set_initial_conditions!(optimization_container.initial_conditions, key, value)
end

model_time_steps(optimization_container::OptimizationContainer) =
    optimization_container.time_steps
model_resolution(optimization_container::OptimizationContainer) =
    optimization_container.resolution
model_has_parameters(optimization_container::OptimizationContainer) =
    get_use_parameters(optimization_container.settings)
model_uses_forecasts(optimization_container::OptimizationContainer) =
    get_use_forecast_data(optimization_container.settings)
model_initial_time(optimization_container::OptimizationContainer) =
    get_initial_time(optimization_container.settings)
# Internal Variables, Constraints and Parameters accessors
get_variables(optimization_container::OptimizationContainer) =
    optimization_container.variables
get_aux_variables(optimization_container::OptimizationContainer) =
    optimization_container.aux_variables
get_constraints(optimization_container::OptimizationContainer) =
    optimization_container.constraints
get_parameters(optimization_container::OptimizationContainer) =
    optimization_container.parameters
get_expression(optimization_container::OptimizationContainer, name::Symbol) =
    optimization_container.expressions[name]
get_initial_conditions(optimization_container::OptimizationContainer) =
    optimization_container.initial_conditions
get_PTDF(optimization_container::OptimizationContainer) =
    get_PTDF(optimization_container.settings)
get_settings(optimization_container::OptimizationContainer) =
    optimization_container.settings
get_jump_model(optimization_container::OptimizationContainer) =
    optimization_container.JuMPmodel
get_base_power(optimization_container::OptimizationContainer) =
    optimization_container.base_power

function get_variable(optimization_container::OptimizationContainer, key::VariableKey)
    var = get(optimization_container.variables, key, nothing)
    if var === nothing
        name = encode_key(key)
        keys = encode_key.(get_variable_keys(optimization_container))
        @error "$name is not stored" sort!(keys)
        throw(IS.InvalidValue("variable $name is not stored"))
    end
    return var
end

function get_variable(
    optimization_container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: PSY.Component}
    return get_variable(optimization_container, VariableKey(T, U, meta))
end

function get_variable_keys(optimization_container::OptimizationContainer)
    return collect(keys(optimization_container.variables))
end

function _assign_container!(container::Dict, key, value)
    if haskey(container, key)
        @error "variable $(encode_key(key)) is already stored" sort!(
            encode_key.(keys(container)),
        )
        throw(IS.InvalidValue("$key is already stored"))
    end
    container[key] = value
end

function add_aux_var_container!(
    optimization_container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: AuxVariableType, U <: PSY.Component}
    var_key = AuxVarKey(T, U)
    if sparse
        container = sparse_container_spec(Float64, axs...)
    else
        container = container_spec(Float64, axs...)
    end
    _assign_container!(optimization_container.aux_variables, var_key, container)
    return container
end

function add_var_container!(
    optimization_container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: VariableType, U <: PSY.Component}
    var_key = VariableKey(T, U)
    if sparse
        container = sparse_container_spec(JuMP.VariableRef, axs...)
    else
        container = container_spec(JuMP.VariableRef, axs...)
    end
    _assign_container!(optimization_container.variables, var_key, container)
    return container
end

function add_var_container!(
    optimization_container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta::String,
    axs...;
    sparse = false,
) where {T <: VariableType, U <: PSY.Component}
    var_key = VariableKey(T, U, meta)
    if sparse
        container = sparse_container_spec(JuMP.VariableRef, axs...)
    else
        container = container_spec(JuMP.VariableRef, axs...)
    end
    _assign_container!(optimization_container.variables, var_key, container)
    return container
end

function get_constraint(
    optimization_container::OptimizationContainer,
    constraint_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    return get_constraint(optimization_container, make_constraint_name(constraint_type, T))
end

function get_constraint(
    optimization_container::OptimizationContainer,
    constraint_type::AbstractString,
)
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

# This is a temporary method while refactoring variable container
function add_cons_container!(
    optimization_container::OptimizationContainer,
    cons_type::ConstraintType,
    var_key::VariableKey,
    axs...;
    sparse = false,
)
    return add_cons_container!(
        optimization_container,
        cons_type,
        var_key.entry_type(),
        var_key.component_type,
        axs...;
        sparse = sparse,
    )
end

# This is a temporary method while refactoring variable container
function add_cons_container!(
    optimization_container::OptimizationContainer,
    cons_type::ConstraintType,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: VariableType, U <: PSY.Component}
    cons_key = make_constraint_name(cons_type, T, U)
    return add_cons_container!(optimization_container, cons_key, axs...; sparse = sparse)
end

function add_cons_container!(
    optimization_container::OptimizationContainer,
    cons_key::Symbol,
    axs...;
    sparse = false,
)
    if sparse
        container = sparse_container_spec(JuMP.ConstraintRef, axs...)
    else
        container = container_spec(JuMP.ConstraintRef, axs...)
    end
    _assign_container!(optimization_container.constraints, cons_key, container)
    return container
end

function get_parameter_names(optimization_container::OptimizationContainer)
    return collect(keys(optimization_container.parameters))
end

function get_parameter_container(
    optimization_container::OptimizationContainer,
    name::AbstractString,
)
    return get_parameter_container(optimization_container, Symbol(name))
end

function get_parameter_container(
    optimization_container::OptimizationContainer,
    name::Symbol,
)
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

function get_parameter_container(
    optimization_container::OptimizationContainer,
    ref::UpdateRef,
)
    return get_parameter_container(optimization_container, ref.access_ref)
end

function get_parameter_array(optimization_container::OptimizationContainer, ref)
    return get_parameter_array(get_parameter_container(optimization_container, ref))
end

function assign_parameter!(
    optimization_container::OptimizationContainer,
    container::ParameterContainer,
)
    @debug "assign_parameter" container.update_ref
    name = container.update_ref.access_ref
    if name isa AbstractString
        name = Symbol(name)
    end

    if haskey(optimization_container.parameters, name)
        @error "parameter $name is already stored" sort!(
            get_parameter_names(optimization_container),
        )
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

function assign_expression!(
    optimization_container::OptimizationContainer,
    name::Symbol,
    value,
)
    @debug "set_expression" name
    optimization_container.expressions[name] = value
    return
end

function add_expression_container!(
    optimization_container::OptimizationContainer,
    exp_name::Symbol,
    axs...,
)
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

function export_optimizer_stats(
    optimizer_stats::Dict{Symbol, Any},
    optimization_container::OptimizationContainer,
    path::String,
)
    optimizer_stats[:termination_status] =
        Int(JuMP.termination_status(optimization_container.JuMPmodel))
    optimizer_stats[:primal_status] =
        Int(JuMP.primal_status(optimization_container.JuMPmodel))
    optimizer_stats[:dual_status] = Int(JuMP.dual_status(optimization_container.JuMPmodel))

    if optimizer_stats[:primal_status] == MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        optimizer_stats[:obj_value] = JuMP.objective_value(optimization_container.JuMPmodel)
    else
        optimizer_stats[:obj_value] = Inf
    end

    try
        optimizer_stats[:solve_time] =
            MOI.get(optimization_container.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by the Solver")
        optimizer_stats[:solve_time] = NaN # "Not Supported by solver"
    end
    write_optimizer_stats(optimizer_stats, path)
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function serialize_optimization_model(
    optimization_container::OptimizationContainer,
    save_path::String,
)
    MOF_model = MOPFM(format = MOI.FileFormats.FORMAT_MOF)
    MOI.copy_to(MOF_model, JuMP.backend(optimization_container.JuMPmodel))
    MOI.write_to_file(MOF_model, save_path)
    return
end

function read_variables(optimization_container::OptimizationContainer)
    return Dict(
        encode_key(k) => axis_array_to_dataframe(v) for
        (k, v) in get_variables(optimization_container)
    )
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
        results_dict[c] = axis_array_to_dataframe(v, [c])
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

function add_to_setting_ext!(
    optimization_container::OptimizationContainer,
    key::String,
    value,
)
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

function get_problem_size(optimization_container::OptimizationContainer)
    model = optimization_container.JuMPmodel
    vars = JuMP.num_variables(model)
    cons = 0
    for (exp, c_type) in JuMP.list_of_constraint_types(model)
        cons += JuMP.num_constraints(model, exp, c_type)
    end
    return "The current total number of variables is $(vars) and total number of constraints is $(cons)"
end

function build_impl!(
    optimization_container::OptimizationContainer,
    template::OperationsProblemTemplate,
    sys::PSY.System,
)
    transmission = template.transmission
    # Order is required
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Services" begin
        construct_services!(
            optimization_container,
            sys,
            template.services,
            template.devices,
        )
    end
    for device_model in values(template.devices)
        @debug "Building $(device_model.component_type) with $(device_model.formulation) formulation"
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(device_model.component_type)" begin
            construct_device!(optimization_container, sys, device_model, transmission)
            @debug get_problem_size(optimization_container)
        end
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(transmission)" begin
        @debug "Building $(transmission) network formulation"
        construct_network!(optimization_container, sys, transmission, template)
        @debug get_problem_size(optimization_container)
    end

    for branch_model in values(template.branches)
        @debug "Building $(branch_model.component_type) with $(branch_model.formulation) formulation"
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(branch_model.component_type)" begin
            construct_device!(optimization_container, sys, branch_model, transmission)
            @debug get_problem_size(optimization_container)
        end
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Objective" begin
        @debug "Building Objective"
        JuMP.@objective(
            optimization_container.JuMPmodel,
            MOI.MIN_SENSE,
            optimization_container.cost_function
        )
    end
    @debug "Total operation count $(optimization_container.JuMPmodel.operator_counter)"

    check_optimization_container(optimization_container)
    return
end
