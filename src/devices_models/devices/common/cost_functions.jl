struct AddCostSpec
    variable_type::Type
    component_type::Type
    has_status_variable::Bool
    has_status_parameter::Bool
    sos_status::SOSStatusVariable
    multiplier::Float64
    variable_cost::Union{Nothing, Function}
    start_up_cost::Union{Nothing, Function}
    shut_down_cost::Union{Nothing, Function}
    fixed_cost::Union{Nothing, Function}
    has_multistart_variables::Bool
    addtional_linear_terms::Dict{String, <:VariableKey}
    uses_compact_power::Bool

    function AddCostSpec(;
        variable_type,
        component_type,
        has_status_variable = false,
        has_status_parameter = false,
        sos_status = SOSStatusVariable.NO_VARIABLE,
        multiplier = OBJECTIVE_FUNCTION_POSITIVE,
        variable_cost = nothing,
        start_up_cost = nothing,
        shut_down_cost = nothing,
        fixed_cost = nothing,
        has_multistart_variables = false,
        addtional_linear_terms = Dict{String, VariableKey}(),
        uses_compact_power = false,
    )
        new(
            variable_type,
            component_type,
            has_status_variable,
            has_status_parameter,
            sos_status,
            multiplier,
            variable_cost,
            start_up_cost,
            shut_down_cost,
            fixed_cost,
            has_multistart_variables,
            addtional_linear_terms,
            uses_compact_power,
        )
    end
end
function AddCostSpec(
    ::Type{<:T},
    ::Type{<:U},
    ::OptimizationContainer,
) where {T <: PSY.Component, U <: AbstractDeviceFormulation}
    error("AddCostSpec is not implemented for $T / $U")
end

set_addtional_linear_terms!(spec::AddCostSpec, key, value) =
    spec.addtional_linear_terms[key] = value

function add_service_variables!(spec::AddCostSpec, service_models)
    for service_model in service_models
        name = get_service_name(service_model)
        set_addtional_linear_terms!(
            spec,
            name,
            VariableKey(
                ActivePowerReserveVariable,
                get_component_type(service_model),
                name,
            ),
        )
    end
    return
end

"""
Add variables to the OptimizationContainer for a service.
"""
function cost_function!(
    container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel{T, U},
    ::Type{<:PM.AbstractPowerModel},
) where {T <: PSY.Component, U <: AbstractDeviceFormulation}
    for d in devices
        spec = AddCostSpec(T, U, container)
        @debug T, spec _group = LOG_GROUP_COST_FUNCTIONS
        service_models = get_services(model)
        add_service_variables!(spec, service_models)
        add_to_cost!(container, spec, PSY.get_operation_cost(d), d)
    end
    return
end

