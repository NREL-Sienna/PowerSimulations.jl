struct DCSeriesBranch <: AbstractBranchFormulation end

abstract type AbstractDCLineForm <: AbstractBranchFormulation end

struct HVDC <: AbstractDCLineForm end

struct VoltageSourceDC <: AbstractDCLineForm end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::Array{B,1},
                        time_range::UnitRange{Int64}) where {B <: PSY.DCBranch,
                                                             S <: PM.AbstractPowerFormulation}

    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_to_$(B)"), 
                 false)
    add_variable(ps_m, 
                 devices, 
                 time_range, 
                 Symbol("Fbr_fr_$(B)"),  
                 false)

end
