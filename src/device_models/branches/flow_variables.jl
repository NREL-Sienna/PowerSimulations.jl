
function flowvariables(ps_m::canonical_model, system_formulation::Type{S}, devices::Array{B,1}, time_range::UnitRange{Int64}) where {B <: PowerSystems.Branch, S <: PM.DCPlosslessForm}

    add_variable(ps_m, devices, time_range, "Fbr")

end


function flowvariables(ps_m::canonical_model, system_formulation::Type{S}, devices::Array{B,1}, time_range::UnitRange{Int64}) where {B <: PowerSystems.Branch, S <: PM.AbstractDCPLLForm}

    add_variable(ps_m, devices, time_range, "Fbr_to")
    add_variable(ps_m, devices, time_range, "Fbr_dr")

end

function flowvariables(ps_m::canonical_model, system_formulation::Type{S}, devices::Array{B,1}, time_range::UnitRange{Int64}) where {B <: PowerSystems.Branch, S <: AbstractACPowerModel}

    add_variable(ps_m, devices, time_range, "PFbr_to")
    add_variable(ps_m, devices, time_range, "PFbr_dr")

    add_variable(ps_m, devices, time_range, "QFbr_to")
    add_variable(ps_m, devices, time_range, "QFbr_dr")

end