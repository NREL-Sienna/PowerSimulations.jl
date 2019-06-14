function status_init(ps_m::CanonicalModel,
                    devices::PSY.FlattenedVectorsIterator{PSD}) where {PSD <: PSY.ThermalGen}

    parameters = model_with_parameters(ps_m)
    lenght_devices = length(devices)
    initial_conditions = Vector{InitialCondition}(undef, lenght_devices)

    for (ix,g) in enumerate(devices)
        if parameters
            initial_conditions[ix] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower > 0)))
        else
            initial_conditions[ix] = InitialCondition(g, 1.0*(g.tech.activepower > 0))
        end
    end

    ps_m.initial_conditions[Symbol("status_$(PSD)")] = initial_conditions

    return

end

function output_init(ps_m::CanonicalModel,
                    devices::PSY.FlattenedVectorsIterator{PSD},
                    set_name::Vector{String}) where {PSD <: PSY.ThermalGen}

    parameters = model_with_parameters(ps_m)
    lenght_devices = length(devices)

    if lenght_devices != length(set_name)
        devices = [d for d in devices if d.name in set_name]
        lenght_devices = length(devices)
    end

    initial_conditions = Vector{InitialCondition}(undef, lenght_devices)

    for (ix, g) in enumerate(devices)
            if parameters
                initial_conditions[ix] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, g.tech.activepower))
            else
                initial_conditions[ix] = InitialCondition(g, g.tech.activepower)
            end
    end

    ps_m.initial_conditions[Symbol("output_$(PSD)")] = initial_conditions

    return isempty(initial_conditions)

end


function duration_init(ps_m::CanonicalModel,
                        devices::PSY.FlattenedVectorsIterator{PSD},
                        set_name::Vector{String}) where {PSD <: PSY.ThermalGen}

    parameters = model_with_parameters(ps_m)
    lenght_devices = length(devices)

    if lenght_devices != length(set_name)
        devices = [d for d in devices if d.name in set_name]
        lenght_devices = length(devices)
    end

    ini_cond_on = Vector{InitialCondition}(undef, lenght_devices)
    ini_cond_off = Vector{InitialCondition}(undef, lenght_devices)

    for (ix,g) in enumerate(devices)
        if parameters
            ini_cond_on[ix] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower > 0)))
            ini_cond_off[ix] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower < 0)))
        else
            ini_cond_on[ix] = InitialCondition(g, 999.0*(g.tech.activepower > 0))
            ini_cond_off[ix] = InitialCondition(g, 999.0*(g.tech.activepower < 0))
        end
    end

    if parameters
        ps_m.initial_conditions[Symbol("duration_ind_on_$(PSD)")] = ini_cond_on
        ps_m.initial_conditions[Symbol("duration_ind_off_$(PSD)")] = ini_cond_off
    else
        ps_m.initial_conditions[Symbol("duration_on_$(PSD)")] = ini_cond_on
        ps_m.initial_conditions[Symbol("duration_off_$(PSD)")] = ini_cond_off
    end

    return isempty(ini_cond_on)

end

function storage_energy_init(ps_m::CanonicalModel,
                             devices::PSY.FlattenedVectorsIterator{PSD}) where {PSD <: PSY.Storage}

    parameters = model_with_parameters(ps_m)
    energy_initial_conditions  = Vector{InitialCondition}(undef, length(devices))

    for (i,g) in enumerate(devices)
            if parameters
                energy_initial_conditions[i] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 0.0))
            else
                energy_initial_conditions[i] = InitialCondition(g, 0.0)
            end
    end

    ps_m.initial_conditions[Symbol("energy_$(PSD)")] = energy_initial_conditions

    return

end

