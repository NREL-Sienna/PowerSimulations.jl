function powerstoragevariables(m::JuMP.AbstractModel, devices_netinjection:: A, devices::Array{T,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, T <: PowerSystems.Storage}

    on_set = [d.name for d in devices if d.available]
    t = 1:time_periods

    pstin = @variable(m, pstin[on_set,t])
    pstout = @variable(m, pstout[on_set,t])

    devices_netinjection = varnetinjectiterate!(devices_netinjection,  pstin, pstout, t, devices)

    return pstin, pstout, devices_netinjection
end

function energystoragevariables(m::JuMP.AbstractModel, devices::Array{T,1}, time_periods::Int64) where T <: PowerSystems.Storage

    on_set = [d.name for d in devices if d.available]
    t = 1:time_periods

    ebt = @variable(m, ebt[on_set,t] >= 0.0)

    return ebt
end