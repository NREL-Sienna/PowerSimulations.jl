struct DevicePower <: InitialConditionQuantity end
struct DeviceStatus <: InitialConditionQuantity end
struct TimeDurationON <: InitialConditionQuantity end
struct TimeDurationOFF <: InitialConditionQuantity end
struct DeviceEnergy <: InitialConditionQuantity end

mutable struct InitialCondition{T<:Union{PJ.ParameterRef,Float64}}
    device::PSY.Device
    update_ref::UpdateRef
    value::T
    cache::Union{Nothing,Type{<:AbstractCache}}
end

function InitialCondition(
    device::PSY.Device,
    access_ref::UpdateRef,
    value::T,
) where {T<:Union{PJ.ParameterRef,Float64}}
    return InitialCondition(device, access_ref, value, nothing)
end

struct ICKey{IC<:InitialConditionQuantity,D<:PSY.Device}
    quantity::Type{IC}
    device_type::Type{D}
end

const DICKDA = Dict{ICKey,Array{InitialCondition}}

function value(p::InitialCondition{Float64})
    return p.value
end

function value(p::InitialCondition{PJ.ParameterRef})
    return PJ.value(p.value)
end

get_condition(ic::InitialCondition) = ic.value

device_name(ini_cond::InitialCondition) = PSY.get_name(ini_cond.device)

#########################Initial Condition Updating#########################################
# TODO: Consider when more than one UC model is used for the stages that the counts need
# to be scaled.
function calculate_ic_quantity(
    initial_condition_key::ICKey{TimeDurationOFF,PSD},
    ic::InitialCondition,
    var_value::Float64,
    cache::Union{Nothing,AbstractCache},
) where {PSD<:PSY.Device}
    name = device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ComparisonTolerance) ? 0.0 : 1.0
    @assert abs(last_status - var_status) < ComparisonTolerance

    if last_status >= 1.0
        return current_counter
    end

    if last_status < 1.0
        return 0.0
    end
end

function calculate_ic_quantity(
    initial_condition_key::ICKey{TimeDurationON,PSD},
    ic::InitialCondition,
    var_value::Float64,
    cache::Union{Nothing,AbstractCache},
) where {PSD<:PSY.Device}
    name = device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ComparisonTolerance) ? 0.0 : 1.0
    @assert abs(last_status - var_status) < ComparisonTolerance

    if last_status >= 1.0
        return 0.0
    end

    if last_status < 1.0
        return current_counter
    end

end

function calculate_ic_quantity(
    initial_condition_key::ICKey{DeviceStatus,PSD},
    ic::InitialCondition,
    var_value::Float64,
    cache::Union{Nothing,AbstractCache},
) where {PSD<:PSY.Device}
    return isapprox(var_value, 0.0, atol = ComparisonTolerance) ? 0.0 : 1.0
end

function calculate_ic_quantity(
    initial_condition_key::ICKey{DevicePower,PSD},
    ic::InitialCondition,
    var_value::Float64,
    cache::Union{Nothing,AbstractCache},
) where {PSD<:PSY.ThermalGen}
    if isnothing(cache)
        status_change_to_on =
            value(ic) <= ComparisonTolerance && var_value >= ComparisonTolerance
        status_change_to_off =
            value(ic) >= ComparisonTolerance && var_value <= ComparisonTolerance
    else
        name = device_name(ic)
        time_cache = cache_value(cache, name)
        status_change_to_on =
            time_cache[:status] >= ComparisonTolerance && var_value <= ComparisonTolerance
        status_change_to_off =
            time_cache[:status] <= ComparisonTolerance && var_value >= ComparisonTolerance
    end


    if status_change_to_on
        return ic.device.tech.activepowerlimits.min
    end

    if status_change_to_off
        return 0.0
    end

    return var_value
end
