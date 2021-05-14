#! format: off

abstract type AuxVariableType end

struct AuxVarKey{T <: AuxVariableType, U <: PSY.Component} <: OptimizationContainerKey
    aux_var_type::Type{T}
    device_type::Type{U}
end

function encode_key(::AuxVarKey{T, U}) where {T <: AuxVariableType, U <: PSY.Component}
    return Symbol("$(IS.strip_module_name(string(T)))_$(IS.strip_module_name(string(U)))")
end

struct TimeDurationOn <: AuxVariableType end
struct TimeDurationOff <: AuxVariableType end

""" Auxiliary Variable for Thermal Generation Models that solve for power above min"""
struct PowerOutput <: AuxVariableType end
