#########################Initial Condition Updating#########################################
# TODO: Consider when more than one UC model is used for the stages that the counts need
# to be scaled.
function calculate_ic_quantity(
    ::ICKey{TimeDurationON, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
) where {T <: PSY.Component}
    cache = get_cache(simulation_cache, ic.cache_type, T)
    name = device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    @debug last_status, var_status, abs(last_status - var_status)
    @assert abs(last_status - var_status) < ABSOLUTE_TOLERANCE

    return last_status >= 1.0 ? current_counter : 0.0
end

function calculate_ic_quantity(
    ::ICKey{TimeDurationOFF, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
) where {T <: PSY.Component}
    cache = get_cache(simulation_cache, ic.cache_type, T)
    name = device_name(ic)
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
) where {T <: PSY.Component}
    current_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    return current_status
end

function calculate_ic_quantity(
    ::ICKey{DevicePower, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
) where {T <: PSY.ThermalGen}
    cache = get_cache(simulation_cache, TimeStatusChange, T)
    # This code determines if there is a status change in the generators. Takes into account TimeStatusChange for the presence of UC stages.
    dev = get_device(ic)
    min_power = PSY.get_active_power_limits(dev).min
    if isnothing(cache)
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
        if min_power > 0.0
            name = device_name(ic)
            time_cache = cache_value(cache, name)
            series = time_cache[:series]
            current = min(time_cache[:current], length(series))
            urrent_status = isapprox(series[current], 1.0; atol = ABSOLUTE_TOLERANCE)
            previous_status = isapprox(series[current - 1], 1.0; atol = ABSOLUTE_TOLERANCE)
            status_change_to_on = current_status && !previous_status
            status_change_to_off = !current_status && previous_status
            status_remains_on = current_status && previous_status
            status_remains_off = !current_status && !previous_status
        else
            status_remains_on = true
        end
        time_cache[:current] += 1
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
) where {T <: PSY.Device}
    return var_value
end

function calculate_ic_quantity(
    ::ICKey{EnergyLevel, T},
    ic::InitialCondition,
    var_value::Float64,
    simulation_cache::Dict{<:CacheKey, AbstractCache},
) where {T <: PSY.Device}
    cache = get_cache(simulation_cache, ic.cache_type, T)
    name = device_name(ic)
    energy_cache = cache_value(cache, name)
    if energy_cache != var_value
        return var_value
    end
    return energy_cache
end

############################# Initial Conditions Initialization ############################
function _make_initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    key::ICKey,
    make_ic_func::Function, # Function to make the initial condition object
    get_val_func::Function, # Function to get the value from the device to intialize
    cache = nothing,
) where {T <: PSY.Component}
    length_devices = length(devices)
    parameters = model_has_parameters(psi_container)
    ic_container = get_initial_conditions(psi_container)
    if !has_initial_conditions(ic_container, key)
        @debug "Setting $(key.ic_type) initial conditions for all devices $(T) based on system data"
        ini_conds = Vector{InitialCondition}(undef, length_devices)
        set_initial_conditions!(ic_container, key, ini_conds)
        for (ix, dev) in enumerate(devices)
            val_ = get_val_func(dev, key)
            val = parameters ? PJ.add_parameter(psi_container.JuMPmodel, val_) : val_
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
            val_ = get_val_func(dev, key)
            val = parameters ? PJ.add_parameter(psi_container.JuMPmodel, val_) : val_
            ic = make_ic_func(ic_container, dev, val, cache)
            push!(ini_conds, ic)
            @debug "set initial condition" key ic val_
        end
    end

    @assert length(ini_conds) == length_devices
    return
end

######################### Initialize Functions for ThermalGen ##############################
"""
Status Init is always calculated based on the Power Output of the device
This is to make it easier to calculate when the previous model doesn't
contain binaries. For instance, looking back on an ED model to find the
IC of the UC model
"""
function status_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    _make_initial_conditions!(
        psi_container,
        devices,
        ICKey(DeviceStatus, T),
        _make_initial_condition_active_power,
        _get_status_value,
    )

    return
end

function output_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    _make_initial_conditions!(
        psi_container,
        devices,
        ICKey(DevicePower, T),
        _make_initial_condition_active_power,
        _get_active_power_output_value,
    )
    return
