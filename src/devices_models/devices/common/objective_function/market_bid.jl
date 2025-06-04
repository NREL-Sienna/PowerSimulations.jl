##################################################
################ PWL Parameters  #################
##################################################

# TODO perhaps it would be more elegant to parameterize IS.PiecewiseStepData on the types of its component vectors?
# TODO if not, this should probably go in a different file
"""
Like [`InfrastructureSystems.PiecewiseStepData`](@extref) but `x_coords` are `VariableRef`.
Functionality is somewhat limited (e.g., no serialization, currently no validation).
"""
@kwdef struct VariableRefStepData <: IS.FunctionData
    x_coords::Vector{JuMP.AbstractJuMPScalar}
    y_coords::Vector{Float64}
end
IS.get_x_coords(data::VariableRefStepData) = data.x_coords
IS.get_y_coords(data::VariableRefStepData) = data.y_coords

const GenericStepData = Union{IS.PiecewiseStepData, VariableRefStepData}
GenericStepData(x_coords::Vector{Float64}, y_coords::Vector{Float64}) =
    IS.PiecewiseStepData(x_coords, y_coords)
GenericStepData(x_coords::Vector{<:JuMP.AbstractJuMPScalar}, y_coords::Vector{Float64}) =
    VariableRefStepData(x_coords, y_coords)

# Determines whether we care about various types of costs, given the formulation
# NOTE: currently works based on what has already been added to the container;
# alternatively we could dispatch on the formulation directly
_consider_startup_time_series(
    container::OptimizationContainer,
    ::DeviceModel{T, D},
) where {T, D} =
    any(
        haskey.(
            [get_variables(container)],
            VariableKey.([StartVariable, MULTI_START_VARIABLES...], [T])),
    )
_consider_shutdown_time_series(
    container::OptimizationContainer,
    ::DeviceModel{T, D},
) where {T, D} =
    haskey(get_variables(container), VariableKey(StopVariable, T))

_consider_initial_input_time_series(
    container::OptimizationContainer,
    ::DeviceModel{T, D},
) where {T, D} =
    haskey(get_variables(container), VariableKey(OnVariable, T))

# TODO the relevant variables seem to be created in the `ModelConstructStage` for this one,
# so we can't check for them here? Will that persist?
_consider_slope_time_series(
    container::OptimizationContainer,
    ::DeviceModel{T, D},
) where {T, D} = true  # temporary, see above

_has_market_bid_cost(device::PSY.StaticInjection) =
    PSY.get_operation_cost(device) isa PSY.MarketBidCost
_has_startup_time_series(device::PSY.StaticInjection) =
    is_time_variant(PSY.get_start_up(PSY.get_operation_cost(device)))
_has_shutdown_time_series(device::PSY.StaticInjection) =
    is_time_variant(PSY.get_shut_down(PSY.get_operation_cost(device)))
_has_incremental_initial_input_time_series(device::PSY.StaticInjection) =
    _has_market_bid_cost(device) &&
    is_time_variant(PSY.get_incremental_initial_input(PSY.get_operation_cost(device)))
_has_incremental_offer_curves_time_series(device::PSY.StaticInjection) =
    _has_market_bid_cost(device) &&
    is_time_variant(PSY.get_incremental_offer_curves(PSY.get_operation_cost(device)))

function validate_initial_input_time_series(device::PSY.StaticInjection, decremental::Bool)
    cost = PSY.get_operation_cost(device)::PSY.MarketBidCost
    ts_initial = is_time_variant(
        if decremental
            PSY.get_decremental_initial_input(cost)
        else
            PSY.get_incremental_initial_input(cost)
        end,
    )
    ts_variable = is_time_variant(
        if decremental
            PSY.get_decremental_offer_curves(cost)
        else
            PSY.get_incremental_offer_curves(cost)
        end,
    )
    label = decremental ? "decremental" : "incremental"

    (ts_initial && !ts_variable) &&
        @warn "In `MarketBidCost` for $(get_name(device)), found time series for `$(label)_initial_input` but not `$(label)_offer_curves`; will ignore `initial_input` of `$(label)_offer_curves"
    (ts_variable && !ts_initial) &&
        throw(
            ArgumentError(
                "In `MarketBidCost` for $(get_name(device)), if providing time series for `$(label)_offer_curves`, must also provide time series for `$(label)_initial_input`",
            ),
        )
    return
