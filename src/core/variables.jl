#! format: off

const ACTIVE_POWER = "P"
const SUBCOMPONENT_ACTIVE_POWER = "P_SubComponent"
const ACTIVE_POWER_IN = "Pin"
const SUBCOMPONENT_ACTIVE_POWER_IN = "Pin_SubComponent"
const ACTIVE_POWER_OUT = "Pout"
const ACTIVE_POWER_SHORTAGE = "P_shortage"
const ACTIVE_POWER_SURPLUS = "P_surplus"
const SUBCOMPONENT_ACTIVE_POWER_OUT = "Pout_SubComponent"
const COLD_START = "start_cold"
const ENERGY = "E"
const SUBCOMPONENT_ENERGY = "E_SubComponent"
const ENERGY_UP = "Eup"
const ENERGY_DOWN = "Edown"
const ENERGY_BUDGET = "energy_budget"
const ENERGY_BUDGET_UP = "energy_budget_up"
const ENERGY_BUDGET_DOWN = "energy_budget_down"
const ENERGY_SHORTAGE  = "energy_shortage"
const ENERGY_SURPLUS = "energy_surplus"
const FLOW_REACTIVE_POWER_FROM_TO = "FqFT"
const FLOW_REACTIVE_POWER_TO_FROM = "FqTF"
const FLOW_ACTIVE_POWER_FROM_TO = "FpFT"
const FLOW_ACTIVE_POWER_TO_FROM = "FpTF"
const FLOW_ACTIVE_POWER = "Fp"
const FLOW_REACTIVE_POWER = "Fq"
const HOT_START = "start_hot"
const INFLOW = "In"
const TARGET = "Target"
const OUTFLOW = "Out"
const ON = "On"
const REACTIVE_POWER = "Q"
const SUBCOMPONENT_REACTIVE_POWER = "Q_SubComponent"
const RESERVE = "R"
const SERVICE_REQUIREMENT = "service_requirement"
const SLACK_DN = "γ⁻"
const SLACK_UP = "γ⁺"
const SPILLAGE = "Sp"
const START = "start"
const STOP = "stop"
const THETA = "theta"
const VM = "Vm"
const LIFT = "z"
const ACTIVE_POWER_PUMP = "Ppump"
const ACTIVE_POWER_THERMAL = "P_thermal"
const ACTIVE_POWER_LOAD = "P_load"
const ACTIVE_POWER_IN_STORAGE = "Pin_storage"
const ACTIVE_POWER_OUT_STORAGE = "Pout_storage"
const ACTIVE_POWER_RENEWABLE = "P_renewable"
const REACTIVE_POWER_THERMAL = "Q_thermal"
const REACTIVE_POWER_LOAD = "Q_load"
const REACTIVE_POWER_STORAGE = "Q_storage"
const REACTIVE_POWER_RENEWABLE = "Q_renewable"

abstract type VariableType end
abstract type SubComponentVariableType <: VariableType end
"""Struct to dispatch the creation of Active Power Variables"""
struct ActivePowerVariable <: VariableType end

"""Struct to dispatch the creation of Active Power Input Variables for 2-directional devices. for instance storage or pump-hydro"""
struct ActivePowerInVariable <: VariableType end

"""Struct to dispatch the creation of Active Power Output Variables for 2-directional devices. for instance storage or pump-hydro"""
struct ActivePowerOutVariable <: VariableType end

struct ActivePowerShortageVariable <: VariableType end

struct ActivePowerSurplusVariable <: VariableType end

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

struct ReserveVariable <: VariableType end

struct ActiveServiceVariable <: VariableType end

struct ServiceRequirementVariable <: VariableType end

struct SpillageVariable <: VariableType end

struct StartVariable <: VariableType end

struct StopVariable <: VariableType end

struct SteadyStateFrequencyDeviation <: VariableType end

struct AreaMismatchVariable <: VariableType end

struct DeltaActivePowerUpVariable <: VariableType end

struct DeltaActivePowerDownVariable <: VariableType end

struct AdditionalDeltaActivePowerUpVariable <: VariableType end

struct AdditionalDeltaActivePowerDownVariable <: VariableType end

struct SmoothACE <: VariableType end

struct SubComponentActivePowerVariable <: SubComponentVariableType end

struct SubComponentReactivePowerVariable <: SubComponentVariableType end

struct SubComponentActivePowerInVariable <: SubComponentVariableType end

struct SubComponentActivePowerOutVariable <: SubComponentVariableType end

