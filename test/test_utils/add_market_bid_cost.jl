# WARNING: included in HydroPowerSimulations's tests as well.
# If you make changes, run those tests too!
"""
Add a MarketBidCost object to the selected components, with specified incremental and/or decremental cost curves.
"""
function add_mbc_inner!(
    sys::PSY.System,
    active_components::ComponentSelector;
    incr_curve::Union{Nothing, PiecewiseIncrementalCurve} = nothing,
    decr_curve::Union{Nothing, PiecewiseIncrementalCurve} = nothing,
)
    @assert !isempty(get_components(active_components, sys)) "No components selected"
    if isnothing(incr_curve) && isnothing(decr_curve)
        error("At least one of incr_curve or decr_curve must be provided")
    end
    mbc = MarketBidCost(;
        no_load_cost = 0.0,
        start_up = (hot = 0.0, warm = 0.0, cold = 0.0),
        shut_down = 0.0,
    )
    if !isnothing(decr_curve)
        set_decremental_offer_curves!(mbc, CostCurve(decr_curve))
    end
    if !isnothing(incr_curve)
        set_incremental_offer_curves!(mbc, CostCurve(incr_curve))
    end
    for comp in get_components(active_components, sys)
        set_operation_cost!(comp, mbc)
    end
end

"""
Add a MarketBidCost object to the selected components, with an incremental cost curve and/or
a decremental cost curve defined by hard-coded values.
"""
function add_mbc!(
    sys::PSY.System,
    active_components::ComponentSelector;
    incremental::Bool = true,
    decremental::Bool = false,
)
    incr_slopes = 100 .* [0.3, 0.5, 0.7]
    decr_slopes = 100 .* [0.7, 0.5, 0.3]
    x_coords = [10.0, 30.0, 50.0, 100.0]
    initial_input = 20.0

    if !incremental && !decremental
        error("At least one of incremental or decremental must be true")
    end
    if incremental
        incr_curve =
            PiecewiseIncrementalCurve(initial_input, x_coords, incr_slopes)
    else
        incr_curve = nothing
    end

    if decremental
        decr_curve =
            PiecewiseIncrementalCurve(initial_input, x_coords, decr_slopes)
    else
        decr_curve = nothing
    end
    add_mbc_inner!(sys, active_components; incr_curve = incr_curve, decr_curve = decr_curve)
end

"""
Get a deterministic or DeterministicSingleTimeSeries time series from the system.
"""
function get_deterministic_ts(sys::PSY.System)
    for device in get_components(PSY.Device, sys)
        if has_time_series(device, Union{DeterministicSingleTimeSeries, Deterministic})
            for key in PSY.get_time_series_keys(device)
                ts = get_time_series(device, key)
                if ts isa DeterministicSingleTimeSeries || ts isa Deterministic
                    return ts
                end
            end
        end
    end
    @assert false "No Deterministic or DeterministicSingleTimeSeries found in system"
    return DeterministicSingleTimeSeries(nothing)
end

