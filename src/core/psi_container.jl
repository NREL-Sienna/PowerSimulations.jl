
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
function _pass_abstract_jump(
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes},
    parameters::Bool,
    JuMPmodel::Union{JuMP.AbstractModel, Nothing},
)
    if !isnothing(JuMPmodel)
        if parameters
            if !haskey(JuMPmodel.ext, :params)
                @info("Model doesn't have Parameters enabled. Parameters will be enabled")
            end
            PJ.enable_parameters(JuMPmodel)
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

function _psi_container_init(
    bus_numbers::Vector{Int},
    jump_model::JuMP.AbstractModel,
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes},
    transmission::Type{S},
    time_steps::UnitRange{Int},
    resolution::Dates.TimePeriod,
    use_forecast_data::Bool,
    initial_time::Dates.DateTime,
    make_parameters_container::Bool,
    ini_con::InitialConditionsContainer,
) where {S <: PM.AbstractPowerModel}
    V = JuMP.variable_type(jump_model)
    psi_container = PSIContainer(
        jump_model,
        optimizer,
        time_steps,
        resolution,
        use_forecast_data,
        initial_time,
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
        ini_con,
        nothing,
    )
    return psi_container
end

mutable struct PSIContainer
    JuMPmodel::JuMP.AbstractModel
    optimizer_factory::Union{Nothing, JuMP.MOI.OptimizerWithAttributes}
    time_steps::UnitRange{Int}
    resolution::Dates.TimePeriod
    use_forecast_data::Bool
    initial_time::Dates.DateTime
    variables::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    parameters::Union{Nothing, ParametersContainer}
    initial_conditions::InitialConditionsContainer
    pm::Union{Nothing, PM.AbstractPowerModel}

    function PSIContainer(
        JuMPmodel::JuMP.AbstractModel,
        optimizer_factory::Union{Nothing, JuMP.MOI.OptimizerWithAttributes},
        time_steps::UnitRange{Int},
        resolution::Dates.TimePeriod,
        use_forecast_data::Bool,
        initial_time::Dates.DateTime,
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
            optimizer_factory,
            time_steps,
            resolution,
            use_forecast_data,
            initial_time,
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
    optimizer::Union{Nothing, JuMP.MOI.OptimizerWithAttributes};
    kwargs...,
) where {T <: PM.AbstractPowerModel}
    check_kwargs(kwargs, PSICONTAINER_ACCEPTED_KWARGS, "PSIContainer")
    PSY.check_forecast_consistency(sys)
    user_defined_model = get(kwargs, :JuMPmodel, nothing)
    ini_con = get(kwargs, :initial_conditions, InitialConditionsContainer())
    make_parameters_container = get(kwargs, :use_parameters, false)
    use_forecast_data = get(kwargs, :use_forecast_data, true)
    jump_model =
        _pass_abstract_jump(optimizer, make_parameters_container, user_defined_model)
    initial_time = get(kwargs, :initial_time, PSY.get_forecasts_initial_time(sys))

    if use_forecast_data
        horizon = get(kwargs, :horizon, PSY.get_forecasts_horizon(sys))
        time_steps = 1:horizon
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

    return _psi_container_init(
        bus_numbers,
        jump_model,
        optimizer,
        T,
        time_steps,
        resolution,
        use_forecast_data,
        initial_time,
        make_parameters_container,
        ini_con,
    )

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

function _encode_for_jump(::Type{T}, name1::AbstractString, name2::AbstractString) where {T}
    return Symbol(join((name1, name2, T), _JUMP_NAME_DELIMITER))
end

function _encode_for_jump(::Type{T}, name1::Symbol, name2::Symbol) where {T}
    return _encode_for_jump(T, string(name1), string(name2))
end

function _encode_for_jump(::Type{T}, name::AbstractString) where {T}
    return Symbol(join((name, T), _JUMP_NAME_DELIMITER))
end

function _encode_for_jump(::Type{T}, name::Symbol) where {T}
    return Symbol(join((string(name), T), _JUMP_NAME_DELIMITER))
end

function _encode_for_jump(name::AbstractString)
    return Symbol(name)
end

function _encode_for_jump(name::Symbol)
    return name
end

function decode_symbol(name::Symbol)
    return split(String(name),_JUMP_NAME_DELIMITER)
end

constraint_name(cons_type, device_type) = _encode_for_jump(device_type, cons_type)
constraint_name(cons_type) = _encode_for_jump(cons_type)
variable_name(var_type, device_type) = _encode_for_jump(device_type, var_type)
variable_name(var_type) = _encode_for_jump(var_type)

_variable_type(cm::PSIContainer) = JuMP.variable_type(cm.JuMPmodel)
model_time_steps(psi_container::PSIContainer) = psi_container.time_steps
model_resolution(psi_container::PSIContainer) = psi_container.resolution
model_has_parameters(psi_container::PSIContainer) = !isnothing(psi_container.parameters)
model_uses_forecasts(psi_container::PSIContainer) = psi_container.use_forecast_data
model_initial_time(psi_container::PSIContainer) = psi_container.initial_time
#Internal Variables, Constraints and Parameters accessors
get_variables(psi_container::PSIContainer) = psi_container.variables
get_constraints(psi_container::PSIContainer) = psi_container.constraints
get_parameters(psi_container::PSIContainer) = psi_container.parameters
get_expression(psi_container::PSIContainer, name::Symbol) = psi_container.expressions[name]
get_initial_conditions(psi_container::PSIContainer) = psi_container.initial_conditions

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
    container = _container_spec(psi_container.JuMPmodel, axs...)
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
    return get_parameter_container(psi_container, _encode_for_jump(T, name))
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
    )
    assign_parameter!(psi_container, container)
    return container.array
end

function iterate_parameter_containers(psi_container::PSIContainer)
    Channel() do channel
        for container in values(psi_container.parameters)
            put!(channel, container)
        end
    end
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
    _write_optimizer_log(optimizer_log, path)
    return
end

""" Exports the OpModel JuMP object in MathOptFormat"""
function _write_psi_container(psi_container::PSIContainer, save_path::String)
    MOF_model = MOPFM(format = MOI.FileFormats.FORMAT_MOF)
    MOI.copy_to(MOF_model, JuMP.backend(psi_container.JuMPmodel))
    MOI.write_to_file(MOF_model, save_path)
    return
end

function write_data(
    psi_container::PSIContainer,
    save_path::AbstractString,
    dual_con::Vector{Symbol};
    kwargs...,
)
    duals = Dict{Symbol, Any}()
    file_type = get(kwargs, :file_type, Feather)
    if file_type == Feather || file_type == CSV
        for c in dual_con
            v = get_constraint(psi_container, c)
            duals[c] = result_dataframe_duals(v)
        end
        for (k, v) in duals
            file_path = joinpath(save_path, "$(k)_dual.$(lowercase("$file_type"))")
            file_type.write(file_path, v)
        end
    end
    return
end
