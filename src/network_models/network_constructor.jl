function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{CopperPlatePowerModel},
)
    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, CopperPlatePowerModel)
    end
    copper_plate(optimization_container, :nodal_balance_active, bus_count)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{AreaBalancePowerModel},
)
    area_mapping = PSY.get_aggregation_topology_mapping(PSY.Area, sys)
    branches = get_available_components(PSY.Branch, sys)
    if get_balance_slack_variables(optimization_container.settings)
        throw(
            IS.ConflictingInputsError(
                "Slack Variables are not compatible with AreaBalancePowerModel",
            ),
        )
    end

    area_balance(optimization_container, :nodal_balance_active, area_mapping, branches)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{StandardPTDFModel},
)
    buses = PSY.get_components(PSY.Bus, sys)
    ac_branches = get_available_components(PSY.ACBranch, sys)
    ptdf = get_PTDF(optimization_container)

    if ptdf === nothing
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, StandardPTDFModel)
    end

    ptdf_networkflow(optimization_container, ac_branches, buses, :nodal_balance_active, ptdf)

    dc_branches = get_available_components(PSY.DCBranch, sys)
    dc_branch_types = typeof.(dc_branches)
    for btype in Set(dc_branch_types)
        typed_dc_branches = IS.FlattenIteratorWrapper(
            btype,
            Vector([[b for b in dc_branches if typeof(b) == btype]]),
        )
        add_variables!(optimization_container, StandardPTDFModel(), typed_dc_branches)
    end
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T};
    instantiate_model = instantiate_nip_expr_model,
) where {T <: PM.AbstractPowerModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, T)
    end

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T};
    instantiate_model = instantiate_bfp_expr_model,
) where {T <: PM.AbstractBFModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    get_balance_slack_variables(optimization_container.settings) && add_slacks!(optimization_container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T};
    instantiate_model = instantiate_vip_expr_model,
) where {T <: PM.AbstractIVRModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, T)
    end

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    return
end
