
"""
This function adds the power limits of generators when there are no CommitmentVariables
"""
function activepower_dispatch(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    pth = m[:pth]
    time_index = m[:pth].indexsets[2]
    name_index = m[:pth].indexsets[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent"): true

    # TODO: @constraintref dissapears in JuMP 0.19. A new syntax goes here.
    # JuMP.JuMPArray(Array{ConstraintRef}(JuMP.size(x)), x.indexsets[1], x.indexsets[2])

    @constraintref pmax_thermal[1:length(name_index),1:length(time_index)]
    @constraintref pmin_thermal[1:length(name_index),1:length(time_index)]

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name

            pmin_thermal[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min)
            pmax_thermal[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max)

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
function activepower_commitment(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.ThermalGen

    pth = m[:pth]
    onth = m[:onth]

    time_index = m[:pth].indexsets[2]
    name_index = m[:pth].indexsets[1]

    (length(time_index) != time_periods) ? error("Length of time dimension inconsistent"): true

    @constraintref pmax_thermal[1:length(name_index),1:length(time_index)]
    @constraintref pmin_thermal[1:length(name_index),1:length(time_index)]

    for t in time_index, (ix, name) in enumerate(name_index)

        if name == devices[ix].name
            pmin_thermal[ix, t] = @constraint(m, pth[name, t] >= devices[ix].tech.realpowerlimits.min*onth[name,t])
            pmax_thermal[ix, t] = @constraint(m, pth[name, t] <= devices[ix].tech.realpowerlimits.max*onth[name,t])
        else
            error("Bus name in Array and variable do not match")
        end

    end

    JuMP.registercon(m, :pmax_thermal, pmax_thermal)
    JuMP.registercon(m, :pmin_thermal, pmin_thermal)

    return m
end

function powerconstraints(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64, commitment::Bool = false) where T <: PowerSystems.ThermalGen

    commitment ? m = activepower_commitment(m, devices, time_periods) : m = activepower_dispatch(m, devices, time_periods)

    return m

end