function status_init(canonical_model::CanonicalModel,
                    devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)
    initial_conditions = Vector{InitialCondition}(undef, length_devices)

    for (ix, g) in enumerate(devices)
        if parameters
            initial_conditions[ix] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 1.0*(PSY.get_activepower(g) > 0)))
        else
            initial_conditions[ix] = InitialCondition(g, 1.0*(PSY.get_activepower(g) > 0))
        end
    end

    canonical_model.initial_conditions[Symbol("status_$(PSD)")] = initial_conditions

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

    canonical_model.initial_conditions[Symbol("output_$(PSD)")] = initial_conditions

    return isempty(initial_conditions)

end


function duration_init_on(canonical_model::CanonicalModel,
                        devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    ini_cond_on = Vector{InitialCondition}(undef, length_devices)

    for (ix, g) in enumerate(devices)
        if parameters
            ini_cond_on[ix] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 999.0*(PSY.get_activepower(g) > 0)))
        else
            ini_cond_on[ix] = InitialCondition(g, 999.0*(PSY.get_activepower(g) > 0))
        end
    end

    key_on = Symbol("duration_on_$(PSD)") 
    if key_on in keys(canonical_model.initial_conditions) && !isempty(canonical_model.initial_conditions[key_on])
        vcat(canonical_model.initial_conditions[key_on],ini_cond_on)
    else
        canonical_model.initial_conditions[key_on] = ini_cond_on
    end

end

function duration_init_off(canonical_model::CanonicalModel,
                        devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.ThermalGen}

    parameters = model_has_parameters(canonical_model)
    length_devices = length(devices)

    ini_cond_on = Vector{InitialCondition}(undef, length_devices)
    ini_cond_off = Vector{InitialCondition}(undef, length_devices)

    for (ix, g) in enumerate(devices)
        if parameters
            ini_cond_off[ix] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 999.0*(PSY.get_activepower(g) < 0)))
        else
            ini_cond_off[ix] = InitialCondition(g, 999.0*(PSY.get_activepower(g) < 0))
        end
    end

    key_off = Symbol("duration_off_$(PSD)") 
    if key_off in keys(canonical_model.initial_conditions) && !isempty(canonical_model.initial_conditions[key_off])
        vcat(canonical_model.initial_conditions[key_off],ini_cond_off)
    else
        canonical_model.initial_conditions[key_off] = ini_cond_off
    end

end

function storage_energy_init(canonical_model::CanonicalModel,
                             devices::PSY.FlattenIteratorWrapper{PSD}) where {PSD<:PSY.Storage}

    parameters = model_has_parameters(canonical_model)
    energy_initial_conditions  = Vector{InitialCondition}(undef, length(devices))

    for (i, g) in enumerate(devices)
            if parameters
                energy_initial_conditions[i] = InitialCondition(g, PJ.add_parameter(canonical_model.JuMPmodel, 0.0))
            else
                energy_initial_conditions[i] = InitialCondition(g, 0.0)
            end
    end

    canonical_model.initial_conditions[Symbol("energy_$(PSD)")] = energy_initial_conditions

    return

end
