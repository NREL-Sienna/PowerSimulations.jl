function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{CopperPlatePowerModel},
    template::ProblemTemplate,
)
    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    if get_balance_slack_variables(container.settings)
        add_slacks!(container, CopperPlatePowerModel)
    end
    copper_plate(container, :nodal_balance_active, bus_count)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{AreaBalancePowerModel},
    template::ProblemTemplate,
)
    area_mapping = PSY.get_aggregation_topology_mapping(PSY.Area, sys)
    branches = get_available_components(PSY.Branch, sys)
    if get_balance_slack_variables(container.settings)
        throw(
            IS.ConflictingInputsError(
                "Slack Variables are not compatible with AreaBalancePowerModel",
            ),
        )
    end

    area_balance(container, :nodal_balance_active, area_mapping, branches)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{StandardPTDFModel},
    template::ProblemTemplate,
)
    buses = PSY.get_components(PSY.Bus, sys)
    ptdf = get_PTDF(container)

    if ptdf === nothing
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    if get_balance_slack_variables(container.settings)
        add_slacks!(container, StandardPTDFModel)
    end

    copper_plate(container, :nodal_balance_active, length(buses))
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::ProblemTemplate,
) where {T <: PTDFPowerModel}
    construct_network!(
        container,
        sys,
        T,
        template;
        instantiate_model = instantiate_nip_ptdf_expr_model,
    )

    add_pm_expr_refs!(container, T, sys)
    copper_plate(container, :nodal_balance_active, length(PSY.get_components(PSY.Bus, sys)))

    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::ProblemTemplate;
    instantiate_model = instantiate_nip_expr_model,
) where {T <: PM.AbstractPowerModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_balance_slack_variables(container.settings)
        add_slacks!(container, T)
    end

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_var_refs!(container, T, sys)
    add_pm_con_refs!(container, T, sys)

    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::ProblemTemplate;
    instantiate_model = instantiate_bfp_expr_model,
) where {T <: PM.AbstractBFModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    get_balance_slack_variables(container.settings) && add_slacks!(container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_var_refs!(container, T, sys)
    add_pm_con_refs!(container, T, sys)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::ProblemTemplate;
    instantiate_model = instantiate_vip_expr_model,
) where {T <: PM.AbstractIVRModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_balance_slack_variables(container.settings)
        add_slacks!(container, T)
    end

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_var_refs!(container, T, sys)
    add_pm_con_refs!(container, T, sys)
    return
end
