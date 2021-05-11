#! format: off

abstract type AuxVariableType end

struct AuxVarKey{T <: AuxVariableType, U <: PSY.Component} <: OptimizationContainerKey
    aux_var_type::Type{T}
    device_type::Type{U}
end

struct TimeDurationON <: AuxVariableType end
struct TimeDurationOFF <: AuxVariableType end

make_variable_name(::Type{TimeDurationON}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "TimeON")
make_variable_name(::Type{TimeDurationOFF}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "TimeOFF")
