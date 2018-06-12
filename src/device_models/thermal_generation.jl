# TODO: Change the types in T from ThermalGento Thermal when PowerSystems gets updated

"""
This function add the variables for power generation output to the model
"""
function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    on_set = [d.name for d in devices if d.status == true]
    t = 1:time_periods
    @variable(m::JuMP.Model, P_th[on_set,t]) # Power output of generators
    return P_th   
end


"""
This function add the variables for power generation commitment to the model
"""
function CommitmentVariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    on_set = [d.name for d in devices if d.status == true]
    t = 1:time_periods
    @variable(m::JuMP.Model, on_th[on_set,t], Bin) # Power output of generators
    @variable(m::JuMP.Model, start_th[on_set,t], Bin) # Power output of generators
    @variable(m::JuMP.Model, stop_th[on_set,t], Bin) # Power output of generators
    return on_th, start_th, stop_th    
end

"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function PowerConstraints(m::JuMP.Model, P_th::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen
    (length(P_th.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    @constraintref Pmax_th[1:length(P_th.indexsets[1]),1:length(P_th.indexsets[2])]
    @constraintref Pmin_th[1:length(P_th.indexsets[1]),1:length(P_th.indexsets[2])]
    for (ix, name) in enumerate(P_th.indexsets[1])
            if name == devices[ix].name
                for t in P_th.indexsets[2]
                    Pmin_th[ix, t] = @constraint(m, P_th[name, t] >= devices[ix].tech.realpowerlimits.min)
                    Pmax_th[ix, t] = @constraint(m, P_th[name, t] <= devices[ix].tech.realpowerlimits.max)
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
function PowerConstraints(m::JuMP.Model, P_th, on_th, devices::Array{T,1}, time_periods::Int) where T <: ThermalGen

    (length(P_th.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref Pmax_th[1:length(P_th.indexsets[1]),1:length(P_th.indexsets[2])]
    @constraintref Pmin_th[1:length(P_th.indexsets[1]),1:length(P_th.indexsets[2])]
    for (ix, name) in enumerate(P_th.indexsets[1])
            if name == devices[ix].name
                for t in P_th.indexsets[2]
                    Pmin_th[ix, t] = @constraint(m, P_th[name, t] >= devices[ix].tech.realpowerlimits.min*on_th[name,t])
                    Pmax_th[ix, t] = @constraint(m, P_th[name, t] <= devices[ix].tech.realpowerlimits.max*on_th[name,t])
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end
