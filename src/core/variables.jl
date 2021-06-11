struct VariableKey{T <: VariableType, U <: PSY.Component} <: OptimizationContainerKey
    meta::String
end

function VariableKey(
    ::Type{T},
    ::Type{U},
    meta = CONTAINER_KEY_EMPTY_META,
) where {T <: VariableType, U <: PSY.Component}
    return VariableKey{T, U}(meta)
end

function VariableKey(::Type{T}) where {T <: VariableType}
    return VariableKey(T, PSY.Component, CONTAINER_KEY_EMPTY_META)
end

function VariableKey(::Type{T}, meta::String) where {T <: VariableType}
    return VariableKey(T, PSY.Component, meta)
end

get_entry_type(::VariableKey{T, U}) where {T <: VariableType, U <: PSY.Component} = T
get_component_type(::VariableKey{T, U}) where {T <: VariableType, U <: PSY.Component} = U

"""Struct to dispatch the creation of Active Power Variables"""
struct ActivePowerVariable <: VariableType end

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

struct FlowReactivePowerVariable <: VariableType end

struct FlowActivePowerFromToVariable <: VariableType end

struct FlowActivePowerToFromVariable <: VariableType end

struct FlowReactivePowerFromToVariable <: VariableType end

struct FlowReactivePowerToFromVariable <: VariableType end

struct VariableNotDefined <: VariableType end

###############################

const START_VARIABLES = (HotStartVariable, WarmStartVariable, ColdStartVariable)
