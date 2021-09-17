function calculate_ic_quantity(ic::InitialCondition, ::Float64, ::Dates.Period)
    error("Initial condition calculation for $(typeof(ic)) not implemented")
end

function calculate_ic_quantity(
    ic::InitialCondition{InitialTimeDurationOn, T},
    var_value::Float64,
    elapsed_period::Dates.Period,
) where {T <: Union{Float64, PJ.ParameterRef}}
    name = get_component_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0

    @assert abs(last_status - var_status) < ABSOLUTE_TOLERANCE
    last_status >= 1.0 ? current_counter : 0.0

    return
end

function calculate_ic_quantity(
    ic::InitialCondition{InitialTimeDurationOff, T},
    var_value::Float64,
    elapsed_period::Dates.Period,
) where {T <: Union{Float64, PJ.ParameterRef}}
    name = get_component_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0

    @assert abs(last_status - var_status) < ABSOLUTE_TOLERANCE
    last_status >= 1.0 ? 0.0 : current_counter
    return
end

function calculate_ic_quantity(
    ic::InitialCondition{DeviceStatus, T},
    var_value::Float64,
    elapsed_period::Dates.Period,
) where {T <: Union{Float64, PJ.ParameterRef}}
    current_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    return current_status
end

function calculate_ic_quantity(
    ic::InitialCondition{DevicePower, T},
    var_value::Float64,
    elapsed_period::Dates.Period,
) where {T <: Union{Float64, PJ.ParameterRef}} 
end

function calculate_ic_quantity(
    ic::InitialCondition{InitialEnergyLevel, T},
    var_value::Float64,
    ::Dates.Period,
) where {T <: Union{Float64, PJ.ParameterRef}}
    #cache = get_cache(simulation_cache, ic.cache_type, T)
    #name = get_component_name(ic)
    #energy_cache = cache_value(cache, name)
    #if energy_cache != var_value
    #    return var_value
    #end
    #
    return
end
