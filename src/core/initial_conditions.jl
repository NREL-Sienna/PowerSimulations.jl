struct ICKey{T <: PSI.InitialConditionType, U <: PSY.Component} <:
       PSI.OptimizationContainerKey
    meta::String
end

function ICKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: InitialConditionType, U <: PSY.Component}
    return ICKey{T, U}(meta)
end

get_entry_type(::ICKey{T, U}) where {T <: InitialConditionType, U <: PSY.Component} = T
get_component_type(::ICKey{T, U}) where {T <: InitialConditionType, U <: PSY.Component} = U

"""
Container for the initial condition data
"""
struct InitialCondition{T <: InitialConditionType, U <: Union{PJ.ParameterRef, Float64}}
    component::PSY.Component
    value::U
end

function InitialCondition(
    ::Type{T},
    component::PSY.Component,
    value::U,
) where {T <: InitialConditionType, U <: Union{PJ.ParameterRef, Float64}}
    return InitialCondition{T, U}(component, value)
end

function InitialCondition(
    ::ICKey{T, U},
    component::U,
    value::V,
) where {
    T <: InitialConditionType,
    U <: PSY.Component,
    V <: Union{PJ.ParameterRef, Float64},
}
    return InitialCondition{T, U}(component, value)
end

function get_condition(p::InitialCondition{T, Float64}) where {T <: InitialConditionType}
    return p.value
end

function get_condition(
    p::InitialCondition{T, PJ.ParameterRef},
) where {T <: InitialConditionType}
    return JuMP.value(p.value)
end

get_component(ic::InitialCondition) = ic.component
get_value(ic::InitialCondition) = ic.value
get_component_name(ic::InitialCondition) = PSY.get_name(ic.component)

"""
Stores data to populate initial conditions before the build call
"""
mutable struct InitializationData
    duals::Dict{ConstraintKey, DataFrames.DataFrame}
    parameters::Dict{ParameterKey, DataFrames.DataFrame}
    variables::Dict{VariableKey, DataFrames.DataFrame}
    aux_variables::Dict{AuxVarKey, DataFrames.DataFrame}
end

function InitializationData()
    return InitializationData(
        Dict{ConstraintKey, DataFrames.DataFrame}(),
        Dict{ParameterKey, DataFrames.DataFrame}(),
        Dict{VariableKey, DataFrames.DataFrame}(),
        Dict{AuxVarKey, DataFrames.DataFrame}(),
    )
end

######################### Initial Conditions Definitions#####################################
struct DevicePower <: InitialConditionType end
struct DeviceAboveMinPower <: InitialConditionType end
struct DeviceStatus <: InitialConditionType end
struct InitialTimeDurationOn <: InitialConditionType end
struct InitialTimeDurationOff <: InitialConditionType end
struct InitialEnergyLevel <: InitialConditionType end
struct InitialEnergyLevelUp <: InitialConditionType end
struct InitialEnergyLevelDown <: InitialConditionType end
struct AreaControlError <: InitialConditionType end