end

function _add_market_bid_parameters_helper(
    consider_fn,
    filter_fn,
    param,
    container,
    model,
    devices,
)
    if consider_fn(container, model)
        my_devices = filter(filter_fn, devices)
        if length(my_devices) > 0
            add_parameters!(container, param, my_devices, model)
            return true
        end
    end
    return false
end

function add_market_bid_parameters!(
    container::OptimizationContainer,
    devices,
    model::DeviceModel,
)
    devices = filter(_has_market_bid_cost, collect(devices))  # https://github.com/NREL-Sienna/InfrastructureSystems.jl/issues/460

    # Startup cost parameters
    _add_market_bid_parameters_helper(
        _consider_startup_time_series,
        _has_startup_time_series,
        StartupCostParameter,
        container,
        model,
        devices,
    )

    # Shutdown cost parameters
    _add_market_bid_parameters_helper(
        _consider_shutdown_time_series,
        _has_shutdown_time_series,
        ShutdownCostParameter,
        container,
        model,
        devices,
    )

    # Min gen cost parameters
    # TODO decremental case
    _add_market_bid_parameters_helper(
        _consider_initial_input_time_series,
        _has_incremental_initial_input_time_series,
        IncrementalCostAtMinParameter,
        container,
        model,
        devices,
    )

    # Variable cost: slope parameters
    # TODO decremental case
    _add_market_bid_parameters_helper(
        _consider_slope_time_series,
        _has_incremental_offer_curves_time_series,
        IncrementalPiecewiseLinearSlopeParameter,
        container,
        model,
        devices,
    )

    # Variable cost: breakpoint parameters
    # TODO decremental case
    _add_market_bid_parameters_helper(
        _consider_slope_time_series,
        _has_incremental_offer_curves_time_series,
        IncrementalPiecewiseLinearBreakpointParameter,
        container,
        model,
        devices,
    )
end

##################################################
################# PWL Variables ##################
##################################################

# For Market Bid
function _add_pwl_variables!(
    container::OptimizationContainer,
    ::Type{T},
    component_name::String,
    time_period::Int,
    cost_data::GenericStepData,
    ::Type{U},
) where {
    T <: PSY.Component,
    U <: AbstractPiecewiseLinearBlockOffer,
}
    var_container = lazy_container_addition!(container, U(), T)
    # length(PiecewiseStepData) gets number of segments, here we want number of points
    break_points = PSY.get_x_coords(cost_data)
    pwlvars = Array{JuMP.VariableRef}(undef, length(break_points))
    for i in 1:(length(break_points) - 1)
        pwlvars[i] =
            var_container[(component_name, i, time_period)] = JuMP.@variable(
                get_jump_model(container),
                base_name = "$(nameof(U))_$(component_name)_{pwl_$(i), $time_period}",
                lower_bound = 0.0,
            )
    end
    return pwlvars
end

##################################################
################# PWL Constraints ################
##################################################

_include_min_gen_power_in_constraint(::ActivePowerVariable) = true
_include_min_gen_power_in_constraint(::PowerAboveMinimumVariable) = false

