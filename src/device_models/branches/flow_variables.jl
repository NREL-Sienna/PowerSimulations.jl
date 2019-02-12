function flow_variables(ps_m::CanonicalModel, system_formulation::Type{S}, devices::Array{B,1}, time_range::UnitRange{Int64}) where {B <: PSY.Branch, S <: PM.DCPlosslessForm}

    add_variable(ps_m, devices, time_range, "Fbr", false)

end


function flow_variables(ps_m::CanonicalModel, system_formulation::Type{S}, devices::Array{B,1}, time_range::UnitRange{Int64}) where {B <: PSY.Branch, S <: PM.AbstractDCPLLForm}

    add_variable(ps_m, devices, time_range, "Fbr_to", false)
    add_variable(ps_m, devices, time_range, "Fbr_fr", false)

end

function flow_variables(ps_m::CanonicalModel, system_formulation::Type{S}, devices::Array{B,1}, time_range::UnitRange{Int64}) where {B <: PSY.Branch, S <: PM.AbstractPowerFormulation}

    add_variable(ps_m, devices, time_range, "PFbr_to", false)
    add_variable(ps_m, devices, time_range, "PFbr_fr", false)

    add_variable(ps_m, devices, time_range, "QFbr_to", false)
    add_variable(ps_m, devices, time_range, "QFbr_fr", false)

end