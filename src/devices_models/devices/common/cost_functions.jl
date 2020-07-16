@doc raw"""
    ps_cost(psi_container::PSIContainer,
                var_name::Symbol,
                index::String,
                cost_component::Float64,
                dt::Float64,
                sign::Float64)

Returns linear cost terms for sum of variables with common factor to be used for cost expression for psi_container model.

# Equation

``` gen_cost = sum(variable)*cost_component ```

# LaTeX

`` cost = dt\times sign\sum_{i\in I} c x_i ``

Returns:

``` sign*gen_cost*dt ```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* var_name::Symbol: The variable name
* index::String: The index of the variable container
* cost_component::Float64 : cost to be associated with variable
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    cost_component::Float64,
    dt::Float64,
    sign::Float64,
)
    variable = get_variable(psi_container, var_name)[index, :]
    gen_cost = sum(variable) * cost_component
    return sign * gen_cost * dt
end

@doc raw"""
    ps_cost(psi_container::PSIContainer,
                var_name::Symbol,
                index::String,
                cost_component::PSY.VariableCost{Float64},
                dt::Float64,
                sign::Float64)

Returns linear cost terms for sum of variables with common factor to be used for cost expression for psi_container model.
Does this by calling ```ps_cost``` that has Float64 cost component input.

Returns:

``` ps_cost(psi_container, variable, PSY.get_cost(cost_component), dt, sign) ```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* var_name::Symbol: The variable name
* index::String: The index of the variable container
* cost_component::PSY.VariableCost{Float64} : container for cost to be associated with variable
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    cost_component::PSY.VariableCost{Float64},
    dt::Float64,
    sign::Float64,
)
    return ps_cost(psi_container, var_name, index, PSY.get_cost(cost_component), dt, sign)
end

@doc raw"""
    ps_cost(psi_container::PSIContainer,
                var_name::Symbol,
                index::String,
                cost_component::PSY.VariableCost{NTuple{2, Float64}}
                dt::Float64,
                sign::Float64)

Returns quadratic cost terms for sum of variables with common factor to be used for cost expression for psi_container model.

# Equation

``` gen_cost = dt*sign*(sum(variable.^2)*cost_component[1] + sum(variable)*cost_component[2]) ```

# LaTeX

`` cost = dt\times sign (sum_{i\in I} c_1 v_i^2 + sum_{i\in I} c_2 v_i ) ``

for quadratic factor large enough. Otherwise

``` return ps_cost(psi_container, variable, cost_component[2], dt, 1.0) ```

Returns ```gen_cost```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* var_name::Symbol: The variable name
* index::String: The index of the variable container
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    cost_component::PSY.VariableCost{NTuple{2, Float64}},
    dt::Float64,
    sign::Float64,
)
    if cost_component[1] >= eps()
        variable = get_variable(psi_container, var_name)[index, :]
        gen_cost =
            sum(variable .^ 2) * cost_component[1] + sum(variable) * cost_component[2]
        return sign * gen_cost * dt
    else
        return ps_cost(psi_container, var_name, index, cost_component[2], dt, 1.0)
    end
end

@doc raw"""
    _pwlparamcheck(cost_)

Returns True/False depending on compatibility of the cost data with the linear implementation method

Returns ```flag```

# Arguments

* cost_::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function _pwlparamcheck(cost_)
    flag = true
    slopes = PSY.get_slopes(cost_)
    # First element of the array is the average cost at P_min
    for ix in 2:(length(slopes) - 1)
        if slopes[ix] > slopes[ix + 1]
            @debug slopes
            return flag = false
        end
    end
    return flag
end

