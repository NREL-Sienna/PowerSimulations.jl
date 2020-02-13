const MISSING_INITIAL_CONDITIONS_TIME_COUNT = 999.0

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
        _get_active_power_status_value,
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
        TimeStatusChange,
    )

    return
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
            _get_active_power_duration_value,
            TimeStatusChange,
        )
    end

    return
end

######################### Initialize Functions for Storage #################################

function storage_energy_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.Storage}
    key = ICKey(DeviceEnergy, T)
    _make_initial_conditions!(
        psi_container,
        devices,
        ICKey(DeviceEnergy, T),
        _make_initial_condition_energy,
        _get_energy_value,
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
        _get_active_power_status_value,
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
            _get_active_power_duration_value,
            TimeStatusChange,
        )
    end

    return
end

function storage_energy_init(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.HydroGen}
    key = ICKey(DeviceEnergy, T)
    _make_initial_conditions!(
        psi_container,
        devices,
        ICKey(DeviceEnergy, T),
        _make_initial_condition_reservoir_energy,
        _get_reservoir_energy_value,
    )

    return
end

function _make_initial_conditions!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{T},
    key::ICKey,
    make_ic_func::Function,
    get_val_func::Function,
    cache = nothing,
) where {T <: PSY.Device}
    length_devices = length(devices)

    if !has_initial_conditions(psi_container, key)
        @debug "Setting $(key.ic_type) initial conditions for the status of all devices $(T) based on system data"
        ini_conds = Vector{InitialCondition}(undef, length_devices)
        set_initial_conditions!(psi_container, key, ini_conds)
        for (ix, dev) in enumerate(devices)
            ini_conds[ix] = make_ic_func(psi_container, dev, get_val_func(dev, key), cache)
        end
    else
        ini_conds = get_initial_conditions(psi_container, key)
        ic_devices = Set((IS.get_uuid(ic.device) for ic in ini_conds))
        for dev in devices
            IS.get_uuid(dev) in ic_devices && continue
            @debug "Setting $(key.ic_type) initial conditions for the status device $(PSY.get_name(dev)) based on system data"
            push!(
                ini_conds,
                make_ic_func(psi_container, dev, get_val_func(dev, key), cache),
            )
        end
    end

    @assert length(ini_conds) == length_devices
    return
end

function _make_initial_condition_active_power(
    psi_container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(
        psi_container,
        device,
        _get_ref_active_power(T, psi_container),
        value,
        cache,
    )
end

function _make_initial_condition_energy(
    psi_container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(
        psi_container,
        device,
        _get_ref_energy(T, psi_container),
        value,
        cache,
    )
end

function _make_initial_condition_reservoir_energy(
    psi_container,
    device::T,
    value,
    cache = nothing,
) where {T <: PSY.Component}
    return InitialCondition(
        psi_container,
        device,
        _get_ref_reservoir_energy(T, psi_container),
        value,
        cache,
    )
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
    psi_container::PSIContainer,
) where {T <: PSY.Component}
    return model_has_parameters(psi_container) ?
           UpdateRef{JuMP.VariableRef}(T, ACTIVE_POWER) :
           UpdateRef{T}(ACTIVE_POWER, "get_activepower")
end

function _get_ref_energy(::Type{T}, psi_container::PSIContainer) where {T <: PSY.Component}
    return model_has_parameters(psi_container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "get_energy")
end

function _get_ref_reservoir_energy(
    ::Type{T},
    psi_container::PSIContainer,
) where {T <: PSY.Component}
    # TODO: reviewers, is ENERGY correct here?
    return model_has_parameters(psi_container) ? UpdateRef{JuMP.VariableRef}(T, ENERGY) :
           UpdateRef{T}(ENERGY, "get_storage_capacity")
end
