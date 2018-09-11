### Constraints for Thermal Generation without commitment variables ####

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitmentconstraints(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: StandardThermalCommitment, S <: AbstractDCPowerModel}

    onth = m[:onth]
    startth = m[:startth]
    stopth = m[:stopth]

    name_index = m[:onth].axes[1]
    time_index = m[:onth].axes[2]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    commitment_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(onth))), name_index, time_index)

    for (ix,name) in enumerate(name_index)
        if name == devices[ix].name

            t1 = time_index[1]

            if devices[ix].tech.activepower > 0.0
                init = 1
            else
                init = 0
            end

            commitment_thermal[name,t1] = @constraint(m, onth[name,t1] == init + startth[name,t1] - stopth[name,t1])

            for t in time_index[2:end]

                commitment_thermal[name,t] = @constraint(m, onth[name,t] == onth[name,t-1] + startth[name,t] - stopth[name,t])

            end

        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :commitment_thermal, commitment_thermal)

    return m
end


function timeconstraints(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; initial = 9999) where {T <: PowerSystems.ThermalGen, D <: StandardThermalCommitment, S <: AbstractDCPowerModel}

    devices = [d for d in devices if !isa(d.tech.timelimits,Nothing)]

    if !isempty(devices)
        # TODO: Change loop orders, loop over time first and then over the device names

        onth = m[:onth]
        startth = m[:startth]
        stopth = m[:stopth]
        time_index = m[:onth].axes[2]
        name_index = [d.name for d in devices]

       (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

       minup_thermal = JuMP.JuMPArray(Array{ConstraintRef}((undef, length(name_index), time_periods)), name_index, time_index)

       mindown_thermal = JuMP.JuMPArray(Array{ConstraintRef}((undef, length(name_index), time_periods)), name_index, time_index)

        for t in time_index[2:end], (ix,name) in enumerate(onth.axes[1])

            #TODO: add initial condition constraint and check this formulation, we need to move the set calculation outside of here. 

            if name == devices[ix].name
                minup_thermal[name,t] = @constraint(m,sum([startth[name,i] for i in ((t-devices[ix].tech.timelimits.up+1) :t) if i > 0 ]) <= onth[name,t])
                mindown_thermal[name,t] = @constraint(m,sum([stopth[name,i] for i in ((t-devices[ix].tech.timelimits.down + 1) :t) if i > 0]) <= (1 - onth[name,t]) )
            else
                error("Bus name in Array and variable do not match")
            end
        end

        JuMP.registercon(m, :minup_thermal, minup_thermal)
        JuMP.registercon(m, :mindown_thermal, mindown_thermal)

    end
    return m
end

#TODO: Add the Knueven Model