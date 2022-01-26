function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, Float64},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: InitialConditionType}
    ic_data = get_initial_conditions_data(container)
    var_type = initial_condition_variable(U(), component, V())
    if !has_initial_condition_value(ic_data, var_type, W)
        val = initial_condition_default(U(), component, V())
    else
        val = get_initial_condition_value(ic_data, var_type, W)[1, PSY.get_name(component)]
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, val)
end

function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, PJ.ParameterRef},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: InitialConditionType}
    ic_data = get_initial_conditions_data(container)
    var_type = initial_condition_variable(U(), component, V())
    if !has_initial_condition_value(ic_data, var_type, W)
        val = initial_condition_default(U(), component, V())
    else
        val = get_initial_condition_value(ic_data, var_type, W)[1, PSY.get_name(component)]
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, add_jump_parameter(get_jump_model(container), val))
end

function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, Float64},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: InitialTimeDurationOff}
    ic_data = get_initial_conditions_data(container)
    var_type = initial_condition_variable(U(), component, V())
    if !has_initial_condition_value(ic_data, var_type, W)
        val = initial_condition_default(U(), component, V())
    else
        var = get_initial_condition_value(ic_data, var_type, W)[1, PSY.get_name(component)]
        val = 0.0
        if !PSY.get_status(component) && !(var > ABSOLUTE_TOLERANCE)
            val = PSY.get_time_at_status(component)
        end
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, val)
end

function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, PJ.ParameterRef},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: InitialTimeDurationOff}
    ic_data = get_initial_conditions_data(container)
    var_type = initial_condition_variable(U(), component, V())
    if !has_initial_condition_value(ic_data, var_type, W)
        val = initial_condition_default(U(), component, V())
    else
        var = get_initial_condition_value(ic_data, var_type, W)[1, PSY.get_name(component)]
        val = 0.0
        if !PSY.get_status(component) && !(var > ABSOLUTE_TOLERANCE)
            val = PSY.get_time_at_status(component)
        end
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, add_jump_parameter(get_jump_model(container), val))
end

function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, Float64},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: InitialTimeDurationOn}
    ic_data = get_initial_conditions_data(container)
    var_type = initial_condition_variable(U(), component, V())
    if !has_initial_condition_value(ic_data, var_type, W)
        val = initial_condition_default(U(), component, V())
    else
        var = get_initial_condition_value(ic_data, var_type, W)[1, PSY.get_name(component)]
        val = 0.0
        if PSY.get_status(component) && (var > ABSOLUTE_TOLERANCE)
            val = PSY.get_time_at_status(component)
        end
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, val)
end

function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, PJ.ParameterRef},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: InitialTimeDurationOn}
    ic_data = get_initial_conditions_data(container)
    var_type = initial_condition_variable(U(), component, V())
    if !has_initial_condition_value(ic_data, var_type, W)
        val = initial_condition_default(U(), component, V())
    else
        var = get_initial_condition_value(ic_data, var_type, W)[1, PSY.get_name(component)]
        val = 0.0
        if PSY.get_status(component) && (var > ABSOLUTE_TOLERANCE)
            val = PSY.get_time_at_status(component)
        end
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, add_jump_parameter(get_jump_model(container), val))
end

function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, PJ.ParameterRef},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: Union{InitialEnergyLevel, InitialEnergyLevelUp, InitialEnergyLevelDown}}
    ic_data = get_initial_conditions_data(container)
    val = initial_condition_default(U(), component, V())
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, add_jump_parameter(get_jump_model(container), val))
end

function _get_initial_conditions_value(
    ::Vector{T},
    component::W,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, Float64},
    V <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    W <: PSY.Component,
} where {U <: Union{InitialEnergyLevel, InitialEnergyLevelUp, InitialEnergyLevelDown}}
    ic_data = get_initial_conditions_data(container)
    val = initial_condition_default(U(), component, V())
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        LOG_GROUP_BUILD_INITIAL_CONDITIONS
    return T(component, val)
end

function add_initial_condition!(
    container::OptimizationContainer,
    components::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::U,
    ::D,
) where {
    T <: PSY.Component,
    U <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    D <: InitialConditionType,
}
    ini_cond_vector = add_initial_condition_container!(container, D(), T, components)
    for (ix, component) in enumerate(components)
        ini_cond_vector[ix] =
            _get_initial_conditions_value(ini_cond_vector, component, D(), U(), container)
    end
end
