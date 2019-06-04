abstract type AbstractDCLineForm <: AbstractBranchFormulation end

struct HVDCLossless <: AbstractDCLineForm end

struct HVDC <: AbstractDCLineForm end

struct VoltageSourceDC <: AbstractDCLineForm end


function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenedVectorsIterator{B}) where {B <: PSY.DCBranch,
                                                             S <: StandardPTDFForm}
    
    return

end

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenedVectorsIterator{B},
                                device_formulation::Type{D},
                                system_formulation::Type{StandardPTDFForm}) where {B <: PSY.DCBranch,
                                                                     D <: AbstractBranchFormulation}

    range_data = [(h.name, (min = -1*h.rate, max = h.rate)) for h in devices]

    device_range(ps_m, 
                range_data, 
                Symbol("rate_limit_$(B)"), 
                Symbol("br_$(B)"))

    return

end