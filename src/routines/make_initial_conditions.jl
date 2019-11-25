const MISSING_INITIAL_CONDITIONS_TIME_COUNT = 999.0

"""
Status Initis is always calculated based on the Power Output of the device
This is to make it easier to calculate when the previous model doesn't
contain binaries. For instance, looking back on an ED model to find the
IC of the UC model
"""
function status_init(psi_container::PSIContainer,
                     devices::IS.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}
    key = ICKey(DeviceStatus, PSD)
    parameters = model_has_parameters(psi_container)
    length_devices = length(devices)
    ini_conds = get_initial_conditions(psi_container, key)
    # Improve here
    ref_key = parameters ? Symbol("P_$(PSD)") : :activepower

    if isempty(ini_conds)
        @info("Setting $(key.quantity) initial conditions for the status of all devices $(PSD) based on system data")
        ini_conds = psi_container.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)
        for (ix, g) in enumerate(devices)
            status_value = (PSY.get_activepower(g) > 0) ? 1.0 : 0.0
            ini_conds[ix] = InitialCondition(psi_container,
                                            g,
                                            ref_key,
                                            status_value)
        end
    else
        ic_devices = (ic.device for ic in ini_conds)
        for g in devices
            g in ic_devices && continue
            @info("Setting $(key.quantity) initial conditions for the status device $(g.name) based on system data")
                status_value = (PSY.get_activepower(g) > 0) ? 1.0 : 0.0
                push!(ini_conds, InitialCondition(psi_container,
                                                  g,
                                                  ref_key,
                                                  status_value))
        end
    end
    @assert length(ini_conds) == length(devices)
    return
end

function output_init(psi_container::PSIContainer,
                    devices::IS.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}
    key = ICKey(DevicePower, PSD)
    parameters = model_has_parameters(psi_container)
    length_devices = length(devices)
    ini_conds = get_initial_conditions(psi_container, key)
    # Improve this
    ref_key = parameters ? Symbol("P_$(PSD)") : :activepower

    if isempty(ini_conds)
        @info("Setting $(key.quantity) initial_condition of all devices $(PSD) based on system data")
        ini_conds = psi_container.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)
        for (ix, g) in enumerate(devices)
                ini_conds[ix] = InitialCondition(psi_container,
                                                g,
                                                ref_key,
                                                PSY.get_activepower(g),
                                                TimeStatusChange)
        end
    else
        ic_devices = (ic.device for ic in ini_conds)
        for g in devices
            g in ic_devices && continue
            @info("Setting $(key.quantity) initial_condition of device $(g.name) based on system data")
                push!(ini_conds, InitialCondition(psi_container,
                                                g,
                                                ref_key,
                                                PSY.get_activepower(g),
                                                TimeStatusChange))
        end
    end

    @assert length(ini_conds) == length(devices)
    return
end

function duration_init(psi_container::PSIContainer,
                        devices::IS.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}
    keys = [ICKey(TimeDurationON, PSD), ICKey(TimeDurationOFF, PSD)]
    parameters = model_has_parameters(psi_container)
    length_devices = length(devices)
    ref_key = parameters ? Symbol("P_$(PSD)") : :activepower

    for (ik, key) in enumerate(keys)
        ini_conds = get_initial_conditions(psi_container, key)

        if isempty(ini_conds)
            @info("Setting $(key.quantity) initial_condition of all devices $(PSD) based on system data")
            ini_conds = psi_container.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)
            for (ix, g) in enumerate(devices)
                time_on = (PSY.get_activepower(g) > 0) ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                time_off = PSY.get_activepower(g) <= 0 ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                times = [time_on, time_off]
                ini_conds[ix] = InitialCondition(psi_container,
                                                    g,
                                                    ref_key,
                                                    times[ik],
                                                    TimeStatusChange)
            end
        else
            ic_devices = (ic.device for ic in ini_conds if !isnothing(ic.cache))
            for g in devices
                g in ic_devices && continue
                time_on = (PSY.get_activepower(g) > 0) ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                time_off = PSY.get_activepower(g) <= 0 ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                times = [time_on, time_off]
                @info("Setting $(key.quantity) initial_condition of device $(g.name) based on system data")
                push!(ini_conds, InitialCondition(
                                                  psi_container,
                                                  g,
                                                  ref_key,
                                                  times[ik],
                                                  TimeStatusChange
                                                  )
                    )
            end

        end
        @assert length(ini_conds) == length(devices)
    end
    return
end

######################### Initialize Functions for Storage #################################

