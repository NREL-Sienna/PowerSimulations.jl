######################### Initialize Functions for Storage #################################
function status_init(canonical_model::CanonicalModel,
                     devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}


    key = Symbol("ON_$(PSD)")
    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)
    ini_conds = get_ini_cond(canonical_model, key)

    if isempty(ini_conds)
        @info("Setting initial conditions for the status of all devices $(PSD) based on system data")
        ini_conds = canonical_model.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)

        for (ix, g) in enumerate(devices)
            if parameters
                ini_conds[ix] = InitialCondition(g,
                                                PJ.add_parameter(canonical_model.JuMPmodel,
                                                1.0*(PSY.get_activepower(g) > 0)))
            else
                ini_conds[ix] = InitialCondition(g,
                                                1.0*(PSY.get_activepower(g) > 0))
            end
        end

    else

        ic_devices = (ic.device for ic in ini_conds)
        for g in devices
            g in ic_devices && continue
            @info("Setting initial conditions for the status device $(g.name) based on system data")
            if parameters
                push!(ini_conds, InitialCondition(g,
                                                PJ.add_parameter(canonical_model.JuMPmodel,
                                                1.0*(PSY.get_activepower(g) > 0))))
            else
                push!(ini_conds, InitialCondition(g,
                                                1.0*(PSY.get_activepower(g) > 0)))
            end
        end

    end

    @assert length(ini_conds) == length(devices)

    return

end

function output_init(canonical_model::CanonicalModel,
                    devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}

    key = Symbol("P_$(PSD)")
    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)
    ini_conds = get_ini_cond(canonical_model, key)

    if isempty(ini_conds)
        @info("Setting $(key) initial_condition of all devices $(PSD) based on system data")
        ini_conds = canonical_model.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)

        for (ix, g) in enumerate(devices)
            if parameters
                ini_conds[ix] = InitialCondition(g,
                                                PJ.add_parameter(canonical_model.JuMPmodel,
                                                PSY.get_activepower(g)))
            else
                ini_conds[ix] = InitialCondition(g,
                                                PSY.get_activepower(g))
            end
        end

    else

        ic_devices = (ic.device for ic in ini_conds)

        for g in devices
            g in ic_devices && continue
            @info("Setting $(key) initial_condition of device $(g.name) based on system data")
            if parameters
                push!(ini_conds, InitialCondition(g,
                                                PJ.add_parameter(canonical_model.JuMPmodel,
                                                PSY.get_activepower(g))))
            else
                push!(ini_conds, InitialCondition(g, PSY.get_activepower(g)))
            end
        end

    end

    @assert length(ini_conds) == length(devices)

    return

end

function duration_init(canonical_model::CanonicalModel,
                        devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}

    keys = [Symbol("duration_on_$(PSD)"), Symbol("duration_off_$(PSD)")]
    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    for (ik, key) in enumerate(keys)
        ini_conds = get_ini_cond(canonical_model, key)

        if isempty(ini_conds)
            @info("Setting $(key) initial_condition of all devices $(PSD) based on system data")
            ini_conds = canonical_model.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)

            for (ix, g) in enumerate(devices)
                times = [999.0*(PSY.get_activepower(g) > 0),  # Time on
                         999.0*(PSY.get_activepower(g) <= 0)] # Time off

                if parameters
                    ini_conds[ix] = InitialCondition(g,
                                    PJ.add_parameter(canonical_model.JuMPmodel, times[ik]))
                else
                    ini_conds[ix] = InitialCondition(g, times[ik])
                end

            end

        else

            ic_devices = (ic.device for ic in ini_conds)

            for g in devices
                g in ic_devices && continue
                times = [999.0*(PSY.get_activepower(g) > 0),  # Time on
                         999.0*(PSY.get_activepower(g) <= 0)] # Time off
                @info("Setting $(key) initial_condition of device $(g.name) based on system data")
                if parameters
                    push!(ini_conds, InitialCondition(g,
                                                    PJ.add_parameter(canonical_model.JuMPmodel,
                                                    times[ik])))
                else
                    push!(ini_conds, InitialCondition(g, times[ik]))
                end
            end

        end

        @assert length(ini_conds) == length(devices)

    end



    return

end

######################### Initialize Functions for Storage #################################

function storage_energy_init(canonical_model::CanonicalModel,
                             devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.Storage}

    key = Symbol("E_$(PSD)")
    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)
    ini_conds = get_ini_cond(canonical_model, key)


    if isempty(ini_conds)
        @info("Setting $(key) initial_condition of all devices $(PSD) based on system data")
        ini_conds = canonical_model.initial_conditions[key] = Vector{InitialCondition}(undef, length_devices)

        for (ix, g) in enumerate(devices)
            if parameters
                    ini_conds[ix] = InitialCondition(g,
                                                    PJ.add_parameter(canonical_model.JuMPmodel,
                                                    PSY.get_energy(g)))
            else
                    ini_conds[ix] = InitialCondition(g, PSY.get_energy(g))
            end
        end

    else

        ic_devices = (ic.device for ic in ini_conds)

        for g in devices
            g in ic_devices && continue
            @info("Setting $(key) initial_condition of device $(g.name) based on system data")
            if parameters
                push!(ini_conds, InitialCondition(g,
                                                PJ.add_parameter(canonical_model.JuMPmodel,
                                                PSY.get_energy(g))))
            else
                push!(ini_conds, InitialCondition(g, PSY.get_energy(g)))
            end
        end

    end

        @assert length(ini_conds) == length(devices)

        return

end
