abstract type SubComponentVariableType <: VariableType end

struct VariableKey{T <: VariableType, U <: Union{PSY.Component, PSY.System}} <:
       OptimizationContainerKey
    meta::String
end

function VariableKey(
    ::Type{T},
    ::Type{U},
    meta=CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: Union{PSY.Component, PSY.System}}
    if isabstracttype(U)
        error("Type $U can't be abstract")
    end
    check_meta_chars(meta)
    return VariableKey{T, U}(meta)
end

function VariableKey(
    ::Type{T},
    meta::String=CONTAINER_KEY_EMPTY_META,
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
"""
struct ActivePowerVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Variables above minimum power for Thermal Compact formulations
"""
struct PowerAboveMinimumVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Input Variables for 2-directional devices. For instance storage or pump-hydro
"""
struct ActivePowerInVariable <: VariableType end

"""
Struct to dispatch the creation of Active Power Output Variables for 2-directional devices. For instance storage or pump-hydro
"""
struct ActivePowerOutVariable <: VariableType end

struct HotStartVariable <: VariableType end

struct WarmStartVariable <: VariableType end

struct ColdStartVariable <: VariableType end

struct EnergyVariable <: VariableType end

struct EnergyVariableUp <: VariableType end

struct EnergyVariableDown <: VariableType end

struct EnergyShortageVariable <: VariableType end

struct EnergySurplusVariable <: VariableType end

struct LiftVariable <: VariableType end

struct OnVariable <: VariableType end

struct ReactivePowerVariable <: VariableType end

struct ReservationVariable <: VariableType end

struct ActivePowerReserveVariable <: VariableType end

struct ServiceRequirementVariable <: VariableType end

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
variables for dispatchable EVs
"""

struct DeltaPowerVariable <: VariableType end   # Change in charging power
struct DeferedChargeVariable <: VariableType end  # How far behind the baseline are you

"""
Struct to dispatch the creation of Flow Active Power Variables
"""
struct FlowActivePowerVariable <: VariableType end

# This Variable Type doesn't make sense since there are no lossless NetworkModels with ReactivePower.
# struct FlowReactivePowerVariable <: VariableType end

struct FlowActivePowerFromToVariable <: VariableType end

struct FlowActivePowerToFromVariable <: VariableType end

struct FlowReactivePowerFromToVariable <: VariableType end

struct FlowReactivePowerToFromVariable <: VariableType end

struct VariableNotDefined <: VariableType end

struct ComponentActivePowerVariable <: SubComponentVariableType end

struct ComponentReactivePowerVariable <: SubComponentVariableType end

struct ComponentActivePowerReserveUpVariable <: SubComponentVariableType end

struct ComponentActivePowerReserveDownVariable <: SubComponentVariableType end

# Necessary as a work around ofr HVDC models with losses
struct HVDCTotalPowerDeliveredVariable <: VariableType end

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
convert_result_to_natural_units(::Type{ComponentActivePowerVariable}) = true
convert_result_to_natural_units(::Type{ComponentReactivePowerVariable}) = true
convert_result_to_natural_units(::Type{ComponentActivePowerReserveUpVariable}) = true
convert_result_to_natural_units(::Type{ComponentActivePowerReserveDownVariable}) = true
convert_result_to_natural_units(::Type{HVDCTotalPowerDeliveredVariable}) = true
