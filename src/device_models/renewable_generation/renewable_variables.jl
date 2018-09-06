function activepowervariables(m::JuMP.Model, devices_netinjection::A, devices::Array{T,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, T <: PowerSystems.RenewableGen}

    on_set = [d.name for d in devices]

    t = 1:time_periods

    pre = @variable(m, pre[on_set,t] >= 0) # Power output of generators

    devices_netinjection = varnetinjectiterate!(devices_netinjection,  pre, t, devices)

    return pre, devices_netinjection
end
