function loadvariables(m::JuMP.Model, devices_netinjection:: A, devices::Array{T,1}, time_periods::Int64) where {A <: JumpExpressionMatrix, T <: PowerSystems.ElectricLoad}
    on_set = [d.name for d in devices if (d.available == true && !isa(d,PowerSystems.StaticLoad))]

    t = 1:time_periods

    pcl = @variable(m, pcl[on_set,t] >= 0.0) # Power output of generators

    varnetinjectiterate!(devices_netinjection,  pcl, t, devices)

    return pcl, devices_netinjection
end