"""
Extend the MarketBidCost objects attached to the selected components such that they're determined by a time series.

# Arguments:

  - `initial_varies`: whether the initial input time series should have values that vary
    over time (as opposed to a time series with constant values over time)
  - `breakpoints_vary`: whether the breakpoints in the variable cost time series should vary
    over time
  - `slopes_vary`: whether the slopes of the variable cost time series should vary over time
  - `active_components`: a `ComponentSelector` specifying which components should get time
    series
  - `initial_input_names_vary`: whether the initial input time series names should vary over
    components
  - `variable_cost_names_vary`: whether the variable cost time series names should vary over
    components
"""
function extend_mbc!(
    sys::PSY.System,
    active_components::ComponentSelector;
    modify_baseline_pwl = nothing,
    initial_varies::Bool = false,
    breakpoints_vary::Bool = false,
    slopes_vary::Bool = false,
    initial_input_names_vary::Bool = false,
    variable_cost_names_vary::Bool = false,
    zero_cost_at_min::Bool = false,
    create_extra_tranches::Bool = false,
    do_override_min_x::Bool = false,
)
    @assert !isempty(get_components(active_components, sys)) "No components selected"
    # incremental_initial_input is cost at minimum generation, NOT cost at zero generation
    for comp in get_components(active_components, sys)
        op_cost = get_operation_cost(comp)
        if do_override_min_x && :active_power_limits in fieldnames(typeof(comp))
            min_power = with_units_base(sys, UnitSystem.NATURAL_UNITS) do
                get_active_power_limits(comp).min
            end
        else
            min_power = nothing
        end

        @assert op_cost isa MarketBidCost
        for (getter, setter_initial, setter_curves, incr_or_decr) in (
            (
                get_incremental_offer_curves,
                set_incremental_initial_input!,
                set_incremental_offer_curves!,
                "incremental",
            ),
            (
                get_decremental_offer_curves,
                set_decremental_initial_input!,
                set_decremental_offer_curves!,
                "decremental",
            ),
        )
            cost_curve = getter(op_cost)
            isnothing(cost_curve) && continue

            baseline = get_value_curve(cost_curve)::PiecewiseIncrementalCurve
            baseline_initial = get_initial_input(baseline)
            if zero_cost_at_min
                baseline_initial = 0.0
            end
            baseline_pwl = get_function_data(baseline)
            if do_override_min_x && isnothing(min_power)
                min_power = first(get_x_coords(baseline_pwl))
            end

            !isnothing(modify_baseline_pwl) &&
                (baseline_pwl = modify_baseline_pwl(baseline_pwl))
            # primes for easier attribution
            incr_initial = initial_varies ? (0.11, 0.05) : (0.0, 0.0)
            incr_x = breakpoints_vary ? (0.02, 0.07, 0.03) : (0.0, 0.0, 0.0)
            incr_y = slopes_vary ? (0.02, 0.07, 0.03) : (0.0, 0.0, 0.0)

            name_modifier = "_$(replace(get_name(comp), " " => "_"))_"

            initial_name =
                "initial_input $(incr_or_decr)" *
                (initial_input_names_vary ? name_modifier : "")
            my_initial_ts = make_deterministic_ts(
                sys,
                initial_name,
                baseline_initial,
                incr_initial...;
            )
            variable_name =
                "variable_cost $(incr_or_decr)" *
                (variable_cost_names_vary ? name_modifier : "")
            my_pwl_ts = make_deterministic_ts(
                sys,
                variable_name,
                baseline_pwl,
                incr_x,
                incr_y;
                create_extra_tranches = create_extra_tranches,
                override_min_x = do_override_min_x ? min_power : nothing,
            )
            initial_key = add_time_series!(sys, comp, my_initial_ts)
            curve_key = add_time_series!(sys, comp, my_pwl_ts)
            setter_initial(op_cost, initial_key)
            setter_curves(op_cost, curve_key)
        end
    end
end

"""
Make a deterministic time series from a tuple or a float value. See below function for
details about the arguments.
"""
function make_deterministic_ts(
    name::String,
    ini_val::T,
    res_incr::Number,
    interval_incr::Number,
    init_time::DateTime,
    horizon::Period,
    interval::Period,
    window_count::Int,
    resolution::Period,
) where {T <: Union{Number, Tuple}}
    horizon_count = IS.get_horizon_count(horizon, resolution)
    ts_data = OrderedDict{DateTime, Vector{T}}()
    for i in 0:(window_count - 1)
        if ini_val isa Tuple
            series = [
                ini_val .+ (res_incr * j + i * interval_incr) for
                j in 0:(horizon_count - 1)
            ]
        else
            series = ini_val .+ res_incr .* (0:(horizon_count - 1)) .+ i * interval_incr
        end
        ts_data[init_time + i * interval] = series
    end
    return Deterministic(;
        name = name,
        data = ts_data,
        resolution = resolution,
        interval = interval,
    )
