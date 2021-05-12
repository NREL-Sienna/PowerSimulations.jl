#! format: off

abstract type AuxVariableType end

struct AuxVarKey{T <: AuxVariableType, U <: PSY.Component} <: OptimizationContainerKey
    aux_var_type::Type{T}
    device_type::Type{U}
end

encode_key(::AuxVarKey{T, U}) where {T <: AuxVariableType, U <: PSY.Component} = Symbol("$(T)_$(U)")

struct TimeDurationOn <: AuxVariableType end
struct TimeDurationOff <: AuxVariableType end

""" Auxiliary Variable for Thermal Generation Models that solve for power above min"""
struct PowerOutput <: AuxVariableType end
