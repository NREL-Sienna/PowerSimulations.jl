
function flowvariables(m::JuMP.Model, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Branch, S <: PM.AbstractDCPForm}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    fbr = @variable(m, fbr[on_set,time_range])

end


function flowvariables(m::JuMP.Model, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Branch, S <: PM.AbstractDCPLLForm}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    fbr_to = @variable(m, fbr_to[on_set,time_range])
    fbr_fr = @variable(m, fbr_fr[on_set,time_range])

end

function flowvariables(m::JuMP.Model, system_formulation::Type{S}, devices::Array{B,1}, time_periods::Int64) where {B <: PowerSystems.Branch, S <: AbstractACPowerModel}

    on_set = [d.name for d in devices if d.available == true]

    time_range = 1:time_periods

    active_fbr_to = @variable(m, active_fbr_to[on_set,time_range])
    active_fbr_fr = @variable(m, active_fbr_fr[on_set,time_range])

    reactive_fbr_to = @variable(m, reactive_fbr_to[on_set,time_range])
    reactive_fbr_fr = @variable(m, reactive_fbr_fr[on_set,time_range])

end