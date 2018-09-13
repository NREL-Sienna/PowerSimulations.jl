### Constraints for Thermal Generation without commitment variables ####

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""
function commitmentconstraints(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; args...) where {T <: PowerSystems.ThermalGen, D <: StandardThermalCommitment, S <: AbstractDCPowerModel}

    # set args default values
    if :initialstatus in keys(args)
        initialstatus = args[:initialstatus]
    else
        initialstatus = 1
    end

    on_th = m[:on_th]
    start_th = m[:start_th]
    stop_th = m[:stop_th]

    name_index = m[:on_th].axes[1]
    time_index = m[:on_th].axes[2]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    commitment_th = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(on_th))), name_index, time_index)

    for (ix,name) in enumerate(name_index)
        if name == devices[ix].name

            t1 = time_index[1]

            if devices[ix].tech.activepower > 0.0
                init = 1
            else
                init = 0
            end

            commitment_th[name,t1] = @constraint(m, on_th[name,t1] == init + start_th[name,t1] - stop_th[name,t1])

            for t in time_index[2:end]

                commitment_th[name,t] = @constraint(m, on_th[name,t] == on_th[name,t-1] + start_th[name,t] - stop_th[name,t])

            end

        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :commitment_th, commitment_th)

    return m
end


function timeconstraints(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64; args...) where {T <: PowerSystems.ThermalGen, D <: StandardThermalCommitment, S <: AbstractDCPowerModel}
    
    # set args default values
    if :initialonduration in keys(args)
        initialonduration = args[:initialonduration]
    else
        initialonduration = 9999
    end

    if :initialoffduration in keys(args)
        initialoffduration = args[:initialoffduration]
    else
        initialoffduration = 9999
    end

    
    devices = [d for d in devices if !isa(d.tech.timelimits,Nothing)]

    if !isempty(devices)
        # TODO: Change loop orders, loop over time first and then over the device names

        on_th = m[:on_th]
        start_th = m[:start_th]
        stop_th = m[:stop_th]
        time_index = m[:on_th].axes[2]
        name_index = [d.name for d in devices]

       (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

       minup_th = JuMP.JuMPArray(Array{ConstraintRef}((undef, length(name_index), time_periods)), name_index, time_index)

       mindown_th = JuMP.JuMPArray(Array{ConstraintRef}((undef, length(name_index), time_periods)), name_index, time_index)

        for t in time_index[2:end], (ix,name) in enumerate(on_th.axes[1])

            #TODO: add initial condition constraint and check this formulation, we need to move the set calculation outside of here. 
            minup_th[name,t] = @constraint(m,sum([start_th[name,i] for i in ((t-devices[ix].tech.timelimits.up+1) :t) if i > 0 ]) <= on_th[name,t])
            mindown_th[name,t] = @constraint(m,sum([stop_th[name,i] for i in ((t-devices[ix].tech.timelimits.down + 1) :t) if i > 0]) <= (1 - on_th[name,t]) )

        end

        JuMP.registercon(m, :minup_th, minup_th)
        JuMP.registercon(m, :mindown_th, mindown_th)

    else
        @warn("There are no generators with Min-up -down limits data in the system")    
        
    end

    return m
end

#TODO: Add the Knueven Model