end

function output_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
)
    _make_initial_conditions!(
        psi_container,
        devices,
        ICKey(DevicePower, PSY.ThermalMultiStart),
        _make_initial_condition_active_power,
        _get_active_power_output_above_min_value,
    )
end

function duration_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    for key in (ICKey(TimeDurationON, T), ICKey(TimeDurationOFF, T))
        _make_initial_conditions!(
            psi_container,
            devices,
            key,
            _make_initial_condition_active_power,
            _get_duration_value,
            TimeStatusChange,
        )
    end

    return
end

######################### Initialize Functions for Storage #################################
# TODO: This IC needs a cache for Simulation over long periods of tim
function storage_energy_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.Storage}
    key = ICKey(EnergyLevel, T)
    _make_initial_conditions!(
        psi_container,
        devices,
        key,
        _make_initial_condition_energy,
        _get_initial_energy_value,
    )

    return
end

######################### Initialize Functions for Hydro #################################
function status_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    _make_initial_conditions!(
        psi_container,
        devices,
        ICKey(DeviceStatus, T),
        _make_initial_condition_active_power,
        _get_status_value,
        # Doesn't require Cache
    )
end

function output_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    _make_initial_conditions!(
        psi_container,
        devices,
        ICKey(DevicePower, T),
        _make_initial_condition_active_power,
        _get_active_power_output_value,
        # Doesn't require Cache
    )

    return
end

function duration_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    for key in (ICKey(TimeDurationON, T), ICKey(TimeDurationOFF, T))
        _make_initial_conditions!(
            psi_container,
            devices,
            key,
            _make_initial_condition_active_power,
            _get_duration_value,
            TimeStatusChange,
        )
    end

    return
end

function storage_energy_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    key = ICKey(EnergyLevel, T)
    _make_initial_conditions!(
        psi_container,
        devices,
        key,
        _make_initial_condition_reservoir_energy,
        _get_reservoir_energy_value,
        StoredEnergy,
    )

    return
end

function area_control_init(
    psi_container::PSIContainer,
    services::IS.FlattenIteratorWrapper{PSY.AGC},
)
    key = ICKey(AreaControlError, PSY.AGC)
    _make_initial_conditions!(
        psi_container,
        services,
        key,
        _make_initial_condition_area_control,
        _get_ace_error,
        # Doesn't require Cache
    )

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

function _make_initial_condition_area_control(
    container,
    device::PSY.AGC,
    value,
    cache = nothing,
)
    return InitialCondition(device, _get_ref_ace_error(PSY.AGC, container), value, cache)
end

function _get_status_value(device, key)
    return PSY.get_status(device) ? 1.0 : 0.0
end

function _get_active_power_output_value(device, key)
    if !PSY.get_status(device)
        return 0.0
    end
    return PSY.get_active_power(device)
end

function _get_active_power_output_above_min_value(device, key)
    if !PSY.get_status(device)
        return 0.0
    end
    power_above_min = PSY.get_active_power(device) - PSY.get_active_power_limits(device).min
    PSY.get_name(device)
    @assert power_above_min >= -ABSOLUTE_TOLERANCE
    return power_above_min
end

function _get_initial_energy_value(device, key)
    return PSY.get_initial_energy(device)
end

function _get_reservoir_energy_value(device, key)
    return PSY.get_initial_storage(device)
end

function _get_ace_error(device, key)
    return PSY.get_initial_ace(device)
end

function _get_duration_value(dev, key)
    if key.ic_type == TimeDurationON
        value = PSY.get_status(dev) ? PSY.get_time_at_status(dev) : 0.0
    else
        @assert key.ic_type == TimeDurationOFF
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
        return UpdateRef{T}(ACTIVE_POWER, "get_active_power")
    end
end

function _get_ref_energy(::Type{T}, container::InitialConditions) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "get_initial_energy")
end

function _get_ref_reservoir_energy(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "get_storage_capacity")
end
function _get_ref_ace_error(::Type{PSY.AGC}, container::InitialConditions)
    T = PSY.AGC
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, "ACE") :
           UpdateRef{T}("ACE", "get_initial_ace")
end
