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

convert_result_to_natural_units(::Type{PowerOutput}) = true
convert_result_to_natural_units(::Type{PowerFlowLineReactivePower}) = true
convert_result_to_natural_units(::Type{PowerFlowLineActivePower}) = true

"Whether the auxiliary variable is calculated using a `PowerFlowEvaluationModel`"
is_from_power_flow(::Type{<:AuxVariableType}) = false
is_from_power_flow(::Type{PowerFlowVoltageAngle}) = true
is_from_power_flow(::Type{PowerFlowVoltageMagnitude}) = true
is_from_power_flow(::Type{PowerFlowLineReactivePower}) = true
is_from_power_flow(::Type{PowerFlowLineActivePower}) = true
