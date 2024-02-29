"""
Struct to dispatch the creation of Active Power Variables

Docs abbreviation: ``Pg``
"""
struct ActivePowerVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Active Power Variables above minimum power for Thermal Compact formulations

Docs abbreviation: ``\\hat{Pg}``
"""
struct PowerAboveMinimumVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Active Power Input Variables for 2-directional devices. For instance storage or pump-hydro

Docs abbreviation: ``Pg^{in}``
"""
struct ActivePowerInVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Active Power Output Variables for 2-directional devices. For instance storage or pump-hydro

Docs abbreviation: ``Pg^{out}``
"""
struct ActivePowerOutVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Hot Start Variable for Thermal units with temperature considerations

Docs abbreviation: TODO
"""
struct HotStartVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Warm Start Variable for Thermal units with temperature considerations

Docs abbreviation: TODO
"""
struct WarmStartVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Cold Start Variable for Thermal units with temperature considerations

Docs abbreviation: TODO
"""
struct ColdStartVariable <: IS.VariableType end

"""
Struct to dispatch the creation of a variable for energy storage level (state of charge)

Docs abbreviation: ``E``
"""
struct EnergyVariable <: IS.VariableType end

struct LiftVariable <: IS.VariableType end

"""
Struct to dispatch the creation of a binary commitment status variable

Docs abbreviation: ``u``
"""
struct OnVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Reactive Power Variables

Docs abbreviation: ``Qg``
"""
struct ReactivePowerVariable <: IS.VariableType end

"""
Struct to dispatch the creation of binary storage charge reservation variable

Docs abbreviation: ``r``
"""
struct ReservationVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Active Power Reserve Variables

Docs abbreviation: ``Pr``
"""
struct ActivePowerReserveVariable <: IS.VariableType end

struct ServiceRequirementVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Binary Start Variables

Docs abbreviation: TODO
"""
struct StartVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Binary Stop Variables

Docs abbreviation: TODO
"""
struct StopVariable <: IS.VariableType end

struct SteadyStateFrequencyDeviation <: IS.VariableType end

struct AreaMismatchVariable <: IS.VariableType end

struct DeltaActivePowerUpVariable <: IS.VariableType end

struct DeltaActivePowerDownVariable <: IS.VariableType end

struct AdditionalDeltaActivePowerUpVariable <: IS.VariableType end

struct AdditionalDeltaActivePowerDownVariable <: IS.VariableType end

struct SmoothACE <: IS.VariableType end

struct SystemBalanceSlackUp <: IS.VariableType end

struct SystemBalanceSlackDown <: IS.VariableType end

struct ReserveRequirementSlack <: IS.VariableType end

struct FlowActivePowerSlackUpperBound <: IS.VariableType end

struct FlowActivePowerSlackLowerBound <: IS.VariableType end

"""
Struct to dispatch the creation of Voltage Magnitude Variables for AC formulations

Docs abbreviation: TODO
"""
struct VoltageMagnitude <: IS.VariableType end

"""
Struct to dispatch the creation of Voltage Angle Variables for AC/DC formulations

Docs abbreviation: TODO
"""
struct VoltageAngle <: IS.VariableType end

"""
Struct to dispatch the creation of bidirectional Active Power Flow Variables

Docs abbreviation: ``P``
"""
struct FlowActivePowerVariable <: IS.VariableType end

# This Variable Type doesn't make sense since there are no lossless NetworkModels with ReactivePower.
# struct FlowReactivePowerVariable <: IS.VariableType end

"""
Struct to dispatch the creation of unidirectional Active Power Flow Variables

Docs abbreviation: ``\\overrightarrow{P}``
"""
struct FlowActivePowerFromToVariable <: IS.VariableType end

"""
Struct to dispatch the creation of unidirectional Active Power Flow Variables

Docs abbreviation: ``\\overleftarrow{P}``
"""
struct FlowActivePowerToFromVariable <: IS.VariableType end

