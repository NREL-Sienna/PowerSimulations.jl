struct OptimizationContainerMetadata
    container_key_lookup::Dict{String, <:OptimizationContainerKey}
end

function OptimizationContainerMetadata()
    return OptimizationContainerMetadata(Dict{String, OptimizationContainerKey}())
end

function deserialize_metadata(
    ::Type{OptimizationContainerMetadata},
    output_dir::String,
    model_name,
)
    filename = _make_metadata_filename(output_dir)
    return Serialization.deserialize(filename)
end

function deserialize_key(metadata::OptimizationContainerMetadata, name::AbstractString)
    !haskey(metadata.container_key_lookup, name) && error("$name is not stored")
    return metadata.container_key_lookup[name]
end

add_container_key!(x::OptimizationContainerMetadata, key, val) =
    x.container_key_lookup[key] = val
get_container_key(x::OptimizationContainerMetadata, key) = x.container_key_lookup[key]
has_container_key(x::OptimizationContainerMetadata, key) =
    haskey(x.container_key_lookup, key)

mutable struct OptimizationContainer <: AbstractModelContainer
    JuMPmodel::JuMP.Model
    time_steps::UnitRange{Int}
    resolution::Dates.TimePeriod
    settings::Settings
    settings_copy::Settings
    variables::Dict{VariableKey, AbstractArray}
    aux_variables::Dict{AuxVarKey, AbstractArray}
    duals::Dict{ConstraintKey, AbstractArray}
    constraints::Dict{ConstraintKey, AbstractArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::Dict{ExpressionKey, JuMP.Containers.DenseAxisArray}
    parameters::Dict{ParameterKey, ParameterContainer}
    initial_conditions::Dict{ICKey, Vector{<:InitialCondition}}
    initial_conditions_data::InitialConditionsData
    pm::Union{Nothing, PM.AbstractPowerModel}
    base_power::Float64
    solve_timed_log::Dict{Symbol, Any}
    built_for_recurrent_solves::Bool
    metadata::OptimizationContainerMetadata
    default_time_series_type::Type{<:PSY.TimeSeriesData}
end

function OptimizationContainer(
    sys::PSY.System,
    settings::Settings,
    jump_model::Union{Nothing, JuMP.Model},
    ::Type{T},
) where {T <: PSY.TimeSeriesData}
    resolution = PSY.get_time_series_resolution(sys)
    if isabstracttype(T)
        error("Default Time Series Type $V can't be abstract")
    end

    return OptimizationContainer(
        jump_model === nothing ? _make_jump_model(settings) :
        _finalize_jump_model!(jump_model, settings),
        1:1,
        IS.time_period_conversion(resolution),
        settings,
        copy_for_serialization(settings),
        Dict{VariableKey, AbstractArray}(),
        Dict{AuxVarKey, AbstractArray}(),
        Dict{ConstraintKey, AbstractArray}(),
        Dict{ConstraintKey, AbstractArray}(),
        zero(JuMP.GenericAffExpr{Float64, JuMP.VariableRef}),
        Dict{ExpressionKey, AbstractArray}(),
        Dict{ParameterKey, ParameterContainer}(),
        Dict{ICKey, Vector{InitialCondition}}(),
        InitialConditionsData(),
        nothing,
        PSY.get_base_power(sys),
        Dict{Symbol, Any}(),
        false,
        OptimizationContainerMetadata(),
        T,
    )
end

# This is broken with the addition of the default_time_series field
# function OptimizationContainer(filename::AbstractString)
#     return OptimizationContainer(
#         jump_model === nothing ? _make_jump_model(settings) :
#         _finalize_jump_model!(jump_model, settings),
#         1:1,
#         IS.time_period_conversion(resolution),
#         settings,
#         copy_for_serialization(settings),
#         Dict{VariableKey, AbstractArray}(),
#         Dict{AuxVarKey, AbstractArray}(),
#         Dict{ConstraintKey, AbstractArray}(),
#         Dict{ConstraintKey, AbstractArray}(),
#         Dict{String, OptimizationContainerKey}(),
#         zero(JuMP.GenericAffExpr{Float64, JuMP.VariableRef}),
#         Dict{ExpressionKey, AbstractArray}(),
#         Dict{ParameterKey, ParameterContainer}(),
#         Dict{ICKey, Vector{InitialCondition}}(),
#         nothing,
#         PSY.get_base_power(sys),
#         Dict{Symbol, Any}(),
#         false,
#         PSY.Deterministic,
#     )
# end

built_for_recurrent_solves(container::OptimizationContainer) =
    container.built_for_recurrent_solves

get_aux_variables(container::OptimizationContainer) = container.aux_variables
get_base_power(container::OptimizationContainer) = container.base_power
get_constraints(container::OptimizationContainer) = container.constraints
get_default_time_series_type(container::OptimizationContainer) =
    container.default_time_series_type
get_duals(container::OptimizationContainer) = container.duals
get_expressions(container::OptimizationContainer) = container.expressions
get_initial_conditions(container::OptimizationContainer) = container.initial_conditions
get_initial_time(container::OptimizationContainer) = get_initial_time(container.settings)
get_jump_model(container::OptimizationContainer) = container.JuMPmodel
get_metadata(container::OptimizationContainer) = container.metadata
get_parameters(container::OptimizationContainer) = container.parameters
get_resolution(container::OptimizationContainer) = container.resolution
get_settings(container::OptimizationContainer) = container.settings
get_time_steps(container::OptimizationContainer) = container.time_steps
get_variables(container::OptimizationContainer) = container.variables
get_initial_conditions_data(container::OptimizationContainer) =
    container.initial_conditions_data

function is_milp(container::OptimizationContainer)
    type_of_optimizer = typeof(container.JuMPmodel.moi_backend.optimizer.model)
    supports_milp = hasfield(type_of_optimizer, :last_solved_by_mip)
    !supports_milp && return false
    return container.JuMPmodel.moi_backend.optimizer.model.last_solved_by_mip
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

    if get_direct_mode_optimizer(settings)
        throw(
            IS.ConflictingInputsError(
                "Externally provided JuMP models are not compatible with the direct model keyword argument. Use JuMP.direct_model before passing the custom model",
            ),
        )
    end

    #if get_optimizer_log_print(settings)
    #    JuMP.unset_silent(JuMPmodel)
    #    @debug "optimizer unset to silent"
    #else
    #    JuMP.set_silent(JuMPmodel)
    #    @debug "optimizer set to silent"
    #end
    return JuMPmodel
end

function _prepare_jump_model_for_simulation!(JuMPmodel::JuMP.Model, settings::Settings)
    if !haskey(JuMPmodel.ext, :ParameterJuMP)
        @debug("Model doesn't have Parameters enabled. Parameters will be enabled")
        PJ.enable_parameters(JuMPmodel)
        JuMP.set_optimizer(JuMPmodel, optimizer)
    end
    return
end

function _make_jump_model(settings::Settings)
    @debug "Instantiating the JuMP model"
    optimizer = get_optimizer(settings)
    if get_direct_mode_optimizer(settings)
        JuMPmodel = JuMP.direct_model(MOI.instantiate(optimizer))
    elseif optimizer === nothing
        JuMPmodel = JuMP.Model()
        @debug "The optimization model has no optimizer attached"
    else
        JuMPmodel = JuMP.Model(optimizer)
    end
    _finalize_jump_model!(JuMPmodel, settings)

    return JuMPmodel
end

function init_optimization_container!(
    container::OptimizationContainer,
    ::Type{T},
    sys::PSY.System,
) where {T <: PM.AbstractPowerModel}
    @assert !(container.JuMPmodel === nothing)
    PSY.set_units_base_system!(sys, "SYSTEM_BASE")
    # The order of operations matter
    settings = get_settings(container)

    if get_initial_time(settings) == UNSET_INI_TIME
        if get_default_time_series_type(container) <: PSY.AbstractDeterministic
            set_initial_time!(settings, PSY.get_forecast_initial_timestamp(sys))
        elseif get_default_time_series_type(container) <: PSY.SingleTimeSeries
            ini_time, _ = PSY.check_time_series_consistency(sys, PSY.SingleTimeSeries)
            set_initial_time!(settings, ini_time)
        end
    end

    if get_horizon(settings) == UNSET_HORIZON
        set_horizon!(settings, PSY.get_forecast_horizon(sys))
    end

    total_number_of_devices = length(get_available_components(PSY.Device, sys))
    container.time_steps = 1:get_horizon(settings)

    # The 10e6 limit is based on the sizes of the lp benchmark problems http://plato.asu.edu/ftp/lpcom.html
    # The maximum numbers of constraints and variables in the benchmark problems is 1,918,399 and 1,259,121,
    # respectively. See also https://prod-ng.sandia.gov/techlib-noauth/access-control.cgi/2013/138847.pdf
    variable_count_estimate = length(container.time_steps) * total_number_of_devices

    if variable_count_estimate > 10e6
        @warn(
            "The estimated total number of variables that will be created in the model is $(variable_count_estimate). The total number of variables might be larger than 10e6 and could lead to large build or solve times."
        )
    end

    return
end

function add_to_setting_ext!(container::OptimizationContainer, key::String, value)
    settings = get_settings(container)
    push!(get_ext(settings), key => value)
    @debug "Add to settings ext" key value
    return
end

function check_optimization_container(container::OptimizationContainer)
    for (k, param_container) in container.parameters
        valid = !all(isnan.(param_container.multiplier_array.data))
        if !valid
            error("The model container has invalid values in $(encode_key_as_string(k))")
        end
    end
    return
end

function get_problem_size(container::OptimizationContainer)
    model = container.JuMPmodel
    vars = JuMP.num_variables(model)
    cons = 0
    for (exp, c_type) in JuMP.list_of_constraint_types(model)
        cons += JuMP.num_constraints(model, exp, c_type)
    end
    return "The current total number of variables is $(vars) and total number of constraints is $(cons)"
end

abstract type ConstructStage end
struct ArgumentConstructStage end
struct ModelConstructStage end

# This function is necessary while we switch from ParameterJuMP to POI
function _make_container_array(parameter_jump::Bool, ax...)
    if parameter_jump
        return JuMP.Containers.DenseAxisArray{PGAE}(undef, ax...)
    else
        return JuMP.Containers.DenseAxisArray{GAE}(undef, ax...)
    end
end

function _make_system_expressions!(
    container::OptimizationContainer,
    bus_numbers::Vector{Int},
    ::Type{<:PM.AbstractPowerModel},
)
    parameter_jump = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    container.expressions = Dict(
        ExpressionKey(ActivePowerBalance, PSY.Bus) =>
            _make_container_array(parameter_jump, bus_numbers, time_steps),
        ExpressionKey(ReactivePowerBalance, PSY.Bus) =>
            _make_container_array(parameter_jump, bus_numbers, time_steps),
    )
    return
end

function _make_system_expressions!(
    container::OptimizationContainer,
    bus_numbers::Vector{Int},
    ::Type{<:PM.AbstractActivePowerModel},
)
    parameter_jump = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    container.expressions = Dict(
        ExpressionKey(ActivePowerBalance, PSY.Bus) =>
            _make_container_array(parameter_jump, bus_numbers, time_steps),
    )
    return
end

function _make_system_expressions!(
    container::OptimizationContainer,
    ::Vector{Int},
    ::Type{CopperPlatePowerModel},
)
    parameter_jump = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    container.expressions = Dict(
        ExpressionKey(ActivePowerBalance, PSY.System) =>
            _make_container_array(parameter_jump, time_steps),
    )
    return
end

function _make_system_expressions!(
    container::OptimizationContainer,
    bus_numbers::Vector{Int},
    ::Type{T},
) where {T <: Union{PTDFPowerModel, StandardPTDFModel}}
    parameter_jump = built_for_recurrent_solves(container)
    time_steps = get_time_steps(container)
    container.expressions = Dict(
        ExpressionKey(ActivePowerBalance, PSY.System) =>
            _make_container_array(parameter_jump, time_steps),
        ExpressionKey(ActivePowerBalance, PSY.Bus) =>
            _make_container_array(parameter_jump, bus_numbers, time_steps),
    )
    return
end

function initialize_system_expressions!(
    container::OptimizationContainer,
    ::Type{T},
    system::PSY.System,
) where {T <: PM.AbstractPowerModel}
    bus_numbers = sort([PSY.get_number(b) for b in PSY.get_components(PSY.Bus, system)])
    _make_system_expressions!(container, bus_numbers, T)
    return
end

function build_impl!(container::OptimizationContainer, template, sys::PSY.System)
    transmission = get_network_formulation(template)
    transmission_model = get_network_model(template)

    initialize_system_expressions!(container, transmission, sys)

    # Order is required
    for device_model in values(template.devices)
        @debug "Building Arguments for $(get_component_type(device_model)) with $(get_formulation(device_model)) formulation" _group =
            :ConstructGroup
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(get_component_type(device_model))" begin
            if validate_available_devices(device_model, sys)
                construct_device!(
                    container,
                    sys,
                    ArgumentConstructStage(),
                    device_model,
                    transmission,
                )
            end
            @debug get_problem_size(container)
        end
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Services" begin
        construct_services!(
            container,
            sys,
            ArgumentConstructStage(),
            get_service_models(template),
            get_device_models(template),
        )
        #  TODO: Add dual variable container for services
    end

    for branch_model in values(template.branches)
        @debug "Building Arguments for $(get_component_type(branch_model)) with $(get_formulation(branch_model)) formulation" _group =
            :ConstructGroup
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(get_component_type(branch_model))" begin
            if validate_available_devices(branch_model, sys)
                construct_device!(
                    container,
                    sys,
                    ArgumentConstructStage(),
                    branch_model,
                    transmission_model,
                )
            end
            @debug get_problem_size(container)
        end
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Services" begin
        construct_services!(
            container,
            sys,
            ModelConstructStage(),
            get_service_models(template),
            get_device_models(template),
        )
    end

    for device_model in values(template.devices)
        @debug "Building Model for $(get_component_type(device_model)) with $(get_formulation(device_model)) formulation" _group =
            :ConstructGroup
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(get_component_type(device_model))" begin
            if validate_available_devices(device_model, sys)
                construct_device!(
                    container,
                    sys,
                    ModelConstructStage(),
                    device_model,
                    transmission,
                )
            end
            @debug get_problem_size(container)
        end
    end

    # This function should be called after construct_device ModelConstructStage
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(transmission)" begin
        @debug "Building $(transmission) network formulation"
        construct_network!(container, sys, transmission_model, template)
        @debug get_problem_size(container)
    end

    for branch_model in values(template.branches)
        @debug "Building Model for $(get_component_type(branch_model)) with $(get_formulation(branch_model)) formulation" _group =
            :ConstructGroup
        TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(get_component_type(branch_model))" begin
            if validate_available_devices(branch_model, sys)
                construct_device!(
                    container,
                    sys,
                    ModelConstructStage(),
                    branch_model,
                    transmission_model,
                )
            end
            @debug get_problem_size(container)
        end
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Objective" begin
        @debug "Building Objective"
        JuMP.@objective(container.JuMPmodel, MOI.MIN_SENSE, container.cost_function)
    end
    @debug "Total operation count $(container.JuMPmodel.operator_counter)"

    check_optimization_container(container)
    return
end

"""
Default solve method for OptimizationContainer
"""
function solve_impl!(
    container::OptimizationContainer,
    system::PSY.System,
    log::Dict{Symbol, Any},
)
    jump_model = get_jump_model(container)
    _, log[:timed_solve_time], log[:solve_bytes_alloc], log[:sec_in_gc] =
        @timed JuMP.optimize!(jump_model)
    model_status = JuMP.primal_status(jump_model)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        error("Optimizer returned $model_status")
    end

    _, log[:timed_calculate_aux_variables] =
        @timed calculate_aux_variables!(container, system)
    _, log[:timed_calculate_dual_variables] =
        @timed calculate_dual_variables!(container, system)
    # TODO: Run IIS here if supported by the solver
    return
end

function export_optimizer_stats(
    optimizer_stats::Dict{Symbol, Any},
    container::OptimizationContainer,
    path::String,
)
    optimizer_stats[:termination_status] = Int(JuMP.termination_status(container.JuMPmodel))
    optimizer_stats[:primal_status] = Int(JuMP.primal_status(container.JuMPmodel))
    optimizer_stats[:dual_status] = Int(JuMP.dual_status(container.JuMPmodel))

    if optimizer_stats[:primal_status] == MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        optimizer_stats[:obj_value] = JuMP.objective_value(container.JuMPmodel)
    else
        optimizer_stats[:obj_value] = Inf
    end

    try
        optimizer_stats[:solve_time] = MOI.get(container.JuMPmodel, MOI.SolveTime())
    catch
        @warn("SolveTime() property not supported by the Solver")
        optimizer_stats[:solve_time] = NaN # "Not Supported by solver"
    end
    write_optimizer_stats(optimizer_stats, path)
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function serialize_optimization_model(container::OptimizationContainer, save_path::String)
    MOF_model = MOPFM(format = MOI.FileFormats.FORMAT_MOF)
    MOI.copy_to(MOF_model, JuMP.backend(container.JuMPmodel))
    MOI.write_to_file(MOF_model, save_path)
    return
end

const _CONTAINER_METADATA_FILE = "optimization_container_metadata.bin"

_make_metadata_filename(output_dir) = joinpath(output_dir, _CONTAINER_METADATA_FILE)

function serialize_metadata!(container::OptimizationContainer, output_dir::String)
    for key in Iterators.flatten((
        keys(container.constraints),
        keys(container.duals),
        keys(container.parameters),
        keys(container.variables),
    ))
        encoded_key = encode_key_as_string(key)
        if has_container_key(container.metadata, encoded_key)
            # Constraints and Duals can store the same key.
            IS.@assert_op key == get_container_key(container.metadata, encoded_key)
        end
        add_container_key!(container.metadata, encoded_key, key)
    end

    filename = _make_metadata_filename(output_dir)
    Serialization.serialize(filename, container.metadata)
    @debug "Serialized container keys to $filename" _group = IS.LOG_GROUP_SERIALIZATION
end

function deserialize_metadata!(
    container::OptimizationContainer,
    output_dir::String,
    model_name,
)
    merge!(
        container.metadata.container_key_lookup,
        deserialize_metadata(OptimizationContainerMetadata, output_dir, model_name),
    )
    return
end

function _assign_container!(container::Dict, key::OptimizationContainerKey, value)
    if haskey(container, key)
        @error "$(encode_key(key)) is already stored" sort!(encode_key.(keys(container)))
        throw(IS.InvalidValue("$key is already stored"))
    end
    container[key] = value
    @debug "Added container entry $(typeof(key)) $(encode_key(key))" _group =
        LOG_GROUP_OPTIMZATION_CONTAINER
    return
end

####################################### Variable Container #################################
function _add_var_container!(
    container::OptimizationContainer,
    var_key::VariableKey{T, U},
    sparse::Bool,
    axs...,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    if sparse
        var_container = sparse_container_spec(JuMP.VariableRef, axs...)
    else
        var_container = container_spec(JuMP.VariableRef, axs...)
    end
    _assign_container!(container.variables, var_key, var_container)
    return var_container
end

function add_var_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    var_key = VariableKey(T, U)
    return _add_var_container!(container, var_key, sparse, axs...)
end

function add_var_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta::String,
    axs...;
    sparse = false,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    var_key = VariableKey(T, U, meta)
    return _add_var_container!(container, var_key, sparse, axs...)
end

function get_variable_keys(container::OptimizationContainer)
    return collect(keys(container.variables))
end

function get_variable(container::OptimizationContainer, key::VariableKey)
    var = get(container.variables, key, nothing)
    if var === nothing
        name = encode_key(key)
        keys = encode_key.(get_variable_keys(container))
        @error "$name is not stored" sort!(keys)
        throw(IS.InvalidValue("variable $name is not stored"))
    end
    return var
end

function get_variable(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    meta = remove_delimiter!(meta)
    return get_variable(container, VariableKey(T, U, meta))
end

function read_variables(container::OptimizationContainer)
    return Dict(k => axis_array_to_dataframe(v) for (k, v) in get_variables(container))
end

##################################### AuxVariable Container ################################
function add_aux_var_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: AuxVariableType, U <: PSY.Component}
    var_key = AuxVarKey(T, U)
    if sparse
        aux_var_container = sparse_container_spec(Float64, axs...)
    else
        aux_var_container = container_spec(Float64, axs...)
    end
    _assign_container!(container.aux_variables, var_key, aux_var_container)
    return aux_var_container
end

function get_aux_variable_keys(container::OptimizationContainer)
    return collect(keys(container.aux_variables))
end

function get_aux_variable(container::OptimizationContainer, key::AuxVarKey)
    aux = get(container.aux_variables, key, nothing)
    if aux === nothing
        name = encode_key(key)
        keys = encode_key.(get_variable_keys(container))
        @error "$name is not stored" sort!(keys)
        throw(IS.InvalidValue("Auxiliary variable $name is not stored"))
    end
    return aux
end

function get_aux_variable(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: AuxVariableType, U <: PSY.Component}
    return get_aux_variable(container, AuxVarKey(T, U, meta))
end

##################################### DualVariable Container ################################
function add_dual_container!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    if is_milp(container)
        @warn(
            "Current formulation has resulted in a MILP problem, dual value retrieval is not supported for MILP problems."
        )
    else
        const_key = ConstraintKey(T, U)
        if sparse
            dual_container = sparse_container_spec(Float64, axs...)
        else
            dual_container = container_spec(Float64, axs...)
        end
        _assign_container!(container.duals, const_key, dual_container)
        return dual_container
    end
    return
end

function get_dual_keys(container::OptimizationContainer)
    return collect(keys(container.duals))
end

##################################### Constraint Container #################################
function _add_cons_container!(
    container::OptimizationContainer,
    cons_key::ConstraintKey,
    axs...;
    sparse = false,
)
    if sparse
        cons_container = sparse_container_spec(JuMP.ConstraintRef, axs...)
    else
        cons_container = container_spec(JuMP.ConstraintRef, axs...)
    end
    _assign_container!(container.constraints, cons_key, cons_container)
    return cons_container
end

function add_cons_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    cons_key = ConstraintKey(T, U, meta)
    return _add_cons_container!(container, cons_key, axs...; sparse = sparse)
end

function get_constraint_keys(container::OptimizationContainer)
    return collect(keys(container.constraints))
end

function get_constraint(container::OptimizationContainer, key::ConstraintKey)
    var = get(container.constraints, key, nothing)
    if var === nothing
        name = encode_key(key)
        keys = encode_key.(get_constraint_keys(container))
        @error "$name is not stored" (keys)
        throw(IS.InvalidValue("constraint $name is not stored"))
    end

    return var
end

function get_constraint(
    container::OptimizationContainer,
    constraint_type::ConstraintType,
    meta = CONTAINER_KEY_EMPTY_META,
)
    return get_constraint(container, ConstraintKey(constraint_type, meta))
end

function get_constraint(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ConstraintType, U <: PSY.Component}
    return get_constraint(container, ConstraintKey(T, U, meta))
end

function read_duals(container::OptimizationContainer)
    return Dict(
        k => axis_array_to_dataframe(v, [encode_key(k)]) for (k, v) in get_duals(container)
    )
end

##################################### Parameter Container ##################################
function _add_param_container!(container::OptimizationContainer, key::ParameterKey, axs...)
    param_container = ParameterContainer(
        JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, axs...),
        fill!(JuMP.Containers.DenseAxisArray{Float64}(undef, axs...), 1.0),
    )
    _assign_container!(container.parameters, key, param_container)
    return param_container
end

function _add_param_container!(
    container::OptimizationContainer,
    key::ParameterKey{T, U},
    attribute::TimeSeriesAttributes{V},
    axs...,
) where {T <: TimeSeriesParameter, U <: PSY.Component, V <: PSY.TimeSeriesData}
    # Temporary while we change to POI vs PJ
    param_type = built_for_recurrent_solves(container) ? PJ.ParameterRef : Float64
    param_container = ParameterContainer(
        attribute,
        JuMP.Containers.DenseAxisArray{param_type}(undef, axs...),
        fill!(JuMP.Containers.DenseAxisArray{Float64}(undef, axs...), NaN),
    )
    _assign_container!(container.parameters, key, param_container)
    return param_container
end

function add_param_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    param_key = ParameterKey(T, U, meta)
    return _add_param_container!(container, param_key, axs...)
end

function add_param_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    ::Type{V},
    name::String,
    axs...;
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: TimeSeriesParameter, U <: PSY.Component, V <: PSY.TimeSeriesData}
    param_key = ParameterKey(T, U, meta)
    if isabstracttype(V)
        error("$V can't be abstract: $param_key")
    end
    attributes = TimeSeriesAttributes{V}(name)
    return _add_param_container!(container, param_key, attributes, axs...)