function add_to_cost_expression!(
    container::OptimizationContainer,
    cost_expression::JuMP.AbstractJuMPScalar,
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    T_ce = typeof(cost_expression)
    T_cf = typeof(container.cost_function.invariant_terms)
    if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
        container.cost_function.invariant_terms += cost_expression
    else
        JuMP.add_to_expression!(container.cost_function.invariant_terms, cost_expression)
    end
    return
end

function add_to_variant_cost_expression!(
    container::OptimizationContainer,
    cost_expression::JuMP.AbstractJuMPScalar,
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    T_ce = typeof(cost_expression)
    T_cf = typeof(container.cost_function.variant_terms)
    if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
        container.cost_function.variant_terms += cost_expression
    else
        JuMP.add_to_expression!(container.cost_function.variant_terms, cost_expression)
    end
    return
end

function has_on_variable(
    container::OptimizationContainer,
    ::Type{T};
    variable_type = OnVariable,
) where {T <: PSY.Component}
    # get_variable can't be used because the default behavior is to error if variables is not present
    return haskey(container.variables, VariableKey(variable_type, T))
end

function has_on_parameter(
    container::OptimizationContainer,
    ::Type{T},
) where {T <: PSY.Component}
    if !built_for_recurrent_solves(container)
        return false
    end
    # get_parameter can't be used because the default behavior is to error if variables is not present
    return haskey(container.parameters, ParameterKey(OnStatusParameter, T))
end

function slope_convexity_check(slopes::Vector{Float64})
    flag = true
    for ix in 1:(length(slopes) - 1)
        if slopes[ix] > slopes[ix + 1]
            @debug slopes _group = LOG_GROUP_COST_FUNCTIONS
            return flag = false
        end
    end
    return flag
end

function _convert_variable_cost(var_cost::Vector{NTuple{2, Float64}})
    no_load_cost, p_min = var_cost[1]
    var_cost = PSY.VariableCost([(c - no_load_cost, pp - p_min) for (c, pp) in var_cost])
    return var_cost, no_load_cost
end

@doc raw"""
Returns True/False depending on compatibility of the cost data with the linear implementation method

Returns ```flag```

# Arguments

* cost_ : container for linear factors
"""
function pwlparamcheck(cost)
    slopes = PSY.get_slopes(cost)
    # First element of the return is the average cost at P_min.
    # Shouldn't be passed for convexity check
    return slope_convexity_check(slopes[2:end])
end

function linear_gen_cost!(
    container::OptimizationContainer,
    ::T,
    component::U,
    linear_term::Float64,
    time_period::Int,
) where {T <: VariableType, U <: PSY.Component}
    component_name = PSY.get_name(component)
    variable = get_variable(container, T(), U)[component_name, time_period]
    gen_cost = sum(variable) * linear_term
    add_to_cost_expression!(container, gen_cost, component, time_period)
    return
end

function linear_gen_cost!(
    container::OptimizationContainer,
    ::T,
    component::U,
    linear_term::Float64,
    time_period::Int,
) where {T <: ActivePowerVariable, U <: PSY.Component}
    # Do not multiply by dt here since this function is used also for linear costs not
    # subject to time_scaling
    component_name = PSY.get_name(component)
    variable = get_variable(container, T(), U)[component_name, time_period]
    gen_cost = sum(variable) * linear_term
    add_to_cost_expression!(container, gen_cost, component, time_period)
    add_to_expression!(
        container,
        ProductionCostExpression,
        gen_cost,
        component,
        time_period,
    )
    return
end

function _add_pwl_variables!(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
) where {T <: PSY.Component}
    var_container = lazy_container_addition!(container, PieceWiseLinearCostVariable(), T)
    pwlvars = Array{JuMP.VariableRef}(undef, length(cost_data))
    for i in 1:length(cost_data)
        pwlvars[i] =
            var_container[(component_name, i, time_period)] = JuMP.@variable(
                get_jump_model(container),
                base_name = "PieceWiseLinearCostVariable_$(component_name)_{pwl_$(i), $time_period}",
                start = 0.0,
                lower_bound = 0.0,
                upper_bound = 1.0
            )
    end
    return pwlvars
end

function get_pwl_cost_expression(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
) where {T <: PSY.Component}
    pwl_var_container = get_variable(container, PieceWiseLinearCostVariable(), T)
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    gen_cost = JuMP.AffExpr(0.0)
    slopes = PSY.get_slopes(cost_data)
    upb = PSY.get_breakpoint_upperbounds(cost_data)
    for i in 1:length(cost_data)
        JuMP.add_to_expression!(
            gen_cost,
            slopes[i] * upb[i] * dt * pwl_var_container[(component_name, i, time_period)],
        )
    end
    return gen_cost
end

@doc raw"""
Returns piecewise cost expression using SOS Type-2 implementation for optimization_container model.

# Equations

``` variable = sum(sos_var[i]*cost_data[2][i])```

``` gen_cost = sum(sos_var[i]*cost_data[1][i]) ```

# LaTeX

`` variable = (sum_{i\in I} c_{2, i} sos_i) ``

`` gen_cost = (sum_{i\in I} c_{1, i} sos_i) ``

Returns ```gen_cost```

# Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* variable::DenseAxisArray{JV} : variable array
* cost_data::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function pwl_gencost_sos!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
    ::Type{T},
) where {T <: PSY.Component}
    return _pwl_gencost_sos!(
        container,
        component_name,
        time_period,
        spec.sos_status,
        cost_data,
        spec.variable_type,
        T,
    )
end

function pwl_gencost_sos!(
    container::OptimizationContainer,
    attributes::CostFunctionAttributes,
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
    ::Type{T},
) where {T <: PSY.Component}
    return _pwl_gencost_sos!(
        container,
        component_name,
        time_period,
        attributes.sos_status,
        cost_data,
        attributes.variable_type,
        T,
    )
end

function _pwl_gencost_sos!(
    container::OptimizationContainer,
    component_name::String,
    time_period::Int,
    sos_status::SOSStatusVariable,
    cost_data::Vector{NTuple{2, Float64}},
    ::Type{S},
    ::Type{T},
) where {S <: VariableType, T <: PSY.Component}
    base_power = get_base_power(container)
    variables = get_variable(container, S(), T)
    const_container = lazy_container_addition!(
        container,
        PieceWiseLinearCostConstraint(),
        T,
        axes(variables)...,
    )
    variable = variables[component_name, time_period]
    jump_model = get_jump_model(container)
    if sos_status == SOSStatusVariable.NO_VARIABLE
        bin = 1.0
        @debug "Using Piecewise Linear cost function but no variable/parameter ref for ON status is passed. Default status will be set to online (1.0)" _group =
            LOG_GROUP_COST_FUNCTIONS

    elseif sos_status == SOSStatusVariable.PARAMETER
        bin =
            get_parameter(container, OnStatusParameter(), T).parameter_array[component_name]
        @debug "Using Piecewise Linear cost function with parameter OnStatusParameter, $T" _group =
            LOG_GROUP_COST_FUNCTIONS
    elseif sos_status == SOSStatusVariable.VARIABLE
        bin = get_variable(container, OnVariable(), T)[component_name, time_period]
        @debug "Using Piecewise Linear cost function with variable OnVariable $T" _group =
            LOG_GROUP_COST_FUNCTIONS
    else
        @assert false
    end

    pwlvars = _add_pwl_variables!(container, T, component_name, time_period, cost_data)
    gen_cost = get_pwl_cost_expression(container, T, component_name, time_period, cost_data)
    JuMP.@constraint(jump_model, sum(pwlvars[i] for i in 1:length(cost_data)) == bin)
    JuMP.@constraint(jump_model, pwlvars in MOI.SOS2(collect(1:length(pwlvars))))
    const_container[component_name, time_period] = JuMP.@constraint(
        jump_model,
        variable == sum([
            var_ * cost_data[ix][2] / base_power for (ix, var_) in enumerate(pwlvars)
        ])
    )
    return gen_cost
end

@doc raw"""
Returns piecewise cost expression using linear implementation for optimization_container model.

# Equations

``` 0 <= pwl_var[i] <= (cost_data[2][i] - cost_data[2][i-1])```

``` variable = sum(pwl_var[i])```

``` gen_cost = sum(pwl_var[i]*cost_data[1][i]/cost_data[2][i]) ```

# LaTeX
`` 0 <= pwl_i <= (c_{2, i} - c_{2, i-1})``

`` variable = (sum_{i\in I} pwl_i) ``

`` gen_cost = (sum_{i\in I}  pwl_i) c_{1, i}/c_{2, i} ``

Returns ```gen_cost```

# Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* variable::DenseAxisArray{JV} : variable array
* cost_data::Vector{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function pwl_gencost_linear!(
    container::OptimizationContainer,
    attr::CostFunctionAttributes,
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
    ::Type{T},
) where {T <: PSY.Component}
    return _pwl_gencost_linear!(
        container,
        component_name,
        time_period,
        cost_data,
        attr.variable_type,
        T,
    )
end

function pwl_gencost_linear!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
    ::Type{T},
) where {T <: PSY.Component}
    return _pwl_gencost_linear!(
        container,
        component_name,
        time_period,
        cost_data,
        spec.variable_type,
        T,
    )
end

function _pwl_gencost_linear!(
    container::OptimizationContainer,
    component_name::String,
    time_period::Int,
    cost_data::Vector{NTuple{2, Float64}},
    ::Type{S},
    ::Type{T},
) where {S <: VariableType, T <: PSY.Component}
    base_power = get_base_power(container)
    variables = get_variable(container, S(), T)
    const_container = lazy_container_addition!(
        container,
        PieceWiseLinearCostConstraint(),
        T,
        axes(variables)...,
    )
    variable = variables[component_name, time_period]
    jump_model = get_jump_model(container)
    break_points = PSY.get_breakpoint_upperbounds(cost_data)

    pwlvars = _add_pwl_variables!(container, T, component_name, time_period, cost_data)
    gen_cost = get_pwl_cost_expression(container, T, component_name, time_period, cost_data)
    const_container[component_name, time_period] = JuMP.@constraint(
        jump_model,
        variable == sum([
            var_ * break_points[ix] / base_power for (ix, var_) in enumerate(pwlvars)
        ])
    )
    return gen_cost
end

"""
Adds to the models costs represented by PowerSystems TwoPart costs
"""
function add_to_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    cost_data::PSY.TwoPartCost,
    component::PSY.Component,
)
    component_name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    @debug "TwoPartCost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    if spec.variable_cost !== nothing
        variable_cost = spec.variable_cost(cost_data)
        for t in time_steps
            variable_cost!(container, spec, component, variable_cost, t)
        end
    else
        @warn "No variable cost defined for $component_name"
    end

    if spec.fixed_cost !== nothing && spec.has_status_variable
        @debug "Fixed cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(container, OnVariable(), component, spec.fixed_cost, t)
        end
    end
    return
end

"""
Adds to the models costs represented by PowerSystems ThreePart costs
"""
function add_to_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    cost_data::PSY.ThreePartCost,
    component::PSY.Component,
)
    component_name = PSY.get_name(component)
    @debug "ThreePartCost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    variable_cost = spec.variable_cost(cost_data)
    time_steps = get_time_steps(container)
    for t in time_steps
        variable_cost!(container, spec, component, variable_cost, t)
    end

    if spec.start_up_cost !== nothing
        @debug "Start up cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                StartVariable(),
                component,
                spec.start_up_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    if spec.shut_down_cost !== nothing
        @debug "Shut down cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                StopVariable(),
                component,
                spec.shut_down_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    if spec.fixed_cost !== nothing && spec.has_status_variable
        @debug "Fixed cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                OnVariable(),
                component,
                spec.fixed_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    return