"""
Implement the constraints for PWL Block Offer variables. That is:

```math
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} = p_t \\\\
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} <= P_{k+1,t}^{max} - P_{k,t}^{max}
```
"""
function _add_pwl_constraint!(
    container::OptimizationContainer,
    component::T,
    ::U,
    break_points::Vector{<:JuMPOrFloat},
    period::Int,
    ::Type{V},
    ::Type{W},
) where {T <: PSY.Component, U <: VariableType,
    V <: AbstractPiecewiseLinearBlockOffer,
    W <: AbstractPiecewiseLinearBlockOfferConstraint}
    variables = get_variable(container, U(), T)
    const_container = lazy_container_addition!(
        container,
        W(),
        T,
        axes(variables)...,
    )
    len_cost_data = length(break_points) - 1
    jump_model = get_jump_model(container)
    pwl_vars = get_variable(container, V(), T)
    name = PSY.get_name(component)
    sum_pwl_vars = sum(pwl_vars[name, ix, period] for ix in 1:len_cost_data)

    # TODO fix https://github.com/NREL-Sienna/PowerSimulations.jl/issues/1318 better, this is a stopgap
    if _include_min_gen_power_in_constraint(U())
        on_vars = get_variable(container, OnVariable(), T)
        min_power = if first(break_points) isa Number
            # In this case, we can use the first breakpoint without creating a quadratic constraint
            first(break_points)
        else
            # In this case, using the first breakpoint would create a quadratic constraint
            @warn "FIXME implicitly assuming first breakpoint is at generator min power for all time periods"
            component.active_power_limits.min/PSY.get_base_power(component)*get_base_power(container)
        end
        sum_pwl_vars += min_power * on_vars[name, period]
    end

    const_container[name, period] = JuMP.@constraint(
        jump_model,
        variables[name, period] == sum_pwl_vars
    )

    for ix in 1:len_cost_data
        JuMP.@constraint(
            jump_model,
            pwl_vars[name, ix, period] <= break_points[ix + 1] - break_points[ix]
        )
    end
    return
end

"""
Implement the constraints for PWL Block Offer variables for ORDC. That is:

```math
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} = p_t \\\\
\\sum_{k\\in\\mathcal{K}} \\delta_{k,t} <= P_{k+1,t}^{max} - P_{k,t}^{max}
```
"""
function _add_pwl_constraint!(
    container::OptimizationContainer,
    component::T,
    ::U,
    break_points::Vector{Float64},
    sos_status::SOSStatusVariable,
    period::Int,
) where {T <: PSY.ReserveDemandCurve, U <: ServiceRequirementVariable}
    name = PSY.get_name(component)
    variables = get_variable(container, U(), T, name)
    const_container = lazy_container_addition!(
        container,
        PiecewiseLinearBlockIncrementalOfferConstraint(),
        T,
        axes(variables)...;
        meta = name,
    )
    len_cost_data = length(break_points) - 1
    jump_model = get_jump_model(container)
    pwl_vars = get_variable(container, PiecewiseLinearBlockIncrementalOffer(), T)
    const_container[name, period] = JuMP.@constraint(
        jump_model,
        variables[name, period] ==
        sum(pwl_vars[name, ix, period] for ix in 1:len_cost_data)
    )

    for ix in 1:len_cost_data
        JuMP.@constraint(
            jump_model,
            pwl_vars[name, ix, period] <= break_points[ix + 1] - break_points[ix]
        )
    end
    return
end

##################################################
################ PWL Expressions #################
##################################################

get_offer_curves_for_var(var, comp::PSY.Component) =
    get_offer_curves_for_var(var, get_operation_cost(comp))
get_offer_curves_for_var(::PiecewiseLinearBlockIncrementalOffer, cost::PSY.MarketBidCost) =
    PSY.get_incremental_offer_curves(cost)
get_offer_curves_for_var(::PiecewiseLinearBlockDecrementalOffer, cost::PSY.MarketBidCost) =
    PSY.get_decremental_offer_curves(cost)

get_multiplier_for_var(::PiecewiseLinearBlockIncrementalOffer) = OBJECTIVE_FUNCTION_POSITIVE
get_multiplier_for_var(::PiecewiseLinearBlockDecrementalOffer) = OBJECTIVE_FUNCTION_NEGATIVE

