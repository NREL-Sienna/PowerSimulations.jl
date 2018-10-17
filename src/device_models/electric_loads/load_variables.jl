function activepowervariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where {T <: PowerSystems.ElectricLoad}

    on_set = [d.name for d in devices]

    t = 1:time_periods

    p_cl = @variable(m, p_cl[on_set,t] >= 0.0, start = 0.0) # Power of controllable loads

    return p_cl
end

function reactivepowervariables(m::JuMP.Model, devices::Array{T,1}, time_periods::Int64) where {T <: PowerSystems.ElectricLoad}

    on_set = [d.name for d in devices]

    t = 1:time_periods

    q_cl = @variable(m, q_cl[on_set,t] >= 0.0, start = 0.0) # Power of controllable loads

    return q_cl
end