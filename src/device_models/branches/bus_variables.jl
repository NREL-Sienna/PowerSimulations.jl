function anglevariables(m::JuMP.Model, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Branch, S <: PM.AbstractDCPForm}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    fbr = @variable(m, fbr[on_set,time_range])

end


function voltagevariables(m::JuMP.Model, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Branch, S <: PM.AbstractDCPForm}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    fbr = @variable(m, fbr[on_set,time_range])

end

