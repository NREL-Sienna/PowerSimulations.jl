function _get_all_single_outage_by_type(
    sys::PSY.System,
    valid_outages::IS.FlattenIteratorWrapper{T},
    generators::IS.FlattenIteratorWrapper{V},
    ::Type{X},
) where {
    T <: PSY.Outage,
    V <: PSY.Generator,
    X <: PSY.Generator,
}
    single_outage_generators = V[]
    for outage in valid_outages
        components = PSY.get_associated_components(sys, outage)
        if !all(c -> c <: X, typeof.(components)) || length(components) != 1
            continue
        end
        component = first(components)
        if (component in generators) && !(component in single_outage_generators)
            push!(single_outage_generators, component)
        end
    end
    return single_outage_generators
end

function _get_all_scuc_valid_outages(
    sys::PSY.System,
    model::DeviceModel{T, D},
) where {T <: PSY.Generator, D <: AbstractSecurityConstrainedUnitCommitment}
    return PSY.get_supplemental_attributes(
        sa ->
            typeof(sa) in Base.uniontypes(OutagesSCUC) && #rewrite based on ForcedOutage
                all(
                    c -> c <: PSY.Generator,
                    typeof.(PSY.get_associated_components(sys, sa)),
                ),
        PSY.Outage,
        sys,
    )
end

function add_variable!(
    container::OptimizationContainer,
    variable_type::T,
    devices::U,
    generator_outages::X,
    formulation,
) where {
    T <: AbstractContingencyVariableType,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    X <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    @info("++++ CODE IS BUILDING AbstractContingencyVariableType VARIABLES")
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    binary = get_variable_binary(variable_type, D, formulation)

    variable = add_variable_container!(
        container,
        variable_type,
        D,
        [PSY.get_name(d) for d in generator_outages],
        [PSY.get_name(d) for d in devices],
        time_steps,
    )
    @show variable
    @show typeof(variable)
    for t in time_steps, d in devices, o in generator_outages
        name = PSY.get_name(d)
        name_outage = PSY.get_name(o)
        variable[name_outage, name, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "$(T)_$(D)_{$(name), $(t)}",
            binary = binary
        )
        ub = get_variable_upper_bound(variable_type, d, formulation)
        ub !== nothing && JuMP.set_upper_bound(variable[name_outage, name, t], ub)

        lb = get_variable_lower_bound(variable_type, d, formulation)
        lb !== nothing && JuMP.set_lower_bound(variable[name_outage, name, t], lb)

        if get_warm_start(settings)
            init = get_variable_warm_start_value(variable_type, d, formulation)
            init !== nothing && JuMP.set_start_value(variable[name_outage, name, t], init)
        end
    end

    return
end

"""
This function creates the arguments model for a full thermal Security-Constrained dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ThermalGen, D <: AbstractSecurityConstrainedUnitCommitment}
    devices = get_available_components(model, sys)

    add_variables!(container, ActivePowerVariable, devices, D())
    add_variables!(container, OnVariable, devices, D())
    add_variables!(container, StartVariable, devices, D())
    add_variables!(container, StopVariable, devices, D())

    add_variables!(container, TimeDurationOn, devices, D())
    add_variables!(container, TimeDurationOff, devices, D())

    valid_outages = _get_all_scuc_valid_outages(sys, model)
    @show valid_outages
    if isempty(valid_outages)
        throw(
            ArgumentError(
                "System $(PSY.get_name(sys)) has no valid supplemental attributes associated to devices $(PSY.ThermalGen) 
                to add the variables/expressions/constraints for the requested device formulation: $D.",
            ))
    end

    #TODO Handle also G-2 cases
    generator_outages =
        _get_all_single_outage_by_type(sys, valid_outages, devices, T)
    @show generator_outages
    add_variables!(
        container,
        PostContingencyActivePowerChangeVariable,
        devices,
        generator_outages,
        D(),
    )

    initial_conditions!(container, devices, D())

    if haskey(get_time_series_names(model), ActivePowerTimeSeriesParameter)
        add_parameters!(container, ActivePowerTimeSeriesParameter, devices, model)
    end
    if haskey(get_time_series_names(model), FuelCostParameter)
        add_parameters!(container, FuelCostParameter, devices, model)
    end

    add_to_expression!(
        container,
        ActivePowerBalance,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )

    add_expressions!(container, ProductionCostExpression, devices, model)
    add_expressions!(container, FuelConsumptionExpression, devices, model)

    add_to_expression!(
        container,
        ActivePowerRangeExpressionLB,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        ActivePowerRangeExpressionUB,
        ActivePowerVariable,
        devices,
        model,
        network_model,
    )
    add_to_expression!(
        container,
        FuelConsumptionExpression,
        ActivePowerVariable,
        devices,
        model,
    )
    if get_use_slacks(model)
        add_variables!(container, RateofChangeConstraintSlackUp, devices, D())
        add_variables!(container, RateofChangeConstraintSlackDown, devices, D())
    end

    add_feedforward_arguments!(container, model, devices)
    return
end

"""
This function creates the constraints for the model for a full thermal Security-Constrained dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::DeviceModel{T, <:AbstractSecurityConstrainedUnitCommitment},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ThermalGen}
    devices = get_available_components(model, sys)
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerRangeExpressionLB,
        devices,
        model,
        network_model,
    )
    add_constraints!(
        container,
        ActivePowerVariableLimitsConstraint,
        ActivePowerRangeExpressionUB,
        devices,
        model,
        network_model,
    )

    add_constraints!(container, CommitmentConstraint, devices, model, network_model)
    add_constraints!(container, RampConstraint, devices, model, network_model)
    add_constraints!(container, DurationConstraint, devices, model, network_model)
    if haskey(get_time_series_names(model), ActivePowerTimeSeriesParameter)
        add_constraints!(
            container,
            ActivePowerVariableTimeSeriesLimitsConstraint,
            ActivePowerRangeExpressionUB,
            devices,
            model,
            network_model,
        )
    end

    add_feedforward_constraints!(container, model, devices)

    objective_function!(container, devices, model, get_network_formulation(network_model))

    add_constraint_dual!(container, sys, model)
    return
end
