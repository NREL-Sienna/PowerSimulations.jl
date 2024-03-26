"""
Struct to dispatch the creation of Active Power Variables

Docs abbreviation: ``Pg``
"""
struct ActivePowerVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Variables above minimum power for Thermal Compact formulations

Docs abbreviation: ``\\hat{Pg}``
"""
struct PowerAboveMinimumVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Input Variables for 2-directional devices. For instance storage or pump-hydro

Docs abbreviation: ``Pg^{in}``
"""
struct ActivePowerInVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Output Variables for 2-directional devices. For instance storage or pump-hydro

Docs abbreviation: ``Pg^{out}``
"""
struct ActivePowerOutVariable <: VariableType end

"""
Struct to dispatch the creation of Hot Start Variable for Thermal units with temperature considerations

Docs abbreviation: TODO
"""
struct HotStartVariable <: VariableType end

"""
Struct to dispatch the creation of Warm Start Variable for Thermal units with temperature considerations

Docs abbreviation: TODO
"""
struct WarmStartVariable <: VariableType end

"""
Struct to dispatch the creation of Cold Start Variable for Thermal units with temperature considerations

Docs abbreviation: TODO
"""
struct ColdStartVariable <: VariableType end

"""
Struct to dispatch the creation of a variable for energy storage level (state of charge)

Docs abbreviation: ``E``
"""
struct EnergyVariable <: VariableType end

struct LiftVariable <: VariableType end

"""
Struct to dispatch the creation of a binary commitment status variable

Docs abbreviation: ``u``
"""
struct OnVariable <: VariableType end

"""
Struct to dispatch the creation of Reactive Power Variables

Docs abbreviation: ``Qg``
"""
struct ReactivePowerVariable <: VariableType end

"""
Struct to dispatch the creation of binary storage charge reservation variable

Docs abbreviation: ``r``
"""
struct ReservationVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Reserve Variables

Docs abbreviation: ``Pr``
"""
struct ActivePowerReserveVariable <: VariableType end

struct ServiceRequirementVariable <: VariableType end

"""
Struct to dispatch the creation of Binary Start Variables

Docs abbreviation: TODO
"""
struct StartVariable <: VariableType end

"""
Struct to dispatch the creation of Binary Stop Variables

Docs abbreviation: TODO
"""
struct StopVariable <: VariableType end

struct SteadyStateFrequencyDeviation <: VariableType end

struct AreaMismatchVariable <: VariableType end

struct DeltaActivePowerUpVariable <: VariableType end

struct DeltaActivePowerDownVariable <: VariableType end

struct AdditionalDeltaActivePowerUpVariable <: VariableType end

struct AdditionalDeltaActivePowerDownVariable <: VariableType end

struct SmoothACE <: VariableType end

struct SystemBalanceSlackUp <: VariableType end

struct SystemBalanceSlackDown <: VariableType end

struct ReserveRequirementSlack <: VariableType end

"""
Struct to dispatch the creation of Voltage Magnitude Variables for AC formulations

Docs abbreviation: TODO
"""
struct VoltageMagnitude <: VariableType end

"""
Struct to dispatch the creation of Voltage Angle Variables for AC/DC formulations

Docs abbreviation: TODO
"""
struct VoltageAngle <: VariableType end

"""
Struct to dispatch the creation of bidirectional Active Power Flow Variables

Docs abbreviation: ``P``
"""
struct FlowActivePowerVariable <: VariableType end

# This Variable Type doesn't make sense since there are no lossless NetworkModels with ReactivePower.
# struct FlowReactivePowerVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Active Power Flow Variables

Docs abbreviation: ``\\overrightarrow{P}``
"""
struct FlowActivePowerFromToVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Active Power Flow Variables

Docs abbreviation: ``\\overleftarrow{P}``
"""
struct FlowActivePowerToFromVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Reactive Power Flow Variables

Docs abbreviation: ``\\overrightarrow{Q}``
"""
struct FlowReactivePowerFromToVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Reactive Power Flow Variables

Docs abbreviation: ``\\overleftarrow{Q}``
"""
struct FlowReactivePowerToFromVariable <: VariableType end

"""
Struct to dispatch the creation of Phase Shifters Variables

Docs abbreviation: TODO
"""
struct PhaseShifterAngle <: VariableType end

# Necessary as a work around for HVDCTwoTerminal models with losses
"""
Struct to dispatch the creation of HVDC Losses Auxiliary Variables

Docs abbreviation: TODO
"""
struct HVDCLosses <: VariableType end

"""
Struct to dispatch the creation of HVDC Flow Direction Auxiliary Variables

Docs abbreviation: TODO
"""
struct HVDCFlowDirectionVariable <: VariableType end

"""
Struct to dispatch the creation of piecewise linear cost variables for objective function

Docs abbreviation: TODO
"""
struct PieceWiseLinearCostVariable <: VariableType end

struct InterfaceFlowSlackUp <: VariableType end

struct InterfaceFlowSlackDown <: VariableType end

struct UpperBoundFeedForwardSlack <: VariableType end

struct LowerBoundFeedForwardSlack <: VariableType end

const START_VARIABLES = (HotStartVariable, WarmStartVariable, ColdStartVariable)

should_write_resulting_value(::Type{<:VariableType}) = true
should_write_resulting_value(::Type{PieceWiseLinearCostVariable}) = false

convert_result_to_natural_units(::Type{<:VariableType}) = false

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
