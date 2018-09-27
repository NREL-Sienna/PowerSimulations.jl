function activepowervariables(m::JuMP.Model, devices::Array{R,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, R <: PowerSystems.RenewableGen}

    on_set = [d.name for d in devices]

    t = 1:time_periods

    p_re = @variable(m, p_re[on_set,t] >= 0)

    return p_re

end

function reactivepowervariables(m::JuMP.Model, devices::Array{R,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, R <: PowerSystems.RenewableGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    q_re = @variable(m, q_re[on_set,t]) # Power output of generators

    return q_re
end


