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
flow_variables!(psi_container::PSIContainer,
                ::Type{<:PM.AbstractPowerModel},
                ::IS.FlattenIteratorWrapper{<:PSY.ACBranch}) = nothing

function flow_variables!(psi_container::PSIContainer,
                        ::Type{<:StandardPTDFModel},
                        devices::IS.FlattenIteratorWrapper{B}) where B<:PSY.ACBranch
    var_name = Symbol("Fp_$(B)")

    add_variable(psi_container,
                devices,
                var_name,
                false)
    return
end

#################################### Flow Variable Bounds ##################################################
function branch_rate_bounds!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                ::Type{<:AbstractBranchFormulation},
                                ::Type{<:PM.AbstractDCPModel}) where {B<:PSY.ACBranch}
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values[ix] = (min = -1*PSY.get_rate(d), max = PSY.get_rate(d))
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end
    set_variable_bounds(psi_container,
                        DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                        Symbol("Fp_$(B)"))
    return
end

function branch_rate_bounds!(psi_container::PSIContainer,
                            devices::IS.FlattenIteratorWrapper{B},
                            ::Type{<:AbstractBranchFormulation},
                            ::Type{<:PM.AbstractActivePowerModel}) where B<:PSY.ACBranch
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values[ix] = (min = -1*PSY.get_rate(d), max = PSY.get_rate(d))
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end
    set_variable_bounds(psi_container,
                        DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                        Symbol("FpFT_$(B)"))

    set_variable_bounds(psi_container,
                        DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                        Symbol("FpTF_$(B)"))
    return
end

function branch_rate_bounds!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                ::Type{D},
                                ::Type{S}) where {B<:PSY.ACBranch,
                                                  D<:AbstractBranchFormulation,
                                                  S<:PM.AbstractPowerModel}
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values[ix] = (min = -1*PSY.get_rate(d), max = PSY.get_rate(d))
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end
    set_variable_bounds(psi_container,
                        DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                        Symbol("FpFT_$(B)"))

    set_variable_bounds(psi_container,
                        DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                        Symbol("FpTF_$(B)"))
    return
end

#################################### Rate Limits Constraints ##################################################
function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                ::Type{D},
                                ::Type{S},
                                feed_forward::Nothing) where {B<:PSY.ACBranch,
                                                  D<:AbstractBranchFormulation,
                                                  S<:PM.AbstractDCPModel}
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values[ix] = (min = -1*PSY.get_rate(d), max = PSY.get_rate(d))
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end

    device_range(psi_container,
                 DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                 Symbol("RateLimit_$(B)"),
                 Symbol("Fp_$(B)"))
    return
end

function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                ::Type{<:AbstractBranchFormulation},
                                ::Type{<:PM.AbstractActivePowerModel},
                                feed_forward::Nothing) where B<:PSY.ACBranch
    names = Vector{String}(undef, length(devices))
    limit_values = Vector{MinMax}(undef, length(devices))
    additional_terms_ub = Vector{Vector{Symbol}}(undef, length(devices))
    additional_terms_lb = Vector{Vector{Symbol}}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values[ix] = (min = -1*PSY.get_rate(d), max = PSY.get_rate(d))
        names[ix] = PSY.get_name(d)
        services_ub = Vector{Symbol}()
        services_lb = Vector{Symbol}()
        for service in PSY.get_services(d)
            SR = typeof(service)
            push!(services_ub, Symbol("R$(PSY.get_name(service))_$SR"))
        end
        additional_terms_ub[ix] = services_ub
        additional_terms_lb[ix] = services_lb
    end

    device_range(psi_container,
                 DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                 Symbol("RateLimitFT_$(B)"),
                 Symbol("FpFT_$(B)"))

    device_range(psi_container,
                 DeviceRange(names, limit_values, additional_terms_ub, additional_terms_ub),
                 Symbol("RateLimitTF_$(B)"),
                 Symbol("FpTF_$(B)"))
    return
end


function branch_rate_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{B},
                                ::Type{<:AbstractBranchFormulation},
                                ::Type{<:PM.AbstractPowerModel},
                                feed_forward::Nothing) where B<:PSY.ACBranch
    range_data = [(PSY.get_name(h), PSY.get_rate(h)) for h in devices]

    rating_constraint!(psi_container,
                        range_data,
                        Symbol("RateLimitFT_$(B)"),
                        (Symbol("FpFT_$(B)"), Symbol("FqFT_$(B)")))

    rating_constraint!(psi_container,
                        range_data,
                        Symbol("RateLimitTF_$(B)"),
                        (Symbol("FpTF_$(B)"), Symbol("FqTF_$(B)")))

    return

end

#################################### Flow Limits Constraints ##################################################
function branch_flow_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{PSY.MonitoredLine},
                                ::Type{FlowMonitoredLine},
                                ::Union{Type{PM.DCPPowerModel}, Type{StandardPTDFModel}},
                                feed_forward::Nothing)


    flow_range_data = [(PSY.get_name(h), PSY.get_flowlimits(h)) for h in devices]

    var_name = Symbol("Fp_$(B)")

    device_range(psi_container,
                range_data,
                Symbol("FlowLimit_$(B)"),
                var_name)

    return

end

function branch_flow_constraint!(psi_container::PSIContainer,
                                devices::IS.FlattenIteratorWrapper{PSY.MonitoredLine},
                                ::Type{FlowMonitoredLine},
                                ::Type{<:PM.AbstractPowerModel},
                                feed_forward::Nothing)
    names = Vector{String}(undef, length(devices))
    limit_values_FT = Vector{MinMax}(undef, length(devices))
    limit_values_TF = Vector{MinMax}(undef, length(devices))

    for (ix, d) in enumerate(devices)
        limit_values_FT[ix] = PSY.get_flowlimits(d)
        limit_values_TFt[ix] = (min = PSY.get_flowlimits(d).max, max = PSY.get_flowlimits(d).min)
        names[ix] = PSY.get_name(d)
    end

    device_range(psi_container,
                 DeviceRange(names, limit_values_out, Vector{Vector{Symbol}}(), Vector{Vector{Symbol}}()),
                 Symbol("FlowLimitFT_$(B)"),
                 Symbol("FpFT_$(B)"))

    device_range(psi_container,
                 DeviceRange(names, limit_values_in, Vector{Vector{Symbol}}(), Vector{Vector{Symbol}}()),
                 Symbol("FlowLimitTF_$(B)"),
                 Symbol("FpTF_$(B)"))
    return
end
