struct AuxVarKey{T <: AuxVariableType, U <: PSY.Component} <: OptimizationContainerKey
    meta::String
end

function AuxVarKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: AuxVariableType, U <: PSY.Component}
    return AuxVarKey{T, U}(meta)
end

get_entry_type(::AuxVarKey{T, U}) where {T <: AuxVariableType, U <: PSY.Component} = T
get_component_type(::AuxVarKey{T, U}) where {T <: AuxVariableType, U <: PSY.Component} = U

struct TimeDurationOn <: AuxVariableType end
struct TimeDurationOff <: AuxVariableType end

""" Auxiliary Variable for Thermal Generation Models that solve for power above min"""
struct PowerOutput <: AuxVariableType end

should_write_resulting_value(::Type{<:AuxVariableType}) = true

convert_result_to_natural_units(::Type{<:VariableType}) = false
