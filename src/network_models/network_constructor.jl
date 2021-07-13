function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{CopperPlatePowerModel},
    template::ProblemTemplate,
)
    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    get_use_slacks(model) && add_slacks!(container, CopperPlatePowerModel)

    copper_plate(container, :nodal_balance_active, bus_count)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{AreaBalancePowerModel},
    template::ProblemTemplate,
)
    area_mapping = PSY.get_aggregation_topology_mapping(PSY.Area, sys)
    branches = get_available_components(PSY.Branch, sys)
    if get_use_slacks(model)
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
    model::NetworkModel{StandardPTDFModel},
    template::ProblemTemplate,
)
    buses = PSY.get_components(PSY.Bus, sys)
    ptdf = get_PTDF(model)

    if ptdf === nothing
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    get_use_slacks(model) && add_slacks!(container, StandardPTDFModel)

    copper_plate(container, :nodal_balance_active, length(buses))
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
    template::ProblemTemplate,
) where {T <: PTDFPowerModel}
    construct_network!(
        container,
        sys,
        model,
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
    model::NetworkModel{T},
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

    get_use_slacks(model) && add_slacks!(container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_var_refs!(container, T, sys)
    add_pm_con_refs!(container, T, sys)

    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
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

    get_use_slacks(model) && add_slacks!(container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_var_refs!(container, T, sys)
    add_pm_con_refs!(container, T, sys)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
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

    get_use_slacks(model) && add_slacks!(container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_var_refs!(container, T, sys)
    add_pm_con_refs!(container, T, sys)
    return
end
