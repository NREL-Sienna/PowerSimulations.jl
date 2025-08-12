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

function _get_all_scuc_valid_outages(
    sys::PSY.System,
    T::Type{<:PSY.Component},
)
    return PSY.get_supplemental_attributes(
        sa ->
            typeof(sa) in Base.uniontypes(OutagesSCUC) && #rewrite based on ForcedOutage
                all(
                    c -> c <: T,
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
    formulation::AbstractSecurityConstrainedUnitCommitment,
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
        if name == name_outage
            JuMP.set_upper_bound(variable[name_outage, name, t], 0.0)
            JuMP.set_lower_bound(variable[name_outage, name, t], 0.0)
            JuMP.set_start_value(variable[name_outage, name, t], 0.0)
            continue
        end

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

    #TODO Handle also G-k cases
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
        add_constraints!(
            container,
            PostContingengyGenerationBalanceConstraint,
            devices,
            generator_outages,
            model,
            network_model,
        )

        add_to_expression!(
            container,
            PostContingencyNodalActivePowerDeployment,
            PostContingencyActivePowerChangeVariable,
            devices,
            generator_outages,
            model,
            network_model,
        )

        #ADD EXPRESSION TO CALCULATE POST CONTINGENCY FLOW FOR EACH Branch  
        add_to_expression!(
            container,
            sys,
            PTDFPostContingencyBranchFlow,
            FlowActivePowerVariable,
            ActivePowerVariable,
            PostContingencyActivePowerChangeVariable,
            devices,
            generator_outages,
            model,
            network_model,
        )

        #ADD CONSTRAINT FOR EACH CONTINGENCY: FLOW <= RATE LIMIT
        add_constraints!(
            container,
            PostContingencyRateLimitConstraintB,
            PSY.get_components(PSY.ACTransmission, sys),
            generator_outages,
            model,
            network_model,
        )

        #ADD RAMPING CONSTRAINTS
        add_constraints!(
            container,
            PostContingencyRampConstraint,
            PostContingencyActivePowerChangeVariable,
            devices,
            generator_outages,
            model,
            network_model,
        )
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
Default implementation to add variables to PostContingencySystemBalanceExpressions for G-1 formulation
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
            X,
            IS.Optimization.CONTAINER_KEY_EMPTY_META,
        ),
    )
    variable = get_variable(container, U(), V)
    variable_outages = get_variable(container, Y(), X)

    for d in devices
        name = PSY.get_name(d)
        for d_outage in devices_outages
            if d == d_outage
                for t in time_steps
                    _add_to_jump_expression!(
                        expression[name, t],
                        variable[name, t],
                        -1.0,
                    )
                end
                continue
            end

            name_outage = PSY.get_name(d_outage)

            for t in time_steps
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

