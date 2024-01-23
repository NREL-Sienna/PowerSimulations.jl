struct AuxVarKey{T <: AuxVariableType, U <: PSY.Component} <: OptimizationContainerKey
    meta::String
end

function AuxVarKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: AuxVariableType, U <: PSY.Component}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    return AuxVarKey{T, U}(meta)
end

get_entry_type(::AuxVarKey{T, U}) where {T <: AuxVariableType, U <: PSY.Component} = T
get_component_type(::AuxVarKey{T, U}) where {T <: AuxVariableType, U <: PSY.Component} = U

"""
Auxiliary Variable for Thermal Generation Models to keep track of time elapsed on
"""
struct TimeDurationOn <: AuxVariableType end

"""
Auxiliary Variable for Thermal Generation Models to keep track of time elapsed off
"""
struct TimeDurationOff <: AuxVariableType end

"""
Auxiliary Variable for Thermal Generation Models that solve for power above min
"""
struct PowerOutput <: AuxVariableType end

"""
Auxiliary Variable for the bus angle results from power flow evaluation
"""
struct PowerFlowVoltageAngle <: AuxVariableType end

"""
Auxiliary Variable for the bus voltage magnitued results from power flow evaluation
"""
struct PowerFlowVoltageMagnitude <: AuxVariableType end

"""
Auxiliary Variable for the line reactive flow from power flow evaluation
"""
struct PowerFlowLineReactivePower <: AuxVariableType end

"""
Auxiliary Variable for the line active flow from power flow evaluation
"""
struct PowerFlowLineActivePower <: AuxVariableType end

should_write_resulting_value(::Type{<:AuxVariableType}) = true

convert_result_to_natural_units(::Type{<:AuxVariableType}) = false
convert_result_to_natural_units(::Type{PowerOutput}) = true
convert_result_to_natural_units(::Type{PowerFlowLineReactivePower}) = true
convert_result_to_natural_units(::Type{PowerFlowLineActivePower}) = true
