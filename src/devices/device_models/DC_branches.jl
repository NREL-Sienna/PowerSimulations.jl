struct DCSeriesBranch <: AbstractBranchFormulation end

abstract type AbstractDCLineForm <: AbstractBranchFormulation end

struct HVDC <: AbstractDCLineForm end

struct VoltageSourceDC <: AbstractDCLineForm end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::Array{B,1},
                        time_steps::UnitRange{Int64}) where {B <: PSY.DCBranch,
                                                             S <: PM.AbstractPowerFormulation}

end
