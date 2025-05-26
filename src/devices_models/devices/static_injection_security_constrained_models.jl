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
    model::DeviceModel{T, D},
    network_model::NetworkModel{<:PM.AbstractActivePowerModel},
) where {T <: PSY.ThermalGen, D <: AbstractSecurityConstrainedUnitCommitment}
    devices = get_available_components(model, sys)

    valid_outages = _get_all_scuc_valid_outages(sys, model)
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

    if !isempty(generator_outages)
        add_variables!(
            container,
            PostContingencyActivePowerChangeVariable,
            devices,
            generator_outages,
            D(),
        )
        add_to_expression!(
            container,
            PostContingencyActivePowerGeneration,
            ActivePowerVariable,
            PostContingencyActivePowerChangeVariable,
            devices,
            generator_outages,
            model,
            network_model,
        )
        add_constraints!(
            container,
            PostContingencyActivePowerVariableLimitsConstraint,
            devices,
            generator_outages,
            model,
            network_model,
        )
          
        add_to_expression!(
            container,
            PostContingencyActivePowerBalance,
            ActivePowerVariable,
            PostContingencyActivePowerChangeVariable,
            devices,
            generator_outages,
            model,
            network_model,
        )

        #ADD EXPRESSION FOR EACH CONTINGENCY: CALCULATE FLOW FOR EACH Branch
        
        #ADD CONSTRAINT FOR EACH CONTINGENCY: FLOW <= RATE LIMIT
    end

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

"""
Add post-contingency rate limit constraints for Generators for G-1 formulation
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{PostContingencyActivePowerVariableLimitsConstraint},
    devices::IS.FlattenIteratorWrapper{S},
    generator_outages::Vector{T},
    device_model::DeviceModel{T, U},
    network_model::NetworkModel{V},
) where {
    S <: PSY.Generator,
    T <: PSY.Generator,
    U <: AbstractSecurityConstrainedUnitCommitment,
    V <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    con_lb =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            get_name.(generator_outages),
            device_names,
            time_steps;
            meta = "lb",
        )

    con_ub =
        add_constraints_container!(
            container,
            cons_type(),
            T,
            get_name.(generator_outages),
            device_names,
            time_steps;
            meta = "ub",
        )

    expressions = get_expression(
        container,
        ExpressionKey(
            PostContingencyActivePowerGeneration,
            T,
            IS.Optimization.CONTAINER_KEY_EMPTY_META,
        ),
    )

    for device in devices
        device_name = get_name(device)

        for generator_outage in generator_outages
            #TODO HOW WE SHOULD HANDLE THE EXPRESSIONS AND CONSTRAINTS RELATED TO THE OUTAGE OF THE GENERATOR RESPECT TO ITSELF?
            if device == generator_outage
                continue
            end

            gen_outage_name = get_name(generator_outage)

            limits = get_min_max_limits(
                device,
                ActivePowerVariableLimitsConstraint,
                U,
            )

            for t in time_steps
                con_ub[gen_outage_name, device_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[gen_outage_name, device_name, t] <=
                        limits.max)
                con_lb[gen_outage_name, device_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[gen_outage_name, device_name, t] >=
                        limits.min)
            end
        end
    end

    return
end



"""
Default implementation to add variables to PostContingencySystemBalanceExpressions
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::Type{Y},
    devices::IS.FlattenIteratorWrapper{V},
    devices_outages::Vector{X},
    device_model::DeviceModel{X, W},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyActivePowerBalance,
    U <: VariableType,
    Y <: AbstractContingencyVariableType,
    V <: PSY.Generator,
    X <: PSY.Generator,
    W <: AbstractSecurityConstrainedUnitCommitment,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)

    if !isempty(devices_outages)
        container.expressions[ExpressionKey(T, X)] =
            _make_container_array(
                get_name.(devices_outages),
                time_steps,
            )
    end
    
    expression = get_expression(
        container,
        ExpressionKey(
            T,
            V,
            IS.Optimization.CONTAINER_KEY_EMPTY_META,
        ),
    )
    variable = get_variable(container, U(), V)
    variable_outages = get_variable(container, Y(), X)

    for d in devices
        name = PSY.get_name(d)
        for d_outage in devices_outages
            
            if d == d_outage
                for t in get_time_steps(container)
                    _add_to_jump_expression!(
                        expression[name, t],
                        variable[ name, t],
                        -1.0,
                    )
                end
                continue
            end

            name_outage = PSY.get_name(d_outage)

            for t in get_time_steps(container)
                _add_to_jump_expression!(
                    expression[name_outage, t],
                    variable_outages[name_outage, name, t],
                    1.0,
                )
            end
        end
    end
    return
end