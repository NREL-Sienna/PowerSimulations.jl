#Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

#Abstract Line Models

abstract type AbstractLineForm <: AbstractBranchFormulation end

struct StaticLine <: AbstractLineForm end
struct StaticLineUnbounded <: AbstractLineForm end

struct FlowMonitoredLine <: AbstractLineForm end

#Abstract Transformer Models

abstract type AbstractTransformerForm <: AbstractBranchFormulation end

struct StaticTransformer <: AbstractTransformerForm end
struct StaticTransformerUnbounded <: AbstractTransformerForm end

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

    var_name = Symbol("Fp_$(B)")

    add_variable(ps_m,
                devices,
                var_name,
                false)
                #ub_value = d -> PSY.get_rate(d), # Add flow bounds in rate constraints
                #lb_value = d -> -1.0*PSY.get_rate(d))

    return

end

#################################### Flow Limits Variables ##################################################

function branch_rate_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Union{Type{PM.DCPlosslessForm}, Type{StandardPTDFForm}}) where {B <: PSY.ACBranch,
                                                                    D <: AbstractBranchFormulation}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    var_name = Symbol("Fp_$(B)")

    device_range(ps_m,
                range_data,
                Symbol("RateLimit_$(B)"),
                var_name)

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
                Symbol("RateLimitFT_$(B)"),
                Symbol("FpFT_$(B)"))
    
    device_range(ps_m,
                range_data,
                Symbol("RateLimitTF_$(B)"),
                Symbol("FpTF_$(B)"))


    return

end


function branch_rate_constraint(ps_m::CanonicalModel,
    devices::PSY.FlattenIteratorWrapper{B},
    device_formulation::Type{D},
    system_formulation::Type{S}) where {B <: PSY.ACBranch,
                                        D <: AbstractBranchFormulation,
                                        S <: PM.AbstractPowerFormulation}

    range_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    rating_constraint(ps_m,
                        range_data,
                        Symbol("RateLimitFT_$(B)"),
                        (Symbol("FpFT_$(B)"), Symbol("FqFT_$(B)")))

    rating_constraint(ps_m,
                        range_data,
                        Symbol("RateLimitTF_$(B)"),
                        (Symbol("FpTF_$(B)"), Symbol("FqTF_$(B)")))

    return

end

function branch_rate_constraint(ps_m::CanonicalModel,
    devices::PSY.FlattenIteratorWrapper{B},
    device_formulation::Union{Type{StaticLineUnbounded}, Type{StaticTransformerUnbounded}},
    system_formulation::Type{S}) where {B <: PSY.ACBranch,
                                        S <: PM.AbstractPowerFormulation}

    # This code is intended to do nothing

    return

end


function branch_flow_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{PSY.MonitoredLine}, # TODO: Do we need an AbstractMonitoredLine?
                                device_formulation::Type{FlowMonitoredLine},
                                system_formulation::Union{Type{PM.DCPlosslessForm}, Type{StandardPTDFForm}})


    flow_range_data = [(PSY.get_name(h), PSY.get_flowlimits(h)) for h in devices]

    var_name = Symbol("Fp_$(B)")

    device_range(ps_m,
                range_data,
                Symbol("FlowLimit_$(B)"),
                var_name)

    return

end

function branch_flow_constraint(ps_m::CanonicalModel,
                                devices::PSY.FlattenIteratorWrapper{PSY.MonitoredLine},
                                device_formulation::Type{FlowMonitoredLine},
                                system_formulation::Type{S}) where {S <: PM.AbstractPowerFormulation}

    FTflow_range_data = [(PSY.get_name(h), PSY.get_flowlimits(h)) for h in devices]
    TFflow_range_data = [(PSY.get_name(h), (min = PSY.get_flowlimits(h).max, max = PSY.get_flowlimits(h).min)) for h in devices]

    device_range(ps_m,
                FTflow_range_data,
                Symbol("FlowLimitFT_$(B)"),
                Symbol("FpFT_$(B)"))
    
    device_range(ps_m,
                TFflow_range_data,
                Symbol("FlowLimitTF_$(B)"),
                Symbol("FpTF_$(B)"))


    return

end