end

"""
Adds to the models costs represented by PowerSystems Multi-Start costs.
"""
function add_to_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    cost_data::PSY.MultiStartCost,
    component::PSY.Component,
)
    component_name = PSY.get_name(component)
    time_steps = get_time_steps(container)

    if spec.fixed_cost !== nothing && spec.has_status_variable
        @debug "Fixed cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                OnVariable(),
                component,
                spec.fixed_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    if spec.shut_down_cost !== nothing
        @debug "Shut down cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                StopVariable(),
                component,
                spec.shut_down_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    # Original implementation had SOS by default, here it detects if that's needed
    variable_cost_data = spec.variable_cost(cost_data)
    for t in time_steps
        variable_cost!(container, spec, component, variable_cost_data, t)
    end

    # Start-up costs
    if spec.start_up_cost !== nothing
        start_cost_data = PSY.get_start_up(cost_data)
        if spec.has_multistart_variables
            for (st, var_type) in enumerate(START_VARIABLES), t in time_steps
                linear_gen_cost!(
                    container,
                    var_type(),
                    component,
                    start_cost_data[st] * spec.multiplier,
                    t,
                )
            end
        else
            for t in time_steps
                linear_gen_cost!(
                    container,
                    StartVariable(),
                    component,
                    start_cost_data[1] * spec.multiplier,
                    t,
                )
            end
        end
    end
    return
