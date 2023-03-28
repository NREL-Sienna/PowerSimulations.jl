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

struct HotStartVariable <: VariableType end

struct WarmStartVariable <: VariableType end

struct ColdStartVariable <: VariableType end

"""
Struct to dispatch the creation of a variable for energy storage level (state of charge)

Docs abbreviation: ``E``
"""
struct EnergyVariable <: VariableType end

"""
Struct to dispatch the creation of a variable for energy storage level (state of charge) of upper reservoir

Docs abbreviation: ``E^{up}``
"""
struct EnergyVariableUp <: VariableType end

"""
Struct to dispatch the creation of a variable for energy storage level (state of charge) of lower reservoir

Docs abbreviation: ``E^{down}``
"""
struct EnergyVariableDown <: VariableType end

"""
Struct to dispatch the creation of a slack variable for energy storage levels < target storage levels

Docs abbreviation: ``E^{shortage}``
"""
struct EnergyShortageVariable <: VariableType end

"""
Struct to dispatch the creation of a slack variable for energy storage levels > target storage levels

Docs abbreviation: ``E^{surplus}``
"""
struct EnergySurplusVariable <: VariableType end

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
Struct to dispatch the creation of energy (water) spillage variable representing energy released from a storage/reservoir not injected into the network

Docs abbreviation: ``S``
"""
struct WaterSpillageVariable <: VariableType end

struct StartVariable <: VariableType end

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

struct VoltageMagnitude <: VariableType end

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

struct PhaseShifterAngle <: VariableType end

# Necessary as a work around for HVDCP2P models with losses
struct HVDCLosses <: VariableType end
struct HVDCFlowDirectionVariable <: VariableType end

struct PieceWiseLinearCostVariable <: VariableType end

const START_VARIABLES = (HotStartVariable, WarmStartVariable, ColdStartVariable)

should_write_resulting_value(::Type{<:VariableType}) = true
should_write_resulting_value(::Type{PieceWiseLinearCostVariable}) = false

convert_result_to_natural_units(::Type{<:VariableType}) = false

convert_result_to_natural_units(::Type{ActivePowerVariable}) = true
convert_result_to_natural_units(::Type{PowerAboveMinimumVariable}) = true
convert_result_to_natural_units(::Type{ActivePowerInVariable}) = true
convert_result_to_natural_units(::Type{ActivePowerOutVariable}) = true
convert_result_to_natural_units(::Type{EnergyVariable}) = true
convert_result_to_natural_units(::Type{EnergyVariableUp}) = true
convert_result_to_natural_units(::Type{EnergyVariableDown}) = true
convert_result_to_natural_units(::Type{EnergyShortageVariable}) = true
convert_result_to_natural_units(::Type{EnergySurplusVariable}) = true
convert_result_to_natural_units(::Type{ReactivePowerVariable}) = true
convert_result_to_natural_units(::Type{ActivePowerReserveVariable}) = true
convert_result_to_natural_units(::Type{ServiceRequirementVariable}) = true
# convert_result_to_natural_units(::Type{WaterSpillageVariable }) = true # TODO: is this pu?
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
