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

struct ActivePowerVariable <: VariableType end

function make_variable_name(::Type{ActivePowerVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, ACTIVE_POWER)
end

struct ActivePowerInVariable <: VariableType end

function make_variable_name(
    ::Type{ActivePowerInVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, ACTIVE_POWER_IN)
end

struct ActivePowerOutVariable <: VariableType end

function make_variable_name(
    ::Type{ActivePowerOutVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, ACTIVE_POWER_OUT)
end

struct AreaMismatchVariable <: VariableType end

function make_variable_name(::Type{AreaMismatchVariable})
    return encode_symbol(AREA_MISMATCH)
end

struct ColdStartVariable <: VariableType end

function make_variable_name(::Type{ColdStartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, COLD_START)
end

struct EnergyVariable <: VariableType end

function make_variable_name(::Type{EnergyVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, ENERGY)
end

struct HotStartVariable <: VariableType end

function make_variable_name(::Type{HotStartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, HOT_START)
end

struct LiftVariable <: VariableType end

function make_variable_name(::Type{LiftVariable})
    return encode_symbol(LIFT)
end

struct OnVariable <: VariableType end

function make_variable_name(::Type{OnVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, ON)
end

struct ReactivePowerVariable <: VariableType end

function make_variable_name(
    ::Type{ReactivePowerVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, REACTIVE_POWER)
end

struct ReserveVariable <: VariableType end

function make_variable_name(::Type{ReserveVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, RESERVE)
end

struct ActiveServiceVariable <: VariableType end

struct ServiceRequirementVariable <: VariableType end

function make_variable_name(
    ::Type{ServiceRequirementVariable},
    ::Type{T},
) where {T <: PSY.Component}
    return encode_symbol(T, SERVICE_REQUIREMENT)
end

struct SpillageVariable <: VariableType end

function make_variable_name(::Type{SpillageVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, SPILLAGE)
end

struct StartVariable <: VariableType end

function make_variable_name(::Type{StartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, START)
end

struct StopVariable <: VariableType end

function make_variable_name(::Type{StopVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, STOP)
end

struct WarmStartVariable <: VariableType end

function make_variable_name(::Type{WarmStartVariable}, ::Type{T}) where {T <: PSY.Device}
    return encode_symbol(T, WARM_START)
end

struct DeltaActivePowerUpVariable <: VariableType end

function make_variable_name(
    ::Type{DeltaActivePowerUpVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, "ΔP_up")
end

struct DeltaActivePowerDownVariable <: VariableType end

function make_variable_name(
    ::Type{DeltaActivePowerDownVariable},
    ::Type{T},
) where {T <: PSY.Device}
    return encode_symbol(T, "ΔP_dn")
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
