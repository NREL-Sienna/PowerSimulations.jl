
"""
This function adds the ramping limits of generators when there are no CommitmentVariables
"""
function rampconstraints(m::JuMP.AbstractModel, devices::Array{T,1}, device_formulation::Type{ThermalRampLimitDispatch}, system_formulation::Type{S}, time_periods::Int64; kwargs...) where {T <: PSY.ThermalGen, S <: PM.AbstractPowerFormulation}

    devices = [d for d in devices if !isa(d.tech.ramplimits,Nothing)]

    if !isempty(devices)

        p_th = m[:p_th]
        time_index = m[:p_th].axes[2]
        name_index = [d.name for d in devices]

        if :initialpower in keys(args)
            initialpower = args[:initialpower]
        else
            initialpower = Dict([name=>devices[ix].tech.activepower for (ix,name) in enumerate(name_index)])
        end

        (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

        rampdown_th = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, length(name_index), time_periods), name_index, time_index)
        rampup_th = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, length(name_index), time_periods), name_index, time_index)

        for (ix,name) in enumerate(name_index)
            t1 = time_index[1]
            rampdown_th[name,t1] = JuMP.@constraint(m,  initialpower[name] - p_th[name,t1] <= devices[ix].tech.ramplimits.down)
            rampup_th[name,t1] = JuMP.@constraint(m,  p_th[name,t1] - initialpower[name] <= devices[ix].tech.ramplimits.up)
        end

        for t in time_index[2:end], (ix,name) in enumerate(name_index)
            rampdown_th[name,t] = JuMP.@constraint(m,  p_th[name,t-1] - p_th[name,t] <= devices[ix].tech.ramplimits.down)
            rampup_th[name,t] = JuMP.@constraint(m,  p_th[name,t] - p_th[name,t-1] <= devices[ix].tech.ramplimits.up)
        end

        JuMP.register_object(m, :rampdown_th, rampdown_th)
        JuMP.register_object(m, :rampup_th, rampup_th)


    else
        @warn "Data doesn't contain generators with ramping limits"

    end

    return m

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function rampconstraints(m::JuMP.AbstractModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; kwargs...) where {T <: PSY.ThermalGen, D <: AbstractThermalCommitmentForm, S <: PM.AbstractActivePowerFormulation}

    devices = [d for d in devices if !isa(d.tech.ramplimits,Nothing)]

    if !isempty(devices)

        p_th = m[:p_th]
        start_th = m[:start_th]
        stop_th = m[:stop_th]


        time_index = m[:p_th].axes[2]
        name_index = [d.name for d in devices]

        if :initialpower in keys(args)
            initialpower = args[:initialpower]
        else
            initialpower = Dict([name=>devices[ix].tech.activepower for (ix,name) in enumerate(name_index)])
        end

        (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

        rampdown_th = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)
        rampup_th = JuMP.Containers.DenseAxisArray(Array{JuMP.ConstraintRef}(undef, length(name_index), time_periods), name_index, time_index)

        for (ix,name) in enumerate(name_index)
            t1 = time_index[1]
            rampdown_th[name,t1] = JuMP.@constraint(m, initialpower[name] - p_th[name,t1] <= devices[ix].tech.ramplimits.down + devices[ix].tech.activepowerlimits.max * stop_th[name,t1] )
            rampup_th[name,t1] = JuMP.@constraint(m, p_th[name,t1] - initialpower[name] <= devices[ix].tech.ramplimits.up + devices[ix].tech.activepowerlimits.min * start_th[name,t1] )
        end

        for t in time_index[2:end], (ix,name) in enumerate(name_index)
            rampdown_th[name,t] = JuMP.@constraint(m, p_th[name,t-1] - p_th[name,t] <= devices[ix].tech.ramplimits.down + devices[ix].tech.activepowerlimits.max * stop_th[name,t] )
            rampup_th[name,t] = JuMP.@constraint(m, p_th[name,t] - p_th[name,t-1] <= devices[ix].tech.ramplimits.up + devices[ix].tech.activepowerlimits.min * start_th[name,t] )
        end

        JuMP.register_object(m, :rampdown_th, rampdown_th)
        JuMP.register_object(m, :rampup_th, rampup_th)

    else
        @warn "There are no generators with Ramping Limits Data in the System"
    end


    return m

end