function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_function::PSY.MarketBidCost,
    ::GenericStepData,  # TODO use this??
    ::U,
    ::V,
    ::W,
) where {
    T <: PSY.Component,
    U <: VariableType,
    V <: AbstractDeviceFormulation,
    W <: AbstractPiecewiseLinearBlockOffer,
}
    # TODO refactor
    is_decremental = (W() isa PiecewiseLinearBlockDecrementalOffer)
    cost_data_normalized = _get_pwl_data(is_decremental, container, component, time_period)

    resolution = get_resolution(container)
    dt = Dates.value(resolution) / MILLISECONDS_IN_HOUR
    multiplier = get_multiplier_for_var(W()) * dt

    name = PSY.get_name(component)
    pwl_var_container = get_variable(container, W(), T)
    gen_cost = JuMP.AffExpr(0.0)
    y_coords_cost_data = PSY.get_y_coords(cost_data_normalized)
    for (i, cost) in enumerate(y_coords_cost_data)
        JuMP.add_to_expression!(  # TODO variant?
            gen_cost,
            cost * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return gen_cost
end

"""
Get cost expression for StepwiseCostReserve
"""
function _get_pwl_cost_expression(
    container::OptimizationContainer,
    component::T,
    time_period::Int,
    cost_data::GenericStepData,
    multiplier::Float64,
) where {T <: PSY.ReserveDemandCurve}
    name = PSY.get_name(component)
    pwl_var_container = get_variable(container, PiecewiseLinearBlockIncrementalOffer(), T)
    slopes = PSY.get_y_coords(cost_data)
    ordc_cost = JuMP.AffExpr(0.0)
    for i in 1:length(slopes)
        JuMP.add_to_expression!(
            ordc_cost,
            slopes[i] * multiplier * pwl_var_container[(name, i, time_period)],
        )
    end
    return ordc_cost
end

###############################################
######## MarketBidCost: Fixed Curves ##########
###############################################

# Data should be such that there are no NaNs up to some point and then all NaNs
function _up_to_first_nan(arr::Vector{Float64})
    last_ix = findfirst(isnan, arr) - 1
    @assert all(isnan, arr[(last_ix + 1):end])
    result = arr[1:last_ix]
    @assert all(!isnan, result)
    return result
end

# Serves a similar role as _lookup_maybe_time_variant_param, but needs extra logic
function _get_pwl_data(
    is_decremental::Bool,
    container::OptimizationContainer,
    component::T,
    time::Int,
) where {T <: PSY.Component}
    # TODO refactor?
    cost_data = (
        if is_decremental
            PSY.get_decremental_offer_curves
        else
            PSY.get_incremental_offer_curves
        end)(
        PSY.get_operation_cost(component))

    if is_time_variant(cost_data)
        name = PSY.get_name(component)

        SlopeParam = if is_decremental
            DecrementalPiecewiseLinearSlopeParameter
        else
            IncrementalPiecewiseLinearSlopeParameter
        end
        slope_param_arr = get_parameter_array(container, SlopeParam(), T)
        slope_param_mult = get_parameter_multiplier_array(container, SlopeParam(), T)
        slope_cost_component =
            slope_param_arr[name, time, :] .* slope_param_mult[name, time, :]

        BreakpointParam = if is_decremental
            DecrementalPiecewiseLinearBreakpointParameter
        else
            IncrementalPiecewiseLinearBreakpointParameter
        end
        breakpoint_param_container = get_parameter(container, BreakpointParam(), T)
        breakpoint_param_arr = get_parameter_column_refs(breakpoint_param_container, name)  # performs component -> time series many-to-one mapping
        breakpoint_param_mult = get_multiplier_array(breakpoint_param_container)
        # TODO do I now have additional axes for slope_param_mult but not breakpoint_param_mult?
        breakpoint_cost_component =
            breakpoint_param_arr[time, :] .* breakpoint_param_mult[name, time]

        # NaNs signify that we had more space in the container than tranches in the
        # function, so it's valid to discard trailing NaNs
        slope_cost_component = _up_to_first_nan(slope_cost_component.data)
        # @assert all(
        #     breakpoint_cost_component.data[length(slope_cost_component)+2:end] .==
        #     _BREAKPOINT_PAD_VALUE)
        breakpoint_cost_component =
            breakpoint_cost_component.data[1:(length(slope_cost_component) + 1)]

        cost_component = GenericStepData(
            breakpoint_cost_component,
            slope_cost_component,
        )
        # PSY's cost_function_timeseries.jl says this will always be natural units
        unit_system = PSY.UnitSystem.NATURAL_UNITS
    else
        cost_component = PSY.get_function_data(PSY.get_value_curve(cost_data))
        unit_system = PSY.get_power_units(cost_data)
    end

    result = get_piecewise_incrementalcurve_per_system_unit(cost_component,
        unit_system,
        get_base_power(container),
        PSY.get_base_power(component),
    )

    # TODO move these checks to before we convert to VariableRef
    # if is_decremental
    #     PSY.is_concave(result) ||
    #         error("Decremental MarketBidCost for component $(name) is non-concave")
    # else
    #     PSY.is_convex(result) ||
    #         error("Incremental MarketBidCost for component $(name) is non-convex")
    # end

    return result
end

"""
Add PWL cost terms for data coming from the MarketBidCost
with a fixed incremental offer curve
"""
function add_pwl_term!(
    is_decremental::Bool,
    container::OptimizationContainer,
    component::T,
    cost_function::PSY.MarketBidCost,
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractDeviceFormulation}
    name = PSY.get_name(component)
    # TODO refactor?
    W = if is_decremental
        PiecewiseLinearBlockDecrementalOffer
    else
        PiecewiseLinearBlockIncrementalOffer
    end
    X = if is_decremental
        PiecewiseLinearBlockDecrementalOfferConstraint
    else
        PiecewiseLinearBlockIncrementalOfferConstraint
    end

    name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    for t in time_steps
        data = _get_pwl_data(is_decremental, container, component, t)
        break_points = PSY.get_x_coords(data)
        _add_pwl_variables!(container, T, name, t, data, W)
        _add_pwl_constraint!(
            container,
            component,
            U(),
            break_points,
            t,
            W,
            X,
        )
        pwl_cost = _get_pwl_cost_expression(
            container,
            component,
            t,
            cost_function,
            data,
            U(),
            V(),
            W(),
        )

        add_to_expression!(
            container,
            ProductionCostExpression,
            pwl_cost,
            component,
            t,
        )
        add_to_objective_variant_expression!(container, pwl_cost)
    end
end

##################################################
########## PWL for StepwiseCostReserve  ##########
##################################################

# Not touching this in PR #1303, TODO figure it out later -GKS
function _add_pwl_term!(
    container::OptimizationContainer,
    component::T,
    cost_data::PSY.CostCurve{PSY.PiecewiseIncrementalCurve},
    ::U,
    ::V,
) where {T <: PSY.Component, U <: VariableType, V <: AbstractServiceFormulation}
    multiplier = objective_function_multiplier(U(), V())
    resolution = get_resolution(container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    base_power = get_base_power(container)
    value_curve = PSY.get_value_curve(cost_data)
    power_units = PSY.get_power_units(cost_data)
    cost_component = PSY.get_function_data(value_curve)
    device_base_power = PSY.get_base_power(component)
    data = get_piecewise_incrementalcurve_per_system_unit(
        cost_component,
        power_units,
        base_power,
        device_base_power,
    )
    name = PSY.get_name(component)
    time_steps = get_time_steps(container)
    pwl_cost_expressions = Vector{JuMP.AffExpr}(undef, time_steps[end])
    sos_val = _get_sos_value(container, V, component)
    for t in time_steps
        break_points = PSY.get_x_coords(data)
        _add_pwl_variables!(
            container,
            T,
            name,
            t,
            data,
            PiecewiseLinearBlockIncrementalOffer,
        )
        _add_pwl_constraint!(container, component, U(), break_points, sos_val, t)
        pwl_cost = _get_pwl_cost_expression(container, component, t, data, multiplier * dt)
        pwl_cost_expressions[t] = pwl_cost
    end
    return pwl_cost_expressions
end

############################################################
######## MarketBidCost: PiecewiseIncrementalCurve ##########
############################################################

"""
Creates piecewise linear market bid function using a sum of variables and expression for market participants.
Decremental offers are not accepted for most components, except Storage systems and loads.

# Arguments

  - container::OptimizationContainer : the optimization_container model built in PowerSimulations
  - var_key::VariableKey: The variable name
  - component_name::String: The component_name of the variable container
  - cost_function::MarketBidCost : container for market bid cost
"""
function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.MarketBidCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    component_name = PSY.get_name(component)
    @debug "Market Bid" _group = LOG_GROUP_COST_FUNCTIONS component_name
    if !isnothing(PSY.get_decremental_offer_curves(cost_function))
        error("Component $(component_name) is not allowed to participate as a demand.")
    end
    add_pwl_term!(
        false,
        container,
        component,
        cost_function,
        T(),
        U(),
    )
    return
end

function _add_variable_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    cost_function::PSY.MarketBidCost,
    ::U,
) where {T <: VariableType,
    U <: AbstractControllablePowerLoadFormulation}
    component_name = PSY.get_name(component)
    @debug "Market Bid" _group = LOG_GROUP_COST_FUNCTIONS component_name
    if !(isnothing(PSY.get_incremental_offer_curves(cost_function)))
        error("Component $(component_name) is not allowed to participate as a supply.")
    end
    add_pwl_term!(
        true,
        container,
        component,
        cost_function,
        T(),
        U(),
    )
    return
end

function _add_service_bid_cost!(
    container::OptimizationContainer,
    component::PSY.Component,
    service::T,
) where {T <: PSY.Reserve{<:PSY.ReserveDirection}}
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
    forecast_data_values = PSY.get_cost.(TimeSeries.values(forecast_data))
    # Single Price Bid
    if eltype(forecast_data_values) == Float64
        data_values = forecast_data_values
        # Single Price/Quantity Bid
    elseif eltype(forecast_data_values) == Vector{NTuple{2, Float64}}
        data_values = [v[1][1] for v in forecast_data_values]
    else
        error("$(eltype(forecast_data_values)) not supported for MarketBidCost")
    end

    reserve_variable =
        get_variable(container, ActivePowerReserveVariable(), T, PSY.get_name(service))
    component_name = PSY.get_name(component)
    for t in time_steps
        add_to_objective_invariant_expression!(
            container,
            data_values[t] * base_power * reserve_variable[component_name, t],
        )
    end
    return
end

function _add_service_bid_cost!(::OptimizationContainer, ::PSY.Component, ::PSY.Service) end

function _add_vom_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.MarketBidCost,
    ::U,
) where {T <: VariableType, U <: AbstractDeviceFormulation}
    incremental_cost_curves = PSY.get_incremental_offer_curves(op_cost)
    if is_time_variant(incremental_cost_curves)
        # TODO this might imply a change to the MBC struct?
        @warn "Incremental curves are time variant, there is no VOM cost source. Skipping VOM cost."
        return
    end
    _add_vom_cost_to_objective_helper!(
        container,
        T(),
        component,
        op_cost,
        incremental_cost_curves,
        U(),
    )
    return