"""
Struct to dispatch the creation of unidirectional Reactive Power Flow Variables

Docs abbreviation: ``\\overrightarrow{Q}``
"""
struct FlowReactivePowerFromToVariable <: IS.VariableType end

"""
Struct to dispatch the creation of unidirectional Reactive Power Flow Variables

Docs abbreviation: ``\\overleftarrow{Q}``
"""
struct FlowReactivePowerToFromVariable <: IS.VariableType end

"""
Struct to dispatch the creation of Phase Shifters Variables

Docs abbreviation: TODO
"""
struct PhaseShifterAngle <: IS.VariableType end

# Necessary as a work around for HVDCTwoTerminal models with losses
"""
Struct to dispatch the creation of HVDC Losses Auxiliary Variables

Docs abbreviation: TODO
"""
struct HVDCLosses <: IS.VariableType end

"""
Struct to dispatch the creation of HVDC Flow Direction Auxiliary Variables

Docs abbreviation: TODO
"""
struct HVDCFlowDirectionVariable <: IS.VariableType end

"""
Struct to dispatch the creation of piecewise linear cost variables for objective function

Docs abbreviation: TODO
"""
struct PieceWiseLinearCostVariable <: IS.VariableType end

struct InterfaceFlowSlackUp <: IS.VariableType end

struct InterfaceFlowSlackDown <: IS.VariableType end

struct UpperBoundFeedForwardSlack <: IS.VariableType end

struct LowerBoundFeedForwardSlack <: IS.VariableType end

const START_VARIABLES = (HotStartVariable, WarmStartVariable, ColdStartVariable)

should_write_resulting_value(::Type{<:IS.VariableType}) = true
should_write_resulting_value(::Type{PieceWiseLinearCostVariable}) = false

convert_result_to_natural_units(::Type{<:IS.VariableType}) = false

convert_result_to_natural_units(::Type{ActivePowerVariable}) = true
convert_result_to_natural_units(::Type{PowerAboveMinimumVariable}) = true
convert_result_to_natural_units(::Type{ActivePowerInVariable}) = true
convert_result_to_natural_units(::Type{ActivePowerOutVariable}) = true
convert_result_to_natural_units(::Type{EnergyVariable}) = true
convert_result_to_natural_units(::Type{ReactivePowerVariable}) = true
convert_result_to_natural_units(::Type{ActivePowerReserveVariable}) = true
convert_result_to_natural_units(::Type{ServiceRequirementVariable}) = true
convert_result_to_natural_units(::Type{AreaMismatchVariable}) = true
convert_result_to_natural_units(::Type{DeltaActivePowerUpVariable}) = true
convert_result_to_natural_units(::Type{DeltaActivePowerDownVariable}) = true
convert_result_to_natural_units(::Type{AdditionalDeltaActivePowerUpVariable}) = true
convert_result_to_natural_units(::Type{AdditionalDeltaActivePowerDownVariable}) = true
convert_result_to_natural_units(::Type{SmoothACE}) = true
convert_result_to_natural_units(::Type{SystemBalanceSlackUp}) = true
convert_result_to_natural_units(::Type{SystemBalanceSlackDown}) = true
convert_result_to_natural_units(::Type{ReserveRequirementSlack}) = true
convert_result_to_natural_units(::Type{FlowActivePowerVariable}) = true
convert_result_to_natural_units(::Type{FlowActivePowerFromToVariable}) = true
convert_result_to_natural_units(::Type{FlowActivePowerToFromVariable}) = true
convert_result_to_natural_units(::Type{FlowReactivePowerFromToVariable}) = true
convert_result_to_natural_units(::Type{FlowReactivePowerToFromVariable}) = true
convert_result_to_natural_units(::Type{HVDCLosses}) = true
convert_result_to_natural_units(::Type{InterfaceFlowSlackUp}) = true
convert_result_to_natural_units(::Type{InterfaceFlowSlackDown}) = true
