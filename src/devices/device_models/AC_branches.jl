#Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

#Abstract Line Models

abstract type AbstractLineForm <: AbstractBranchFormulation end

struct StaticLine <: AbstractLineForm end

#Abstract Transformer Models

abstract type AbstractTransformerForm <: AbstractBranchFormulation end

struct StaticTransformer <: AbstractTransformerForm end

# Not implemented yet
struct TapControl <: AbstractTransformerForm end
struct PhaseControl <: AbstractTransformerForm end

#################################### Branch Variables ##################################################
# Because of the way we integrate with PowerModels, most of the time PowerSimulations will create variables
# for the branch flows either in AC or DC.
function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenIteratorWrapper{B}) where {B <: PSY.ACBranch,
                                                             S <: PM.AbstractPowerFormulation}
    return

end

function flow_variables(ps_m::CanonicalModel,
                        system_formulation::Type{S},
                        devices::PSY.FlattenIteratorWrapper{B}) where {B <: PSY.ACBranch,
                                                             S <: StandardPTDFForm}

    var_name = Symbol("Pbr_$(B)")

    add_variable(ps_m,
                devices,
                var_name,
                false,
                ub_value = d -> PSY.get_rate(d),
                lb_value = d -> -1.0*PSY.get_rate(d))

    return

end

#################################### Flow Limits Variables ##################################################

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{StandardPTDFForm}) where {B <: PSY.ACBranch,
                                                                    D <: AbstractBranchFormulation}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    device_range(ps_m,
                range_data,
                Symbol("rate_limit_$(B)"),
                Symbol("Pbr_$(B)"))


    return

end

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{PM.DCPlosslessForm}) where {B <: PSY.ACBranch,
                                                                    D <: AbstractBranchFormulation}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    device_range(ps_m,
                range_data,
                Symbol("rate_limit_fwd_$(B)"),
                Symbol("Pbr_fwd_$(B)"))


    return

end

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B <: PSY.ACBranch,
                                                                    D <: AbstractBranchFormulation,
                                                                    S <: PM.AbstractActivePowerFormulation}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    device_range(ps_m,
                range_data,
                Symbol("rate_limit_fwd_$(B)"),
                Symbol("Pbr_fwd_$(B)"))
    
    device_range(ps_m,
                range_data,
                Symbol("rate_limit_bwd_$(B)"),
                Symbol("Pbr_bwd_$(B)"))


    return

end


function branch_rate_constraint(ps_m::CanonicalModel,
    devices::PSY.FlattenIteratorWrapper{B},
    device_formulation::Type{D},
    system_formulation::Type{S}) where {B <: PSY.ACBranch,
                                        D <: AbstractBranchFormulation,
                                        S <: PM.AbstractPowerFormulation}

    @show range_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    rating_constraint(ps_m,
                        range_data,
                        Symbol("rate_limit_fwd_$(B)"),
                        (Symbol("Pbr_fwd_$(B)"), Symbol("Qbr_fwd_$(B)")))

    rating_constraint(ps_m,
                        range_data,
                        Symbol("rate_limit_bwd_$(B)"),
                        (Symbol("Pbr_bwd_$(B)"), Symbol("Qbr_bwd_$(B)")))

    return

end
