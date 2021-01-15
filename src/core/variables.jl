#! format: off

const ACTIVE_POWER = "P"
const ACTIVE_POWER_IN = "Pin"
const ACTIVE_POWER_OUT = "Pout"
const COLD_START = "start_cold"
const ENERGY = "E"
const ENERGY_UP = "Eup"
const ENERGY_DOWN = "Edown"
const ENERGY_BUDGET = "energy_budget"
const ENERGY_BUDGET_UP = "energy_budget_up"
const ENERGY_BUDGET_DOWN = "energy_budget_down"
const FLOW_ACTIVE_POWER = "Fp"
const HOT_START = "start_hot"
const INFLOW = "In"
const TARGET = "Target"
const OUTFLOW = "Out"
const ON = "On"
const REACTIVE_POWER = "Q"
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

abstract type VariableType end

"""Struct to dispatch the creation of Active Power Variables"""
struct ActivePowerVariable <: VariableType end

"""Struct to dispatch the creation of Active Power Input Variables for 2-directional devices. for instance storage or pump-hydro"""
struct ActivePowerInVariable <: VariableType end

"""Struct to dispatch the creation of Active Power Output Variables for 2-directional devices. for instance storage or pump-hydro"""
struct ActivePowerOutVariable <: VariableType end

struct HotStartVariable <: VariableType end

struct WarmStartVariable <: VariableType end

struct ColdStartVariable <: VariableType end

struct EnergyVariable <: VariableType end

struct EnergyVariableUp <: VariableType end

struct EnergyVariableDown <: VariableType end

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

"""Struct to dispatch the creation of Flow Active Power Variables"""
struct FlowActivePowerVariable <: VariableType end

###############################

const START_VARIABLES = (HotStartVariable, WarmStartVariable, ColdStartVariable)

###############################

make_variable_name(var_type, device_type) = encode_symbol(device_type, var_type)
make_variable_name(var_type) = encode_symbol(var_type)

###############################

make_variable_name(::Type{ActivePowerVariable}, ::Type{T}) where {T <: PSY.Component} = encode_symbol(T, "P")

make_variable_name(::Type{ActivePowerInVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Pin")

make_variable_name(::Type{ActivePowerOutVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Pout")

make_variable_name(::Type{HotStartVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "start_hot")

make_variable_name(::Type{WarmStartVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "start_warm")

make_variable_name(::Type{ColdStartVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "start_cold")

make_variable_name(::Type{EnergyVariable}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "E")

make_variable_name(::Type{EnergyVariableUp}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Eup")

make_variable_name(::Type{EnergyVariableDown}, ::Type{T}) where {T <: PSY.Device} = encode_symbol(T, "Edown")

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
