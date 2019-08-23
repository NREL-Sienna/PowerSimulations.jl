function output_init(ps_m::CanonicalModel,
                    devices::Array{PSD,1},
                    parameters::Bool) where {PSD <: PSY.ThermalGen}

    initial_conditions = Vector{InitialCondition}(undef, length(devices))

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            if parameters
                initial_conditions[i] = PSI.InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, g.tech.activepower))
            else
                initial_conditions[i] = PSI.InitialCondition(g, g.tech.activepower)
            end
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(initial_conditions, i:last(idx))

    key = Symbol("thermal_output") 
    if key in keys(ps_m.initial_conditions) && !isempty(ps_m.initial_conditions[key])
        vcat(ps_m.initial_conditions[key],initial_conditions)
    else
        ps_m.initial_conditions[key] = initial_conditions
    end

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
                initial_conditions[i] = PSI.InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 1.0*(g.tech.activepower > 0)))
            else
                initial_conditions[i] = PSI.InitialCondition(g, 1.0*(g.tech.activepower > 0))
            end
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(initial_conditions, i:last(idx))
    key = Symbol("thermal_status") 
    if key in keys(ps_m.initial_conditions) && !isempty(ps_m.initial_conditions[key])
        vcat(ps_m.initial_conditions[key],initial_conditions)
    else
        ps_m.initial_conditions[key] = initial_conditions
    end

    return

end

function duration_init_on(ps_m::CanonicalModel,
                        devices::Array{PSD,1},
                        parameters::Bool) where {PSD <: PSY.ThermalGen}

    ini_cond_on = Vector{InitialCondition}(undef, length(devices))

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            if parameters
                ini_cond_on[i] = PSI.InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 999.0*(g.tech.activepower > 0)))
            else
                ini_cond_on[i] = PSI.InitialCondition(g, 999.0*(g.tech.activepower > 0))
            end
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(ini_cond_on, i:last(idx))

    key = Symbol("thermal_duration_on") 
    if key in keys(ps_m.initial_conditions) && !isempty(ps_m.initial_conditions[key])
        vcat(ps_m.initial_conditions[key],ini_cond_on)
    else
        ps_m.initial_conditions[key] = ini_cond_on
    end

    return

end


function duration_init_off(ps_m::CanonicalModel,
                        devices::Array{PSD,1},
                        parameters::Bool) where {PSD <: PSY.ThermalGen}

    ini_cond_off = Vector{InitialCondition}(undef, length(devices))

    idx = eachindex(devices)
    i, state = iterate(idx)
    for g in devices
        if !isnothing(g.tech.ramplimits)
            if parameters
                ini_cond_off[i] = PSI.InitialCondition(g, PJ.add_parameter(ps_m.JuMPmodel, 999.0*(g.tech.activepower < 0)))
            else
                ini_cond_off[i] = PSI.InitialCondition(g, 999.0*(g.tech.activepower < 0))
            end
            y = iterate(idx, state)
            y === nothing && (i += 1; break)
            i, state = y
        end
    end

    deleteat!(ini_cond_off, i:last(idx))

    key = Symbol("thermal_duration_off") 
    if key in keys(ps_m.initial_conditions) && !isempty(ps_m.initial_conditions[key])
        vcat(ps_m.initial_conditions[key],ini_cond_off)
    else
        ps_m.initial_conditions[key] = ini_cond_off
    end

    return

end
