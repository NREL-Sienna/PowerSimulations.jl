function _pass_abstract_jump(optimizer::Union{Nothing, JuMP.OptimizerFactory},
                              parameters::Bool,
                              JuMPmodel::Union{JuMP.AbstractModel,Nothing})
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
        @info("The optimization model has no optimizer attached")
    end
    @info("Instantiating the JuMP model")
    JuMPmodel = JuMP.Model(optimizer)
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

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64},
                                parameters::Bool) where {S<:PM.AbstractPowerModel}
    return DSDA(:nodal_balance_active =>  _make_container_array(V,
                                                                parameters,
                                                                bus_numbers,
                                                                time_steps),
                :nodal_balance_reactive => _make_container_array(V,
                                                                 parameters,
                                                                 bus_numbers,
                                                                 time_steps))
end

function _make_expressions_dict(transmission::Type{S},
                                V::DataType,
                                bus_numbers::Vector{Int64},
                                time_steps::UnitRange{Int64},
                                parameters::Bool) where {S<:PM.AbstractActivePowerModel}
    return DSDA(:nodal_balance_active =>  _make_container_array(V,
                                                                parameters,
                                                                bus_numbers,
                                                                time_steps))
end


function _psi_container_init(bus_numbers::Vector{Int64},
                        jump_model::JuMP.AbstractModel,
                        optimizer::Union{Nothing, JuMP.OptimizerFactory},
                        transmission::Type{S},
                        time_steps::UnitRange{Int64},
                        resolution::Dates.TimePeriod,
                        use_forecast_data::Bool,
                        initial_time::Dates.DateTime,
                        make_parameters_container::Bool,
                        ini_con::DICKDA) where {S<:PM.AbstractPowerModel}
    V = JuMP.variable_type(jump_model)
    psi_container = PSIContainer(jump_model,
                              optimizer,
                              time_steps,
                              resolution,
                              use_forecast_data,
                              initial_time,
                              DSDA(),
                              DSDA(),
                              zero(JuMP.GenericAffExpr{Float64, V}),
                              _make_expressions_dict(transmission,
                                                     V,
                                                     bus_numbers,
                                                     time_steps,
                                                     make_parameters_container),
                              make_parameters_container ? DRDA() : nothing,
                              ini_con,
                              nothing)
    return psi_container
end

mutable struct PSIContainer
    JuMPmodel::JuMP.AbstractModel
    optimizer_factory::Union{Nothing, JuMP.OptimizerFactory}
    time_steps::UnitRange{Int64}
    resolution::Dates.TimePeriod
    use_forecast_data::Bool
    initial_time::Dates.DateTime
    variables::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    cost_function::JuMP.AbstractJuMPScalar
    expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray}
    parameters::Union{Nothing, Dict{UpdateRef, JuMP.Containers.DenseAxisArray}}
    initial_conditions::DICKDA
    pm::Union{Nothing, PM.AbstractPowerModel}

    function PSIContainer(JuMPmodel::JuMP.AbstractModel,
                       optimizer_factory::Union{Nothing, JuMP.OptimizerFactory},
                       time_steps::UnitRange{Int64},
                       resolution::Dates.TimePeriod,
                       use_forecast_data::Bool,
                       initial_time::Dates.DateTime,
                       variables::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                       constraints::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                       cost_function::JuMP.AbstractJuMPScalar,
                       expressions::Dict{Symbol, JuMP.Containers.DenseAxisArray},
                       parameters::Union{Nothing, Dict{UpdateRef, JuMP.Containers.DenseAxisArray}},
                       initial_conditions::DICKDA,
                       pm::Union{Nothing, PM.AbstractPowerModel})
        resolution = IS.time_period_conversion(resolution)
        new(JuMPmodel,
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
            pm)
    end
end

function PSIContainer(::Type{T},
                   sys::PSY.System,
                   optimizer::Union{Nothing, JuMP.OptimizerFactory};
                   kwargs...) where {T<:PM.AbstractPowerModel}
    PSY.check_forecast_consistency(sys)
    user_defined_model = get(kwargs, :JuMPmodel, nothing)
    ini_con = get(kwargs, :initial_conditions, DICKDA())
    make_parameters_container = get(kwargs, :use_parameters, false)
    use_forecast_data = get(kwargs, :use_forecast_data, true)
    jump_model = _pass_abstract_jump(optimizer, make_parameters_container, user_defined_model)
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

    return _psi_container_init(bus_numbers,
                           jump_model,
                           optimizer,
                           T,
                           time_steps,
                           resolution,
                           use_forecast_data,
                           initial_time,
                           make_parameters_container,
                           ini_con)

end

function InitialCondition(psi_container::PSIContainer,
                          device::T,
                          access_ref::AbstractString,
                          value::Float64,
                          cache::Union{Nothing, Type{<:AbstractCache}}=nothing) where T <: PSY.Device
    if model_has_parameters(psi_container)
        return InitialCondition(device,
                                UpdateRef{JuMP.VariableRef}(access_ref, T),
                                PJ.add_parameter(psi_container.JuMPmodel, value),
                                cache)
    else
        if !hasfield(T, Symbol(access_ref))
            error("Device of type $T doesn't contain the field $access_ref")
        end
        return InitialCondition(device,
                                UpdateRef{T}(access_ref, T),
                                value,
                                cache)
    end

