function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{CopperPlatePowerModel},
    template::OperationsProblemTemplate,
)
    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, CopperPlatePowerModel)
    end
    copper_plate!(CopperPlatePowerModel, optimization_container)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{AreaBalancePowerModel},
    template::OperationsProblemTemplate,
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
    ::PSY.System,
    ::Type{StandardPTDFModel},
    template::OperationsProblemTemplate,
)
    ptdf = get_PTDF(optimization_container)

    if ptdf === nothing
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    if get_balance_slack_variables(optimization_container.settings)
        add_slacks!(optimization_container, StandardPTDFModel)
    end

    copper_plate!(StandardPTDFModel, optimization_container)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate,
) where {T <: PTDFPowerModel}
    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "PowerModels.PTDFPowerModel" begin
        construct_network!(
            optimization_container,
            sys,
            T,
            template;
            instantiate_model = instantiate_nip_ptdf_expr_model,
        )

        add_pm_expr_refs!(optimization_container, T, sys)
    end

    TimerOutputs.@timeit BUILD_PROBLEMS_TIMER "CopperPlateBalance" begin
        copper_plate!(StandardPTDFModel, optimization_container)
    end

    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate;
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
    powermodels_network!(optimization_container, T, sys, template, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)

    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate;
    instantiate_model = instantiate_bfp_expr_model,
) where {T <: PM.AbstractBFModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    get_balance_slack_variables(optimization_container.settings) &&
        add_slacks!(optimization_container, T)

    @debug "Building the $T network with $instantiate_model method"
    powermodels_network!(optimization_container, T, sys, template, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    return
end

function construct_network!(
    optimization_container::OptimizationContainer,
    sys::PSY.System,
    ::Type{T},
    template::OperationsProblemTemplate;
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
    powermodels_network!(optimization_container, T, sys, template, instantiate_model)
    add_pm_var_refs!(optimization_container, T, sys)
    add_pm_con_refs!(optimization_container, T, sys)
    return
end
