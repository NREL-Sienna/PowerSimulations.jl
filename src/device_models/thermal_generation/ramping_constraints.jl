
"""
This function adds the ramping limits of generators when there are no CommitmentVariables
"""
function ramp_dispatch(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    devices = [d for d in devices if !isa(d.tech.ramplimits,Nothing)]

    if !isempty(devices)

        pth = m[:pth]
        time_index = m[:pth].axes[2]
        name_index = [d.name for d in devices]

        (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

        rampdown_thermal = JuMP.JuMPArray(Array{ConstraintRef}((length(name_index), time_periods)), name_index, time_index)
        rampup_thermal = JuMP.JuMPArray(Array{ConstraintRef}((length(name_index), time_periods)), name_index, time_index)

        for (ix,name) in enumerate(name_index)

            t1 = time_index[1]

            if name == devices[ix].name

                rampdown_thermal[name,t1] = @constraint(m,  devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down)
                rampup_thermal[name,t1] = @constraint(m,  pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up)

            else
                error("Bus name in Array and variable do not match")
            end
        end

        for t in time_index[2:end], (ix,name) in enumerate(name_index)

            if name == devices[ix].name

                rampdown_thermal[name,t] = @constraint(m,  pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down)
                rampup_thermal[name,t] = @constraint(m,  pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up)

            else
                error("Bus name in Array and variable do not match")
            end
        end

        JuMP.registercon(m, :rampdown_thermal, rampdown_thermal)
        JuMP.registercon(m, :rampup_thermal, rampup_thermal)


    else
        warn("Data doesn't contain generators with ramping limits")

    end

    return m

end


"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""

function ramp_commitment(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    devices = [d for d in devices if !isa(d.tech.ramplimits,Nothing)]

    if !isempty(devices)

        pth = m[:pth]
        onth = m[:onth]

        time_index = m[:pth].axes[2]
        name_index = m[:pth].axes[1]

        (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

        rampdown_thermal = JuMP.JuMPArray(Array{ConstraintRef}((length(name_index), time_periods)), name_index, time_index)
        rampup_thermal = JuMP.JuMPArray(Array{ConstraintRef}((length(name_index), time_periods)), name_index, time_index)

        for (ix,name) in enumerate(name_index)
            if name == devices[ix].name
                t1 = time_index[1]
                rampdown_thermal[name,t1] = @constraint(m, devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down * onth[name,t1])
                rampup_thermal[name,t1] = @constraint(m, pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up  * onth[name,t1])
            else
                error("Bus name in Array and variable do not match")
            end
        end

        for t in time_index[2:end], (ix,name) in enumerate(name_index)
            if name == devices[ix].name
                rampdown_thermal[name,t] = @constraint(m, pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down * onth[name,t])
                rampup_thermal[name,t] = @constraint(m, pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up * onth[name,t] )
            else
                error("Bus name in Array and variable do not match")
            end
        end

        JuMP.registercon(m, :rampdown_thermal, rampdown_thermal)
        JuMP.registercon(m, :rampup_thermal, rampup_thermal)

        return m
    end
end

function rampconstraints(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64, commitment::Bool = false) where T <: PowerSystems.ThermalGen

    commitment ? m = ramp_dispatch(m, devices, time_periods) : m = ramp_commitment(m, devices, time_periods)

    return m

end