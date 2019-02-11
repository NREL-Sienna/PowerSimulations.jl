"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower(m::JuMP.AbstractModel, devices::Array{L,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {L <: PowerSystems.ElectricLoad, D <: AbstractControllableLoadForm, S <: PM.AbstractPowerFormulation}

    p_cl = m[:p_cl]
    time_index = m[:p_cl].axes[2]
    name_index = m[:p_cl].axes[1]

    (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

    pmax_cl = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(undef, length.(JuMP.axes(p_cl))), name_index, time_index)
    for t in time_index, (ix, name) in enumerate(name_index)
        if name == devices[ix].name
            pmax_cl[name, t] = @constraint(m, p_cl[name, t] <= devices[ix].maxactivepower * values(devices[ix].scalingfactor)[t])
        else
            @error "Bus name in Array and variable do not match"
        end

    end


    JuMP.register_object(m, :loadcontrol_activelimit, pmax_cl)

end


function reactivepower(m::JuMP.AbstractModel, devices::Array{L,1}, device_formulation::Type{D}, system_formulation::Type{S}, time_periods::Int64) where {L <: PowerSystems.ElectricLoad, D <: AbstractControllableLoadForm, S <: AbstractACPowerModel}

    q_cl = m[:q_cl]
    p_cl = m[:p_cl]
    time_index = m[:q_cl].axes[2]
    name_index = m[:q_cl].axes[1]

    (length(time_index) != time_periods) ? @error("Length of time dimension inconsistent") : true

    qmax_cl = JuMP.Containers.DenseAxisArray(Array{ConstraintRef}(undef, length.(JuMP.axes(q_cl))), name_index, time_index)

    for t in time_index, (ix, name) in enumerate(name_index)
        if name == devices[ix].name
            qmax_cl[name, t] = @constraint(m, q_cl[name, t] == p_cl[name, t]*sin(atan((devices[ix].maxactivepower/devices[ix].maxreactivepower))))
        else
            @error "Bus name in Array and variable do not match"
        end
    end

    JuMP.register_object(m, :loadcontrol_reactivelimit, qmax_cl)

end
