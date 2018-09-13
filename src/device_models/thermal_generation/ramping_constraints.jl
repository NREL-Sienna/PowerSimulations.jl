
"""
This function adds the ramping limits of generators when there are no CommitmentVariables
"""
function rampconstraints(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; args...) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalDispatchForm, S <: AbstractDCPowerModel}

    if :initialpower in keys(args)
        initialpower = args[:initialpower]
    else
        initialpower = devices[ix].tech.activepower #should this be 9999?
    end
    
    devices = [d for d in devices if !isa(d.tech.ramplimits,Nothing)]

    if !isempty(devices)

        p_th = m[:p_th]
        time_index = m[:p_th].axes[2]
        name_index = [d.name for d in devices]

        (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

        rampdown_th = JuMP.JuMPArray(Array{ConstraintRef}(undef, length(name_index), time_periods), name_index, time_index)
        rampup_th = JuMP.JuMPArray(Array{ConstraintRef}(undef, length(name_index), time_periods), name_index, time_index)

        for (ix,name) in enumerate(name_index)
            t1 = time_index[1]
            rampdown_th[name,t1] = @constraint(m,  devices[ix].tech.activepower - p_th[name,t1] <= devices[ix].tech.ramplimits.down)
            rampup_th[name,t1] = @constraint(m,  p_th[name,t1] - initialpower <= devices[ix].tech.ramplimits.up)
        end

        for t in time_index[2:end], (ix,name) in enumerate(name_index)
            rampdown_th[name,t] = @constraint(m,  p_th[name,t-1] - p_th[name,t] <= devices[ix].tech.ramplimits.down)
            rampup_th[name,t] = @constraint(m,  p_th[name,t] - p_th[name,t-1] <= devices[ix].tech.ramplimits.up)
        end

        JuMP.registercon(m, :rampdown_th, rampdown_th)
        JuMP.registercon(m, :rampup_th, rampup_th)


    else
        @warn("Data doesn't contain generators with ramping limits")

    end

    return m

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""
function rampconstraints(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; args...) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalCommitmentForm, S <: AbstractDCPowerModel}

    if :initialpower in keys(args)
        initialpower = args[:initialpower]
    else
        initialpower = devices[ix].tech.activepower #should this be 9999?
    end

    devices = [d for d in devices if !isa(d.tech.ramplimits,Nothing)]

    if !isempty(devices)

        p_th = m[:p_th]
        on_th = m[:on_th]

        time_index = m[:p_th].axes[2]
        name_index = [d.name for d in devices]

        (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

        rampdown_th = JuMP.JuMPArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)
        rampup_th = JuMP.JuMPArray(Array{ConstraintRef}(undef, length(name_index), time_periods), name_index, time_index)

        for (ix,name) in enumerate(name_index)
            t1 = time_index[1]
            rampdown_th[name,t1] = @constraint(m, devices[ix].tech.activepower - p_th[name,t1] <= devices[ix].tech.ramplimits.down * on_th[name,t1])
            rampup_th[name,t1] = @constraint(m, p_th[name,t1] - initialpower <= devices[ix].tech.ramplimits.up  * on_th[name,t1])
        end

        for t in time_index[2:end], (ix,name) in enumerate(name_index)
            rampdown_th[name,t] = @constraint(m, p_th[name,t-1] - p_th[name,t] <= devices[ix].tech.ramplimits.down * on_th[name,t])
            rampup_th[name,t] = @constraint(m, p_th[name,t] - p_th[name,t-1] <= devices[ix].tech.ramplimits.up * on_th[name,t] )
        end

        JuMP.registercon(m, :rampdown_th, rampdown_th)
        JuMP.registercon(m, :rampup_th, rampup_th)

    else
        @warn("There are no generators with Ramping Limits Data in the System")    
        
    end
        
    
    return m

end