"""
Add post-contingency Generation Balance Constraints for Generators for G-1 formulation and G-1 with reserves (SecurityConstrainedReservesFormulation)
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{R},
    devices::Union{IS.FlattenIteratorWrapper{S}, Vector{S}},
    generator_outages::Union{IS.FlattenIteratorWrapper{T}, Vector{T}},
    ::Union{DeviceModel{X, U}, ServiceModel{X, U}},
    network_model::NetworkModel{V},
) where {
    R <: PostContingengyGenerationBalanceConstraint,
    S <: PSY.Generator,
    T <: PSY.Generator,
    X <: Union{PSY.Generator, PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    U <: Union{
        AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation,
    },
    V <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in devices]
    device_outages_names = [PSY.get_name(d) for d in generator_outages]

    expressions = get_expression(
        container,
        ExpressionKey(
            PostContingencyActivePowerBalance,
            T,
            IS.Optimization.CONTAINER_KEY_EMPTY_META,
        ),
    )
    if !isempty(generator_outages) && !haskey(container.constraints, ConstraintKey(R, T))
        constraint =
            add_constraints_container!(container, R(), T, device_outages_names, time_steps)
    end
    constraint = get_constraint(container, ConstraintKey(R, T))

    for t in time_steps, d_outage in device_outages_names
        constraint[d_outage, t] =
            JuMP.@constraint(get_jump_model(container), expressions[d_outage, t] == 0)
    end

    return
end

function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    devices::Union{IS.FlattenIteratorWrapper{D}, Vector{D}},
    devices_outages::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    ::Union{DeviceModel{Y, W}, ServiceModel{Y, W}},#DeviceModel{V, W},
    network_model::NetworkModel{X};
    service::R = nothing,
) where {
    T <: PostContingencyNodalActivePowerDeployment,
    U <: AbstractContingencyVariableType,
    D <: PSY.Generator,
    V <: PSY.Generator,
    Y <: Union{PSY.Generator, PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    W <: Union{
        AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation,
    },
    X <: AbstractPTDFModel,
    R <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}, Nothing},
}
    time_steps = get_time_steps(container)
    ptdf = get_PTDF_matrix(network_model)
    bus_numbers = ptdf.axes[1]

    if !isempty(devices_outages) &&
       !haskey(container.expressions, ExpressionKey(T, PSY.ACBus))
        container.expressions[ExpressionKey(T, PSY.ACBus)] =
            _make_container_array(
                get_name.(devices_outages),
                bus_numbers,
                time_steps,
            )
    end

    expression = get_expression(container, T(), PSY.ACBus)
    ptdf = get_PTDF_matrix(network_model)

    if W <: AbstractSecurityConstrainedReservesFormulation
        variable_outages = get_variable(
            container,
            U(),
            R,
            PSY.get_name(service),
        )
        mult = 1.0
        if typeof(service) <: PSY.Reserve{PSY.ReserveDown}
            mult = -1.0
        end

    else
        variable_outages = get_variable(container, U(), V)
        mult = 1.0
    end

    network_reduction = get_network_reduction(network_model)
    for d in devices
        name = PSY.get_name(d)
        bus_no = PNM.get_mapped_bus_number(network_reduction, PSY.get_bus(d))

        for d_outage in devices_outages
            if d == d_outage
                continue
            end
            name_outage = PSY.get_name(d_outage)

            for t in get_time_steps(container)
                _add_to_jump_expression!(
                    expression[name_outage, bus_no, t],
                    variable_outages[name_outage, name, t],
                    mult,
                )
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
    sys::PSY.System,
    ::Type{T},
    ::Type{F},
    ::Type{G},
    ::Type{C},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    devices_outages::Union{IS.FlattenIteratorWrapper{X}, Vector{X}},
    device_model::Union{DeviceModel{Y, W}, ServiceModel{Y, W}},
    network_model::NetworkModel{N};
    service::R = nothing,
) where {
    T <: PTDFPostContingencyBranchFlow,
    F <: FlowActivePowerVariable,
    G <: VariableType,
    C <: AbstractContingencyVariableType,
    V <: PSY.Generator,
    X <: PSY.Generator,
    Y <: Union{PSY.Generator, PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    W <: Union{AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation},
    N <: AbstractPTDFModel,
    R <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}, Nothing},
}
    time_steps = get_time_steps(container)
    ptdf = get_PTDF_matrix(network_model)
    network_reduction = get_network_reduction(network_model)
    names_branches = PNM.get_retained_branches_names(network_reduction)

    if !isempty(devices_outages) && !haskey(container.expressions, ExpressionKey(T, X))
        container.expressions[ExpressionKey(T, X)] =
            _make_container_array(
                get_name.(devices_outages),
                names_branches,
                time_steps,
            )
    end

    expression = get_expression(
        container,
        ExpressionKey(
            T,
            X,
            IS.Optimization.CONTAINER_KEY_EMPTY_META,
        ),
    )

    variable = get_variable(container, G(), V)
    #variable_outages = get_variable(container, C(), X)
    nodal_power_deployment_expressions =
        get_expression(container, PostContingencyNodalActivePowerDeployment(), PSY.ACBus)
    jump_model = get_jump_model(container)

    for name in names_branches
        flow_variables = get_variable(
            container,
            F(),
            typeof(get_component(PSY.ACTransmission, sys, name)),
        )
        ptdf_col = ptdf[name, :]
        for d_outage in devices_outages
            name_outage = PSY.get_name(d_outage)
            bus_number_outage = PSY.get_number(PSY.get_bus(d_outage))

            expression[name_outage, name, :] .= _make_post_contingency_flow_expressions!(
                jump_model,
                name * name_outage,
                time_steps,
                ptdf_col,
                nodal_power_deployment_expressions[name_outage, :, :].data,
            )
            for t in time_steps
                _add_to_jump_expression!(
                    expression[name_outage, name, t],
                    flow_variables[name, t],
                    1.0,
                )
                #TODO extend to G-k
                _add_to_jump_expression!(
                    expression[name_outage, name, t],
                    variable[name_outage, t],
                    (-1) * ptdf[name, bus_number_outage],
                )
            end
        end
    end
    return
end

function _make_post_contingency_flow_expressions!(
    jump_model::JuMP.Model,
    name_thread::String,
    time_steps::UnitRange{Int},
    ptdf_col::AbstractVector{Float64},
    nodal_power_deployment_expressions::Matrix{JuMP.AffExpr},
)
    #@debug Threads.threadid() name_thread
    expressions = Vector{JuMP.AffExpr}(undef, length(time_steps))
    for t in time_steps
        expressions[t] = JuMP.@expression(
            jump_model,
            sum(
                ptdf_col[i] * nodal_power_deployment_expressions[i, t] for
                i in 1:length(ptdf_col)
            )
        )
    end
    #return name_thread, expressions
    # change when using the not concurrent version
    return expressions
end

"""
Add branch post-contingency rate limit constraints for ACBranch after a G-k outage
"""
function add_constraints!(
    container::OptimizationContainer,
    cons_type::Type{PostContingencyRateLimitConstraintB},
    branches::Union{
        IS.FlattenIteratorWrapper{PSY.ACTransmission},
        Vector{PSY.ACTransmission},
    },
    generators_outages::Vector{T},
    device_model::Union{DeviceModel{Y, U}, ServiceModel{Y, U}},
    network_model::NetworkModel{V},
) where {
    T <: PSY.Generator,
    Y <: Union{PSY.Generator, PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    U <: Union{AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation},
    V <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    device_names = [PSY.get_name(d) for d in branches]
    if !haskey(container.constraints, ConstraintKey(cons_type, T, "lb"))
        con_lb =
            add_constraints_container!(
                container,
                cons_type(),
                T,
                get_name.(generators_outages),
                device_names,
                time_steps;
                meta = "lb",
            )

        con_ub =
            add_constraints_container!(
                container,
                cons_type(),
                T,
                get_name.(generators_outages),
                device_names,
                time_steps;
                meta = "ub",
            )
    end

    con_lb = get_constraint(
        container,
        ConstraintKey(cons_type, T, "lb"),
    )

    con_ub = get_constraint(
        container,
        ConstraintKey(cons_type, T, "ub"),
    )
    expressions = get_expression(
        container,
        ExpressionKey(
            PTDFPostContingencyBranchFlow,
            T,
            IS.Optimization.CONTAINER_KEY_EMPTY_META,
        ),
    )

    param_keys = get_parameter_keys(container)

    for branch in branches
        branch_name = get_name(branch)

        param_key = ParameterKey(
            PostContingencyDynamicBranchRatingTimeSeriesParameter,
            typeof(branch),
        )
        has_dlr_ts = (param_key in param_keys) && PSY.has_time_series(branch)

        device_dynamic_branch_rating_ts = []
        if has_dlr_ts
            device_dynamic_branch_rating_ts, mult =
                _get_device_post_contingency_dynamic_branch_rating_time_series(
                    container,
                    param_key,
                    branch_name,
                    network_model)
        end

        for generator_outage in generators_outages
            gen_outage_name = get_name(generator_outage)

            limits = get_min_max_limits(
                branch,
                PostContingencyRateLimitConstraintB,
                AbstractBranchFormulation,
                network_model,
            )

            for t in time_steps
                # device_dynamic_branch_rating_ts is empty if this device doesn't have a time series
                if !isempty(device_dynamic_branch_rating_ts)
                    limits = (
                        min = -1 * device_dynamic_branch_rating_ts[t] *
                              mult[branch_name, t],
                        max = device_dynamic_branch_rating_ts[t] * mult[branch_name, t],
                    ) #update limits
                end

                con_ub[gen_outage_name, branch_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[gen_outage_name, branch_name, t] <=
                        limits.max)
                con_lb[gen_outage_name, branch_name, t] =
                    JuMP.@constraint(get_jump_model(container),
                        expressions[gen_outage_name, branch_name, t] >=
                        limits.min)
            end
        end
    end

    return
end

"""
This function adds the post-contingency ramping limits
"""
function add_constraints!(
    container::OptimizationContainer,
    T::Type{PostContingencyRampConstraint},
    ::Type{X},
    devices::Union{IS.FlattenIteratorWrapper{U}, Vector{U}},
    generators_outages::Union{IS.FlattenIteratorWrapper{G}, Vector{G}},
    model::Union{DeviceModel{Y, V}, ServiceModel{Y, V}},
    ::NetworkModel{W};
    service::R = nothing,
) where {
    X <: AbstractContingencyVariableType,
    U <: PSY.Generator,
    G <: PSY.Generator,
    V <: Union{AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation},
    W <: AbstractPTDFModel,
    Y <: Union{PSY.Generator, PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    R <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}, Nothing},
}
    add_linear_ramp_constraints!(
        container,
        T,
        X,
        devices,
        generators_outages,
        model,
        W;
        service = service,
    )
    return
end

@doc raw"""
Constructs allowed rate-of-change constraints for G-1 formulations from change_variables, and rate data.



