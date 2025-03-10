# Functions commmonly used in PWL Approximations
_sq(x) = x^2

get_variable_binary(
    ::PieceWiseLinearInterpolationVariable,
    ::Type{<:PSY.Device},
    ::AbstractDeviceFormulation,
) = false

function _get_breakpoints_for_pwl_function(
    min_val::Float64,
    max_val::Float64,
    f,
    num_segments::Int = DEFAULT_INTERPOLATION_LENGTH,
)
    # num_segments is the number of variables
    # num_bkpts is the total breakpoints for the segments
    num_bkpts = num_segments + 1
    step = (max_val - min_val) / num_segments
    x_bkpts = Vector{Float64}(undef, num_bkpts)
    y_bkpts = Vector{Float64}(undef, num_bkpts)
    # first breakpoint is always the minimum value
    x_bkpts[1] = min_val
    y_bkpts[1] = f(min_val)
    for i in 1:num_segments
        x_val = min_val + step * i
        x_bkpts[i + 1] = x_val
        y_bkpts[i + 1] = f(x_val)
    end
    return x_bkpts, y_bkpts
end

function add_variable!(
    container::OptimizationContainer,
    variable_type::PieceWiseLinearInterpolationVariable,
    devices::U,
    formulation,
) where {
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    binary = get_variable_binary(variable_type, D, formulation)

    breakpoints_range = 1:BINARY_PWL_INTERPOLATION_LENGTH
    variable = add_variable_container!(
        container,
        PieceWiseLinearInterpolationVariable(),
        D,
        PSY.get_name.(devices),
        breakpoints_range,
        time_steps,
    )

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps, k in breakpoints_range
            vname = "$(PieceWiseLinearInterpolationVariable)_{$(name), $(k), $(t)}"
            variable[name, k, t] = JuMP.@variable(
                get_jump_model(container),
                base_name = vname,
                binary = binary,
                lower_bound = 0.0,
                upper_bound = 1.0
            )
        end
    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{OnVariableBounds},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    constraint = add_constraints_container!(
        container,
        OnVariableBounds(),
        T,
        PSY.get_name.(devices),
        time_steps,
    )

    @show OnVariableBounds

    on_var    = get_variable(container, OnVariable(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        cname = "$(OnVariableBounds)_{$(name), $(t)}"
        constraint[name, t] = JuMP.@constraint(
            get_jump_model(container),
            base_name = cname, 
            0.0 <= on_var[name, t] <= 1.0
        )

    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{StartVariableBounds},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    constraint = add_constraints_container!(
        container,
        StartVariableBounds(),
        T,
        PSY.get_name.(devices),
        time_steps,
    )

    @show StartVariableBounds

    start_var    = get_variable(container, StartVariable(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        cname = "$(StartVariableBounds)_{$(name), $(t)}"
        constraint[name, t] = JuMP.@constraint(
            get_jump_model(container),
            base_name = cname, 
            0.0 <= start_var[name, t] <= 1.0
        )

    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{StopVariableBounds},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    constraint = add_constraints_container!(
        container,
        StopVariableBounds(),
        T,
        PSY.get_name.(devices),
        time_steps,
    )

    @show StopVariableBounds

    stop_var    = get_variable(container, StopVariable(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        cname = "$(StopVariableBounds)_{$(name), $(t)}"
        constraint[name, t] = JuMP.@constraint(
            get_jump_model(container),
            base_name = cname, 
            0.0 <= stop_var[name, t] <= 1.0
        )

    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ContinousIntegerApproximation},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    constraint = add_constraints_container!(
        container,
        ContinousIntegerApproximation(),
        T,
        PSY.get_name.(devices),
        time_steps,
    )

    @show ContinousIntegerApproximation

    on_var    = get_variable(container, OnVariable(), T)
    on_var_sq = get_variable(container, OnVariableSquared(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        cname = "$(ContinousIntegerApproximation)_{$(name), $(t)}"
        constraint[name, t] = JuMP.@constraint(
            get_jump_model(container),
            base_name = cname, 
            on_var_sq[name, t] - on_var[name, t] == 0.0
        )

    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ConvexCombinationUnitary},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    constraint = add_constraints_container!(
        container,
        ConvexCombinationUnitary(),
        T,
        PSY.get_name.(devices),
        time_steps,
    )

    @show ConvexCombinationUnitary

    δ = get_variable(container, PieceWiseLinearInterpolationVariable(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        cname = "$(ConvexCombinationUnitary)_{$(name), $(t)}"
        constraint[name, t] = JuMP.@constraint(
            base_name = cname,
            get_jump_model(container),
            sum(δ[name, k, t] for k in 1:BINARY_PWL_INTERPOLATION_LENGTH) == 1.0
        )
    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{ConvexCombinationApproximation},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    @show ConvexCombinationApproximation

    x_bkpts, y_bkpts =
        _get_breakpoints_for_pwl_function(0.0, 1.0, _sq, BINARY_PWL_INTERPOLATION_LENGTH)

    constraint_x = add_constraints_container!(
        container,
        ConvexCombinationApproximation(),
        T,
        PSY.get_name.(devices),
        time_steps;
        meta = "x",
    )

    constraint_y = add_constraints_container!(
        container,
        ConvexCombinationApproximation(),
        T,
        PSY.get_name.(devices),
        time_steps;
        meta = "y",
    )

    δ = get_variable(container, PieceWiseLinearInterpolationVariable(), T)
    on_var_sq = get_variable(container, OnVariableSquared(), T)
    on_var = get_variable(container, OnVariable(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        cname_y = "$(ConvexCombinationApproximation)_y_{$(name), $(t)}"
        cname_x = "$(ConvexCombinationApproximation)_x_{$(name), $(t)}"
        constraint_y[name, t] = JuMP.@constraint(
            get_jump_model(container),
            base_name = cname_y,
            sum(δ[name, k, t] * y_bkpts[k] for k in 1:BINARY_PWL_INTERPOLATION_LENGTH) == on_var_sq[name, t]
        )
        constraint_x[name, t] = JuMP.@constraint(
            get_jump_model(container),
            base_name = cname_x,
            sum(δ[name, k, t] * x_bkpts[k] for k in 1:BINARY_PWL_INTERPOLATION_LENGTH) == on_var[name, t]
        )
    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{PieceWiseLinearApproximationSecant},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    breakpoints_range = 1:BINARY_PWL_INTERPOLATION_LENGTH
    x_bkpts, y_bkpts =
        _get_breakpoints_for_pwl_function(0.0, 1.0, _sq, BINARY_PWL_INTERPOLATION_LENGTH)
    on_var = get_variable(container, OnVariable(), T)
    on_var_sq = get_variable(container, OnVariableSquared(), T)

    @show PieceWiseLinearApproximationSecant

    constraint = add_constraints_container!(
        container,
        PieceWiseLinearApproximationSecant(),
        T,
        PSY.get_name.(devices),
        breakpoints_range,
        time_steps,
    )

    for d in devices
        name = PSY.get_name(d)
        for k in breakpoints_range
            slope = (y_bkpts[k + 1] - y_bkpts[k]) / (x_bkpts[k + 1] - x_bkpts[k])
            for t in time_steps
                cname = "$(PieceWiseLinearApproximationSecant)_{$(name), $(k), $(t)}"
                constraint[name, k, t] = JuMP.@constraint(
                    get_jump_model(container),
                    base_name = cname,
                    on_var_sq[name, t] <=
                    y_bkpts[k] + slope * (on_var[name, t] - x_bkpts[k])
                )
            end
        end
    end

    return
end

function add_constraints!(
    container::OptimizationContainer,
    ::Type{PieceWiseLinearApproximationTangent},
    devices::IS.FlattenIteratorWrapper{T},
    model::DeviceModel,
) where {T <: PSY.Device}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)

    breakpoints_range = 1:BINARY_PWL_INTERPOLATION_LENGTH
    x_bkpts, y_bkpts =
        _get_breakpoints_for_pwl_function(0.0, 1.0, _sq, BINARY_PWL_INTERPOLATION_LENGTH)
    on_var = get_variable(container, OnVariable(), T)
    on_var_sq = get_variable(container, OnVariableSquared(), T)

    @show PieceWiseLinearApproximationTangent
    
    constraint = add_constraints_container!(
        container,
        PieceWiseLinearApproximationTangent(),
        T,
        PSY.get_name.(devices),
        breakpoints_range,
        time_steps,
    )

    for d in devices
        name = PSY.get_name(d)
        for t in time_steps, k in breakpoints_range
            cname = "$(PieceWiseLinearApproximationTangent)_{$(name), $(k), $(t)}"
            constraint[name, k, t] = JuMP.@constraint(
                get_jump_model(container),
                base_name = cname,
                on_var_sq[name, t] >=
                y_bkpts[k] + 2 * x_bkpts[k] * (on_var[name, t] - x_bkpts[k])
            )
        end
    end

    return
end
