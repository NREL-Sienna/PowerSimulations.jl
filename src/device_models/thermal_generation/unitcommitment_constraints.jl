### Constraints for Thermal Generation without commitment variables ####

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""

function commitmentconstraints(m::JuMP.Model, devices::Array{ T,1}, time_periods::Int64, commitment::Bool = true) where T <: PowerSystems.ThermalGen

    onth = m[:onth]
    startth = m[:startth]
    stopth = m[:stopth]

    time_index = m[:onth].indexsets[2]
    name_index = m[:onth].indexsets[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    @constraintref commitment_thermal[1:length(name_index),1:length(time_index)]

    for (ix,name) in enumerate(name_index)
        if name == devices[ix].name

            t1 = time_index[1]

            if devices[ix].tech.realpower > 0.0
                init =1
            else
                init =0
            end

            commitment_thermal[ix,t1] = @constraint(m, onth[name,t1] == init + startth[name,t1] - stopth[name,t1])

            for t in onth.indexsets[2][2:end]

                commitment_thermal[ix,t] = @constraint(m, onth[name,t] == onth[name,t-1] + startth[name,t] - stopth[name,t])

            end

        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :commitment_thermal, commitment_thermal)

    return m
end


function timeconstraints(m::JuMP.Model, onth::PowerVariable, startth::PowerVariable, stopth::PowerVariable, devices::Array{T,1}, time_periods::Int; Initial = 999) where T <: PowerSystems.ThermalGen

    devices = [d for d in devices if !isa(d.tech.ramplimits,Nothing)]

    if !isempty(devices)
        # TODO: Change loop orders, loop over time first and then over the device names

        (length(onth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
        (length(startth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
        (onth.indexsets[1] !== startth.indexsets[1]) ? warn("Start and Commitment Status variables indexes are inconsistent"): true

        @constraintref minup_thermal[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]
        @constraintref mindown_thermal[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]
        for (ix,name) in enumerate(onth.indexsets[1])
            if name == devices[ix].name
                for t in onth.indexsets[2][2:end] #TODO : add initial condition constraint
                    minup_thermal[ix,t] = @constraint(m,sum([startth[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.up+1):t) if i > 0 ]) <= onth[name,t])
                    mindown_thermal[ix,t] = @constraint(m,sum([stopth[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.down + 1):t) if i > 0]) <= (1 - onth[name,t]) )
                end
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