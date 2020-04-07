#########################Initial Condition Updating#########################################
# TODO: Consider when more than one UC model is used for the stages that the counts need
# to be scaled.
function calculate_ic_quantity(
    initial_condition_key::ICKey{TimeDurationON, T},
    ic::InitialCondition,
    var_value::Float64,
    cache::TimeStatusChange,
) where {T <: PSY.Component}
    name = device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    @assert abs(last_status - var_status) < ABSOLUTE_TOLERANCE

    return last_status >= 1.0 ? current_counter : 0.0
end

function calculate_ic_quantity(
    initial_condition_key::ICKey{TimeDurationOFF, T},
    ic::InitialCondition,
    var_value::Float64,
    cache::TimeStatusChange,
) where {T <: PSY.Component}
    name = device_name(ic)
    time_cache = cache_value(cache, name)

    current_counter = time_cache[:count]
    last_status = time_cache[:status]
    var_status = isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
    @assert abs(last_status - var_status) < ABSOLUTE_TOLERANCE

    return last_status >= 1.0 ? 0.0 : current_counter
end

function calculate_ic_quantity(
    initial_condition_key::ICKey{DeviceStatus, T},
    ic::InitialCondition,
    var_value::Float64,
    cache::Union{Nothing, AbstractCache},
) where {T <: PSY.Component}
    return isapprox(var_value, 0.0, atol = ABSOLUTE_TOLERANCE) ? 0.0 : 1.0
end

function calculate_ic_quantity(
    initial_condition_key::ICKey{DevicePower, T},
    ic::InitialCondition,
    var_value::Float64,
    cache::Union{Nothing, AbstractCache},
) where {T <: PSY.ThermalGen}
    status_change_to_on =
        get_condition(ic) <= ABSOLUTE_TOLERANCE && var_value >= ABSOLUTE_TOLERANCE
    status_change_to_off =
        get_condition(ic) >= ABSOLUTE_TOLERANCE && var_value <= ABSOLUTE_TOLERANCE
    if status_change_to_on
        return ic.device.tech.activepowerlimits.min
    end

    if status_change_to_off
        return 0.0
    end

    return var_value
end

function calculate_ic_quantity(
    initial_condition_key::ICKey{EnergyLevel, T},
    ic::InitialCondition,
    var_value::Float64,
    cache::Union{Nothing, AbstractCache},
) where {T <: PSY.Component}

    name = device_name(ic)
    energy_cache = cache_value(cache, name)
    if energy_cache != var_value
        return var_value
    end
    return energy_cache
end

"""
Status Init is always calculated based on the Power Output of the device
This is to make it easier to calculate when the previous model doesn't
contain binaries. For instance, looking back on an ED model to find the
IC of the UC model
"""
function status_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    _make_initial_conditions!(
        container,
        devices,
        ICKey(DeviceStatus, T),
        _make_initial_condition_active_power,
        _get_active_power_status_value,
    )

    return
end

function output_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    _make_initial_conditions!(
        container,
        devices,
        ICKey(DevicePower, T),
        _make_initial_condition_active_power,
        _get_active_power_output_value,
    )

    return
end

function duration_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    for key in (ICKey(TimeDurationON, T), ICKey(TimeDurationOFF, T))
        _make_initial_conditions!(
            container,
            devices,
            key,
            _make_initial_condition_active_power,
            _get_active_power_duration_value,
            TimeStatusChange,
        )
    end

    return
end

######################### Initialize Functions for Storage #################################
# TODO: This IC needs a cache for Simulation over long periods of tim
function storage_energy_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.Storage}
    key = ICKey(EnergyLevel, T)
    _make_initial_conditions!(
        container,
        devices,
        key,
        _make_initial_condition_energy,
        _get_energy_value,
    )

    return
end

######################### Initialize Functions for Hydro #################################
function status_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    _make_initial_conditions!(
        container,
        devices,
        ICKey(DeviceStatus, T),
        _make_initial_condition_active_power,
        _get_active_power_status_value,
        # Doesn't require Cache
    )
end

function output_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    _make_initial_conditions!(
        container,
        devices,
        ICKey(DevicePower, T),
        _make_initial_condition_active_power,
        _get_active_power_output_value,
        # Doesn't require Cache
    )

    return
end

function duration_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    for key in (ICKey(TimeDurationON, T), ICKey(TimeDurationOFF, T))
        _make_initial_conditions!(
            container,
            devices,
            key,
            _make_initial_condition_active_power,
            _get_active_power_duration_value,
            TimeStatusChange,
        )
    end

    return
end

function storage_energy_init(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    key = ICKey(EnergyLevel, T)
    _make_initial_conditions!(
        container,
        devices,
        key,
        _make_initial_condition_reservoir_energy,
        _get_reservoir_energy_value,
        StoredEnergy,
    )

    return
end

function _make_initial_conditions!(
    container::InitialConditions,
    devices::IS.FlattenIteratorWrapper{T},
    key::ICKey,
    make_ic_func::Function,
    get_val_func::Function,
    cache = nothing,
) where {T <: PSY.Device}
    length_devices = length(devices)

    if !has_initial_conditions(container, key)
        @debug "Setting $(key.ic_type) initial conditions for the status of all devices $(T) based on system data"
        ini_conds = Vector{InitialCondition}(undef, length_devices)
        set_initial_conditions!(container, key, ini_conds)
        for (ix, dev) in enumerate(devices)
            val = get_val_func(dev, key)
            ic = make_ic_func(container, dev, val, cache)
            ini_conds[ix] = ic
            @IS.record :simulation InitialConditionUpdateEvent(
                Dates.DateTime(1970, 1, 1),
                key,
                ic,
                val,
                0,
            )
        end
    else
        ini_conds = get_initial_conditions(container, key)
        ic_devices = Set((IS.get_uuid(ic.device) for ic in ini_conds))
        for dev in devices
            IS.get_uuid(dev) in ic_devices && continue
            @debug "Setting $(key.ic_type) initial conditions for the status device $(PSY.get_name(dev)) based on system data"
            val = get_val_func(dev, key)
            ic = make_ic_func(container, dev, val, cache)
            push!(ini_conds, ic)
            @IS.record :simulation InitialConditionUpdateEvent(
                Dates.DateTime(1970, 1, 1),
                key,
                ic,
                val,
                0,
            )
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

function _get_active_power_status_value(device, key)
    return PSY.get_activepower(device) > 0 ? 1.0 : 0.0
end

function _get_active_power_output_value(device, key)
    return PSY.get_activepower(device)
end

function _get_energy_value(device, key)
    return PSY.get_energy(device)
end

function _get_reservoir_energy_value(device, key)
    return PSY.get_initial_storage(device)
end

function _get_active_power_duration_value(dev, key)
    if key.ic_type == TimeDurationON
        value = PSY.get_activepower(dev) > 0 ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
    else
        @assert key.ic_type == TimeDurationOFF
        value = PSY.get_activepower(dev) <= 0 ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
    end

    return value
end

function _get_ref_active_power(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ACTIVE_POWER) :
           UpdateRef{T}(ACTIVE_POWER, "get_activepower")
end

function _get_ref_energy(::Type{T}, container::InitialConditions) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "get_energy")
end

function _get_ref_reservoir_energy(
    ::Type{T},
    container::InitialConditions,
) where {T <: PSY.Component}
    return get_use_parameters(container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "get_storage_capacity")
end
