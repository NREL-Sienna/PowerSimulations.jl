function GenerationVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: GenericBattery
    on_set = [d.name for d in devices if d.status]
    t = 1:time_steps
    @variable(m, pbtin[on_set,t] >= 0.0)
    @variable(m, pbtout[on_set,t] >= 0.0) 
    return pbtin, pbtout       
end

function StorageVariables(m::JuMP.Model, devices::Array{T,1}, time_steps) where T <: GenericBattery
    on_set = [d.name for d in devices if d.status]
    t = 1:time_steps
    @variable(m, ebt[on_set,t] >= 0) 
    return ebt             
end

function PowerConstraints(m::JuMP.Model, pbtin::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, pbtout::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, devices::Array{T,1}, time_periods::Int) where T <: GenericBattery
    (length(pbtin.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    (length(pbtout.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    @constraintref Pmax_in[1:length(pbtin.indexsets[1]),1:length(pbtin.indexsets[2])]
    @constraintref Pmax_out[1:length(pbtout.indexsets[1]),1:length(pbtout.indexsets[2])]
    (pbtin.indexsets[1] !== pbtout.indexsets[1]) ? warn("Input/Output variables indexes are inconsistent"): true
    for (ix, name) in enumerate(pbtin.indexsets[1])
            if name == devices[ix].name
                for t in pbtin.indexsets[2]
                    Pmax_out[ix, t] = @constraint(m, pbtin[name, t] <= devices[ix].inputrealpowerlimit)
                    Pmax_out[ix, t] = @constraint(m, pbtout[name, t] <= devices[ix].outputrealpowerlimit)
                end    
            else
                error("Bus name in Array and variable do not match")
            end
    end
    return true
end

function EnergyBalanceConstraint(m::JuMP.Model, pbtin::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, pbtout::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, ebt::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, devices::Array{T,1}, time_periods::Int) where T <: GenericBattery
    (length(pbtin.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    (length(pbtout.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    (length(ebt.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref Balance[1:length(ebt.indexsets[1]),1:length(ebt.indexsets[2])] 
    (pbtin.indexsets[1] !== pbtout.indexsets[1]) ? warn("Input/Output variables indexes are inconsistent"): true
    for (ix,name) in enumerate(ebt.indexsets[1])
        if name == devices[ix].name
            t1 = pbtin.indexsets[2][1]
            Balance[ix,t1] = @constraint(m,ebt[name,t1] == devices[ix].energy -  pbtout[name,t1]/devices[ix].efficiency.out + pbtin[name,t1]*devices[ix].efficiency.in)
            for t in ebt.indexsets[2][2:end] 
                Balance[ix,t] = @constraint(m,ebt[name,t] == ebt[name,t-1] -  pbtout[name,t]/devices[ix].efficiency.out + pbtin[name,t]*devices[ix].efficiency.in)    
            end
        end
    end
    return true
end

function EnergyLimitConstraint(m::JuMP.Model, ebt::JuMP.JuMPArray{JuMP.Variable,2,Tuple{Array{String,1},UnitRange{Int64}}}, devices::Array{T,1}, time_periods::Int) where T <: GenericBattery

    (length(ebt.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref Limit[1:length(ebt.indexsets[1]),1:length(ebt.indexsets[2])]
    for (ix,name) in enumerate(ebt.indexsets[1])
        if name == devices[ix].name
            for t in ebt.indexsets[2]
                Limit[ix,t] =@constraint(m,ebt[name,t] <= devices[ix].capacity.max)
            end
        end
    end
    return true
end