end

function has_initial_conditions(psi_container::PSIContainer, key::ICKey)
    return key in keys(psi_container.initial_conditions)
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

# Var_ref
function get_value(psi_container::PSIContainer, ref::UpdateRef{JuMP.VariableRef})
    return get_variable(psi_container, ref.access_ref)
end

# param_ref
function get_value(psi_container::PSIContainer, ref::UpdateRef{PJ.ParameterRef})
    for (k, v) in psi_container.parameters
        if k.access_ref == ref.access_ref
            return v
        end
    end

    throw(IS.InvalidValue("$(ref) is not stored"))
end


const JUMP_NAME_DELIMITER = "_"

function _encode_for_jump(name::AbstractString, ::Type{T}) where T
    return Symbol(join((name, string(T)), JUMP_NAME_DELIMITER))
end

function _encode_for_jump(name::AbstractString)
    return Symbol(name)
end

# Ideally, the next two functions can be deleted once all existing code is changed to call
# the form above.

function _encode_for_jump(name::Symbol, ::Type{T}) where T
    return _encode_for_jump(string(name), T)
end

function _encode_for_jump(name::Symbol)
    return name
end

"""
Returns two-element Tuple (name, device_type) if device type was encoded into the name
else one element Tuple with just the name.
"""
function _decode_from_jump(sym)
    return Tuple(split(string(sym), JUMP_NAME_DELIMITER))
end

constraint_name(cons_type, device_type) = _encode_for_jump(cons_type, device_type)
constraint_name(cons_type) = _encode_for_jump(cons_type)
variable_name(var_type, device_type) = _encode_for_jump(var_type, device_type)
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
get_parameters(psi_container::PSIContainer, param_reference::UpdateRef) = psi_container.parameters[param_reference]
get_expression(psi_container::PSIContainer, name::Symbol) = psi_container.expressions[name]
get_initial_conditions(psi_container::PSIContainer) = psi_container.initial_conditions

function get_variable(
    psi_container::PSIContainer,
    var_type::AbstractString,
    device_type::Type{<:PSY.Device},
)
    return get_variable(psi_container, variable_name(var_type, device_type))
end

function get_variable(psi_container::PSIContainer, var_type::AbstractString)
    return get_variable(psi_container, variable_name(var_type))
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

function set_variable!(
    psi_container::PSIContainer,
    variable_type::AbstractString,
    device_type::Type{<:PSY.Device},
    value,
)
    set_variable!(psi_container, variable_name(variable_type, device_type), value)
    return
end

function set_variable!(
    psi_container::PSIContainer,
    variable_type::AbstractString,
    value,
)
    set_variable!(psi_container, variable_name(variable_type), value)
    return
end

function set_variable!(psi_container::PSIContainer, name::Symbol, value)
    @debug "set_variable" name
    psi_container.variables[name] = value
    return
end

function add_var_container!(psi_container::PSIContainer, var_name::Symbol, axs...)
    container = _container_spec(psi_container.JuMPmodel, axs...)
    set_variable!(psi_container, var_name, container)
    return container
end

function get_constraint(
    psi_container::PSIContainer,
    constraint_type::AbstractString,
    device_type::Type{<:PSY.Device},
)
    return get_constraint(psi_container, constraint_name(constraint_type, device_type))
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

function set_constraint!(
    psi_container::PSIContainer,
    constraint_type::AbstractString,
    device_type::Type{<:PSY.Device},
    value,
)
    set_constraint!(psi_container, constraint_name(constraint_type, device_type), value)
    return
end

function set_constraint!(
    psi_container::PSIContainer,
    constraint_type::AbstractString,
    value,
)
    set_constraint!(psi_container, constraint_name(constraint_type), value)
    return
end

function set_constraint!(psi_container::PSIContainer, name::Symbol, value)
    @debug "set_constraint" name
    psi_container.constraints[name] = value
    return
end

function add_cons_container!(psi_container::PSIContainer, cons_name::Symbol, axs...)
    container = JuMPConstraintArray(undef, axs...)
    set_constraint!(psi_container, cons_name, container)
    return container
end

function get_parameter(psi_container::PSIContainer, ref::UpdateRef)
    parameter = get(psi_container.parameters, ref, nothing)
    if isnothing(parameter)
        @error "$ref is not stored" sort!(get_parameter_refs(psi_container))
        throw(IS.InvalidValue("parameter $ref is not stored"))
    end
        
    return parameter
end

function get_parameter_refs(psi_container::PSIContainer)
    return collect(keys(psi_container.parameters))
end

function set_parameter!(psi_container::PSIContainer, ref::UpdateRef, value)
    @debug "set_parameter" ref
    psi_container.parameters[ref] = value
    return
end

function add_param_container!(psi_container::PSIContainer, param_reference::UpdateRef, axs...)
    container = JuMP.Containers.DenseAxisArray{PJ.ParameterRef}(undef, axs...)
    set_parameter!(psi_container, param_reference, container)
    return container
end
