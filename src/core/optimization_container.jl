"Optimization Container construction stage"
abstract type ConstructStage end

struct ArgumentConstructStage <: ConstructStage end
struct ModelConstructStage <: ConstructStage end

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
    filename = _make_metadata_filename(model_name, output_dir)
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
    expressions::Dict{ExpressionKey, AbstractArray}
    parameters::Dict{ParameterKey, ParameterContainer}
    initial_conditions::Dict{ICKey, Vector{<:InitialCondition}}
    initial_conditions_data::InitialConditionsData
    pm::Union{Nothing, PM.AbstractPowerModel}
    base_power::Float64
    optimizer_stats::OptimizerStats
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

    if jump_model !== nothing && get_direct_mode_optimizer(settings)
        throw(
            IS.ConflictingInputsError(
                "Externally provided JuMP models are not compatible with the direct model keyword argument. Use JuMP.direct_model before passing the custom model",
            ),
        )
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
        OptimizerStats(),
        false,
        OptimizationContainerMetadata(),
        T,
    )
end

# TODO: This constructor need to be re-enabled for the deserialization of OptimizationContainer from JSON
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
#         OptimizerStats(),
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
set_initial_conditions_data!(container::OptimizationContainer, data) =
    container.initial_conditions_data = data
get_optimizer_stats(container::OptimizationContainer) = container.optimizer_stats

function is_milp(container::OptimizationContainer)::Bool
    !supports_milp(container) && return false
    if !isempty(
        JuMP.all_constraints(container.JuMPmodel, JuMP.VariableRef, JuMP.MOI.ZeroOne),
    )
        return true
    end
    return false
end

function supports_milp(container::OptimizationContainer)
    jump_model = get_jump_model(container)
    optimizer_model = jump_model.moi_backend.optimizer.model
    return MOI.supports_constraint(optimizer_model, MOI.VariableIndex, MOI.ZeroOne)
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
    if get_optimizer_solve_log_print(settings)
        JuMP.unset_silent(JuMPmodel)
        @debug "optimizer unset to silent" _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    else
        JuMP.set_silent(JuMPmodel)
        @debug "optimizer set to silent" _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    end
    return JuMPmodel
end

function _prepare_jump_model_for_simulation!(JuMPmodel::JuMP.Model, settings::Settings)
    if !haskey(JuMPmodel.ext, :ParameterJuMP)
        @debug "Model doesn't have Parameters enabled. Parameters will be enabled" _group =
            LOG_GROUP_OPTIMIZATION_CONTAINER
        PJ.enable_parameters(JuMPmodel)
        JuMP.set_optimizer(JuMPmodel, optimizer)
    end
    return
end

function _make_jump_model(settings::Settings)
    @debug "Instantiating the JuMP model" _group = LOG_GROUP_OPTIMIZATION_CONTAINER
    optimizer = get_optimizer(settings)
    if get_direct_mode_optimizer(settings)
        JuMPmodel = JuMP.direct_model(MOI.instantiate(optimizer))
    elseif optimizer === nothing
        JuMPmodel = JuMP.Model()
        @debug "The optimization model has no optimizer attached" _group =
            LOG_GROUP_OPTIMIZATION_CONTAINER
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
    @assert container.JuMPmodel !== nothing
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

    stats = get_optimizer_stats(container)
    stats.detailed_stats = get_detailed_optimizer_stats(settings)

    return
end

function add_to_setting_ext!(container::OptimizationContainer, key::String, value)
    settings = get_settings(container)
    push!(get_ext(settings), key => value)
    @debug "Add to settings ext" key value _group = LOG_GROUP_OPTIMIZATION_CONTAINER
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