end

function get_parameter_keys(container::OptimizationContainer)
    return collect(keys(container.parameters))
end

function get_parameter(container::OptimizationContainer, key::ParameterKey)
    param_container = get(container.parameters, key, nothing)
    if param_container === nothing
        name = encode_key(key)
        keys = encode_key.(get_parameter_keys(container))
        @error "$name is not stored" keys
        throw(IS.InvalidValue("parameter $name is not stored"))
    end
    return param_container
end

function get_parameter(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_parameter(container, ParameterKey(T, U, meta))
end

function get_parameter_array(container::OptimizationContainer, key)
    return get_parameter_array(get_parameter(container, key))
end

function get_parameter_array(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_parameter_array(get_parameter(container, ParameterKey(T, U, meta)))
end

function get_parameter_multiplier_array(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_multiplier_array(get_parameter(container, ParameterKey(T, U, meta)))
end

function get_parameter_attributes(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_attributes(get_parameter(container, ParameterKey(T, U, meta)))
end

function iterate_parameter_containers(container::OptimizationContainer)
    Channel() do channel
        for param_container in values(container.parameters)
            put!(channel, param_container)
        end
    end
end

function read_parameters(container::OptimizationContainer)
    # TODO: Still not obvious implementation since it needs to get the multipliers from
    # the system
    params_dict = Dict{ParameterKey, DataFrames.DataFrame}()
    parameters = get_parameters(container)
    (isnothing(parameters) || isempty(parameters)) && return params_dict
    for (k, v) in parameters
        param_array = axis_array_to_dataframe(get_parameter_array(v))
        multiplier_array = axis_array_to_dataframe(get_multiplier_array(v))
        params_dict[k] = param_array .* multiplier_array
    end
    return params_dict
end

##################################### Expression Container #################################
function _add_expression_container!(
    container::OptimizationContainer,
    expr_key::ExpressionKey,
    axs...;
    sparse = false,
)
    if sparse
        expr_container = sparse_container_spec(JuMP.AbstractJuMPScalar, axs...)
    else
        expr_container = container_spec(JuMP.AbstractJuMPScalar, axs...)
    end
    _assign_container!(container.expressions, expr_key, expr_container)
    return expr_container
end

function add_expression_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}}
    expr_key = ExpressionKey(T, U, meta)
    return _add_expression_container!(container, expr_key, axs...; sparse = sparse)
end

function get_expression_keys(container::OptimizationContainer)
    return collect(keys(container.expressions))
end

function get_expression(container::OptimizationContainer, key::ExpressionKey)
    var = get(container.expressions, key, nothing)
    if var === nothing
        @error "$key is not stored" (get_expression_keys(container))
        throw(IS.InvalidValue("constraint $key is not stored"))
    end

    return var
end

function get_expression(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}}
    return get_expression(container, ExpressionKey(T, U, meta))
end

function has_expression(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ExpressionType, U <: Union{PSY.Component, PSY.System}}
    key = ExpressionKey(T, U, meta)
    var = get(container.expressions, key, nothing)
    if var === nothing
        return false
    end
    return true
end

# Special getter functions to handle system balance expressions
function get_expression(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: SystemBalanceExpressions, U <: PM.AbstractPowerModel}
    return get_expression(container, ExpressionKey(T, PSY.Bus, meta))
end

function get_expression(
    container::OptimizationContainer,
    ::T,
    ::Type{CopperPlatePowerModel},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: SystemBalanceExpressions}
    return get_expression(container, ExpressionKey(T, PSY.System, meta))
end

###################################Initial Conditions Containers############################
function _add_initial_condition_container!(
    container::OptimizationContainer,
    ic_key::ICKey{T, U},
    length_devices::Int,
) where {T <: InitialConditionType, U <: Union{PSY.Component, PSY.System}}
    if built_for_recurrent_solves(container)
        ini_conds = Vector{InitialCondition{T, PJ.ParameterRef}}(undef, length_devices)
    else
        ini_conds = Vector{InitialCondition{T, Float64}}(undef, length_devices)
    end
    _assign_container!(container.initial_conditions, ic_key, ini_conds)
    return ini_conds
end

function add_initial_condition_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs;
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: InitialConditionType, U <: Union{PSY.Component, PSY.System}}
    ic_key = ICKey(T, U, meta)
    @debug "add_initial_condition_container" ic_key
    return _add_initial_condition_container!(container, ic_key, length(axs))
