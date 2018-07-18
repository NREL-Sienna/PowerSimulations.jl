"""
This function add the variables for power generation output to the model
"""
function generationvariables(m::JuMP.Model, devices_netinjection:: A, devices::Array{T,1}, time_periods::Int64) where {A <: PowerExpressionArray, T <: PowerSystems.ThermalGen}
    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    pth = @variable(m::JuMP.Model, pth[on_set,t]) # Power output of generators

    varnetinjectiterate!(devices_netinjection,  pth, t, devices)

    return pth, devices_netinjection
end


"""
This function add the variables for power generation commitment to the model
"""
function commitmentvariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    onset = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    @variable(m, onth[onset,t], Bin) # Power output of generators
    @variable(m, startth[onset,t], Bin) # Power output of generators
    @variable(m, stopth[onset,t], Bin) # Power output of generators

    return onth, startth, stopth
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, pth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen
    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])
    @constraintref pmax_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref pmin_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    for t in pth.indexsets[2], (ix, name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            pmin_thermal[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min)
            pmax_thermal[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max)
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :pmax_thermal, pmax_th)
    JuMP.registercon(m, :pmin_thermal, pmin_th)

    return m
end

"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, pth::PowerVariable, onth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref pmax_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref pmin_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    for t in pth.indexsets[2], (ix, name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            pmin_thermal[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min*onth[name,t])
            pmax_thermal[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max*onth[name,t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :pmax_thermal, pmax_th)
    JuMP.registercon(m, :pmin_thermal, pmin_th)

    return m
end

"""
This function adds the ramping limits of generators when there are no CommitmentVariables
"""
function rampconstraints(m::JuMP.Model, pth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true

    @constraintref rampdown_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref rampup_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]

    for (ix,name) in enumerate(pth.indexsets[1])
        t1 = pth.indexsets[2][1]
        if name == devices[ix].name
            rampdown_thermal[ix,t1] = @constraint(m,  devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down)
            rampup_thermal[ix,t1] = @constraint(m,  pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up)

        else
            error("Bus name in Array and variable do not match")
        end
    end

    for t in pth.indexsets[2][2:end], (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            rampdown_thermal[ix,t] = @constraint(m,  pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down)
            rampup_thermal[ix,t] = @constraint(m,  pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up)

        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :rampdown_thermal, rampdown_th)
    JuMP.registercon(m, :rampup_thermal, rampup_th)

    return m
end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""

function rampconstraints(m::JuMP.Model, pth::PowerVariable, onth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true

    @constraintref rampdown_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref rampup_thermal[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]

    for (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            t1 = pth.indexsets[2][1]
            rampdown_thermal[ix,t1] = @constraint(m,  devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down * onth[name,t1])
            rampup_thermal[ix,t1] = @constraint(m,  pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up  * onth[name,t1])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    for t in pth.indexsets[2][2:end], (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            rampdown_thermal[ix,t] = @constraint(m,  pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down * onth[name,t])
            rampup_thermal[ix,t] = @constraint(m,  pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up * onth[name,t] )
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :rampdown_thermal, rampdown_th)
    JuMP.registercon(m, :rampup_thermal, rampup_th)

    return m
end

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""

function commitmentconstraints(m::JuMP.Model, onth::PowerVariable, startth::PowerVariable, stopth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    (length(onth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (length(startth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (length(stopth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true

    # TODO: Change loop orders, loop over time first and then over the device names

    (stopth.indexsets[1] !== startth.indexsets[1]) ? warn("Start/Stop variables indexes are inconsistent"): true
    (onth.indexsets[1] !== stopth.indexsets[1]) ? warn("Start/Stop and Commitment Status variables indexes are inconsistent"): true

    @constraintref commitment_thermal[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]

    for (ix,name) in enumerate(onth.indexsets[1])
        if name == devices[ix].name
            t1 = onth.indexsets[2][1]
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

    JuMP.registercon(m, :Commitment_thermal, commitment_th)

    return m
end

function timeconstraints(m::JuMP.Model, onth::PowerVariable, startth::PowerVariable, stopth::PowerVariable, devices::Array{T,1}, time_periods::Int; Initial = 999) where T <: PowerSystems.ThermalGen

    # TODO: Change loop orders, loop over time first and then over the device names

    (length(onth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (length(startth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (onth.indexsets[1] !== startth.indexsets[1]) ? warn("Start and Commitment Status variables indexes are inconsistent"): true

    @constraintref uptime[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]
    @constraintref downtime[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]
    for (ix,name) in enumerate(onth.indexsets[1])
        if name == devices[ix].name
            for t in onth.indexsets[2][2:end] #TODO : add initial condition constraint
                uptime_thermal[ix,t] = @constraint(m,sum([startth[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.up+1):t) if i > 0 ]) <= onth[name,t])
                downtime_thermal[ix,t] = @constraint(m,sum([stopth[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.down + 1):t) if i > 0]) <= (1 - onth[name,t]) )
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :minup_thermal, uptime_th)
    JuMP.registercon(m, :mindown_thermal, downtime_th)

    return m
end