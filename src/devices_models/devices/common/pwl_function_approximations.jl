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
            vname = "$(PieceWiseLinearInterpolationVariable)_$(D)_{$(name), $(k), $(t)}"
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

    on_var = get_variable(container, OnVariable(), T)
    on_var_sq = get_variable(container, OnVariableSquared(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        constraint[name, t] = JuMP.@constraint(
            get_jump_model(container),
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

    δ = get_variable(container, PieceWiseLinearInterpolationVariable(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        constraint[name, t] = JuMP.@constraint(
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

    x_bkpts, y_bkpts =
        _get_breakpoints_for_pwl_function(0.0, 1.0, _sq, BINARY_PWL_INTERPOLATION_LENGTH)

    constraint_x = add_constraints_container!(
        container,
        ConvexCombinationApproximation(),
        T,
        PSY.get_name.(devices),
        time_steps,
        "x",
    )

    constraint_y = add_constraints_container!(
        container,
        ConvexCombinationApproximation(),
        PSY.get_name.(devices),
        time_steps,
        "y",
    )

    δ = get_variable(container, PieceWiseLinearInterpolationVariable(), T)
    on_var_sq = get_variable(container, OnVariableSquared(), T)
    on_var = get_variable(container, OnVariable(), T)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        constraint_y[name, t] = JuMP.@constraint(
            get_jump_model(container),
            sum(δ[name, k, t] * y_bkpts[k] for k in 1:BINARY_PWL_INTERPOLATION_LENGTH) == on_var_sq[name, t]
        )
        constraint_x[name, t] = JuMP.@constraint(
            get_jump_model(container),
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

    breakpoints_range = 1:(BINARY_PWL_INTERPOLATION_LENGTH - 1)
    x_bkpts, y_bkpts =
        _get_breakpoints_for_pwl_function(0.0, 1.0, _sq, BINARY_PWL_INTERPOLATION_LENGTH)
    on_var = get_variable(container, OnVariable(), T)
    on_var_sq = get_variable(container, OnVariableSquared(), T)

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
                constraint[name, k, t] = JuMP.@constraint(
                    get_jump_model(container),
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
            constraint[name, k, t] = JuMP.@constraint(
                get_jump_model(container),
                on_var_sq[name, t] >=
                y_bkpts[k] + 2 * x_bkpts[k] * (on_var[name, t] - x_bkpts[k])
            )
        end
    end

    return
end