struct SubComponentEnergyVariable <: SubComponentVariableType end

"""Struct to dispatch the creation of Flow Active Power Variables"""
struct FlowActivePowerVariable <: VariableType end

struct FlowReactivePowerVariable <: VariableType end

struct FlowActivePowerFromToVariable <: VariableType end

struct FlowActivePowerToFromVariable <: VariableType end

struct FlowReactivePowerFromToVariable <: VariableType end

struct FlowReactivePowerToFromVariable <: VariableType end

###############################

const START_VARIABLES = (HotStartVariable, WarmStartVariable, ColdStartVariable)

###############################

make_variable_name(var_type, device_type) = encode_symbol(device_type, var_type)
make_variable_name(var_type) = encode_symbol(var_type)

###############################

make_variable_name(::Type{ActivePowerVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "P")

make_variable_name(::Type{ActivePowerInVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Pin")

make_variable_name(::Type{ActivePowerOutVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Pout")

make_variable_name(::Type{ActivePowerSurplusVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "P_surplus")

make_variable_name(::Type{ActivePowerShortageVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "P_shortage")

make_variable_name(::Type{HotStartVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "start_hot")

make_variable_name(::Type{WarmStartVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "start_warm")

make_variable_name(::Type{ColdStartVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "start_cold")

make_variable_name(::Type{EnergyVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "E")

make_variable_name(::Type{EnergyVariableUp}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Eup")

make_variable_name(::Type{EnergyVariableDown}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Edown")

make_variable_name(::Type{EnergySurplusVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "energy_surplus")

make_variable_name(::Type{EnergyShortageVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "energy_shortage")

make_variable_name(::Type{LiftVariable}) = :lift

make_variable_name(::Type{LiftVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "lift")

make_variable_name(::Type{OnVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "On")

make_variable_name(::Type{ReactivePowerVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Q")

make_variable_name(::Type{ReserveVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "R")

make_variable_name(::Type{ServiceRequirementVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "service_requirement")

make_variable_name(::Type{SpillageVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Sp")

make_variable_name(::Type{StartVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "start")

make_variable_name(::Type{StopVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "stop")

make_variable_name(::Type{SteadyStateFrequencyDeviation}) = :Δf

make_variable_name(::Type{AreaMismatchVariable}) = :area_mismatch

make_variable_name(::Type{DeltaActivePowerUpVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "ΔP_up")

make_variable_name(::Type{DeltaActivePowerUpVariable}, ::Type{PSY.RegulationDevice{T}}) where {T <: PSY.Device} = encode_symbol(T, "ΔP_up")

make_variable_name(::Type{DeltaActivePowerDownVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "ΔP_dn")

make_variable_name(::Type{DeltaActivePowerDownVariable}, ::Type{PSY.RegulationDevice{T}}) where {T <: PSY.Device} = encode_symbol(T, "ΔP_dn")

make_variable_name(::Type{AdditionalDeltaActivePowerUpVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "ΔPe_up")

make_variable_name(::Type{AdditionalDeltaActivePowerUpVariable}, ::Type{PSY.RegulationDevice{T}}) where {T <: PSY.Device} = encode_symbol(T, "ΔPe_up")

make_variable_name(::Type{AdditionalDeltaActivePowerDownVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "ΔPe_dn")

make_variable_name(::Type{AdditionalDeltaActivePowerDownVariable}, ::Type{PSY.RegulationDevice{T}}) where {T <: PSY.Device} = encode_symbol(T, "ΔPe_dn")

make_variable_name(::Type{SmoothACE}, ::Type{T}) where {T <: PSY.AggregationTopology} = encode_symbol(T, "SACE")

make_variable_name(::Type{FlowActivePowerVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "Fp")

make_variable_name(::Type{SubComponentActivePowerVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "P_SubComponent")

make_variable_name(::Type{SubComponentActivePowerInVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "Pin_SubComponent")

make_variable_name(::Type{SubComponentActivePowerOutVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "Pout_SubComponent")

make_variable_name(::Type{SubComponentEnergyVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "E_SubComponent")

make_variable_name(::Type{SubComponentReactivePowerVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "Q_SubComponent")

make_variable_name(::Type{FlowReactivePowerVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "Fq")

make_variable_name(::Type{FlowActivePowerFromToVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "FpFT")

make_variable_name(::Type{FlowActivePowerToFromVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "FpTF")

make_variable_name(::Type{FlowReactivePowerFromToVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "FqFT")

make_variable_name(::Type{FlowReactivePowerToFromVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "FqTF")
