
"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    pth = m[:pth]
    time_index = m[:pth].axes[2]
    name_index = m[:pth].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    pmax_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)
    pmin_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name

            pmin_thermal[name, t] = @constraint(m, pth[name, t] >= devices[ix].tech.activepowerlimits.min)
            pmax_thermal[name, t] = @constraint(m, pth[name, t] <= devices[ix].tech.activepowerlimits.max)

        else
            error("Bus name in Array and variable do not match")
        end

    end

    JuMP.registercon(m, :pmax_thermal, pmax_thermal)
    JuMP.registercon(m, :pmin_thermal, pmin_thermal)

    return m
end

"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function activepower(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalCommitmentForm, S <: AbstractDCPowerModel}

    pth = m[:pth]
    onth = m[:onth]

    time_index = m[:pth].axes[2]
    name_index = m[:pth].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    pmax_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)
    pmin_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name
            pmin_thermal[name, t] = @constraint(m, pth[name, t] >= devices[ix].tech.activepowerlimits.min*onth[name,t])
            pmax_thermal[name, t] = @constraint(m, pth[name, t] <= devices[ix].tech.activepowerlimits.max*onth[name,t])
        else
            error("Bus name in Array and variable do not match")
        end

    end

    JuMP.registercon(m, :pmax_thermal, pmax_thermal)
    JuMP.registercon(m, :pmin_thermal, pmin_thermal)

    return m
end


"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function reactivepower(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalDispatchForm, S <: AbstractACPowerModel}

    qth = m[:qth]
    time_index = m[:qth].axes[2]
    name_index = m[:qth].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    qmax_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(qth))), name_index, time_index)
    qmin_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(qth))), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name

            qmin_thermal[name, t] = @constraint(m, qth[name, t] >= devices[ix].tech.reactivepowerlimits.min)
            qmax_thermal[name, t] = @constraint(m, qth[name, t] <= devices[ix].tech.reactivepowerlimits.max)

        else
            error("Bus name in Array and variable do not match")
        end

    end

    JuMP.registercon(m, :qmax_thermal, qmax_thermal)
    JuMP.registercon(m, :qmin_thermal, qmin_thermal)

    return m
end



"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function reactivepower(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalCommitmentForm, S <: AbstractACPowerModel}

    qth = m[:pth]
    onth = m[:onth]

    time_index = m[:qth].axes[2]
    name_index = m[:qth].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    qmax_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(qth))), name_index, time_index)
    qmin_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(qth))), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name
            qmin_thermal[name, t] = @constraint(m, qth[name, t] >= devices[ix].tech.reactivepowerlimits.min*onth[name,t])
            qmax_thermal[name, t] = @constraint(m, qth[name, t] <= devices[ix].tech.reactivepowerlimits.max*onth[name,t])
        else
            error("Bus name in Array and variable do not match")
        end

    end

    JuMP.registercon(m, :qmax_thermal, qmax_thermal)
    JuMP.registercon(m, :qmin_thermal, qmin_thermal)

    return m
end