function generationvariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: GenericBattery
    on_set = [d.name for d in devices if d.available]
    t = 1:time_periods
    @variable(m, pbtin[on_set,t] >= 0.0)
    @variable(m, pbtout[on_set,t] >= 0.0)
    return pbtin, pbtout
end

function storagevariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: GenericBattery
    on_set = [d.name for d in devices if d.available]
    t = 1:time_periods
    @variable(m, ebt[on_set,t] >= 0.0)
    return ebt
end

function powerconstraints(m::JuMP.Model, pbtin::PowerVariable, pbtout::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: GenericBattery

    (length(pbtin.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    (length(pbtout.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

    @constraintref Pmax_in[1:length(pbtin.indexsets[1]),1:length(pbtin.indexsets[2])]
    @constraintref Pmax_out[1:length(pbtout.indexsets[1]),1:length(pbtout.indexsets[2])]
    (pbtin.indexsets[1] !== pbtout.indexsets[1]) ? warn("Input/Output variables indexes are inconsistent"): true
    for t in pbtin.indexsets[2], (ix, name) in enumerate(pbtin.indexsets[1])
        if name == devices[ix].name
            Pmax_out[ix, t] = @constraint(m, pbtin[name, t] <= devices[ix].inputrealpowerlimit)
            Pmax_out[ix, t] = @constraint(m, pbtout[name, t] <= devices[ix].outputrealpowerlimit)
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end

function energybookkeeping(m::JuMP.Model, pbtin::PowerVariable, pbtout::PowerVariable, ebt::PowerVariable, devices::Array{T,1}, time_periods::Int64; ini_cond = 0.0) where T <: GenericBattery

    (length(pbtin.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent in P_bt_in"): true
    (length(pbtout.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent in P_bt_out"): true
    (length(ebt.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent in E_bt"): true

    @constraintref BookKeep_bt[1:length(ebt.indexsets[1]),1:length(ebt.indexsets[2])]

    (pbtin.indexsets[1] !== pbtout.indexsets[1]) ? warn("Input/Output Power variables indexes are inconsistent"): true
    (pbtout.indexsets[1] !== ebt.indexsets[1]) ? warn("Input/Output and Battery Energy variables indexes are inconsistent"): true

    # TODO: Change loop order
    # TODO: Add Initial SOC for storage
    for (ix,name) in enumerate(ebt.indexsets[1])
        if name == devices[ix].name
            t1 = pbtin.indexsets[2][1]
            BookKeep_bt[ix,t1] = @constraint(m,ebt[name,t1] == devices[ix].energy -  pbtout[name,t1]/devices[ix].efficiency.out + pbtin[name,t1]*devices[ix].efficiency.in)
            for t in ebt.indexsets[2][2:end]
                BookKeep_bt[ix,t] = @constraint(m,ebt[name,t] == ebt[name,t-1] -  pbtout[name,t]/devices[ix].efficiency.out + pbtin[name,t]*devices[ix].efficiency.in)
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end

function energyconstraint(m::JuMP.Model, ebt::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: GenericBattery

    (length(ebt.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref EnergyLimit_bt[1:length(ebt.indexsets[1]),1:length(ebt.indexsets[2])]
    for t in ebt.indexsets[2], (ix,name) in enumerate(ebt.indexsets[1])
        if name == devices[ix].name
            EnergyLimit_bt[ix,t] = @constraint(m,ebt[name,t] <= devices[ix].capacity.max)
        else
            error("Bus name in Array and variable do not match")
        end
    end
    return true
end