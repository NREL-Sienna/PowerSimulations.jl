"""
This function add the variables for power generation output to the model
"""
function generationvariables(m::JuMP.Model, DevicesNetInjection::A, devices::Array{T,1}, time_periods::Int64) where {A <: PowerExpressionArray, T <: PowerSystems.ThermalGen}
    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    pth = @variable(m::JuMP.Model, pth[on_set,t]) # Power output of generators

    varnetinjectiterate!(DevicesNetInjection, pth, t, devices)

    return pth, DevicesNetInjection
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
    @constraintref Pmaxth[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref Pminth[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    for t in pth.indexsets[2], (ix, name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            Pminth[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min)
            Pmaxth[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max)
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :Pmax_Thermal, Pmaxth)
    JuMP.registercon(m, :Pmin_Thermal, Pminth)

    return m
end

"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function powerconstraints(m::JuMP.Model, pth::PowerVariable, onth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref Pmaxth[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref Pminth[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    for t in pth.indexsets[2], (ix, name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            Pminth[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min*onth[name,t])
            Pmaxth[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max*onth[name,t])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :Pmax_Thermal, Pmaxth)
    JuMP.registercon(m, :Pmin_Thermal, Pminth)

    return m
end

"""
This function adds the ramping limits of generators when there are no CommitmentVariables
"""
function rampconstraints(m::JuMP.Model, pth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true

    @constraintref RampDown_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref RampUp_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]

    for (ix,name) in enumerate(pth.indexsets[1])
        t1 = pth.indexsets[2][1]
        if name == devices[ix].name
            RampDown_th[ix,t1] = @constraint(m,  devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down)
            RampUp_th[ix,t1] = @constraint(m,  pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up)

        else
            error("Bus name in Array and variable do not match")
        end
    end

    for t in pth.indexsets[2][2:end], (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            RampDown_th[ix,t] = @constraint(m,  pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down)
            RampUp_th[ix,t] = @constraint(m,  pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up)

        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :RampDown_Thermal, RampDown_th)
    JuMP.registercon(m, :RampUp_Thermal, RampUp_th)

    return m
end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""

function rampconstraints(m::JuMP.Model, pth::PowerVariable, onth::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true

    @constraintref RampDown_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref RampUp_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]

    for (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            t1 = pth.indexsets[2][1]
            RampDown_th[ix,t1] = @constraint(m,  devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down * onth[name,t1])
            RampUp_th[ix,t1] = @constraint(m,  pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up  * onth[name,t1])
        else
            error("Bus name in Array and variable do not match")
        end
    end

    for t in pth.indexsets[2][2:end], (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            RampDown_th[ix,t] = @constraint(m,  pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down * onth[name,t])
            RampUp_th[ix,t] = @constraint(m,  pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up * onth[name,t] )
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :RampDown_Thermal, RampDown_th)
    JuMP.registercon(m, :RampUp_Thermal, RampUp_th)

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

    @constraintref commitment_th[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]

    for (ix,name) in enumerate(onth.indexsets[1])
        if name == devices[ix].name
            t1 = onth.indexsets[2][1]
            if devices[ix].tech.realpower > 0.0
                init =1
            else
                init =0
            end
            commitment_th[ix,t1] = @constraint(m, onth[name,t1] == init + startth[name,t1] - stopth[name,t1])
            for t in onth.indexsets[2][2:end]
                commitment_th[ix,t] = @constraint(m, onth[name,t] == onth[name,t-1] + startth[name,t] - stopth[name,t])
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

    @constraintref Uptime[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]
    @constraintref DownTime[1:length(onth.indexsets[1]),1:length(onth.indexsets[2])]
    for (ix,name) in enumerate(onth.indexsets[1])
        if name == devices[ix].name
            for t in onth.indexsets[2][2:end] #TODO : add initial condition constraint
                Uptime_th[ix,t] = @constraint(m,sum([startth[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.up+1):t) if i > 0 ]) <= onth[name,t])
                DownTime_th[ix,t] = @constraint(m,sum([stopth[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.down + 1):t) if i > 0]) <= (1 - onth[name,t]) )
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :MinUp_thermal, Uptime_th)
    JuMP.registercon(m, :MinDown_thermal, DownTime_th)

    return m
end