# This function is necessary while we switch from ParameterJuMP to POI
function _make_container_array(parameter_jump::Bool, ax...)
    if parameter_jump
        return remove_undef!(JuMPDArray{PGAE}(undef, ax...))
    else
        return remove_undef!(JuMPDArray{GAE}(undef, ax...))
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
            LOG_GROUP_OPTIMIZATION_CONTAINER
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
            @debug "Problem size:" get_problem_size(container) _group =
                LOG_GROUP_OPTIMIZATION_CONTAINER
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
    end

    for branch_model in values(template.branches)
        @debug "Building Arguments for $(get_component_type(branch_model)) with $(get_formulation(branch_model)) formulation" _group =
            LOG_GROUP_OPTIMIZATION_CONTAINER
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
            @debug "Problem size:" get_problem_size(container) _group =
                LOG_GROUP_OPTIMIZATION_CONTAINER
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
            LOG_GROUP_OPTIMIZATION_CONTAINER
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
            @debug "Problem size:" get_problem_size(container) _group =
                LOG_GROUP_OPTIMIZATION_CONTAINER
        end
    end

    # This function should be called after construct_device ModelConstructStage
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "$(transmission)" begin
        @debug "Building $(transmission) network formulation" _group =
            LOG_GROUP_OPTIMIZATION_CONTAINER
        construct_network!(container, sys, transmission_model, template)
        @debug "Problem size:" get_problem_size(container) _group =
            LOG_GROUP_OPTIMIZATION_CONTAINER
    end

    for branch_model in values(template.branches)
        @debug "Building Model for $(get_component_type(branch_model)) with $(get_formulation(branch_model)) formulation" _group =
            LOG_GROUP_OPTIMIZATION_CONTAINER
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
            @debug "Problem size:" get_problem_size(container) _group =
                LOG_GROUP_OPTIMIZATION_CONTAINER
        end
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "Objective" begin
        @debug "Building Objective" _group = LOG_GROUP_OPTIMIZATION_CONTAINER
        JuMP.@objective(container.JuMPmodel, MOI.MIN_SENSE, container.cost_function)
    end
    @debug "Total operation count $(container.JuMPmodel.operator_counter)" _group =
        LOG_GROUP_OPTIMIZATION_CONTAINER

    check_optimization_container(container)

    return
end

"""
Default solve method for OptimizationContainer
"""
function solve_impl!(container::OptimizationContainer, system::PSY.System)
    optimizer_stats = get_optimizer_stats(container)

    jump_model = get_jump_model(container)
    _,
    optimizer_stats.timed_solve_time,
    optimizer_stats.solve_bytes_alloc,
    optimizer_stats.sec_in_gc = @timed JuMP.optimize!(jump_model)
    model_status = JuMP.primal_status(jump_model)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        @error "Optimizer returned $model_status"
        return RunStatus.FAILED
    end

    status = RunStatus.SUCCESSFUL

    _, optimizer_stats.timed_calculate_aux_variables =
        @timed calculate_aux_variables!(container, system)
    _, optimizer_stats.timed_calculate_dual_variables = @timed calculate_dual_variables!(
        container,
        system,
        Base.RefValue{is_milp(container)},
    )
    return status
end

function compute_conflict!(container::OptimizationContainer)
    jump_model = get_jump_model(container)
    JuMP.unset_silent(jump_model)
    jump_model.is_model_dirty = false
    conflict = Dict{Symbol, Array}()
    try
        JuMP.compute_conflict!(jump_model)
    catch e
        @error "Can't compute conflict, check that your optimizer supports conflict refining/IIS" exception =
            (e, catch_backtrace())
        return conflict
    end

    if MOI.get(jump_model, MOI.ConflictStatus()) != MOI.CONFLICT_FOUND
        @error "No conflict could be found for the model. $(MOI.get(jump_model, MOI.ConflictStatus()))"
    end

    for (key, field_container) in get_constraints(container)
        conflict_indices = check_conflict_status(jump_model, field_container)
        if isempty(conflict_indices)
            continue
        else
            conflict[encode_key(key)] = conflict_indices
        end
    end

    #TODO: Serialize the conflict to file

    return conflict
end

function write_optimizer_stats!(container::OptimizationContainer)
    write_optimizer_stats!(get_optimizer_stats(container), get_jump_model(container))
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function serialize_optimization_model(container::OptimizationContainer, save_path::String)
    serialize_optimization_model(get_jump_model(container), save_path)
    return