end

function _get_cost_function_parameter_container(
    container::OptimizationContainer,
    spec::AddCostSpec,
    ::Type{S},
    ::Type{T},
) where {S <: ObjectiveFunctionParameter, T <: PSY.Component}
    if has_container_key(container, S, T)
        return get_parameter(container, S, T)
    else
        container_axes = axes(get_variable(container, spec.variable_type(), T))
        return add_param_container!(
            container,
            S(),
            T,
            spec.sos_status,
            spec.variable_type,
            spec.uses_compact_power,
            container_axes...,
        )
    end
end

"""
Adds to the models costs represented by PowerSystems Market-Bid costs. Implementation for
devices PSY.ThermalMultiStart
"""
function add_to_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    cost_data::PSY.MarketBidCost,
    component::T,
) where {T <: PSY.ThermalMultiStart}
    component_name = PSY.get_name(component)
    @debug "Market Bid" _group = LOG_GROUP_COST_FUNCTIONS component_name
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    variable_cost_forecast = PSY.get_variable_cost(
        component,
        PSY.get_operation_cost(component);
        start_time = initial_time,
        len = length(time_steps),
    )
    variable_cost_forecast_values = TimeSeries.values(variable_cost_forecast)
    jump_model = get_jump_model(container)
    parameter_container =
        _get_cost_function_parameter_container(container, spec, CostFunctionParameter, T)

    for t in time_steps
        if spec.uses_compact_power
            variable_cost, _ = _convert_variable_cost(variable_cost_forecast_values[t])
        else
            variable_cost = variable_cost_forecast_values[t]
        end
        set_parameter!(
            parameter_container,
            jump_model,
            PSY.get_cost(variable_cost),
            # Using 1.0 here since we want to reuse the existing code that adds the mulitpler
            #  of base power times the time delta.
            1.0,
            component_name,
            t,
        )
        variable_cost!(container, parameter_container, component, t)
    end

    if spec.start_up_cost !== nothing
        start_cost_data = spec.start_up_cost(cost_data)
        if spec.has_multistart_variables
            for (st, var_type) in enumerate(START_VARIABLES)
                for t in time_steps
                    linear_gen_cost!(
                        container,
                        var_type(),
                        component,
                        start_cost_data[st] * spec.multiplier,
                        t,
                    )
                end
            end
        else
            for t in time_steps
                linear_gen_cost!(
                    container,
                    StartVariable(),
                    component,
                    start_cost_data[1] * spec.multiplier,
                    t,
                )
            end
        end
    end

    if spec.has_status_variable
        @debug "no_load cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                OnVariable(),
                component,
                PSY.get_no_load(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    if spec.shut_down_cost !== nothing
        @debug "Shut down cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                StopVariable(),
                component,
                spec.shut_down_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    #Service Cost Bid
    ancillary_services = PSY.get_ancillary_services(cost_data)
    for service in ancillary_services
        add_service_bid_cost!(container, spec, component, service)
    end
    return
end

"""
Adds to the models costs represented by PowerSystems Market-Bid costs. Default implementation for any PSY.Component. Uses by default the cost in of the cold stages for
start up costs.
"""
function add_to_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    cost_data::PSY.MarketBidCost,
    component::PSY.Component,
)
    component_name = PSY.get_name(component)
    @debug "Market Bid" _group = LOG_GROUP_COST_FUNCTIONS component_name
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    variable_cost_forecast = PSY.get_variable_cost(
        component,
        PSY.get_operation_cost(component);
        start_time = initial_time,
        len = length(time_steps),
    )
    variable_cost_forecast_values = TimeSeries.values(variable_cost_forecast)
    for t in time_steps
        if spec.uses_compact_power
            variable_cost, _ = _convert_variable_cost(variable_cost_forecast_values[t])
        else
            variable_cost = variable_cost_forecast_values[t]
        end
        variable_cost!(container, spec, component, variable_cost, t)
    end

    if spec.start_up_cost !== nothing
        start_cost_data = spec.start_up_cost(cost_data)
        for t in time_steps
            linear_gen_cost!(
                container,
                StartVariable(),
                component,
                start_cost_data.hot * spec.multiplier,
                t,
            )
        end
    end

    if spec.has_status_variable
        @debug "no_load cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                OnVariable(),
                component,
                PSY.get_no_load(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    if spec.shut_down_cost !== nothing
        @debug "Shut down cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                StopVariable(),
                component,
                spec.shut_down_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    # Service Cost Bid
    ancillary_services = PSY.get_ancillary_services(cost_data)
    for service in ancillary_services
        add_service_bid_cost!(container, spec, component, service)
    end
    return
end

function add_service_bid_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    component::PSY.Component,
    service::PSY.Service,
)
    return