function storage_energy_init(psi_container::PSIContainer,
                             devices::IS.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.Storage}
    key = ICKey(DeviceEnergy, PSD)
    parameters = model_has_parameters(psi_container)
    length_devices = length(devices)
    ini_conds = get_initial_conditions(psi_container, key)
    ref_key = parameters ? Symbol("E_$(PSD)") : :energy

    if isempty(ini_conds)
        @info("Setting $(key.quantity) initial_condition of all devices $(PSD) based on system data")
        ini_conds = psi_container.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)

        for (ix, g) in enumerate(devices)
            ini_conds[ix] = InitialCondition(psi_container,
                                                g,
                                                ref_key,
                                                PSY.get_energy(g))
        end
    else
        ic_devices = (ic.device for ic in ini_conds)
        for g in devices
            g in ic_devices && continue
            @info("Setting $(key.quantity) initial_condition of device $(g.name) based on system data")
            push!(ini_conds, InitialCondition(psi_container,
                                            g,
                                            ref_key,
                                            PSY.get_energy(g)))
        end
    end

    @assert length(ini_conds) == length(devices)
    return
end

######################### Initialize Functions for Hydro #################################
function status_init(psi_container::PSIContainer,
                     devices::IS.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.HydroGen}
    key = ICKey(DeviceStatus, PSD)
    parameters = model_has_parameters(psi_container)
    length_devices = length(devices)
    ini_conds = get_initial_conditions(psi_container, key)
    # Improve here
    ref_key = parameters ? Symbol("P_$(PSD)") : :activepower

    if isempty(ini_conds)
        @info("Setting $(key.quantity) initial conditions for the status of all devices $(PSD) based on system data")
        ini_conds = psi_container.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)
        for (ix, g) in enumerate(devices)
            status_value = (PSY.get_activepower(g) > 0) ? 1.0 : 0.0
            ini_conds[ix] = InitialCondition(psi_container,
                                            g,
                                            ref_key,
                                            status_value)
        end
    else
        ic_devices = (ic.device for ic in ini_conds)
        for g in devices
            g in ic_devices && continue
            @info("Setting $(key.quantity) initial conditions for the status device $(g.name) based on system data")
                status_value = (PSY.get_activepower(g) > 0) ? 1.0 : 0.0
                push!(ini_conds, InitialCondition(psi_container,
                                                  g,
                                                  ref_key,
                                                  status_value))
        end
    end
    @assert length(ini_conds) == length(devices)
    return
end

function output_init(psi_container::PSIContainer,
                    devices::IS.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.HydroGen}
    key = ICKey(DevicePower, PSD)
    parameters = model_has_parameters(psi_container)
    length_devices = length(devices)
    ini_conds = get_initial_conditions(psi_container, key)
    # Improve this
    ref_key = parameters ? Symbol("P_$(PSD)") : :activepower

    if isempty(ini_conds)
        @info("Setting $(key.quantity) initial_condition of all devices $(PSD) based on system data")
        ini_conds = psi_container.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)
        for (ix, g) in enumerate(devices)
                ini_conds[ix] = InitialCondition(psi_container,
                                                g,
                                                ref_key,
                                                PSY.get_activepower(g),
                                                TimeStatusChange)
        end
    else
        ic_devices = (ic.device for ic in ini_conds)
        for g in devices
            g in ic_devices && continue
            @info("Setting $(key.quantity) initial_condition of device $(g.name) based on system data")
                push!(ini_conds, InitialCondition(psi_container,
                                                g,
                                                ref_key,
                                                PSY.get_activepower(g),
                                                TimeStatusChange))
        end
    end

    @assert length(ini_conds) == length(devices)
    return
end

function duration_init(psi_container::PSIContainer,
                        devices::IS.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.HydroGen}
    keys = [ICKey(TimeDurationON, PSD), ICKey(TimeDurationOFF, PSD)]
    parameters = model_has_parameters(psi_container)
    length_devices = length(devices)
    ref_key = parameters ? Symbol("P_$(PSD)") : :activepower

    for (ik, key) in enumerate(keys)
        ini_conds = get_initial_conditions(psi_container, key)
        if isempty(ini_conds)
            @info("Setting $(key.quantity) initial_condition of all devices $(PSD) based on system data")
            ini_conds = psi_container.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)

            for (ix, g) in enumerate(devices)
                time_on = (PSY.get_activepower(g) > 0) ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                time_off = PSY.get_activepower(g) <= 0 ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                times = [time_on, time_off]
                ini_conds[ix] = InitialCondition(psi_container,
                                                    g,
                                                    ref_key,
                                                    times[ik],
                                                    TimeStatusChange)
            end
        else
            ic_devices = (ic.device for ic in ini_conds if !isnothing(ic.cache))
            for g in devices
                g in ic_devices && continue
                time_on = (PSY.get_activepower(g) > 0) ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                time_off = PSY.get_activepower(g) <= 0 ? MISSING_INITIAL_CONDITIONS_TIME_COUNT : 0.0
                times = [time_on, time_off]
                @info("Setting $(key.quantity) initial_condition of device $(g.name) based on system data")
                push!(ini_conds, InitialCondition(
                                                  psi_container,
                                                  g,
                                                  ref_key,
                                                  times[ik],
                                                  TimeStatusChange
                                                  )
                    )
            end
        end

        @assert length(ini_conds) == length(devices)
    end
    return
end
