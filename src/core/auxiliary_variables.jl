#! format: off

abstract type AuxVariableType end

struct AuxVarKey{T <: AuxVariableType, U <: PSY.Component} <: OptimizationContainerKey
    aux_var_type::Type{T}
    device_type::Type{U}
end

struct TimeDurationON <: AuxVariableType end
struct TimeDurationOFF <: AuxVariableType end

encode_key(::AuxVarKey{T, U}) where {T <: AuxVariableType, U <: PSY.Component} = "$(T)_$(U)"
