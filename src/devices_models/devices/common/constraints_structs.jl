abstract type AbstractConstraintInfo end

get_component_name(d::AbstractConstraintInfo) = d.component_name

abstract type AbstractRampConstraintInfo <: AbstractConstraintInfo end
abstract type AbstractRangeConstraintInfo <: AbstractConstraintInfo end

# Pending for refactoring
struct DeviceRampConstraintInfo <: AbstractRampConstraintInfo
    component_name::String
    limits::MinMax
    ic_power::InitialCondition
    ramp_limits::UpDown
    additional_terms_ub::Vector{VariableKey}
    additional_terms_lb::Vector{VariableKey}
end

function DeviceRampConstraintInfo(
    component_name::String,
    limits::PSY.Min_Max,
    ic_power::InitialCondition,
    ramp_limits::UpDown,
)
    return DeviceRampConstraintInfo(
        component_name,
        limits,
        ic_power,
        ramp_limits,
        Vector{VariableKey}(),
        Vector{VariableKey}(),
    )
end

function DeviceRampConstraintInfo(component_name::String, ic_power::InitialCondition)
    return DeviceRampConstraintInfo(
        component_name,
        (min = -Inf, max = Inf),
        ic_power,
        (up = Inf, down = Inf),
    )
end

get_limits(d::DeviceRampConstraintInfo) = d.limits
get_ic_power(d::DeviceRampConstraintInfo) = d.ic_power
get_ramp_limits(d::DeviceRampConstraintInfo) = d.ramp_limits
get_additional_terms_ub(d::DeviceRampConstraintInfo) = d.additional_terms_ub
get_additional_terms_lb(d::DeviceRampConstraintInfo) = d.additional_terms_lb

struct ServiceRampConstraintInfo <: AbstractRampConstraintInfo
    component_name::String
    ramp_limits::UpDown
end

struct ReserveRangeConstraintInfo
    component_name::String
    limits::MinMax
    efficiency::InOut
    time_frames::Dict{Tuple{Symbol, VariableType}, Float64}
    additional_terms_up::Vector{Tuple{Symbol, VariableType}}
    additional_terms_dn::Vector{VariableType}
    component_type::Type{<:PSY.Component}
end

function ReserveRangeConstraintInfo(
    name::String,
    limits::MinMax,
    efficiency::InOut,
    ::Type{T},
) where {T <: PSY.Component}
    return ReserveRangeConstraintInfo(
        name,
        limits,
        efficiency,
        Dict{Symbol, Float64}(),
        Vector{VariableType}(),
        Vector{VariableType}(),
        T,
    )
end

get_component_name(d::ReserveRangeConstraintInfo) = d.component_name
get_component_type(d::ReserveRangeConstraintInfo) = d.component_type
get_time_frames(v::ReserveRangeConstraintInfo) = v.time_frames
get_time_frame(v::ReserveRangeConstraintInfo, name::Symbol) = v.time_frames[name]
set_time_frame!(v::ReserveRangeConstraintInfo, value::Pair{Symbol, Float64}) =
    push!(v.time_frames, value)
