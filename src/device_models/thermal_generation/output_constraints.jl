
"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower(m::JuMP.Model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractDispatchForm, S <: AbstractDCPowerModel}

    pth = m[:pth]
    time_index = m[:pth].axes[2]
    name_index = m[:pth].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    pmax_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)
    pmin_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name

            pmin_thermal[name, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min)
            pmax_thermal[name, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max)

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
function activepower(m::JuMP.Model, devices::Array{D,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractDispatchForm, S <: AbstractDCPowerModel}

    pth = m[:pth]
    onth = m[:onth]

    time_index = m[:pth].axes[2]
    name_index = m[:pth].axes[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent") : true

    pmax_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)
    pmin_thermal = JuMP.JuMPArray(Array{ConstraintRef}(undef,length.(axes(pth))), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name
            pmin_thermal[name, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min*onth[name,t])
            pmax_thermal[name, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max*onth[name,t])
        else
            error("Bus name in Array and variable do not match")
        end

    end

    JuMP.registercon(m, :pmax_thermal, pmax_thermal)
    JuMP.registercon(m, :pmin_thermal, pmin_thermal)

    return m
end