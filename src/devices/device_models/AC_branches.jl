#Generic Branch Models
abstract type AbstractBranchFormulation <: AbstractDeviceFormulation end

#Abstract Line Models

abstract type AbstractLineFormulation <: AbstractBranchFormulation end

struct StaticLine <: AbstractLineFormulation end
struct StaticLineUnbounded <: AbstractLineFormulation end

struct FlowMonitoredLine <: AbstractLineFormulation end

#Abstract Transformer Models

abstract type AbstractTransformerFormulation <: AbstractBranchFormulation end

struct StaticTransformer <: AbstractTransformerFormulation end
struct StaticTransformerUnbounded <: AbstractTransformerFormulation end

# Not implemented yet
struct TapControl <: AbstractTransformerFormulation end
struct PhaseControl <: AbstractTransformerFormulation end

#################################### Branch Variables ##################################################
# Because of the way we integrate with PowerModels, most of the time PowerSimulations will create variables
# for the branch flows either in AC or DC.
function flow_variables!(canonical_model::CanonicalModel,
                        system_formulation::Type{S},
                        devices::IS.FlattenIteratorWrapper{B}) where {B<:PSY.ACBranch,
                                                             S<:PM.AbstractPowerModel}
    return

end

function flow_variables!(canonical_model::CanonicalModel,
                        system_formulation::Type{S},
                        devices::IS.FlattenIteratorWrapper{B}) where {B<:PSY.ACBranch,
                                                                      S<:StandardPTDFModel}

    var_name = Symbol("Fp_$(B)")

    add_variable(canonical_model,
                devices,
                var_name,
                false)
                #ub_value = d -> PSY.get_rate(d), # Add flow bounds in rate constraints
                #lb_value = d -> -1.0*PSY.get_rate(d))

    return

end

#################################### Flow Variable Bounds ##################################################
function branch_rate_bounds!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.ACBranch,
                                                                    D<:AbstractBranchFormulation,
                                                                    S<:PM.AbstractDCPModel}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    set_variable_bounds(canonical_model,
                        range_data,
                        Symbol("Fp_$(B)"))

    return

end

function branch_rate_bounds!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.ACBranch,
                                                                    D<:AbstractBranchFormulation,
                                                                    S<:PM.AbstractActivePowerModel}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    set_variable_bounds(canonical_model,
                        range_data,
                        Symbol("FpFT_$(B)"))

    set_variable_bounds(canonical_model,
                        range_data,
                        Symbol("FpTF_$(B)"))

    return

end

function branch_rate_bounds!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.ACBranch,
                                                                    D<:AbstractBranchFormulation,
                                                                    S<:PM.AbstractPowerModel}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    set_variable_bounds(canonical_model,
                        range_data,
                        Symbol("FpFT_$(B)"))

    set_variable_bounds(canonical_model,
                        range_data,
                        Symbol("FpTF_$(B)"))

    return

end

#################################### Rate Limits Constraints ##################################################
function branch_rate_constraint!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.ACBranch,
                                                                    D<:AbstractBranchFormulation,
                                                                    S<:PM.AbstractDCPModel}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    device_range(canonical_model,
                range_data,
                Symbol("RateLimit_$(B)"),
                Symbol("Fp_$(B)"))

    return

end

function branch_rate_constraint!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.ACBranch,
                                                                    D<:AbstractBranchFormulation,
                                                                    S<:PM.AbstractActivePowerModel}

    range_data = [(PSY.get_name(h), (min = -1*PSY.get_rate(h), max = PSY.get_rate(h))) for h in devices]

    device_range(canonical_model,
                range_data,
                Symbol("RateLimitFT_$(B)"),
                Symbol("FpFT_$(B)"))

    device_range(canonical_model,
                range_data,
                Symbol("RateLimitTF_$(B)"),
                Symbol("FpTF_$(B)"))

    return

end


function branch_rate_constraint!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{B},
                                device_formulation::Type{D},
                                system_formulation::Type{S}) where {B<:PSY.ACBranch,
                                                                    D<:AbstractBranchFormulation,
                                                                    S<:PM.AbstractPowerModel}

    range_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    rating_constraint!(canonical_model,
                        range_data,
                        Symbol("RateLimitFT_$(B)"),
                        (Symbol("FpFT_$(B)"), Symbol("FqFT_$(B)")))

    rating_constraint!(canonical_model,
                        range_data,
                        Symbol("RateLimitTF_$(B)"),
                        (Symbol("FpTF_$(B)"), Symbol("FqTF_$(B)")))

    return

end

#################################### Flow Limits Constraints ##################################################

function branch_flow_constraint!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{PSY.MonitoredLine},
                                device_formulation::Type{FlowMonitoredLine},
                                system_formulation::Union{Type{PM.DCPPowerModel}, Type{StandardPTDFModel}})


    flow_range_data = [(PSY.get_name(h), PSY.get_flowlimits(h)) for h in devices]

    var_name = Symbol("Fp_$(B)")

    device_range(canonical_model,
                range_data,
                Symbol("FlowLimit_$(B)"),
                var_name)

    return

end

function branch_flow_constraint!(canonical_model::CanonicalModel,
                                devices::IS.FlattenIteratorWrapper{PSY.MonitoredLine},
                                device_formulation::Type{FlowMonitoredLine},
                                system_formulation::Type{S}) where {S<:PM.AbstractPowerModel}

    FTflow_range_data = [(PSY.get_name(h), PSY.get_flowlimits(h)) for h in devices]
    TFflow_range_data = [(PSY.get_name(h), (min = PSY.get_flowlimits(h).max, max = PSY.get_flowlimits(h).min)) for h in devices]

    device_range(canonical_model,
                FTflow_range_data,
                Symbol("FlowLimitFT_$(B)"),
                Symbol("FpFT_$(B)"))

    device_range(canonical_model,
                TFflow_range_data,
                Symbol("FlowLimitTF_$(B)"),
                Symbol("FpTF_$(B)"))


    return

end
