function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: GenericBattery
    on_set = [d.name for d in devices if d.status]
    t = 1:time_steps
    @variable(m, P_bt_in[on_set,t] >= 0.0)
    @variable(m, P_bt_out[on_set,t] >= 0.0) 
    return P_bt_in, P_bt_out       
end

function StorageVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: GenericBattery
    on_set = [d.name for d in devices if d.status]
    t = 1:time_steps
    @variable(m, E_bt[on_set,t] >= 0) 
    return E_bt             
end

function PowerConstraints(m::JuMP.Model, P_bt_in::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, P_bt_out::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, devices::Array{T,1}, time_periods::Int) where T <: GenericBattery
    (length(P_bt_in.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    (length(P_bt_out.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    @constraintref Pmax_in[1:length(P_bt_in.indexsets[1]),1:length(P_bt_in.indexsets[2])]
    @constraintref Pmax_out[1:length(P_bt_out.indexsets[1]),1:length(P_bt_out.indexsets[2])]
    (P_bt_in.indexsets[1] !== P_bt_out.indexsets[1]) ? warn("Input/Output variables indexes are inconsistent"): true
    for (ix, name) in enumerate(P_bt_in.indexsets[1])
            if name == devices[ix].name
                for t in P_bt_in.indexsets[2]
                    Pmax_out[ix, t] = @constraint(m, P_bt_in[name, t] <= devices[ix].inputrealpowerlimit)
                    Pmax_out[ix, t] = @constraint(m, P_bt_out[name, t] <= devices[ix].outputrealpowerlimit)
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end