end

function add_service_bid_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    component::PSY.Component,
    service::PSY.Reserve{T},
) where {T <: PSY.ReserveDirection}
    time_steps = get_time_steps(container)
    initial_time = get_initial_time(container)
    base_power = get_base_power(container)
    forecast_data = PSY.get_services_bid(
        component,
        PSY.get_operation_cost(component),
        service;
        start_time = initial_time,
        len = length(time_steps),
    )
    forecast_data_values = PSY.get_cost.(TimeSeries.values(forecast_data)) .* base_power
    if eltype(forecast_data_values) == Float64
        for t in time_steps
            linear_gen_cost!(
                container,
                spec.addtional_linear_terms[PSY.get_name(service)],
                component,
                forecast_data_values[t],
                t,
            )
        end
    else
        error(
            "Current version only supports linear cost bid for services, please change the forecast data for $(PSY.get_name(service))",
        )
    end
    return
end

function add_service_bid_cost!(
    ::OptimizationContainer,
    ::AddCostSpec,
    ::PSY.Component,
    service::PSY.ReserveDemandCurve{T},
) where {T <: PSY.ReserveDirection}
    error(
        "Current version doesn't supports cost bid for ReserveDemandCurve services, please change the forecast data for $(PSY.get_name(service))",
    )
    return