end

function has_initial_condition(container::OptimizationContainer, key::ICKey)
    return haskey(container.initial_conditions, key)
end

function iterate_initial_condition(container::OptimizationContainer)
    return pairs(container.initial_conditions)
end

function get_initial_condition(
    container::OptimizationContainer,
    ::T,
    ::Type{D},
) where {T <: InitialConditionType, D <: PSY.Component}
    return get_initial_condition(container, ICKey(T, D))
end

function get_initial_condition(container::OptimizationContainer, key::ICKey)
    initial_conditions = get(container.initial_conditions, key, nothing)
    if initial_conditions === nothing
        throw(IS.InvalidValue("initial conditions are not stored for $(key)"))
    end
    return initial_conditions
end

function get_initial_conditions_keys(container::OptimizationContainer)
    return collect(keys(container.initial_conditions))
end

# TODO: This code is very simular to the in_memory_model_store function in line 100. Maybe we can do some consolidation
function write_initial_conditions_data(
    container::OptimizationContainer,
    ic_container::OptimizationContainer,
)
    for field in STORE_CONTAINERS
        ic_container_dict = getfield(ic_container, field)
        # TODO: Not ideal, clean up a bit more.
        if field == STORE_CONTAINER_PARAMETERS
            ic_container_dict = read_parameters(ic_container)
        end
        isempty(ic_container_dict) && continue
        ic_data_dict = getfield(get_initial_conditions_data(container), field)
        for (key, field_container) in ic_container_dict
            @debug "Adding $(encode_key_as_string(key)) to InitialConditionsData"
            if field == STORE_CONTAINER_PARAMETERS
                ic_data_dict[key] = ic_container_dict[key]
            else
                ic_data_dict[key] = axis_array_to_dataframe(field_container, nothing)
            end
        end
    end
    return