end

function _add_vom_cost_to_objective!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    op_cost::PSY.MarketBidCost,
    ::U,
) where {T <: VariableType,
    U <: AbstractControllablePowerLoadFormulation}
    decremental_cost_curves = PSY.get_decremental_offer_curves(op_cost)
    _add_vom_cost_to_objective_helper!(
        container,
        T(),
        component,
        op_cost,
        decremental_cost_curves,
        U(),
    )
    return
end

function _add_vom_cost_to_objective_helper!(
    container::OptimizationContainer,
    ::T,
    component::PSY.Component,
    ::PSY.MarketBidCost,
    cost_data::PSY.CostCurve{PSY.PiecewiseIncrementalCurve},
    ::U,
) where {T <: VariableType,
    U <: AbstractDeviceFormulation}
    power_units = PSY.get_power_units(cost_data)
    vom_cost = PSY.get_vom_cost(cost_data)
    multiplier = 1.0 # VOM Cost is always positive
    cost_term = PSY.get_proportional_term(vom_cost)
    iszero(cost_term) && return
    base_power = get_base_power(container)
    device_base_power = PSY.get_base_power(component)
    cost_term_normalized = get_proportional_cost_per_system_unit(cost_term,
        power_units,
        base_power,
        device_base_power)
    for t in get_time_steps(container)
        exp = _add_proportional_term!(container, T(), d, cost_term_normalized * multiplier,
            t)
        add_to_expression!(container, ProductionCostExpression, exp, d, t)
    end
    return
end
