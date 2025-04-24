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
Auxiliary Variables that are calculated using a `PowerFlowEvaluationModel`
"""
abstract type PowerFlowAuxVariableType <: AuxVariableType end

"""
Auxiliary Variable for the bus angle results from power flow evaluation
"""
struct PowerFlowVoltageAngle <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the bus voltage magnitued results from power flow evaluation
"""
struct PowerFlowVoltageMagnitude <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the bus active power injection from power flow evaluation
"""
struct PowerFlowBusActivePowerInjection <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the bus reactive power injection from power flow evaluation
"""
struct PowerFlowBusReactivePowerInjection <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the bus active power withdrawal from power flow evaluation
"""
struct PowerFlowBusActivePowerWithdrawals <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the bus reactive power withdrawal from power flow evaluation
"""
struct PowerFlowBusReactivePowerWithdrawals <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the line reactive flow in the from -> to direction from power flow evaluation
"""
struct PowerFlowLineReactivePowerFromTo <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the line reactive flow in the to -> from direction from power flow evaluation
"""
struct PowerFlowLineReactivePowerToFrom <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the line active flow in the from -> to direction from power flow evaluation
"""
struct PowerFlowLineActivePowerFromTo <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the line active flow in the to -> from direction from power flow evaluation
"""
struct PowerFlowLineActivePowerToFrom <: PowerFlowAuxVariableType end

"""
Auxiliary Variable for the loss factors from AC power flow evaluation that are calculated using the Jacobian matrix
"""
struct PowerFlowLossFactors <: PowerFlowAuxVariableType end

convert_result_to_natural_units(::Type{PowerOutput}) = true
convert_result_to_natural_units(
    ::Type{
        <:Union{
            PowerFlowLineReactivePowerFromTo, PowerFlowLineReactivePowerToFrom,
            PowerFlowLineActivePowerFromTo, PowerFlowLineActivePowerToFrom,
            PowerFlowBusActivePowerInjection, PowerFlowBusReactivePowerInjection,
            PowerFlowBusActivePowerWithdrawals, PowerFlowBusReactivePowerWithdrawals,
        },
    },
) = true

"Whether the auxiliary variable is calculated using a `PowerFlowEvaluationModel`"
is_from_power_flow(::Type{<:AuxVariableType}) = false
is_from_power_flow(::Type{<:PowerFlowAuxVariableType}) = true