end

# TODO: These methods aren't passing the potential meta fields in the keys
function get_initial_conditions_variable(
    container::OptimizationContainer,
    type::VariableType,
    ::Type{T},
) where {T <: Union{PSY.Component, PSY.System}}
    return get_initial_conditions_variable(get_initial_conditions_data(container), type, T)
end

function get_initial_conditions_aux_variable(
    container::OptimizationContainer,
    type::AuxVariableType,
    ::Type{T},
) where {T <: Union{PSY.Component, PSY.System}}
    return get_initial_conditions_aux_variable(
        get_initial_conditions_data(container),
        type,
        T,
    )
end

function get_initial_conditions_dual(
    container::OptimizationContainer,
    type::ConstraintType,
    ::Type{T},
) where {T <: Union{PSY.Component, PSY.System}}
    return get_initial_conditions_dual(get_initial_conditions_data(container), type, T)
end

function get_initial_conditions_parameter(
    container::OptimizationContainer,
    type::ParameterType,
    ::Type{T},
) where {T <: Union{PSY.Component, PSY.System}}
    return get_initial_conditions_parameter(get_initial_conditions_data(container), type, T)
end

function add_to_objective_function!(container::OptimizationContainer, expr)
    JuMP.add_to_expression!(container.cost_function, expr)
end

function deserialize_key(container::OptimizationContainer, name::AbstractString)
    return deserialize_key(container.metadata, name)
end

function calculate_aux_variables!(container::OptimizationContainer, system::PSY.System)
    aux_vars = get_aux_variables(container)
    for key in keys(aux_vars)
        calculate_aux_variable_value!(container, key, system)
    end
    return
end

function calculate_dual_variables!(container::OptimizationContainer, system::PSY.System)
    duals_vars = get_duals(container)
    for key in keys(duals_vars)
        _calculate_dual_variable_value!(container, key, system)
    end
    return
end