@doc raw"""
    _pwlgencost_sos(psi_container::PSIContainer,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::PSY.VariableCost{NTuple{2, Float64}}) where {JV <: JuMP.AbstractVariableRef}

Returns piecewise cost expression using SOS Type-2 implementation for psi_container model.

# Equations

``` variable = sum(sos_var[i]*cost_component[2][i])```

``` gen_cost = sum(sos_var[i]*cost_component[1][i]) ```

# LaTeX

`` variable = (sum_{i\in I} c_{2, i} sos_i) ``

`` gen_cost = (sum_{i\in I} c_{1, i} sos_i) ``

Returns ```gen_cost```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function _pwlgencost_sos(
    psi_container::PSIContainer,
    variable::JV,
    cost_component::Vector{NTuple{2, Float64}},
    status::Union{Nothing, JuMP.AbstractVariableRef} = nothing,
) where {JV <: JuMP.AbstractVariableRef}
    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
    if isnothing(status)
        status = 1.0
        @warn("Using Piecewise Linear cost function
            but no variable/parameter ref for ON status is passed.
            Default status will be set to online (1.0)")
    end
    pwlvars = JuMP.@variable(
        psi_container.JuMPmodel,
        [i = 1:length(cost_component)],
        base_name = "{$(variable)}_{sos}",
        start = 0.0,
        lower_bound = 0.0,
        upper_bound = 1.0
    )

    JuMP.@constraint(psi_container.JuMPmodel, sum(pwlvars) == status)
    JuMP.@constraint(
        psi_container.JuMPmodel,
        pwlvars in MOI.SOS2(collect(1:length(pwlvars)))
    )
    for (ix, var) in enumerate(pwlvars)
        JuMP.add_to_expression!(gen_cost, cost_component[ix][1] * var)
    end

    JuMP.@constraint(
        psi_container.JuMPmodel,
        variable == sum([var * cost_component[ix][2] for (ix, var) in enumerate(pwlvars)])
    )

    return gen_cost, pwlvars
end

@doc raw"""
    _pwlgencost_linear(psi_container::PSIContainer,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::PSY.VariableCost{NTuple{2, Float64}}) where {JV <: JuMP.AbstractVariableRef}

Returns piecewise cost expression using linear implementation for psi_container model.

# Equations

``` 0 <= pwl_var[i] <= (cost_component[2][i] - cost_component[2][i-1])```

``` variable = sum(pwl_var[i])```

``` gen_cost = sum(pwl_var[i]*cost_component[1][i]/cost_component[2][i]) ```

# LaTeX
`` 0 <= pwl_i <= (c_{2, i} - c_{2, i-1})``

`` variable = (sum_{i\in I} pwl_i) ``

`` gen_cost = (sum_{i\in I}  pwl_i) c_{1, i}/c_{2, i} ``

Returns ```gen_cost```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function _pwlgencost_linear(
    psi_container::PSIContainer,
    variable::JV,
    cost_component::Vector{NTuple{2, Float64}},
) where {JV <: JuMP.AbstractVariableRef}
    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
    pwlvars = JuMP.@variable(
        psi_container.JuMPmodel,
        [i = 1:length(cost_component)],
        base_name = "{$(variable)}_{pwl}",
        start = 0.0,
        lower_bound = 0.0,
        upper_bound = PSY.get_breakpoint_upperbounds(cost_component)[i]
    )

    for (ix, pwlvar) in enumerate(pwlvars)
        JuMP.add_to_expression!(gen_cost, PSY.get_slopes(cost_component)[ix] * pwlvar)
    end
    c = JuMP.@constraint(
        psi_container.JuMPmodel,
        variable == sum([pwlvar for (ix, pwlvar) in enumerate(pwlvars)])
    )
    return gen_cost, pwlvars
end

@doc raw"""
    _pwl_cost(cost)

Returns JuMP expression for a piecewise linear cost function depending on the data compatibility.

Returns ```gen_cost```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function _pwl_cost(
    psi_container::PSIContainer,
    variable::JV,
    cost_component::Vector{NTuple{2, Float64}},
    on_status::Union{Nothing, JuMP.AbstractVariableRef} = nothing,
) where {JV <: JuMP.AbstractVariableRef}
    if !_pwlparamcheck(cost_component)
        @warn("The cost function provided for $(variable) device is not compatible with a linear PWL cost function.
        An SOS-2 formulation will be added to the model.
        This will result in additional binary variables added to the model.")
        gen_cost, vars = _pwlgencost_sos(psi_container, variable, cost_component, on_status)
    else
        gen_cost, vars = _pwlgencost_linear(psi_container, variable, cost_component)
    end
    return gen_cost, vars
end

@doc raw"""
    ps_cost(psi_container::PSIContainer,
                var_name::Symbol,
                index::String,
                cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
                dt::Float64,
                sign::Float64)

