function output_init(ps_m::CanonicalModel,
                    devices::PSY.FlattenedVectorsIterator{PSD},
                    parameters::Bool) where {PSD <: PSY.ThermalGen}

    lenght_devices = length(devices)
    initial_conditions = Vector{InitialCondition}(undef, lenght_devices)

    idx = 0
    for g in devices
        if !isnothing(g.tech.ramplimits)
            idx += 1
            if parameters
                initial_conditions[idx] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, g.tech.activepower))
            else
                initial_conditions[idx] = InitialCondition(g, g.tech.activepower)
            end                      
        end
    end

    if idx < lenght_devices  
        deleteat!(initial_conditions, idx+1:lenght_devices) 
    end

    ps_m.initial_conditions[Symbol("output_$(PSD)")] = initial_conditions

    return isempty(initial_conditions)

end

function status_init(ps_m::CanonicalModel,
                    devices::PSY.FlattenedVectorsIterator{PSD},
                    parameters::Bool) where {PSD <: PSY.ThermalGen}

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

function duration_init(ps_m::CanonicalModel,
                        devices::PSY.FlattenedVectorsIterator{PSD},
                        parameters::Bool) where {PSD <: PSY.ThermalGen}

    
    lenght_devices = length(devices)
    ini_cond_on = Vector{InitialCondition}(undef, lenght_devices)
    ini_cond_off = Vector{InitialCondition}(undef, lenght_devices)

    idx = 0
    for g in devices
        if !isnothing(g.tech.timelimits)
            idx += 1
            if parameters
                ini_cond_on[idx] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower > 0)))
                ini_cond_off[idx] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower < 0)))
            else
                ini_cond_on[idx] = InitialCondition(g, 999.0*(g.tech.activepower > 0))
                ini_cond_off[idx] = InitialCondition(g, 999.0*(g.tech.activepower < 0))
            end
        end
    end

    if idx < lenght_devices  
        deleteat!(ini_cond_on, idx+1:lenght_devices) 
        deleteat!(ini_cond_off, idx+1:lenght_devices) 
    end

    if parameters
        ps_m.initial_conditions[Symbol("duration_indicator_on_$(PSD)")] = ini_cond_on
        ps_m.initial_conditions[Symbol("duration_indicator_off_$(PSD)")] = ini_cond_off
    else    
        ps_m.initial_conditions[Symbol("duration_on_$(PSD)")] = ini_cond_on
        ps_m.initial_conditions[Symbol("duration_off_$(PSD)")] = ini_cond_off
    end

    return isempty(ini_cond_on)

end

function storage_energy_init(ps_m::CanonicalModel,
                             devices::PSY.FlattenedVectorsIterator{PSD},
                             parameters::Bool) where {PSD <: PSY.Storage}

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