end

function add_to_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    cost_data::PSY.StorageManagementCost,
    component::PSY.Component,
)
    component_name = PSY.get_name(component)
    @debug "Storage Management Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    time_steps = get_time_steps(container)
    variable_cost = PSY.get_variable(cost_data)
    time_steps = get_time_steps(container)
    for t in time_steps
        variable_cost!(container, spec, component, variable_cost, t)
    end

    if spec.fixed_cost !== nothing && spec.has_status_variable
        @debug "Fixed cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                OnVariable(),
                component,
                spec.fixed_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    if spec.start_up_cost !== nothing
        @debug "Start up cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                StartVariable(),
                component,
                cost_data.spec.start_up_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    if spec.shut_down_cost !== nothing
        @debug "Shut down cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        for t in time_steps
            linear_gen_cost!(
                container,
                StopVariable(),
                component,
                spec.shut_down_cost(cost_data) * spec.multiplier,
                t,
            )
        end
    end

    @debug "Energy Surplus/Shortage cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    base_power = get_base_power(container)
    for t in time_steps
        linear_gen_cost!(
            container,
            EnergySurplusVariable(),
            component,
            cost_data.energy_surplus_cost * OBJECTIVE_FUNCTION_NEGATIVE * base_power,
            t,
        )
        linear_gen_cost!(
            container,
            EnergyShortageVariable(),
            component,
            cost_data.energy_shortage_cost * spec.multiplier * base_power,
            t,
        )
    end

    return
end

@doc raw"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for optimization_container model.

    # Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* var_key::VariableKey: The variable name
* component_name::String: The component_name of the variable container
* cost_component::PSY.VariableCost{Float64} : container for cost to be associated with variable
"""
function variable_cost!(
    ::OptimizationContainer,
    ::AddCostSpec,
    component::PSY.Component,
    ::Nothing,
    ::Int,
)
    @debug "Empty Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    return
end

@doc raw"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for optimization_container model.

    # Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* var_key::VariableKey: The variable name
* component_name::String: The component_name of the variable container
* cost_component::PSY.VariableCost{Float64} : container for cost to be associated with variable
"""
function variable_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    component::PSY.Component,
    cost_component::PSY.VariableCost{Float64},
    time_period::Int,
)
    @debug "Linear Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS PSY.get_name(component)
    base_power = get_base_power(container)
    cost_data = PSY.get_cost(cost_component)
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    linear_gen_cost!(
        container,
        spec.variable_type(),
        component,
        cost_data * spec.multiplier * base_power * dt,
        time_period,
    )
    return
end

@doc raw"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for optimization_container model.

# Equation

``` gen_cost = dt*sign*(sum(variable.^2)*cost_data[1] + sum(variable)*cost_data[2]) ```

# LaTeX

`` cost = dt\times sign (sum_{i\in I} c_1 v_i^2 + sum_{i\in I} c_2 v_i ) ``

for quadratic factor large enough. If the first term of the quadratic objective is 0.0, adds a
linear cost term `sum(variable)*cost_data[2]`

# Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* var_key::VariableKey: The variable name
* component_name::String: The component_name of the variable container
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function variable_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    component::PSY.Component,
    cost_component::PSY.VariableCost{NTuple{2, Float64}},
    time_period::Int,
)
    base_power = get_base_power(container)
    component_name = PSY.get_name(component)
    cost_data = PSY.get_cost(cost_component)
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    if cost_data[1] >= eps()
        @debug "$component_name Quadratic Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
        variable = get_variable(container, spec.variable_type(), spec.component_type)[
            component_name,
            time_period,
        ]
        gen_cost =
            (
                sum((variable .* base_power) .^ 2) * cost_data[1] +
                sum(variable .* base_power) * cost_data[2]
            ) *
            spec.multiplier *
            dt
        add_to_cost_expression!(container, gen_cost, component, time_period)
        add_to_expression!(
            container,
            ProductionCostExpression,
            gen_cost,
            component,
            time_period,
        )
    else
        @debug "$component_name Quadratic Variable Cost with only linear term" _group =
            LOG_GROUP_COST_FUNCTIONS component_name
        linear_gen_cost!(
            container,
            spec.variable_type(),
            component,
            cost_data[2] * spec.multiplier * base_power * dt,
            time_period,
        )
    end
    return