end

const _CONTAINER_METADATA_FILE = "optimization_container_metadata.bin"

_make_metadata_filename(model_name::Symbol, output_dir) =
    joinpath(output_dir, string(model_name), _CONTAINER_METADATA_FILE)
_make_metadata_filename(output_dir) = joinpath(output_dir, _CONTAINER_METADATA_FILE)

function serialize_metadata!(container::OptimizationContainer, output_dir::String)
    for key in Iterators.flatten((
        keys(container.constraints),
        keys(container.duals),
        keys(container.parameters),
        keys(container.variables),
        keys(container.aux_variables),
        keys(container.expressions),
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
function _add_variable_container!(
    container::OptimizationContainer,
    var_key::VariableKey{T, U},
    sparse::Bool,
    axs...,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    if sparse
        var_container = sparse_container_spec(Float64, axs...)
        # We initialize sparse containers with Float64, not ideal and introduces type instability,
        # because JuMP.Containers.SparseAxisArrays can't be initialized with undef
    else
        var_container = container_spec(JuMP.VariableRef, axs...)
    end
    _assign_container!(container.variables, var_key, var_container)
    return var_container
end

function add_variable_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    var_key = VariableKey(T, U)
    return _add_variable_container!(container, var_key, sparse, axs...)
end

function add_variable_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta::String,
    axs...;
    sparse = false,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    var_key = VariableKey(T, U, meta)
    return _add_variable_container!(container, var_key, sparse, axs...)
end

function get_variable_keys(container::OptimizationContainer)
    return collect(keys(container.variables))
end

function get_variable(container::OptimizationContainer, key::VariableKey)
    var = get(container.variables, key, nothing)
    if var === nothing
        name = encode_key(key)
        keys = encode_key.(get_variable_keys(container))
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
    return get_variable(container, VariableKey(T, U, meta))
end

function read_variables(container::OptimizationContainer)
    return Dict(k => axis_array_to_dataframe(v) for (k, v) in get_variables(container))
end

##################################### AuxVariable Container ################################
function add_aux_variable_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
) where {T <: AuxVariableType, U <: PSY.Component}
    var_key = AuxVarKey(T, U)
    if sparse
        aux_variable_container = sparse_container_spec(Float64, axs...)
    else
        aux_variable_container = container_spec(Float64, axs...)
    end
    _assign_container!(container.aux_variables, var_key, aux_variable_container)
    return aux_variable_container
end

function get_aux_variable_keys(container::OptimizationContainer)
    return collect(keys(container.aux_variables))
end

function get_aux_variable(container::OptimizationContainer, key::AuxVarKey)
    aux = get(container.aux_variables, key, nothing)
    if aux === nothing
        name = encode_key(key)
        keys = encode_key.(get_variable_keys(container))
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
        @warn("The model has resulted in a MILP, \n
              dual value retrieval requires solving an additional Linear Program \n
              which increases simulation time and the results could be innacurate.")
    end
    const_key = ConstraintKey(T, U)
    if sparse
        dual_container = sparse_container_spec(Float64, axs...)
    else
        dual_container = container_spec(Float64, axs...)
    end
    _assign_container!(container.duals, const_key, dual_container)
    return dual_container
end

function get_dual_keys(container::OptimizationContainer)
    return collect(keys(container.duals))
end

##################################### Constraint Container #################################
function _add_constraints_container!(
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

function add_constraints_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    cons_key = ConstraintKey(T, U, meta)
    return _add_constraints_container!(container, cons_key, axs...; sparse = sparse)
end

function get_constraint_keys(container::OptimizationContainer)
    return collect(keys(container.constraints))
end

function get_constraint(container::OptimizationContainer, key::ConstraintKey)
    var = get(container.constraints, key, nothing)
    if var === nothing
        name = encode_key(key)
        keys = encode_key.(get_constraint_keys(container))
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
function _add_param_container!(
    container::OptimizationContainer,
    key::ParameterKey{T, U},
    attribute::VariableValueAttributes{<:OptimizationContainerKey},
    axs...,
) where {T <: VariableValueParameter, U <: PSY.Component}
    # Temporary while we change to POI vs PJ
    param_type = built_for_recurrent_solves(container) ? PJ.ParameterRef : Float64
    param_container = ParameterContainer(
        attribute,
        JuMPDArray{param_type}(undef, axs...),
        fill!(JuMPDArray{Float64}(undef, axs...), NaN),
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
        JuMPDArray{param_type}(undef, axs...),
        fill!(JuMPDArray{Float64}(undef, axs...), NaN),
    )
    _assign_container!(container.parameters, key, param_container)
    return param_container
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

function add_param_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    source_key::V,
    axs...;
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableValueParameter, U <: PSY.Component, V <: OptimizationContainerKey}
    param_key = ParameterKey(T, U, meta)
    attributes = VariableValueAttributes(source_key)
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
    key::ParameterKey{T, U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_parameter_array(get_parameter(container, key))
end

function get_parameter_multiplier_array(
    container::OptimizationContainer,
    key::ParameterKey{T, U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_multiplier_array(get_parameter(container, key))
end

function get_parameter_attributes(
    container::OptimizationContainer,
    key::ParameterKey{T, U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_attributes(get_parameter(container, key))
end

function get_parameter_array(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return get_parameter_array(container, ParameterKey(T, U, meta))
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
    (parameters === nothing || isempty(parameters)) && return params_dict
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
    ::Type{T},
    axs...;
    sparse = false,
) where {T <: JuMP.AbstractJuMPScalar}
    if sparse
        expr_container = sparse_container_spec(T, axs...)
    else
        expr_container = container_spec(T, axs...)
    end
    remove_undef!(expr_container)
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
    expr_type = built_for_recurrent_solves(container) ? PGAE : GAE
    return _add_expression_container!(
        container,
        expr_key,
        expr_type,
        axs...;
        sparse = sparse,
    )
end

function add_expression_container!(
    container::OptimizationContainer,
    ::T,
    ::Type{U},
    axs...;
    sparse = false,
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: ProductionCostExpression, U <: Union{PSY.Component, PSY.System}}
    expr_key = ExpressionKey(T, U, meta)
    expr_type = JuMP.QuadExpr
    return _add_expression_container!(
        container,
        expr_key,
        expr_type,
        axs...;
        sparse = sparse,
    )
end

function get_expression_keys(container::OptimizationContainer)
    return collect(keys(container.expressions))
end

function get_expression(container::OptimizationContainer, key::ExpressionKey)
    var = get(container.expressions, key, nothing)
    if var === nothing
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
    ::Type{T},
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

function read_expressions(container::OptimizationContainer)
    return Dict(
        k => axis_array_to_dataframe(v) for (k, v) in get_expressions(container) if
        !(get_entry_type(k) <: SystemBalanceExpressions)
    )
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
    @debug "add_initial_condition_container" ic_key _group = LOG_GROUP_SERVICE_CONSTUCTORS
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

# TODO: This code is very similar to the in_memory_model_store function in line 100. Maybe we can do some consolidation
function write_initial_conditions_data(
    container::OptimizationContainer,
    ic_container::OptimizationContainer,
)
    for field in STORE_CONTAINERS
        ic_container_dict = getfield(ic_container, field)
        if field == STORE_CONTAINER_PARAMETERS
            ic_container_dict = read_parameters(ic_container)
        end
        if field == STORE_CONTAINER_EXPRESSIONS
            continue
        end
        isempty(ic_container_dict) && continue
        ic_data_dict = getfield(get_initial_conditions_data(container), field)
        for (key, field_container) in ic_container_dict
            @debug "Adding $(encode_key_as_string(key)) to InitialConditionsData" _group =
                LOG_GROUP_SERVICE_CONSTUCTORS
            if field == STORE_CONTAINER_PARAMETERS
                ic_data_dict[key] = ic_container_dict[key]
            else
                ic_data_dict[key] = axis_array_to_dataframe(field_container, ["System"])
            end
        end
    end
    return
end

# Note: These methods aren't passing the potential meta fields in the keys
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
    return RunStatus.SUCCESSFUL
end

function _calculate_dual_variable_value!(
    container::OptimizationContainer,
    key::ConstraintKey{CopperPlateBalanceConstraint, PSY.System},
    ::PSY.System,
)
    constraint_container = get_constraint(container, key)
    dual_variable_container = get_duals(container)[key]

    for t in axes(constraint_container)[1]
        # See https://jump.dev/JuMP.jl/stable/manual/solutions/#Dual-solution-values
        dual_variable_container[t] = JuMP.dual(constraint_container[t])
    end
    return
end

function _calculate_dual_variable_value!(
    container::OptimizationContainer,
    key::ConstraintKey{T, D},
    ::PSY.System,
) where {T <: ConstraintType, D <: Union{PSY.Component, PSY.System}}
    constraint_container = get_constraint(container, key)
    dual_variable_container = get_duals(container)[key]

    dims = axes(constraint_container)
    for index in Iterators.product(dims...)
        dual_variable_container[index...] = JuMP.dual(constraint_container[index...])
    end
    return
end

function calculate_dual_variables!(
    container::OptimizationContainer,
    system::PSY.System,
    ::Type{Base.RefValue{false}},
)
    duals_vars = get_duals(container)
    for key in keys(duals_vars)
        _calculate_dual_variable_value!(container, key, system)
    end
    return
end

function _process_duals(container::OptimizationContainer)
    mip_solution = Dict(v => value(v) for v in all_variables(model))
    cache = Dict{VariableRef, Tuple{Float64, Float64, Bool}}()
    for x in all_variables(model)
        is_integer_flag = false
        if is_binary(x)
            unset_binary(x)
        elseif is_integer(x)
            unset_integer(x)
            is_integer_flag = true
        else
            continue
        end
        cache[x] = (
            has_lower_bound(x) ? lower_bound(x) : -Inf,
            has_upper_bound(x) ? upper_bound(x) : Inf,
            is_integer_flag,
        )
        fix(x, mip_solution[x]; force = true)
    end
    set_optimizer(model, lp_solver)
    optimize!(model)

    model_status = JuMP.dual_status(jump_model)
    if model_status != MOI.FEASIBLE_POINT::MOI.ResultStatusCode
        @error "Optimizer returned $model_status"
        return RunStatus.FAILED
    end

    if JuMP.has_duals(jump_model)
        duals = missing  # use shadow_price See https://jump.dev/JuMP.jl/stable/manual/solutions/#Dual-solution-values
    end

    for (x, c) in cache
        unfix(x)
        if c[1] == -Inf
            delete_lower_bound(x, c[1])
        else
            set_lower_bound(x, c[1])
        end
        if c[2] == Inf
            delete_upper_bound(x, c[2])
        else
            set_upper_bound(x, c[2])
        end
        if c[3]
            set_integer(x)
        else
            set_binnary(x)
        end
    end
    return duals
end

function calculate_dual_variables!(
    container::OptimizationContainer,
    system::PSY.System,
    ::Type{Base.RefValue{true}},
)
    isempty(get_duals(container)) && return

    status = _process_duals(container)
    return
end

########################### Helper Functions to get keys ###################################
function get_optimization_container_key(
    ::T,
    ::Type{U},
    meta::String,
) where {T <: AuxVariableType, U <: PSY.Component}
    return AuxVariableKey(T, U, meta)
end

function get_optimization_container_key(
    ::T,
    ::Type{U},
    meta::String,
) where {T <: VariableType, U <: PSY.Component}
    return VariableKey(T, U, meta)
end

function get_optimization_container_key(
    ::T,
    ::Type{U},
    meta::String,
) where {T <: ParameterType, U <: PSY.Component}
    return ParameterKey(T, U, meta)
end

function get_optimization_container_key(
    ::T,
    ::Type{U},
    meta::String,
) where {T <: ConstraintType, U <: PSY.Component}
    return ConstraintKey(T, U, meta)
end
