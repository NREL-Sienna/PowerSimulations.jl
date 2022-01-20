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

"""Struct to dispatch the creation of Active Power Variables"""
struct ActivePowerVariable <: VariableType end

"""Struct to dispatch the creation of Active Power Variables above minimum power for Thermal Compact formulations"""
struct PowerAboveMinimumVariable <: VariableType end

"""Struct to dispatch the creation of Active Power Input Variables for 2-directional devices. For instance storage or pump-hydro"""
struct ActivePowerInVariable <: VariableType end

"""Struct to dispatch the creation of Active Power Output Variables for 2-directional devices. For instance storage or pump-hydro"""
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

"""Struct to dispatch the creation of Flow Active Power Variables"""
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
