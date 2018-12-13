
"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower(ps_m::canonical_model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalDispatchForm, S <: PM.AbstractPowerFormulation}

    range_data = [(g.name, g.tech.activepowerlimits) for g in devices]

    device_range(ps_m, range_data, time_range, "thermal_active_range", "Pth")

end

"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function activepower(ps_m::canonical_model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalCommitmentForm, S <: AbstractDCPowerModel}

    p_th = m[:p_th]
    on_th = m[:on_th]

    time_index = m[:p_th].axes[2]
    name_index = m[:p_th].axes[1]

    (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

    pmax_th = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)
    pmin_th = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name
            pmin_th[name, t] = @constraint(m, p_th[name, t] >= devices[ix].tech.activepowerlimits.min*on_th[name,t])
            pmax_th[name, t] = @constraint(m, p_th[name, t] <= devices[ix].tech.activepowerlimits.max*on_th[name,t])
        else
            @error "Bus name in Array and variable do not match"
        end

    end

    JuMP.register_object(m, :pmax_th, pmax_th)
    JuMP.register_object(m, :pmin_th, pmin_th)

    return m
end


"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function reactivepower(ps_m::canonical_model, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_range::UnitRange{Int64}) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalDispatchForm, S <: AbstractACPowerModel}

    range_data = [(g.name, g.tech.reactivepowerlimits) for g in devices]

    device_range(ps_m, range_data , time_range, "thermal_reactive_range", "Qth")

end



"""
This function adds the power limits of generators when there are CommitmentVariables
"""
function reactivepower(m::JuMP.AbstractModel, devices::Array{T,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {T <: PowerSystems.ThermalGen, D <: AbstractThermalCommitmentForm, S <: AbstractACPowerModel}

    q_th = m[:p_th]
    on_th = m[:on_th]

    time_index = m[:q_th].axes[2]
    name_index = m[:q_th].axes[1]

    (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

    qmax_th = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(undef,length(name_index), time_periods), name_index, time_index)
    qmin_th = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(undef,llength(name_index), time_periods), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name
            qmin_th[name, t] = @constraint(m, q_th[name, t] >= devices[ix].tech.reactivepowerlimits.min*on_th[name,t])
            qmax_th[name, t] = @constraint(m, q_th[name, t] <= devices[ix].tech.reactivepowerlimits.max*on_th[name,t])
        else
            @error "Bus name in Array and variable do not match"
        end

    end

    JuMP.register_object(m, :qmax_th, qmax_th)
    JuMP.register_object(m, :qmin_th, qmin_th)

    return m
end