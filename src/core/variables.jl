abstract type SubComponentVariableType <: VariableType end

struct VariableKey{T <: VariableType, U <: Union{PSY.Component, PSY.System}} <:
       OptimizationContainerKey
    meta::String
end

function VariableKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    check_meta_chars(meta)
    return VariableKey{T, U}(meta)
end

function VariableKey(
    ::Type{T},
    meta::String = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType}
    return VariableKey(T, PSY.Component, meta)
end

get_entry_type(
    ::VariableKey{T, U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}} = T
get_component_type(
    ::VariableKey{T, U},
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}} = U

"""
Struct to dispatch the creation of Active Power Variables

Docs abbreviation: ``p``
"""
struct ActivePowerVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Variables above minimum power for Thermal Compact formulations

Docs abbreviation: ``\\Delta p``
"""
struct PowerAboveMinimumVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Input Variables for 2-directional devices. For instance storage or pump-hydro

Docs abbreviation: ``p^\\text{in}``
"""
struct ActivePowerInVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Output Variables for 2-directional devices. For instance storage or pump-hydro

Docs abbreviation: ``p^\\text{out}``
"""
struct ActivePowerOutVariable <: VariableType end

"""
Struct to dispatch the creation of Hot Start Variable for Thermal units with temperature considerations

Docs abbreviation: ``z^\\text{th}``
"""
struct HotStartVariable <: VariableType end

"""
Struct to dispatch the creation of Warm Start Variable for Thermal units with temperature considerations

Docs abbreviation: ``y^\\text{th}``
"""
struct WarmStartVariable <: VariableType end

"""
Struct to dispatch the creation of Cold Start Variable for Thermal units with temperature considerations

Docs abbreviation: ``x^\\text{th}``
"""
struct ColdStartVariable <: VariableType end

"""
Struct to dispatch the creation of a variable for energy storage level (state of charge)

Docs abbreviation: ``e``
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

Docs abbreviation: ``q``
"""
struct ReactivePowerVariable <: VariableType end

"""
Struct to dispatch the creation of binary storage charge reservation variable

Docs abbreviation: ``u^\\text{st}``
"""
struct ReservationVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Reserve Variables

Docs abbreviation: ``r``
"""
struct ActivePowerReserveVariable <: VariableType end

"""
Struct to dispatch the creation of Service Requirement Variables

Docs abbreviation: ``\\text{req}``
"""
struct ServiceRequirementVariable <: VariableType end

"""
Struct to dispatch the creation of Binary Start Variables

Docs abbreviation: ``v``
"""
struct StartVariable <: VariableType end

"""
Struct to dispatch the creation of Binary Stop Variables

Docs abbreviation: ``w``
"""
struct StopVariable <: VariableType end

struct SteadyStateFrequencyDeviation <: VariableType end

struct AreaMismatchVariable <: VariableType end

struct DeltaActivePowerUpVariable <: VariableType end

struct DeltaActivePowerDownVariable <: VariableType end

struct AdditionalDeltaActivePowerUpVariable <: VariableType end

struct AdditionalDeltaActivePowerDownVariable <: VariableType end

struct SmoothACE <: VariableType end

"""
Struct to dispatch the creation of System-wide slack up variables. Used when there is not enough generation.

Docs abbreviation: ``p^\\text{sl,up}``
"""
struct SystemBalanceSlackUp <: VariableType end

"""
Struct to dispatch the creation of System-wide slack down variables. Used when there is not enough load curtailment.

Docs abbreviation: ``p^\\text{sl,dn}``
"""
struct SystemBalanceSlackDown <: VariableType end

"""
Struct to dispatch the creation of Reserve requirement slack variables. Used when there is not reserves in the system to satisfy the requirement.

Docs abbreviation: ``r^\\text{sl}``
"""
struct ReserveRequirementSlack <: VariableType end

"""
Struct to dispatch the creation of active power flow upper bound slack variables. Used when there is not enough flow through the branch in the forward direction.

Docs abbreviation: ``f^\\text{sl,up}``
"""
struct FlowActivePowerSlackUpperBound <: VariableType end

"""
Struct to dispatch the creation of active power flow lower bound slack variables. Used when there is not enough flow through the branch in the reverse direction.

Docs abbreviation: ``f^\\text{sl,lo}``
"""
struct FlowActivePowerSlackLowerBound <: VariableType end

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

Docs abbreviation: ``f``
"""
struct FlowActivePowerVariable <: VariableType end

# This Variable Type doesn't make sense since there are no lossless NetworkModels with ReactivePower.
# struct FlowReactivePowerVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Active Power Flow Variables

Docs abbreviation: ``f^\\text{from-to}``
"""
struct FlowActivePowerFromToVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Active Power Flow Variables

Docs abbreviation: ``f^\\text{to-from}``
"""
struct FlowActivePowerToFromVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Reactive Power Flow Variables

Docs abbreviation: ``f^\\text{q,from-to}``
"""
struct FlowReactivePowerFromToVariable <: VariableType end

"""
Struct to dispatch the creation of unidirectional Reactive Power Flow Variables

Docs abbreviation: ``f^\\text{q,to-from}``
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

Docs abbreviation: ``\\ell``
"""
struct HVDCLosses <: VariableType end

"""
Struct to dispatch the creation of HVDC Flow Direction Auxiliary Variables

Docs abbreviation: ``u^\\text{dir}``
"""
struct HVDCFlowDirectionVariable <: VariableType end

"""
Struct to dispatch the creation of piecewise linear cost variables for objective function

Docs abbreviation: ``\\delta``
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
