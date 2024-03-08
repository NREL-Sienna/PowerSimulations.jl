"""
Container for the initial condition data
"""
mutable struct InitialCondition{
    T <: InitialConditionType,
    U <: Union{JuMP.VariableRef, Float64},
}
    component::PSY.Component
    value::U
end

function InitialCondition(
    ::Type{T},
    component::PSY.Component,
    value::U,
) where {T <: InitialConditionType, U <: Union{JuMP.VariableRef, Float64}}
    return InitialCondition{T, U}(component, value)
end

function InitialCondition(
    ::InitialConditionKey{T, U},
    component::U,
    value::V,
) where {
    T <: InitialConditionType,
    U <: PSY.Component,
    V <: Union{JuMP.VariableRef, Float64},
}
    return InitialCondition{T, U}(component, value)
end

function get_condition(p::InitialCondition{T, Float64}) where {T <: InitialConditionType}
    return p.value
end

function get_condition(
    p::InitialCondition{T, JuMP.VariableRef},
) where {T <: InitialConditionType}
    return jump_value(p.value)
end

get_component(ic::InitialCondition) = ic.component
get_value(ic::InitialCondition) = ic.value
get_component_name(ic::InitialCondition) = PSY.get_name(ic.component)
get_component_type(ic::InitialCondition) = typeof(ic.component)
get_ic_type(
    ::Type{InitialCondition{T, U}},
) where {T <: InitialConditionType, U <: Union{JuMP.VariableRef, Float64}} = T
get_ic_type(
    ::InitialCondition{T, U},
) where {T <: InitialConditionType, U <: Union{JuMP.VariableRef, Float64}} = T

"""
Stores data to populate initial conditions before the build call
"""
mutable struct InitialConditionsData
    duals::Dict{ConstraintKey, DataFrames.DataFrame}
    parameters::Dict{ParameterKey, DataFrames.DataFrame}
    variables::Dict{VariableKey, DataFrames.DataFrame}
    aux_variables::Dict{AuxVarKey, DataFrames.DataFrame}
end

function InitialConditionsData()
    return InitialConditionsData(
        Dict{ConstraintKey, DataFrames.DataFrame}(),
        Dict{ParameterKey, DataFrames.DataFrame}(),
        Dict{VariableKey, DataFrames.DataFrame}(),
        Dict{AuxVarKey, DataFrames.DataFrame}(),
    )
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.variables[VariableKey(T, U)]
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.aux_variables[AuxVarKey(T, U)]
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.duals[ConstraintKey(T, U)]
end

function get_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return ic_data.parameters[ParameterKey(T, U)]
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.variables, VariableKey(T, U))
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: AuxVariableType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.aux_variables, AuxVarKey(T, U))
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: ConstraintType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.duals, ConstraintKey(T, U))
end

function has_initial_condition_value(
    ic_data::InitialConditionsData,
    ::T,
    ::Type{U},
) where {T <: ParameterType, U <: Union{PSY.Component, PSY.System}}
    return haskey(ic_data.parameters, ParameterKey(T, U))
end

######################### Initial Conditions Definitions#####################################
struct DevicePower <: InitialConditionType end
struct DeviceAboveMinPower <: InitialConditionType end
struct DeviceStatus <: InitialConditionType end
struct InitialTimeDurationOn <: InitialConditionType end
struct InitialTimeDurationOff <: InitialConditionType end
struct InitialEnergyLevel <: InitialConditionType end
struct AreaControlError <: InitialConditionType end