end

"""
Create a deterministic time series with increments to the initial values, breakpoints, and slopes.
Here, the elements of `incrs_x` and `incrs_y` are tuples of three values, corresponding to:

`tranche_incr`: increment between tranche breakpoints.
`res_incr`: increment within the forecast horizon window.
`interval_incr`: increment in baseline, between horizon windows.

`override_min_x`: if provided, overrides the minimum x value in all piecewise curves.
`create_extra_tranches`: if true, split the first tranche of the first timestep into two;
split the last tranche of the last timestep of into three.
"""
function make_deterministic_ts(
    name::String,
    ini_val::PiecewiseStepData,
    incrs_x::NTuple{3, Float64},
    incrs_y::NTuple{3, Float64},
    init_time::DateTime,
    horizon::Period,
    interval::Period,
    count::Int,
    resolution::Period;
    override_min_x = nothing,
    override_max_x = nothing,
    create_extra_tranches = false,
)
    (tranche_incr_x, res_incr_x, interval_incr_x) = incrs_x
    (tranche_incr_y, res_incr_y, interval_incr_y) = incrs_y

    horizon_count = IS.get_horizon_count(horizon, resolution)

    # Perturb the baseline curves by the tranche increments
    xs1, ys1 = deepcopy(get_x_coords(ini_val)), deepcopy(get_y_coords(ini_val))
    xs1 .+= [i * tranche_incr_x for i in 0:(length(xs1) - 1)]
    ys1 .+= [i * tranche_incr_y for i in 0:(length(ys1) - 1)]

    ts_data = OrderedDict{DateTime, Vector{PiecewiseStepData}}()
    for i in 0:(count - 1)
        xs = [deepcopy(xs1) .+ i * interval_incr_x for _ in 1:horizon_count]
        ys = [deepcopy(ys1) .+ i * interval_incr_y for _ in 1:horizon_count]
        for j in 1:horizon_count
            xs[j] .+= (j - 1) * res_incr_x
            ys[j] .+= (j - 1) * res_incr_y
        end
        if !isnothing(override_min_x)
            for j in 1:horizon_count
                xs[j][1] = override_min_x
            end
        end
        if !isnothing(override_max_x)
            for j in 1:horizon_count
                xs[j][end] = override_max_x
            end
        end
        if i == 0 && create_extra_tranches
            xs[1] = [xs[1][1], (xs[1][1] + xs[1][2]) / 2, xs[1][2:end]...]
            ys[1] = [ys[1][1], ys[1][1], ys[1][2:end]...]
        elseif i == count - 1 && create_extra_tranches
            xs[end] = [
                xs[end][1:(end - 1)]...,
                (2 * xs[end][end - 1] + xs[end][end]) / 3,
                (xs[end][end - 1] + 2 * xs[end][end]) / 3,
                xs[end][end],
            ]
            ys[end] = [ys[end][1:(end - 1)]..., ys[end][end], ys[end][end], ys[end][end]]
        end
        ts_data[init_time + i * interval] = PiecewiseStepData.(xs, ys)
    end

    return Deterministic(;
        name = name,
        data = ts_data,
        resolution = resolution,
        interval = interval,
    )
end

"""
Create a deterministic time series as above, with the same horizon, count, and interval as an existing time series.
"""
function make_deterministic_ts(
    sys::PSY.System,
    args...;
    kwargs...,
)
    @assert all(
        PSY.get_time_series_resolutions(sys) .==
        first(PSY.get_time_series_resolutions(sys)),
    )
    return make_deterministic_ts(
        args...,
        first(PSY.get_forecast_initial_times(sys)),
        PSY.get_forecast_horizon(sys),
        PSY.get_forecast_interval(sys),
        PSY.get_forecast_window_count(sys),
        first(PSY.get_time_series_resolutions(sys));
        kwargs...,
    )
end
