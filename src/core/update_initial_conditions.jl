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
    @debug last_status, var_status, abs(last_status - var_status)
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
    @debug last_status, var_status, abs(last_status - var_status)
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
function _make_initial_conditions!(
    optimization_container::OptimizationContainer,
    devices::Union{IS.FlattenIteratorWrapper{T}, Vector{T}},
    device_formulation::Union{AbstractDeviceFormulation, AbstractServiceFormulation},
    variable_type::Union{Nothing, VariableType},
    key::ICKey,
    make_ic_func::Function, # Function to make the initial condition object
    get_val_func::Function, # Function to get the value from the device to intialize
    cache = nothing,
) where {T <: PSY.Component}
    length_devices = length(devices)
    parameters = model_has_parameters(optimization_container)
    ic_container = get_initial_conditions(optimization_container)
    if !has_initial_conditions(ic_container, key)
        @debug "Setting $(key.ic_type) initial conditions for all devices $(T) based on system data"
        ini_conds = Vector{InitialCondition}(undef, length_devices)
        set_initial_conditions!(ic_container, key, ini_conds)
        for (ix, dev) in enumerate(devices)
            val_ = get_val_func(dev, key, device_formulation, variable_type)
            val = parameters ? add_parameter(optimization_container.JuMPmodel, val_) : val_
            ic = make_ic_func(ic_container, dev, val, cache)
            ini_conds[ix] = ic
            @debug "set initial condition" key ic val_
        end
    else
        ini_conds = get_initial_conditions(ic_container, key)
        ic_devices = Set((IS.get_uuid(ic.device) for ic in ini_conds))
        for dev in devices
            IS.get_uuid(dev) in ic_devices && continue
            @debug "Setting $(key.ic_type) initial conditions device $(PSY.get_name(dev)) based on system data"
            val_ = get_val_func(dev, key, device_formulation, variable_type)
            val = parameters ? add_parameter(optimization_container.JuMPmodel, val_) : val_
            ic = make_ic_func(ic_container, dev, val, cache)
            push!(ini_conds, ic)
            @debug "set initial condition" key ic val_
        end
    end

    @assert length(ini_conds) == length_devices
    return
end

function _make_initial_condition_active_power(
    container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(device, _get_ref_active_power(T, container), value, cache)
end

function _make_initial_condition_status(
    container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(device, _get_ref_on_status(T, container), value, cache)
end

function _make_initial_condition_energy(
    container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(device, _get_ref_energy(T, container), value, cache)
end

function _make_initial_condition_reservoir_energy(
    container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(device, _get_ref_reservoir_energy(T, container), value, cache)
end

function _make_initial_condition_reservoir_energy_up(
    container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(
        device,
        _get_ref_reservoir_energy_up(T, container),
        value,
        cache,
    )
end

function _make_initial_condition_reservoir_energy_down(
    container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(
        device,
        _get_ref_reservoir_energy_down(T, container),
        value,
        cache,
    )
end

function _make_initial_condition_area_control(
    container,
    device::PSY.AGC,
    value,
    cache = nothing,
)
    return InitialCondition(device, _get_ref_ace_error(PSY.AGC, container), value, cache)
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
    if key.ic_type == InitialTimeDurationOn
        value = PSY.get_status(dev) ? PSY.get_time_at_status(dev) : 0.0
    else
        @assert key.ic_type == InitialTimeDurationOff
        value = !PSY.get_status(dev) ? PSY.get_time_at_status(dev) : 0.0
    end

    return value
end

function _get_ref_active_power(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    if get_use_parameters(container)
        return UpdateRef{JuMP.VariableRef}(T, ACTIVE_POWER)
    else
        return UpdateRef{T}(ACTIVE_POWER, "active_power")
    end
end

function _get_ref_on_status(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    if get_use_parameters(container)
        return UpdateRef{JuMP.VariableRef}(T, ON)
    else
        return UpdateRef{T}(ON, "On")
    end
end

function _get_ref_energy(::Type{T}, container::InitialConditions) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "initial_energy")
end

function _get_ref_energy(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.HybridSystem}
    return get_use_parameters(container) ?
           UpdateRef{JuMP.VariableRef}(T, SUBCOMPONENT_ENERGY) :
           UpdateRef{T}(SUBCOMPONENT_ENERGY, "initial_energy")
end

function _get_ref_reservoir_energy(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "hydro_budget")
end

function _get_ref_reservoir_energy_up(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY_UP) :
           UpdateRef{T}(ENERGY_UP, "get_hydro_budget")
end

function _get_ref_reservoir_energy_down(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY_DOWN) :
           UpdateRef{T}(ENERGY_DOWN, "get_hydro_budget")
end

function _get_ref_ace_error(::Type{PSY.AGC}, container::InitialConditions)
    T = PSY.AGC
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, "ACE") :
           UpdateRef{T}("ACE", "initial_ace")
end