``` change_variable[name, t] <= rate_data[1][ix].up ```

``` change_variable[name, t-1] >= rate_data[1][ix].down ```

# LaTeX

`` r^{down} \leq \Delta x_t  \leq r^{up}, \forall t \geq  ``

"""
function add_linear_ramp_constraints!(
    container::OptimizationContainer,
    T::Type{<:ConstraintType},
    U::Type{<:AbstractContingencyVariableType},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    generators_outages::Union{IS.FlattenIteratorWrapper{G}, Vector{G}},
    model::Union{DeviceModel{Y, W}, ServiceModel{Y, W}},
    ::Type{<:AbstractPTDFModel};
    service::R = nothing,
) where {
    V <: PSY.Generator,
    G <: PSY.Generator,
    Y <: Union{PSY.Generator, PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    W <: Union{AbstractSecurityConstrainedUnitCommitment,
        AbstractSecurityConstrainedReservesFormulation},
    R <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}, Nothing},
}
    time_steps = get_time_steps(container)
    ramp_devices = _get_ramp_constraint_devices(container, devices)
    minutes_per_period = _get_minutes_per_period(container)

    set_name = [PSY.get_name(r) for r in ramp_devices]
    set_outages_name = [PSY.get_name(r) for r in generators_outages]
    if set_name == []
        @debug "No Contributing devices to service $service with ramping constraints found in the system."
        return
    end
    if !haskey(container.constraints, ConstraintKey(T, G, "up")) &&
       !(R <: PSY.Reserve{PSY.ReserveDown})
        con_up =
            add_constraints_container!(
                container,
                T(),
                G,
                set_outages_name,
                set_name,
                time_steps;
                meta = "up",
            )
    end
    if !haskey(container.constraints, ConstraintKey(T, G, "dn")) &&
       !(R <: PSY.Reserve{PSY.ReserveUp})
        con_down =
            add_constraints_container!(
                container,
                T(),
                G,
                set_outages_name,
                set_name,
                time_steps;
                meta = "dn",
            )
    end

    if !(R <: PSY.Reserve{PSY.ReserveDown})
        con_up = get_constraint(
            container,
            ConstraintKey(T, G, "up"),
        )
    else
        con_up = nothing
    end
    if !(R <: PSY.Reserve{PSY.ReserveUp})
        con_down = get_constraint(
            container,
            ConstraintKey(T, G, "dn"),
        )
    else
        con_down = nothing
    end

    if W <: AbstractSecurityConstrainedReservesFormulation
        variable = get_variable(
            container,
            U(),
            R,
            PSY.get_name(service),
        )
    else
        variable = get_variable(container, U(), G)
    end

    for device in devices
        name = get_name(device)
        # This is to filter out devices that dont need a ramping constraint
        name ∉ set_name && continue
        ramp_limits = PSY.get_ramp_limits(device)

        @debug "add post-contingency rate_of_change_constraint" name

        for device_outage in generators_outages
            name_outage = get_name(device_outage)

            if name == name_outage
                continue
            end

            for t in time_steps
                _add_post_contingency_ramp_dn_constraints!(
                    container,
                    variable,
                    U,
                    con_up,
                    con_down,
                    name_outage,
                    name,
                    t,
                    ramp_limits,
                    minutes_per_period,
                    R,
                )
            end
        end
    end
    return
end

function _add_post_contingency_ramp_dn_constraints!(
    container::OptimizationContainer,
    variable,
    ::Type{PostContingencyActivePowerChangeVariable},
    con_up,
    con_down,
    name_outage::String,
    name::String,
    t::Int64,
    ramp_limits,
    minutes_per_period::Int64,
    R::Type{<:Nothing},
)
    con_up[name_outage, name, t] = JuMP.@constraint(
        get_jump_model(container),
        variable[name_outage, name, t] <=
        ramp_limits.up * minutes_per_period
    )
    con_down[name_outage, name, t] = JuMP.@constraint(
        get_jump_model(container),
        variable[name_outage, name, t] >=
        -ramp_limits.down * minutes_per_period
    )
    return
end

function _add_post_contingency_ramp_dn_constraints!(
    container::OptimizationContainer,
    variable,
    ::Type{PostContingencyActivePowerReserveDeploymentVariable},
    con_up,
    con_down,
    name_outage::String,
    name::String,
    t::Int64,
    ramp_limits,
    minutes_per_period::Int64,
    R::Type{<:Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}}},
)
    if (R <: PSY.Reserve{PSY.ReserveUp})
        con_up[name_outage, name, t] = JuMP.@constraint(
            get_jump_model(container),
            variable[name_outage, name, t] <=
            ramp_limits.up * minutes_per_period
        )
    end
    if (R <: PSY.Reserve{PSY.ReserveDown})
        con_down[name_outage, name, t] = JuMP.@constraint(
            get_jump_model(container),
            variable[name_outage, name, t] <=
            ramp_limits.down * minutes_per_period
        )
    end
    return
end

#G-1 WITH RESERVES AND DELIVERABILITY CONSTRAINTS

function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    service::U,
    contributing_devices::Union{Vector{V}, IS.FlattenIteratorWrapper{V}},
    generator_outages::Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
    formulation::AbstractReservesFormulation,
) where {
    T <: VariableType,
    U <: PSY.AbstractReserve,
    V <: PSY.Component,
    D <: PSY.Component,
}
    add_service_variable!(
        container,
        T(),
        service,
        contributing_devices,
        generator_outages,
        formulation,
    )
    return
end

function add_service_variable!(
    container::OptimizationContainer,
    variable_type::T,
    service::U,
    contributing_devices::V,
    generator_outages::X,
    formulation::AbstractSecurityConstrainedReservesFormulation,
) where {
    T <: AbstractContingencyVariableType,
    U <: PSY.Service,
    V <: Union{Vector{C}, IS.FlattenIteratorWrapper{C}},
    X <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {C <: PSY.Component, D <: PSY.Component}
    @assert !isempty(contributing_devices)
    time_steps = get_time_steps(container)

    binary = get_variable_binary(variable_type, U, formulation)

    variable = add_variable_container!(
        container,
        variable_type,
        U,
        PSY.get_name(service),
        [PSY.get_name(g_o) for g_o in generator_outages],
        [PSY.get_name(d) for d in contributing_devices],
        time_steps,
    )

    for t in time_steps, d in contributing_devices, o in generator_outages
        name = PSY.get_name(d)
        outage_name = PSY.get_name(o)
        variable[outage_name, name, t] = JuMP.@variable(
            get_jump_model(container),
            base_name = "$(T)_$(U)_$(PSY.get_name(service))_{$(outage_name), $(name), $(t)}",
            binary = binary
        )
        if name == outage_name
            JuMP.set_upper_bound(variable[outage_name, name, t], 0.0)
            JuMP.set_lower_bound(variable[outage_name, name, t], 0.0)
            JuMP.set_start_value(variable[outage_name, name, t], 0.0)
            continue
        end

        ub = get_variable_upper_bound(variable_type, service, d, formulation)
        ub !== nothing && JuMP.set_upper_bound(variable[outage_name, name, t], ub)

        lb = get_variable_lower_bound(variable_type, service, d, formulation)
        lb !== nothing && !binary &&
            JuMP.set_lower_bound(variable[outage_name, name, t], lb)

        init = get_variable_warm_start_value(variable_type, d, formulation)
        init !== nothing && JuMP.set_start_value(variable[outage_name, name, t], init)
    end

    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ArgumentConstructStage,
    model::ServiceModel{SR, RangeReserveWithDeliverabilityConstraints},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    ::NetworkModel{<:PM.AbstractPowerModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    add_parameters!(container, RequirementTimeSeriesParameter, service, model)
    contributing_devices = get_contributing_devices(model)

    add_variables!(
        container,
        ActivePowerReserveVariable,
        service,
        contributing_devices,
        RangeReserve(),
    )
    add_to_expression!(container, ActivePowerReserveVariable, model, devices_template)
    add_feedforward_arguments!(container, model, service)
    return
end

function construct_service!(
    container::OptimizationContainer,
    sys::PSY.System,
    ::ModelConstructStage,
    model::ServiceModel{SR, RangeReserveWithDeliverabilityConstraints},
    devices_template::Dict{Symbol, DeviceModel},
    incompatible_device_types::Set{<:DataType},
    network_model::NetworkModel{<:AbstractPTDFModel},
) where {SR <: PSY.Reserve}
    name = get_service_name(model)
    service = PSY.get_component(SR, sys, name)
    !PSY.get_available(service) && return
    contributing_devices = get_contributing_devices(model)

    devices = PSY.get_available_components(PSY.ThermalStandard, sys)    #CORRECT ThermalStandard
    valid_outages = _get_all_scuc_valid_outages(sys, PSY.Generator)
    if isempty(valid_outages)
        throw(
            ArgumentError(
                "System $(PSY.get_name(sys)) has no valid supplemental attributes associated to devices $(PSY.ThermalGen) 
                to add the variables/expressions/constraints for the requested Service formulation: $model.",
            ))
    end
    #TODO Handle also G-k cases
    generator_outages =
        _get_all_single_outage_by_type(sys, valid_outages, devices, PSY.Generator)

    add_constraints!(container, RequirementConstraint, service, contributing_devices, model)
    add_constraints!(
        container,
        ParticipationFractionConstraint,
        service,
        contributing_devices,
        model,
    )

    if !isempty(generator_outages)
        add_variables!(
            container,
            PostContingencyActivePowerReserveDeploymentVariable,
            service,
            contributing_devices,
            generator_outages,
            RangeReserveWithDeliverabilityConstraints(),
        )

        add_constraints!(
            container,
            PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint,
            ActivePowerReserveVariable,
            PostContingencyActivePowerReserveDeploymentVariable,
            contributing_devices,
            generator_outages,
            service,
            model,
            network_model,
        )

        add_to_expression!(
            container,
            PostContingencyActivePowerBalance,
            ActivePowerVariable,
            PostContingencyActivePowerReserveDeploymentVariable,
            contributing_devices,
            generator_outages,
            service,
            model,
            network_model,
        )
        add_constraints!(
            container,
            PostContingengyGenerationBalanceConstraint,
            contributing_devices,
            generator_outages,
            model,
            network_model,
        )

        add_to_expression!(
            container,
            PostContingencyNodalActivePowerDeployment,
            PostContingencyActivePowerReserveDeploymentVariable,
            contributing_devices,
            generator_outages,
            model,
            network_model;
            service = service,
        )

        # #ADD EXPRESSION TO CALCULATE POST CONTINGENCY FLOW FOR EACH Branch  
        add_to_expression!(
            container,
            sys,
            PTDFPostContingencyBranchFlow,
            FlowActivePowerVariable,
            ActivePowerVariable,
            PostContingencyActivePowerReserveDeploymentVariable,
            contributing_devices,
            generator_outages,
            model,
            network_model;
            service = service,
        )

        #ADD CONSTRAINT FOR EACH CONTINGENCY: FLOW <= RATE LIMIT B
        add_constraints!(
            container,
            PostContingencyRateLimitConstraintB,
            PSY.get_available_components(PSY.ACTransmission, sys),
            generator_outages,
            model,
            network_model,
        )

        #ADD RAMPING CONSTRAINTS
        add_constraints!(
            container,
            PostContingencyRampConstraint,
            PostContingencyActivePowerReserveDeploymentVariable,
            contributing_devices,
            generator_outages,
            model,
            network_model;
            service = service,
        )
    end
    objective_function!(container, service, model)

    add_feedforward_constraints!(container, model, service)

    add_constraint_dual!(container, sys, model)

    return
end

"""
Default implementation to add variables to PostContingencySystemBalanceExpressions for G-1 formulation with reserves
"""
function add_to_expression!(
    container::OptimizationContainer,
    ::Type{T},
    ::Type{U},
    ::Type{Y},
    contributing_devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    devices_outages::Vector{X},
    service::R,
    reserves_model::ServiceModel{R, W},
    network_model::NetworkModel{N},
) where {
    T <: PostContingencyActivePowerBalance,
    U <: VariableType,
    Y <: AbstractContingencyVariableType,
    V <: PSY.Generator,
    X <: PSY.Generator,
    R <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    W <: AbstractSecurityConstrainedReservesFormulation,
    N <: AbstractPTDFModel,
}
    time_steps = get_time_steps(container)
    service_name = PSY.get_name(service)
    if !isempty(devices_outages) && !haskey(container.expressions, ExpressionKey(T, X))
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
            X,
            IS.Optimization.CONTAINER_KEY_EMPTY_META,
        ),
    )

    variable = get_variable(container, U(), V)
    reserve_deployment_variable = get_variable(
        container,
        PostContingencyActivePowerReserveDeploymentVariable(),
        R,
        service_name,
    )

    mult = 1.0
    if typeof(service) <: PSY.Reserve{PSY.ReserveDown}
        mult = -1.0
    end

    for d in contributing_devices
        name = PSY.get_name(d)
        for d_outage in devices_outages
            if d == d_outage
                for t in time_steps
                    _add_to_jump_expression!(
                        expression[name, t],
                        variable[name, t],
                        -1.0,
                    )
                end
                continue
            end
            name_outage = PSY.get_name(d_outage)

            for t in time_steps
                _add_to_jump_expression!(
                    expression[name_outage, t],
                    reserve_deployment_variable[name_outage, name, t],
                    mult,
                )
            end
        end
    end
    return
end

function add_constraints!(
    container::OptimizationContainer,
    T::Type{<:PostContingencyActivePowerReserveDeploymentVariableLimitsConstraint},
    X::Type{<:VariableType},
    U::Type{<:AbstractContingencyVariableType},
    devices::Union{IS.FlattenIteratorWrapper{V}, Vector{V}},
    generators_outages::Union{IS.FlattenIteratorWrapper{G}, Vector{G}},
    service::R,
    model::ServiceModel{R, W},
    ::NetworkModel{<:AbstractPTDFModel},
) where {
    V <: PSY.Generator,
    G <: PSY.Generator,
    R <: Union{PSY.Reserve{PSY.ReserveDown}, PSY.Reserve{PSY.ReserveUp}},
    W <: AbstractSecurityConstrainedReservesFormulation,
}
    time_steps = get_time_steps(container)

    set_name = [PSY.get_name(r) for r in devices]
    set_outages_name = [PSY.get_name(r) for r in generators_outages]

    if !haskey(container.constraints, ConstraintKey(T, G, "up")) &&
       (R <: PSY.Reserve{PSY.ReserveUp})
        con =
            add_constraints_container!(
                container,
                T(),
                G,
                set_outages_name,
                set_name,
                time_steps;
                meta = "up",
            )
    end
    if !haskey(container.constraints, ConstraintKey(T, G, "dn")) &&
       (R <: PSY.Reserve{PSY.ReserveDown})
        con =
            add_constraints_container!(
                container,
                T(),
                G,
                set_outages_name,
                set_name,
                time_steps;
                meta = "dn",
            )
    end

    if (R <: PSY.Reserve{PSY.ReserveUp})
        con = get_constraint(
            container,
            ConstraintKey(T, G, "up"),
        )
    else
        con = get_constraint(
            container,
            ConstraintKey(T, G, "dn"),
        )
    end

    variable = get_variable(
        container,
        X(),
        R,
        PSY.get_name(service),
    )

    variable_outage = get_variable(
        container,
        U(),
        R,
        PSY.get_name(service),
    )

    for device in devices
        name = get_name(device)
        @debug "add post-contingency active_power_Reserve_Deployment_Limit_constraint" name

        for device_outage in generators_outages
            name_outage = get_name(device_outage)
            if name == name_outage
                continue
            end

            for t in time_steps
                con[name_outage, name, t] = JuMP.@constraint(
                    get_jump_model(container),
                    variable_outage[name_outage, name, t] <=
                    variable[name, t]
                )
            end
        end
    end
    return
end
