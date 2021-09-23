function _get_initialization_value(
    ::Vector{T},
    component::PSY.Component,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, Float64},
    V <: Union{
        AbstractDeviceFormulation,
        AbstractServiceFormulation,
    },
} where {U <: InitialConditionType}
    ic_data = get_initialization_data(container)
    var_type = initial_condition_variable(D(), component, U())
    if !has_initialization_variable(ic_data, var_type, T)
        val = initial_condition_default(D(), component, U())
    else
        val = initialization_variable(ic_data, var_type, T)[1, PSY.get_name(component)]
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        :ConstructGroup
    return T(component, val)
end

function _get_initialization_value(
    ::Vector{T},
    component::PSY.Component,
    ::U,
    ::V,
    container::OptimizationContainer,
) where {
    T <: InitialCondition{U, PJ.ParameterRef},
    V <: Union{
        AbstractDeviceFormulation,
        AbstractServiceFormulation,
    },
} where {U <: InitialConditionType}
    ic_data = get_initialization_data(container)
    var_type = initial_condition_variable(D(), component, U())
    if !has_initialization_value(ic_data, var_type, T)
        val = initial_condition_default(D(), component, U())
    else
        val = get_initialization_value(ic_data, var_type, T)[1, PSY.get_name(component)]
    end
    @debug "Device $(PSY.get_name(component)) initialized DeviceStatus as $var_type" _group =
        :ConstructGroup
    return T(component, add_jump_parameter(get_jump_model(container), val))
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
            _get_initialization_value(ini_cond_vector, component, D(), U(), container)
    end
end
