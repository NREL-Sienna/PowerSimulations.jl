"""
Container for the initial condition data
"""
mutable struct InitialCondition{
    T <: IS.InitialConditionType,
    U <: Union{JuMP.VariableRef, Float64},
}
    component::PSY.Component
    value::U
end

function InitialCondition(
    ::Type{T},
    component::PSY.Component,
    value::U,
) where {T <: IS.InitialConditionType, U <: Union{JuMP.VariableRef, Float64}}
    return InitialCondition{T, U}(component, value)
end

function InitialCondition(
    ::IS.ICKey{T, U},
    component::U,
    value::V,
) where {
    T <: IS.InitialConditionType,
    U <: PSY.Component,
    V <: Union{JuMP.VariableRef, Float64},
}
    return InitialCondition{T, U}(component, value)
end

function get_condition(p::InitialCondition{T, Float64}) where {T <: IS.InitialConditionType}
    return p.value
end

function get_condition(
    p::InitialCondition{T, JuMP.VariableRef},
) where {T <: IS.InitialConditionType}
    return jump_value(p.value)
end

get_component(ic::InitialCondition) = ic.component
get_value(ic::InitialCondition) = ic.value
get_component_name(ic::InitialCondition) = PSY.get_name(ic.component)
get_component_type(ic::InitialCondition) = typeof(ic.component)
get_ic_type(
    ::Type{InitialCondition{T, U}},
) where {T <: IS.InitialConditionType, U <: Union{JuMP.VariableRef, Float64}} = T
get_ic_type(
    ::InitialCondition{T, U},
) where {T <: IS.InitialConditionType, U <: Union{JuMP.VariableRef, Float64}} = T

"""
Stores data to populate initial conditions before the build call
"""
mutable struct InitialConditionsData
    duals::Dict{IS.ConstraintKey, DataFrames.DataFrame}
    parameters::Dict{IS.ParameterKey, DataFrames.DataFrame}
    variables::Dict{IS.VariableKey, DataFrames.DataFrame}
    aux_variables::Dict{IS.AuxVarKey, DataFrames.DataFrame}
end

function InitialConditionsData()
    return InitialConditionsData(
        Dict{IS.ConstraintKey, DataFrames.DataFrame}(),
        Dict{IS.ParameterKey, DataFrames.DataFrame}(),
        Dict{IS.VariableKey, DataFrames.DataFrame}(),
        Dict{IS.AuxVarKey, DataFrames.DataFrame}(),
    )
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.VariableType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.variables[IS.VariableKey(T, U)]
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.aux_variables[IS.AuxVarKey(T, U)]
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.duals[IS.ConstraintKey(T, U)]
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.ParameterType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.parameters[IS.ParameterKey(T, U)]
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.VariableType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.variables, IS.VariableKey(T, U))
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.aux_variables, IS.AuxVarKey(T, U))
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.duals, IS.ConstraintKey(T, U))
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: IS.ParameterType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.parameters, IS.ParameterKey(T, U))
end

######################### Initial Conditions Definitions#####################################
struct DevicePower <: IS.InitialConditionType end
struct DeviceAboveMinPower <: IS.InitialConditionType end
struct DeviceStatus <: IS.InitialConditionType end
struct InitialTimeDurationOn <: IS.InitialConditionType end
struct InitialTimeDurationOff <: IS.InitialConditionType end
struct InitialEnergyLevel <: IS.InitialConditionType end
struct AreaControlError <: IS.InitialConditionType end
