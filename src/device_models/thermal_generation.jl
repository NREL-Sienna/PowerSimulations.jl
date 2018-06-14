# TODO: Change the types in T from ThermalGento Thermal when PowerSystems gets updated

"""
This function add the variables for power generation output to the model
"""
function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    on_set = [d.name for d in devices if d.status == true]
    t = 1:time_periods
    @variable(m::JuMP.Model, pth[on_set,t]) # Power output of generators
    return pth   
end


"""
This function add the variables for power generation commitment to the model
"""
function CommitmentVariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    on_set = [d.name for d in devices if d.status == true]
    t = 1:time_periods
    @variable(m::JuMP.Model, on_th[on_set,t], Bin) # Power output of generators
    @variable(m::JuMP.Model, start_th[on_set,t], Bin) # Power output of generators
    @variable(m::JuMP.Model, stopth[on_set,t], Bin) # Power output of generators
    return on_th, start_th, stopth    
end

# TODO : add the Knueven model variable
# function IndicatorArcVariable(m::JuMP.Model, devices::Array{T,1}, time_periods::Int)


# end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, pth::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    @constraintref Pmax_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref Pmin_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    for (ix, name) in enumerate(pth.indexsets[1])
            if name == devices[ix].name
                for t in pth.indexsets[2]
                    Pmin_th[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min)
                    Pmax_th[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max)
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end

"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, pth, on_th, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref Pmax_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    @constraintref Pmin_th[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])]
    for (ix, name) in enumerate(pth.indexsets[1])
            if name == devices[ix].name
                for t in pth.indexsets[2]
                    Pmin_th[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min*on_th[name,t])
                    Pmax_th[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max*on_th[name,t])
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end

"""
This function adds the ramping limits of generators when there are no CommitmentVariables
"""
function RampingConstraints_th(m::JuMP.Model, pth::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}} , devices::Array{T,1}, time_periods::Int) where T <: ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    @constraintref Up[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])] 
    @constraintref Down[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])] 
    for (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            t1 = pth.indexsets[2][1]
            Down[ix,t1] = @constraint(m,  devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down)
            Up[ix,t1] = @constraint(m,  pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up)
            for t in pth.indexsets[2][2:end] 
                Down[ix,t] = @constraint(m,  pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down)
                Up[ix,t] = @constraint(m,  pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up)
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end

"""
This function adds the ramping limits of generators when there are CommitmentVariables
"""

function RampingConstraints_th(m::JuMP.Model, pth::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, on_th, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen

    (length(pth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    @constraintref Up[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])] 
    @constraintref Down[1:length(pth.indexsets[1]),1:length(pth.indexsets[2])] 
    for (ix,name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            t1 = pth.indexsets[2][1]
            Down[ix,t1] = @constraint(m,  devices[ix].tech.realpower - pth[name,t1] <= devices[ix].tech.ramplimits.down * on_th[name,t1])
            Up[ix,t1] = @constraint(m,  pth[name,t1] - devices[ix].tech.realpower <= devices[ix].tech.ramplimits.up  * on_th[name,t1])
            for t in pth.indexsets[2][2:end]
                Down[ix,t] = @constraint(m,  pth[name,t-1] - pth[name,t] <= devices[ix].tech.ramplimits.down * on_th[name,t])
                Up[ix,t] = @constraint(m,  pth[name,t] - pth[name,t-1] <= devices[ix].tech.ramplimits.up * on_th[name,t] )
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end

"""
This function adds the Commitment Status constraint when there are CommitmentVariables
"""

function CommitmentStatus_th(m::JuMP.Model,on_th, start_th, stopth, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    (length(on_th.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (length(start_th.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (length(stopth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (stopth.indexsets[1] !== start_th.indexsets[1]) ? warn("Start/Stop variables indexes are inconsistent"): true
    (on_th.indexsets[1] !== stopth.indexsets[1]) ? warn("Start/Stop and Commitment Status variables indexes are inconsistent"): true
    @constraintref Status[1:length(on_th.indexsets[1]),1:length(on_th.indexsets[2])]
    for (ix,name) in enumerate(on_th.indexsets[1])
        if name == devices[ix].name
            t1 = on_th.indexsets[2][1]
            if devices[ix].tech.realpower > 0.0
                init =1
            else
                init =0
            end
            Status[ix,t1] = @constraint(m, on_th[name,t1] == init + start_th[name,t1] - stopth[name,t1] )
            for t in on_th.indexsets[2][2:end]
                Status[ix,t] = @constraint(m, on_th[name,t] == on_th[name,t-1] + start_th[name,t] - stopth[name,t])
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end

function MinimumUpTime_th(m::JuMP.Model,on_th, start_th, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    (length(on_th.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (length(start_th.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (on_th.indexsets[1] !== start_th.indexsets[1]) ? warn("Start and Commitment Status variables indexes are inconsistent"): true
    @constraintref Uptime[1:length(on_th.indexsets[1]),1:length(on_th.indexsets[2])]
    for (ix,name) in enumerate(on_th.indexsets[1])
        if name == devices[ix].name
            for t in on_th.indexsets[2][2:end] #TODO : add initial condition constraint
                Uptime[ix,t] = @constraint(m,sum([start_th[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.up+1):t) if i > 0 ]) <= on_th[name,t])
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end

function MinimumDownTime_th(m::JuMP.Model,on_th, stopth, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    (length(on_th.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (length(stopth.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent") : true
    (on_th.indexsets[1] !== stopth.indexsets[1]) ? warn("Stop and Commitment Status variables indexes are inconsistent"): true
    @constraintref DownTime[1:length(on_th.indexsets[1]),1:length(on_th.indexsets[2])]
    for (ix,name) in enumerate(on_th.indexsets[1])
        if name == devices[ix].name
            for t in on_th.indexsets[2][2:end] #TODO : add initial condition constraint
                DownTime[ix,t] = @constraint(m,sum([stopth[name,Int(i)] for i in ((t-devices[ix].tech.timelimits.down + 1):t) if i > 0]) <= (1 - on_th[name,t]) )
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end