Creates piecewise linear cost function using a sum of variables and expression with sign and time step included.

# Expression

```JuMP.add_to_expression!(gen_cost, c)```

Returns sign*gen_cost*dt

# LaTeX

``cost = sign\times dt \sum_{v\in V} c_v``

where ``c_v`` is given by

`` c_v = \sum_{i\in Ix} \frac{y_i - y_{i-1}}{x_i - x_{i-1}} v^{p.w.}_i ``

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* var_name::Symbol: The variable name
* index::String: The index of the variable container
* cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}}
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
    dt::Float64,
    sign::Float64,
)
    cost_array = cost_component.cost
    # If array is full of tuples with zeros return 0.0
    all(iszero.(last.(cost_array))) && return JuMP.AffExpr(0.0)
    variable = get_variable(psi_container, var_name)[index, :]
    settings_ext = get_ext(get_settings(psi_container))
    if haskey(settings_ext, "variable_on")
        var_name = settings_ext["variable_on"]
        bin = get_variable(psi_container, var_name)[index, :]
    elseif haskey(settings_ext, "parameter_on")
        param_name = settings_ext["parameter_on"]
        bin = get_parameter_container(psi_container, param_name).parameter_array[index]
    else
        bin = nothing
    end
    export_pwl_vars = get_export_pwl_vars(psi_container.settings)
    if export_pwl_vars
        if !haskey(psi_container.variables, :PWL_cost_vars)
            time_steps = model_time_steps(psi_container)
            container = add_var_container!(
                psi_container,
                :PWL_cost_vars,
                [index],
                time_steps,
                1:length(cost_component);
                sparse = true,
            )
        else
            container = get_variable(psi_container, :PWL_cost_vars)
        end
    end
    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
    for (t, var) in enumerate(variable)
        if !isnothing(bin)
            if bin isa ParameterJuMP.ParameterRef
                c, pwl_vars = _pwl_cost(psi_container, var, cost_array, bin)
            else
                c, pwl_vars = _pwl_cost(psi_container, var, cost_array, bin[t])
            end
        else
            c, pwl_vars = _pwl_cost(psi_container, var, cost_array)
        end
        if export_pwl_vars
            for (ix, v) in enumerate(pwl_vars)
                container[(index, t, ix)] = v
            end
        end
        JuMP.add_to_expression!(gen_cost, c)
    end

    return sign * gen_cost * dt
end

@doc raw"""
    add_to_cost(psi_container::PSIContainer,
                     devices::D,
                     var_name::Symbol,
                     cost_symbol::Symbol,
                     sign::Float64 = 1.0) where {D<:IS.FlattenIteratorWrapper{<:PSY.Device}}

Adds cost expression for each device using appropriate call to ```ps_cost```.

# Expression

for d in devices

```    cost_expression = ps_cost(psi_container,
                              variable[PSY.get_name(d), :],
                              getfield(PSY.get_operation_cost(d), cost_symbol),
                              dt,
                              sign) ```
``` psi_container.cost_function += cost_expression ```

# LaTeX

`` COST = \sum_{d\in D} cost_d ``

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* devices::D : set of devices
* var_name::Symbol : name of variable
* cost_symbol::Symbol : symbol associated with costx
"""
function add_to_cost(
    psi_container::PSIContainer,
    devices::D,
    var_name::Symbol,
    cost_symbol::Symbol,
    sign::Float64 = 1.0,
) where {D <: IS.FlattenIteratorWrapper{<:PSY.Component}}
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    for d in devices
        cost_component = getfield(PSY.get_operation_cost(d), cost_symbol)
        cost_expression =
            ps_cost(psi_container, var_name, PSY.get_name(d), cost_component, dt, sign)
        T_ce = typeof(cost_expression)
        T_cf = typeof(psi_container.cost_function)
        if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
            psi_container.cost_function += cost_expression
        else
            JuMP.add_to_expression!(psi_container.cost_function, cost_expression)
        end
    end

    return
end
