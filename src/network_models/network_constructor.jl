function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{CopperPlatePowerModel},
    template::ProblemTemplate,
)
    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, CopperPlatePowerModel)
        add_variables!(container, SystemBalanceSlackDown, sys, CopperPlatePowerModel)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackUp,
            sys,
            model,
            CopperPlatePowerModel,
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
            CopperPlatePowerModel,
        )
        cost_function!(container, PSY.System, model, CopperPlatePowerModel)
    end

    add_constraints!(
        container,
        CopperPlateBalanceConstraint,
        sys,
        model,
        CopperPlatePowerModel,
    )

    add_constraint_dual!(container, sys, model)
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

    area_balance(
        container,
        ExpressionKey(ActivePowerBalance, PSY.Bus),
        area_mapping,
        branches,
    )
    add_constraint_dual!(container, sys, model)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{StandardPTDFModel},
    template::ProblemTemplate,
)
    ptdf = get_PTDF(model)

    if ptdf === nothing
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, CopperPlatePowerModel)
        add_variables!(container, SystemBalanceSlackDown, sys, CopperPlatePowerModel)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackUp,
            sys,
            model,
            StandardPTDFModel,
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
            StandardPTDFModel,
        )
        cost_function!(container, PSY.System, model, StandardPTDFModel)
    end

    add_constraints!(container, CopperPlateBalanceConstraint, sys, model, StandardPTDFModel)

    add_constraint_dual!(container, sys, model)
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

    add_constraints!(container, CopperPlateBalanceConstraint, sys, model, PTDFPowerModel)
    add_constraint_dual!(container, sys, model)

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

    # get_use_slacks(model) && add_slacks!(container, T)

    @debug "Building the $T network with $instantiate_model method" _group =
        LOG_GROUP_NETWORK_CONSTRUCTION
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_variable_refs!(container, T, sys)
    add_pm_constraint_refs!(container, T, sys)

    add_constraint_dual!(container, sys, model)
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

    # need to implement slacks for PM constraint_dcline_power_losses
    # get_use_slacks(model) && add_slacks!(container, T)

    @debug "Building the $T network with $instantiate_model method" _group =
        LOG_GROUP_NETWORK_CONSTRUCTION
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_variable_refs!(container, T, sys)
    add_pm_constraint_refs!(container, T, sys)
    add_constraint_dual!(container, sys, model)
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

    # need to implement slacks for PM constraint_dcline_power_losses
    # get_use_slacks(model) && add_slacks!(container, T)

    @debug "Building the $T network with $instantiate_model method" _group =
        LOG_GROUP_NETWORK_CONSTRUCTION
    powermodels_network!(container, T, sys, template, instantiate_model)
    add_pm_variable_refs!(container, T, sys)
    add_pm_constraint_refs!(container, T, sys)
    add_constraint_dual!(container, sys, model)
    return
end
