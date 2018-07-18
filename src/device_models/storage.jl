function powerstoragevariables(m::JuMP.Model, devices_netinjection:: A, devices::Array{T,1}, time_periods::Int64) where {A <: PowerExpressionArray, T <: PowerSystems.Storage}

    on_set = [d.name for d in devices if d.available]
    t = 1:time_periods

    pstin = @variable(m, pstin[on_set,t])
    pstout = @variable(m, pstout[on_set,t])

    devices_netinjection = varnetinjectiterate!(devices_netinjection,  pstin, pstout, t, devices)

    return pstin, pstout, devices_netinjection
end

function energystoragevariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.Storage

    on_set = [d.name for d in devices if d.available]
    t = 1:time_periods

    ebt = @variable(m, ebt[on_set,t] >= 0.0)

    return ebt
end

function powerconstraints(m::JuMP.Model, pstin::PowerVariable, pstout::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.Storage

    (length(pstin.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    (length(pstout.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

    @constraintref Pmax_in[1:length(pstin.indexsets[1]),1:length(pstin.indexsets[2])]
    @constraintref Pmax_out[1:length(pstout.indexsets[1]),1:length(pstout.indexsets[2])]
    @constraintref Pmin_in[1:length(pstin.indexsets[1]),1:length(pstin.indexsets[2])]
    @constraintref Pmin_out[1:length(pstout.indexsets[1]),1:length(pstout.indexsets[2])]

    (pstin.indexsets[1] !== pstout.indexsets[1]) ? warn("Input/Output variables indexes are inconsistent"): true

    for t in pstin.indexsets[2], (ix, name) in enumerate(pstin.indexsets[1])
        if name == devices[ix].name
            Pmin_in[ix, t] = @constraint(m, pstin[name, t] <= devices[ix].inputrealpowerlimits.min)
            Pmin_out[ix, t] = @constraint(m, pstout[name, t] <= devices[ix].outputrealpowerlimits.min)
            Pmax_in[ix, t] = @constraint(m, pstin[name, t] <= devices[ix].inputrealpowerlimits.max)
            Pmax_out[ix, t] = @constraint(m, pstout[name, t] <= devices[ix].outputrealpowerlimits.max)
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :PmaxIn, Pmax_in)
    JuMP.registercon(m, :PmaxOut, Pmax_out)
    JuMP.registercon(m, :PminIn, Pmin_in)
    JuMP.registercon(m, :PminOut, Pmin_out)

    return m
end

function energybookkeeping(m::JuMP.Model, pstin::PowerVariable, pstout::PowerVariable, ebt::PowerVariable, devices::Array{T,1}, time_periods::Int64; ini_cond = 0.0) where T <: PowerSystems.GenericBattery

    (length(pstin.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent in P_bt_in"): true
    (length(pstout.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent in P_bt_out"): true
    (length(ebt.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent in E_bt"): true

    @constraintref BookKeep_bt[1:length(ebt.indexsets[1]),1:length(ebt.indexsets[2])]

    (pstin.indexsets[1] !== pstout.indexsets[1]) ? warn("Input/Output Power variables indexes are inconsistent"): true
    (pstin.indexsets[1] !== ebt.indexsets[1]) ? warn("Input/Output and Battery Energy variables indexes are inconsistent"): true

    # TODO: Change loop order
    # TODO: Add Initial SOC for storage for sequential simulation
    for (ix,name) in enumerate(ebt.indexsets[1])
        if name == devices[ix].name
            t1 = pstin.indexsets[2][1]
            BookKeep_bt[ix,t1] = @constraint(m,ebt[name,t1] == devices[ix].energy -  pstout[name,t1]/devices[ix].efficiency.out + pstin[name,t1]*devices[ix].efficiency.in)
            for t in ebt.indexsets[2][2:end]
                BookKeep_bt[ix,t] = @constraint(m,ebt[name,t] == ebt[name,t-1] -  pstout[name,t]/devices[ix].efficiency.out + pstin[name,t]*devices[ix].efficiency.in)
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :BookKeep, BookKeep_bt)

    return m

end

function energyconstraints(m::JuMP.Model, ebt::PowerVariable, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.GenericBattery

    (length(ebt.indexsets[2]) != time_periods) ? error("Length of time dimension inconsistent"): true
    @constraintref EnergyLimit_bt[1:length(ebt.indexsets[1]),1:length(ebt.indexsets[2])]
    for t in ebt.indexsets[2], (ix,name) in enumerate(ebt.indexsets[1])
        if name == devices[ix].name
            EnergyLimit_bt[ix,t] = @constraint(m,ebt[name,t] <= devices[ix].capacity.max)
        else
            error("Bus name in Array and variable do not match")
        end
    end

    JuMP.registercon(m, :EmaxMit, EnergyLimit_bt)

    return m
end