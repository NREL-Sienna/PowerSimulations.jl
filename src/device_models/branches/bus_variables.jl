function anglevariables(m::JuMP.Model, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Bus, S <: PM.AbstractACForm}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    theta = @variable(m, theta[on_set,time_range])

end


function voltagevariables(m::JuMP.Model, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Bus, S <: PM.AbstractACForm}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    vm = @variable(m, vm[on_set,time_range])

end

