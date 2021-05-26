struct AuxVarKey{T <: AuxVariableType, U <: PSY.Component} <: OptimizationContainerKey
    entry_type::Type{T}
    component_type::Type{U}
    meta::String
end

function AuxVarKey(::Type{T}, ::Type{U}) where {T <: AuxVariableType, U <: PSY.Component}
    return AuxVarKey(T, U, CONTAINER_KEY_EMPTY_META)
end

struct TimeDurationOn <: AuxVariableType end
struct TimeDurationOff <: AuxVariableType end

""" Auxiliary Variable for Thermal Generation Models that solve for power above min"""
struct PowerOutput <: AuxVariableType end
