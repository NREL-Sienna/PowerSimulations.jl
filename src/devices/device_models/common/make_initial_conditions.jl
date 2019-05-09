function output_init(ps_m::CanonicalModel,
                    devices::Array{PSD,1},
                    parameters::Bool) where {PSD <: PSY.ThermalGen}

    initial_conditions = Vector{InitialCondition}(undef, length(devices))

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            if parameters
                initial_conditions[i] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, g.tech.activepower))
            else
                initial_conditions[i] = InitialCondition(g, g.tech.activepower)
            end
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(initial_conditions, i:last(idx))

    ps_m.initial_conditions[:thermal_output] = initial_conditions

    return

end

function status_init(ps_m::CanonicalModel,
                    devices::Array{PSD,1},
                    parameters::Bool) where {PSD <: PSY.ThermalGen}

    initial_conditions = Vector{InitialCondition}(undef, length(devices))

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            if parameters
                initial_conditions[i] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower > 0)))
            else
                initial_conditions[i] = InitialCondition(g, 1.0*(g.tech.activepower > 0))
            end
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(initial_conditions, i:last(idx))

    ps_m.initial_conditions[:thermal_status] = initial_conditions

    return

end

function duration_init(ps_m::CanonicalModel,
                        devices::Array{PSD,1},
                        parameters::Bool) where {PSD <: PSY.ThermalGen}

    ini_cond_on = Vector{InitialCondition}(undef, length(devices))
    ini_cond_off = Vector{InitialCondition}(undef, length(devices))

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            if parameters
                ini_cond_on[i] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower > 0)))
                ini_cond_off[i] = InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower < 0)))
            else
                ini_cond_on[i] = InitialCondition(g, 999.0*(g.tech.activepower > 0))
                ini_cond_off[i] = InitialCondition(g, 999.0*(g.tech.activepower < 0))
            end
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(ini_cond_on, i:last(idx))
    deleteat!(ini_cond_off, i:last(idx))

    if parameters
        ps_m.initial_conditions[:duration_indicator_status_on] = ini_cond_on
        ps_m.initial_conditions[:duration_indicator_status_off] = ini_cond_off
    else    
        ps_m.initial_conditions[:thermal_duration_on] = ini_cond_on
        ps_m.initial_conditions[:thermal_duration_off] = ini_cond_off
    end

    return isempty(ini_cond_on)

end

