function status_init(canonical_model::CanonicalModel,
                    devices::PSY.FlattenIteratorWrapper{PSD},
                    set_name::Vector{String}) where {PSD<:PSY.ThermalGen}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    if length_devices != length(set_name)
        devices = [d for d in devices if d.name in set_name]
        length_devices = length(devices)
    end

    initial_conditions = Vector{InitialCondition}(undef, length_devices)

    for (ix, g) in enumerate(devices)
        if parameters
            initial_conditions[ix] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 1.0*(PSY.get_activepower(g) > 0)))
        else
            initial_conditions[ix] = InitialCondition(g, 1.0*(PSY.get_activepower(g) > 0))
        end
    end
    key = Symbol("status_$(PSD)")
    if key in keys(canonical_model.initial_conditions) && !isempty(canonical_model.initial_conditions[key])
        vcat(canonical_model.initial_conditions[key],initial_conditions)
    else
        canonical_model.initial_conditions[key] = initial_conditions
    end

    return

end

function output_init(canonical_model::CanonicalModel,
                    devices::PSY.FlattenIteratorWrapper{PSD},
                    set_name::Vector{String}) where {PSD<:PSY.ThermalGen}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    if length_devices != length(set_name)
        devices = [d for d in devices if d.name in set_name]
        length_devices = length(devices)
    end

    initial_conditions = Vector{InitialCondition}(undef, length_devices)

    for (ix, g) in enumerate(devices)
            if parameters
                initial_conditions[ix] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, PSY.get_activepower(g) ))
            else
                initial_conditions[ix] = InitialCondition(g, PSY.get_activepower(g))
            end
    end
    key = Symbol("output_$(PSD)")
    if key in keys(canonical_model.initial_conditions) && !isempty(canonical_model.initial_conditions[key])
        vcat(canonical_model.initial_conditions[key],initial_conditions)
    else
        canonical_model.initial_conditions[key] = initial_conditions
    end

    return isempty(initial_conditions)

end

function duration_init_off(canonical_model::CanonicalModel,
                        devices::PSY.FlattenIteratorWrapper{PSD},
                        set_name::Vector{String}) where {PSD<:PSY.ThermalGen}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    if length_devices != length(set_name)
        devices = [d for d in devices if d.name in set_name]
        length_devices = length(devices)
    end

    ini_cond_off = Vector{InitialCondition}(undef, length_devices)

    for (ix, g) in enumerate(devices)
        if parameters
            ini_cond_off[ix] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 999.0*(PSY.get_activepower(g) < 0)))
        else
            ini_cond_off[ix] = InitialCondition(g, 999.0*(PSY.get_activepower(g) < 0))
        end
    end
    key = Symbol("duration_off_$(PSD)")
    if key in keys(canonical_model.initial_conditions) && !isempty(canonical_model.initial_conditions[key])
        vcat(canonical_model.initial_conditions[key],ini_cond_off)
    else
        canonical_model.initial_conditions[key] = ini_cond_off
    end

    return isempty(ini_cond_off)

end

function duration_init_on(canonical_model::CanonicalModel,
                        devices::PSY.FlattenIteratorWrapper{PSD},
                        set_name::Vector{String}) where {PSD<:PSY.ThermalGen}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    if length_devices != length(set_name)
        devices = [d for d in devices if d.name in set_name]
        length_devices = length(devices)
    end

    ini_cond_on = Vector{InitialCondition}(undef, length_devices)

    for (ix, g) in enumerate(devices)
        if parameters
            ini_cond_on[ix] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 999.0*(PSY.get_activepower(g) > 0)))
        else
            ini_cond_on[ix] = InitialCondition(g, 999.0*(PSY.get_activepower(g) > 0))
        end
    end

    key = Symbol("duration_on_$(PSD)")
    if key in keys(canonical_model.initial_conditions) && !isempty(canonical_model.initial_conditions[key])
        vcat(canonical_model.initial_conditions[key],ini_cond_on)
    else
        canonical_model.initial_conditions[key] = ini_cond_on
    end

    return isempty(ini_cond_on)

end

function storage_energy_init(canonical_model::CanonicalModel,
                             devices::PSY.FlattenIteratorWrapper{PSD},
                             set_name::Vector{String}) where {PSD<:PSY.Storage}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    if length_devices != length(set_name)
        devices = [d for d in devices if d.name in set_name]
        length_devices = length(devices)
    end
    energy_initial_conditions  = Vector{InitialCondition}(undef, length(devices))

    for (i, g) in enumerate(devices)
            if parameters
                energy_initial_conditions[i] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 0.0))
            else
                energy_initial_conditions[i] = InitialCondition(g, 0.0)
            end
    end

    key = Symbol("energy_$(PSD)")
    if key in keys(canonical_model.initial_conditions) && !isempty(canonical_model.initial_conditions[key])
        vcat(canonical_model.initial_conditions[key],energy_initial_conditions)
    else
        canonical_model.initial_conditions[key] = energy_initial_conditions
    end

    return

end