end

@doc raw"""
Creates piecewise linear cost function using a sum of variables and expression with sign and time step included.

# Expression

```JuMP.add_to_expression!(gen_cost, c)```

Returns sign*gen_cost*dt

# LaTeX

``cost = sign\times dt \sum_{v\in V} c_v``

where ``c_v`` is given by

`` c_v = \sum_{i\in Ix} \frac{y_i - y_{i-1}}{x_i - x_{i-1}} v^{p.w.}_i ``

# Arguments

* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* var_key::VariableKey: The variable name
* component_name::String: The component_name of the variable container
* cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}}
"""
function variable_cost!(
    container::OptimizationContainer,
    spec::AddCostSpec,
    component::T,
    cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
    time_period::Int,
) where {T <: PSY.Component}
    component_name = PSY.get_name(component)
    @debug "PWL Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    # If array is full of tuples with zeros return 0.0
    cost_data = PSY.get_cost(cost_component)
    if all(iszero.(last.(cost_data)))
        @debug "All cost terms for component $(component_name) are 0.0" _group =
            LOG_GROUP_COST_FUNCTIONS
        return
    end

    if !pwlparamcheck(cost_component)
        @warn(
            "The cost function provided for $(component_name) is not compatible with a linear PWL cost function.
      An SOS-2 formulation will be added to the model. This will result in additional binary variables."
        )
        gen_cost_ =
            pwl_gencost_sos!(container, spec, component_name, time_period, cost_data, T)
    else
        gen_cost_ =
            pwl_gencost_linear!(container, spec, component_name, time_period, cost_data, T)
    end
    gen_cost = spec.multiplier * gen_cost_
    add_to_cost_expression!(container, gen_cost, component, time_period)
    add_to_expression!(
        container,
        ProductionCostExpression,
        gen_cost,
        component,
        time_period,
    )
    return
end

function variable_cost!(
    container::OptimizationContainer,
    parameter_container::ParameterContainer,
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    param = get_parameter_array(parameter_container)
    attributes = get_attributes(parameter_container)
    variable_cost!(container, param, attributes, component, time_period)
    return
end

function variable_cost!(
    container::OptimizationContainer,
    param_array::AbstractArray{Vector{NTuple{2, Float64}}},
    attributes::CostFunctionAttributes,
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    component_name = PSY.get_name(component)
    @debug "PWL Variable Cost" _group = LOG_GROUP_COST_FUNCTIONS component_name
    # If array is full of tuples with zeros return 0.0
    cost_data = param_array[component_name, time_period]
    if all(iszero.(last.(cost_data)))
        @debug "All cost terms for component $(component_name) are 0.0" _group =
            LOG_GROUP_COST_FUNCTIONS
        return
    end

    if !pwlparamcheck(cost_data)
        @warn(
            "The cost function provided for $(component_name) is not compatible with a linear PWL cost function.
      An SOS-2 formulation will be added to the model. This will result in additional binary variables."
        )
        gen_cost = pwl_gencost_sos!(
            container,
            attributes,
            component_name,
            time_period,
            cost_data,
            T,
        )
    else
        gen_cost = pwl_gencost_linear!(
            container,
            attributes,
            component_name,
            time_period,
            cost_data,
            T,
        )
    end

    add_to_variant_cost_expression!(container, gen_cost, component, time_period)
    add_to_expression!(
        container,
        ProductionCostExpression,
        gen_cost,
        component,
        time_period,
    )
    return
end

function update_variable_cost!(
    container::OptimizationContainer,
    param_array::AbstractArray{Vector{NTuple{2, Float64}}},
    attributes::CostFunctionAttributes,
    component::T,
    time_period::Int,
) where {T <: PSY.Component}
    component_name = PSY.get_name(component)
    cost_data = param_array[component_name, time_period]
    if all(iszero.(last.(cost_data)))
        return
    end

    gen_cost = get_pwl_cost_expression(container, T, component_name, time_period, cost_data)
    # Attribute doesn't have multiplier
    # gen_cost = attributes.multiplier * gen_cost_
    add_to_variant_cost_expression!(container, gen_cost, component, time_period)
    set_expression!(container, ProductionCostExpression, gen_cost, component, time_period)
    return
end
