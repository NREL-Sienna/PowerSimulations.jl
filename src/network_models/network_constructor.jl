function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{CopperPlatePowerModel},
    ::ProblemTemplate,
)
    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, model)
        add_variables!(container, SystemBalanceSlackDown, sys, model)
        add_to_expression!(container, ActivePowerBalance, SystemBalanceSlackUp, sys, model)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        objective_function!(container, sys, model)
    end

    add_constraints!(container, CopperPlateBalanceConstraint, sys, model)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{AreaBalancePowerModel},
    ::ProblemTemplate,
)
    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, model)
        add_variables!(container, SystemBalanceSlackDown, sys, model)
        add_to_expression!(container, ActivePowerBalance, SystemBalanceSlackUp, sys, model)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        objective_function!(container, sys, model)
    end

    add_constraints!(container, CopperPlateBalanceConstraint, sys, model)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{<:AbstractPTDFModel},
    template::ProblemTemplate,
)
    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, model)
        add_variables!(container, SystemBalanceSlackDown, sys, model)
        add_to_expression!(container, ActivePowerBalance, SystemBalanceSlackUp, sys, model)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        objective_function!(container, sys, model)
    end
    # Temporary solution to bypass Balance constraints with AGC
    # Possible alternative is a new network formulation:
    if !_has_agc_model(template)
        add_constraints!(container, CopperPlateBalanceConstraint, sys, model)
    end 
    add_constraint_dual!(container, sys, model)
    return
end

function _has_agc_model(template::ProblemTemplate)
    for service_model in values(get_service_models(template))
        if get_component_type(service_model) == PSY.AGC
            return true
        end 
    end 
    return false 
end  

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
    template::ProblemTemplate;
) where {T <: PM.AbstractActivePowerModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, model)
        add_variables!(container, SystemBalanceSlackDown, sys, model)
        add_to_expression!(container, ActivePowerBalance, SystemBalanceSlackUp, sys, model)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        objective_function!(container, sys, model)
    end

    @debug "Building the $T network with instantiate_nip_expr_model method" _group =
        LOG_GROUP_NETWORK_CONSTRUCTION
    powermodels_network!(container, T, sys, template, instantiate_nip_expr_model)
    add_pm_variable_refs!(container, T, sys, model)
    add_pm_constraint_refs!(container, T, sys)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
    template::ProblemTemplate;
) where {T <: PM.AbstractPowerModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, model)
        add_variables!(container, SystemBalanceSlackDown, sys, model)
        add_to_expression!(container, ActivePowerBalance, SystemBalanceSlackUp, sys, model)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        add_to_expression!(
            container,
            ReactivePowerBalance,
            SystemBalanceSlackUp,
            sys,
            model,
        )
        add_to_expression!(
            container,
            ReactivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        objective_function!(container, sys, model)
    end

    @debug "Building the $T network with instantiate_nip_expr_model method" _group =
        LOG_GROUP_NETWORK_CONSTRUCTION
    powermodels_network!(container, T, sys, template, instantiate_nip_expr_model)
    add_pm_variable_refs!(container, T, sys, model)
    add_pm_constraint_refs!(container, T, sys)

    add_constraint_dual!(container, sys, model)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
    template::ProblemTemplate,
) where {T <: PM.AbstractBFModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, model)
        add_variables!(container, SystemBalanceSlackDown, sys, model)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackUp,
            sys,
            model,
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        add_to_expression!(
            container,
            ReactivePowerBalance,
            SystemBalanceSlackUp,
            sys,
            model,
        )
        add_to_expression!(
            container,
            ReactivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        objective_function!(container, sys, model)
    end

    @debug "Building the $T network with instantiate_bfp_expr_model method" _group =
        LOG_GROUP_NETWORK_CONSTRUCTION
    powermodels_network!(container, T, sys, template, instantiate_bfp_expr_model)
    add_pm_variable_refs!(container, T, sys, model)
    add_pm_constraint_refs!(container, T, sys)
    add_constraint_dual!(container, sys, model)
    return
end

function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{SecurityConstrainedPTDFPowerModel},
    ::ProblemTemplate,
)
    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, model)
        add_variables!(container, SystemBalanceSlackDown, sys, model)
        add_to_expression!(container, ActivePowerBalance, SystemBalanceSlackUp, sys, model)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
        )
        objective_function!(container, sys, model)
    end

    add_constraints!(container, CopperPlateBalanceConstraint, sys, model)
    add_constraint_dual!(container, sys, model)
    return
end

#=
# AbstractIVRModel models not currently supported
function construct_network!(
    container::OptimizationContainer,
    sys::PSY.System,
    model::NetworkModel{T},
    template::ProblemTemplate;
) where {T <: PM.AbstractIVRModel}
    if T in UNSUPPORTED_POWERMODELS
        throw(
            ArgumentError(
                "$(T) formulation is not currently supported in PowerSimulations",
            ),
        )
    end

    if get_use_slacks(model)
        add_variables!(container, SystemBalanceSlackUp, sys, T)
        add_variables!(container, SystemBalanceSlackDown, sys, T)
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackUp,
            sys,
            model,
            T,
        )
        add_to_expression!(
            container,
            ActivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
            T,
        )
        add_to_expression!(
            container,
            ReactivePowerBalance,
            SystemBalanceSlackUp,
            sys,
            model,
            T,
        )
        add_to_expression!(
            container,
            ReactivePowerBalance,
            SystemBalanceSlackDown,
            sys,
            model,
            T,
        )
        objective_function!(container, sys, model)
    end

    @debug "Building the $T network with instantiate_vip_expr_model method" _group =
        LOG_GROUP_NETWORK_CONSTRUCTION
    #Constraints in case the model has DC Buses
    add_constraints!(container, NodalBalanceActiveConstraint, sys, model)
    powermodels_network!(container, T, sys, template, instantiate_vip_expr_model)
    add_pm_variable_refs!(container, T, sys, model)
    add_pm_constraint_refs!(container, T, sys)
    add_constraint_dual!(container, sys, model)
    return
end
=#
