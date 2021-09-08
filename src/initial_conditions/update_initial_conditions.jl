######################### Initial Condition Updating #########################################
# TODO: Consider when more than one UC model is used for the stages that the counts need
# to be scaled.
function calculate_ic_quantity(
    ::ICKey{InitialTimeDurationOn, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
    elapsed_period::Dates.Period,
) where {T <: PSY.Component}
    cache = get_cache(simulation_cache, ic.cache_type, T)
    name = get_device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    @debug last_status, var_status, abs(last_status - var_status) _group =
        LOG_GROUP_INITIAL_CONDITIONS
    @assert abs(last_status - var_status) < ABSOLUTE_TOLERANCE

    return last_status >= 1.0 ? current_counter : 0.0
end

function calculate_ic_quantity(
    ::ICKey{InitialTimeDurationOff, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
    elapsed_period::Dates.Period,
) where {T <: PSY.Component}
    cache = get_cache(simulation_cache, ic.cache_type, T)
    name = get_device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    @debug last_status, var_status, abs(last_status - var_status) _group =
        LOG_GROUP_INITIAL_CONDITIONS
    @assert abs(last_status - var_status) < ABSOLUTE_TOLERANCE

    return last_status >= 1.0 ? 0.0 : current_counter
end

function calculate_ic_quantity(
    ::ICKey{DeviceStatus, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
    elapsed_period::Dates.Period,
) where {T <: PSY.Component}
    current_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    return current_status
end

function _get_active_power_min_limit(dev::T) where {T <: PSY.ThermalGen}
    min_power = PSY.get_active_power_limits(dev).min
    return min_power
end

function calculate_ic_quantity(
    ::ICKey{DevicePower, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
    elapsed_period::Dates.Period,
) where {T <: PSY.ThermalGen}
    cache = get_cache(simulation_cache, TimeStatusChange, T)
    # This code determines if there is a status change in the generators. Takes into account TimeStatusChange for the presence of UC stages.
    dev = get_device(ic)
    min_power = _get_active_power_min_limit(dev)
    if cache === nothing
        # Transitions can't be calculated without cache
        status_change_to_on =
            get_condition(ic) <= min_power && var_value >= ABSOLUTE_TOLERANCE
        status_change_to_off =
            get_condition(ic) >= min_power && var_value <= ABSOLUTE_TOLERANCE
        status_remains_off =
            get_condition(ic) <= min_power && var_value <= ABSOLUTE_TOLERANCE
        status_remains_on =
            get_condition(ic) >= min_power && var_value >= ABSOLUTE_TOLERANCE
    else
        # If the min is 0.0 this calculation doesn't matter
        name = get_device_name(ic)
        time_cache = cache_value(cache, name)
        series = time_cache[:series]
        elapsed_time = time_cache[:elapsed]
        if min_power > 0.0
            #off set by one since the first is the original initial conditions. Series is size
            # horizon + 1
            current = min(time_cache[:current] + 1, length(series)) # HACK
            current_status = isapprox(series[current], 1.0; atol = ABSOLUTE_TOLERANCE)
            # exception for the first time period and last.
            if current == 1
                previous_status = current_status
            else
                previous_status =
                    isapprox(series[current - 1], 1.0; atol = ABSOLUTE_TOLERANCE)
            end
            status_change_to_on = current_status && !previous_status
            status_change_to_off = !current_status && previous_status
            status_remains_on = current_status && previous_status
            status_remains_off = !current_status && !previous_status
        else
            status_remains_on = true
            status_remains_off = false
            status_change_to_off = false
            status_change_to_on = false
        end
        time_cache[:elapsed] += elapsed_period
        if time_cache[:elapsed] == cache.units
            time_cache[:current] += 1
            time_cache[:elapsed] = Dates.Second(0)
        end
    end

    if status_remains_off
        return 0.0
    elseif status_change_to_off
        return 0.0
    elseif status_change_to_on
        return min_power
    elseif status_remains_on
        return var_value
    else
        @assert false
    end
end

function calculate_ic_quantity(
    ::ICKey{DevicePower, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
    elapsed_period::Dates.Period,
) where {T <: PSY.Device}
    return var_value
end

function calculate_ic_quantity(
    ::ICKey{InitialEnergyLevel, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
    elapsed_period::Dates.Period,
) where {T <: PSY.Device}
    cache = get_cache(simulation_cache, ic.cache_type, T)
    name = get_device_name(ic)
    energy_cache = cache_value(cache, name)
    if energy_cache != var_value
        return var_value
    end
    return energy_cache
end

############################# Initial Conditions Initialization ############################
function add_initial_condition!(
    container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::D,
    initial_conditions_type::Type{<:InitialConditionType},
) where {
    T <: PSY.Component,
    D <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
}
    _make_initial_conditions!(
        container,
        devices,
        D(),
        nothing,
        ICKey(initial_conditions_type, T),
        _get_variable_initial_value,
    )
end

function add_initial_condition!(
    container::OptimizationContainer,
    devices::Union{Vector{T}, IS.FlattenIteratorWrapper{T}},
    ::D,
    initial_conditions_type::Type{<:InitialConditionType},
    variable_type::Type{<:VariableType},
) where {
    T <: PSY.Component,
    D <: Union{AbstractDeviceFormulation, AbstractServiceFormulation},
}
    _make_initial_conditions!(
        container,
        devices,
        D(),
        variable_type(),
        ICKey(initial_conditions_type, T),
        _get_variable_initial_value,
    )
end

function _make_initial_conditions!(
    container::OptimizationContainer,
    devices::Union{IS.FlattenIteratorWrapper{T}, Vector{T}},
    device_formulation::Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    variable_type::Union{Nothing, VariableType},
    key::ICKey,
    get_val_func::Function, # Function to get the value from the device to intialize
    cache = nothing,
) where {T <: PSY.Component}
    length_devices = length(devices)
    parameters = built_for_recurrent_solves(container)
    ic_container = get_initial_conditions(container)
    if !haskey(ic_container, key)
        @debug "Setting $(get_entry_type(key)) initial conditions for all devices $(T) based on system data" _group =
            LOG_GROUP_INITIAL_CONDITIONS
        ini_conds = Vector{InitialCondition}(undef, length_devices)
        set_initial_conditions!(container, key, ini_conds)
        for (ix, dev) in enumerate(devices)
            val_ = get_val_func(dev, key, device_formulation, variable_type)
            val = parameters ? add_jump_parameter(container.JuMPmodel, val_) : val_
            ic = InitialCondition(key, dev, val, cache)
            ini_conds[ix] = ic
            @debug "set initial condition" _group = LOG_GROUP_INITIAL_CONDITIONS key ic val_
        end
    end

    @assert length(ini_conds) == length_devices
    return
end

function _get_variable_initial_value(
    d::PSY.Component,
    ::ICKey,
    formulation::AbstractDeviceFormulation,
    variable_type::VariableType,
)
    return get_variable_initial_value(variable_type, d, formulation)
end

function _get_variable_initial_value(
    d::PSY.Component,
    key::ICKey,
    ::AbstractDeviceFormulation,
    ::Nothing,
)
    return _get_duration_value(d, key)
end

function _get_ace_error(device, key)
    return PSY.get_initial_ace(device)
end

function _get_duration_value(dev, key)
    if get_entry_type(key) == InitialTimeDurationOn
        value = PSY.get_status(dev) ? PSY.get_time_at_status(dev) : 0.0
    else
        @assert get_entry_type(key) == InitialTimeDurationOff
        value = !PSY.get_status(dev) ? PSY.get_time_at_status(dev) : 0.0
    end

    return value
end
