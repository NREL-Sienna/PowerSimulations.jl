function activepowervariables(m::JuMP.Model, devices_netinjection::A, devices::Array{T,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, T <: PowerSystems.HydroGen}

    on_set = [d.name for d in devices if d.available == true]

    t = 1:time_periods

    phy = @variable(m, phy[on_set,t]) # Power output of generators

    devices_netinjection = varnetinjectiterate!(devices_netinjection,  phy, t, devices)

    return phy, devices_netinjection

end