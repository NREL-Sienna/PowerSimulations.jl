const ACTIVE_POWER = "P"
const ACTIVE_POWER_IN = "Pin"
const ACTIVE_POWER_OUT = "Pout"
const AREA_MISMATCH = "area_mismatch"
const COLD_START = "start_cold"
const ENERGY = "E"
const ENERGY_BUDGET = "energy_budget"
const FLOW_ACTIVE_POWER = "Fp"
const HOT_START = "start_hot"
const INFLOW = "In"
const ON = "On"
const REACTIVE_POWER = "Q"
const RESERVE = "R"
const SERVICE_REQUIREMENT = "service_requirement"
const SLACK_DN = "γ⁻"
const SLACK_UP = "γ⁺"
const SPILLAGE = "Sp"
const START = "Start"
const STOP = "Stop"
const THETA = "theta"
const VM = "Vm"
const WARM_START = "start_warm"
const LIFT = "z"

abstract type VariableType end

function make_variable_name(::Type{T}) where {T <: VariableType}
    error("make_variable_name not implemented for $T")
end

function make_variable_name(
    ::Type{T},
    ::Type{U},
) where {T <: VariableType, U <: PSY.Component}
    error("make_variable_name not implemented for $T / $U")
end

"""
Struct to dispatch the creation of Active Power Variables
"""
struct ActivePowerVariable <: VariableType end

function make_variable_name(::Type{ActivePowerVariable}, ::Type{T}) where {T <: PSY.Component}
    return encode_symbol(T, "P")
end

"""
Struct to dispatch the creation of Active Power Input Variables for 2-directional devices.
for instance storage or pump-hydro
"""
struct ActivePowerInVariable <: VariableType end

function make_variable_name(
    ::Type{ActivePowerInVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, "Pin")
end

"""
Struct to dispatch the creation of Active Power Output Variables for 2-directional devices.
for instance storage or pump-hydro
"""
struct ActivePowerOutVariable <: VariableType end

function make_variable_name(
    ::Type{ActivePowerOutVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, "Pout")
end

struct ColdStartVariable <: VariableType end

function make_variable_name(::Type{ColdStartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "start_cold")
end

struct EnergyVariable <: VariableType end

function make_variable_name(::Type{EnergyVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "E")
end

struct HotStartVariable <: VariableType end

function make_variable_name(::Type{HotStartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "start_hot")
end

struct LiftVariable <: VariableType end

function make_variable_name(::Type{LiftVariable})
    return encode_symbol("lift")
end

function make_variable_name(::Type{LiftVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "lift")
end

struct OnVariable <: VariableType end

function make_variable_name(::Type{OnVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "on")
end

struct ReactivePowerVariable <: VariableType end

function make_variable_name(
    ::Type{ReactivePowerVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, "reactive_power")
end

struct ReserveVariable <: VariableType end

function make_variable_name(::Type{ReserveVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "R")
end

struct ActiveServiceVariable <: VariableType end

struct ServiceRequirementVariable <: VariableType end

function make_variable_name(
    ::Type{ServiceRequirementVariable},
    ::Type{T},
) where {T <: PSY.Component}
    return encode_symbol(T, "service_requirement")
end

struct SpillageVariable <: VariableType end

function make_variable_name(::Type{SpillageVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "Sp")
end

struct StartVariable <: VariableType end

function make_variable_name(::Type{StartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "start")
end

struct StopVariable <: VariableType end

function make_variable_name(::Type{StopVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, "stop")
end

struct WarmStartVariable <: VariableType end

function make_variable_name(::Type{WarmStartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, WARM_START)
end

##### AGC Variables #####
struct SteadyStateFrequencyDeviation <: VariableType end

function make_variable_name(::Type{SteadyStateFrequencyDeviation})
    return encode_symbol("Δf")
end

struct AreaMismatchVariable <: VariableType end

function make_variable_name(::Type{AreaMismatchVariable})
    return encode_symbol(AREA_MISMATCH)
end

struct DeltaActivePowerUpVariable <: VariableType end

function make_variable_name(
    ::Type{DeltaActivePowerUpVariable},
    ::Type{T},
) where {T <: PSY.Component}
    return encode_symbol(T, "ΔP_up")
end

function make_variable_name(
    ::Type{DeltaActivePowerUpVariable},
    ::Type{PSY.RegulationDevice{T}},
) where {T <: PSY.Device}
    return encode_symbol(T, "ΔP_up")
end

struct DeltaActivePowerDownVariable <: VariableType end

function make_variable_name(
    ::Type{DeltaActivePowerDownVariable},
    ::Type{T},
) where {T <: PSY.Component}
    return encode_symbol(T, "ΔP_dn")
end

function make_variable_name(
    ::Type{DeltaActivePowerDownVariable},
    ::Type{PSY.RegulationDevice{T}},
) where {T <: PSY.Device}
    return encode_symbol(T, "ΔP_dn")
end

struct AdditionalDeltaActivePowerUpVariable <: VariableType end

function make_variable_name(
    ::Type{AdditionalDeltaActivePowerUpVariable},
    ::Type{T},
) where {T <: PSY.Component}
    return encode_symbol(T, "ΔPe_up")
end

function make_variable_name(
    ::Type{AdditionalDeltaActivePowerUpVariable},
    ::Type{PSY.RegulationDevice{T}},
) where {T <: PSY.Device}
    return encode_symbol(T, "ΔPe_up")
end

struct AdditionalDeltaActivePowerDownVariable <: VariableType end

function make_variable_name(
    ::Type{AdditionalDeltaActivePowerDownVariable},
    ::Type{T},
) where {T <: PSY.Component}
    return encode_symbol(T, "ΔPe_dn")
end


function make_variable_name(
    ::Type{AdditionalDeltaActivePowerDownVariable},
    ::Type{PSY.RegulationDevice{T}},
) where {T <: PSY.Device}
    return encode_symbol(T, "ΔPe_dn")
end

function encode_symbol(::Type{T}, name1::AbstractString, name2::AbstractString) where {T}
    return Symbol(join((name1, name2, IS.strip_module_name(T)), PSI_NAME_DELIMITER))
end

function encode_symbol(
    ::Type{T},
    name1::AbstractString,
    name2::AbstractString,
) where {T <: PSY.Reserve}
    T_ = replace(IS.strip_module_name(T), "{" => "_")
    T_ = replace(T_, "}" => "")
    return Symbol(join((name1, name2, T_), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name1::Symbol, name2::Symbol) where {T}
    return encode_symbol(IS.strip_module_name(T), string(name1), string(name2))
end

function encode_symbol(::Type{T}, name::AbstractString) where {T}
    return Symbol(join((name, IS.strip_module_name(T)), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name::AbstractString) where {T <: PSY.Reserve}
    T_ = replace(IS.strip_module_name(T), "{" => "_")
    T_ = replace(T_, "}" => "")
    return Symbol(join((name, T_), PSI_NAME_DELIMITER))
end

function encode_symbol(::Type{T}, name::Symbol) where {T}
    return encode_symbol(T, string(name))
end

function encode_symbol(name::AbstractString)
    return Symbol(name)
end

function encode_symbol(name1::AbstractString, name2::AbstractString)
    return Symbol(join((name1, name2), PSI_NAME_DELIMITER))
end

function encode_symbol(name::Symbol)
    return name
end

function decode_symbol(name::Symbol)
    return split(String(name), PSI_NAME_DELIMITER)
end

make_variable_name(var_type, device_type) = encode_symbol(device_type, var_type)
make_variable_name(var_type) = encode_symbol(var_type)
