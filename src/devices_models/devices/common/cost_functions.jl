@doc raw"""
    ps_cost(psi_container::PSIContainer,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::Float64,
                dt::Float64,
                sign::Float64) where {JV <: JuMP.AbstractVariableRef}

Returns linear cost terms for sum of variables with common factor to be used for cost expression for psi_container model.

# Equation

``` gen_cost = sum(variable)*cost_component ```

# LaTeX

`` cost = dt\times sign\sum_{i\in I} c x_i ``

Returns:

``` sign*gen_cost*dt ```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::Float64 : cost to be associated with variable
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    variable::JuMP.Containers.DenseAxisArray{JV},
    cost_component::Float64,
    dt::Float64,
    sign::Float64,
) where {JV <: JuMP.AbstractVariableRef}
    gen_cost = sum(variable) * cost_component

    return sign * gen_cost * dt

end

@doc raw"""
    ps_cost(psi_container::PSIContainer,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::PSY.VariableCost{Float64},
                dt::Float64,
                sign::Float64) where {JV <: JuMP.AbstractVariableRef}

Returns linear cost terms for sum of variables with common factor to be used for cost expression for psi_container model.
Does this by calling ```ps_cost``` that has Float64 cost component input.

Returns:

``` ps_cost(psi_container, variable, PSY.get_cost(cost_component), dt, sign) ```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{Float64} : container for cost to be associated with variable
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    variable::JuMP.Containers.DenseAxisArray{JV},
    cost_component::PSY.VariableCost{Float64},
    dt::Float64,
    sign::Float64,
) where {JV <: JuMP.AbstractVariableRef}
    return ps_cost(psi_container, variable, PSY.get_cost(cost_component), dt, sign)
end

@doc raw"""
    ps_cost(psi_container::PSIContainer,
                variable::JuMP.Containers.DenseAxisArray{JV},
                cost_component::PSY.VariableCost{NTuple{2, Float64}}
                dt::Float64,
                sign::Float64) where {JV <: JuMP.AbstractVariableRef}

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
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    variable::JuMP.Containers.DenseAxisArray{JV},
    cost_component::PSY.VariableCost{NTuple{2, Float64}},
    dt::Float64,
    sign::Float64,
) where {JV <: JuMP.AbstractVariableRef}
    if cost_component[1] >= eps()
        gen_cost =
            sum(variable .^ 2) * cost_component[1] + sum(variable) * cost_component[2]
        return sign * gen_cost * dt
    else
        return ps_cost(psi_container, variable, cost_component[2], dt, 1.0)
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
    if abs(
        cost_[1][1] / cost_[1][2] -
        ((cost_[2][1] - cost_[1][1]) / (cost_[2][2] - cost_[1][2])),
    ) > 1.0
        flag = false
    end
    l = length(cost_)
    for i in 1:(l - 2)
        if ((cost_[i + 1][1] - cost_[i][1]) / (cost_[i + 1][2] - cost_[i][2])) >
           ((cost_[i + 2][1] - cost_[i + 1][1]) / (cost_[i + 2][2] - cost_[i + 1][2]))
            flag = false
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
) where {JV <: JuMP.AbstractVariableRef}
    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
    pwlvars = JuMP.@variable(
        psi_container.JuMPmodel,
        [i = 1:length(cost_component)],
        base_name = "{$(variable)}_{sos}",
        start = 0.0,
        lower_bound = 0.0,
        upper_bound = 1.0
    )

    JuMP.@constraint(psi_container.JuMPmodel, sum(pwlvars) == 1.0)
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

    return gen_cost
end

@doc raw"""
    _pwlgencost_sos(psi_container::PSIContainer,
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
    upperbound(i) =
        (i == 1 ? cost_component[i][2] : (cost_component[i][2] - cost_component[i - 1][2]))
    pwlvars = JuMP.@variable(
        psi_container.JuMPmodel,
        [i = 1:length(cost_component)],
        base_name = "{$(variable)}_{pwl}",
        start = 0.0,
        lower_bound = 0.0,
        upper_bound = upperbound(i)
    )

    for (ix, pwlvar) in enumerate(pwlvars)
        if ix == 1
            JuMP.add_to_expression!(
                gen_cost,
                cost_component[ix][1] * (pwlvar / cost_component[ix][2]),
            )
        else
            JuMP.add_to_expression!(
                gen_cost,
                (cost_component[ix][1] - cost_component[ix - 1][1]) *
                (pwlvar / (cost_component[ix][2] - cost_component[ix - 1][2])),
            )
        end
    end

    c = JuMP.@constraint(
        psi_container.JuMPmodel,
        variable == sum([pwlvar for (ix, pwlvar) in enumerate(pwlvars)])
    )

    return gen_cost
end

@doc raw"""
    _gen_cost(cost_)

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
) where {JV <: JuMP.AbstractVariableRef}
    # If array is full of tuples with zeros return 0.0
    all(iszero.(last.(cost_component))) && return 0.0

    if !_pwlparamcheck(cost_component)
        @warn("The cost function provided for $(variable) device is not compatible with a linear PWL cost function.
        An SOS-2 formulation will be added to the model.
        This will result in additional binary variables added to the model.")
        gen_cost = _pwlgencost_sos(psi_container, variable, cost_component)
    else
        gen_cost = _pwlgencost_linear(psi_container, variable, cost_component)
    end
    return gen_cost
end

@doc raw"""
    ps_cost(psi_container::PSIContainer,
                 variable::JuMP.Containers.DenseAxisArray{JV},
                 cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
                 dt::Float64,
                 sign::Float64) where {JV<:JuMP.AbstractVariableRef}

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
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}}
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function ps_cost(
    psi_container::PSIContainer,
    variable::JuMP.Containers.DenseAxisArray{JV},
    cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
    dt::Float64,
    sign::Float64,
) where {JV <: JuMP.AbstractVariableRef}
    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
    cost_array = cost_component.cost
    for var in variable
        c = _pwl_cost(psi_container, var, cost_array)
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
                              getfield(PSY.get_op_cost(d), cost_symbol),
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
) where {D <: IS.FlattenIteratorWrapper{<:PSY.Device}}
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Minute(resolution)) / 60
    variable = get_variable(psi_container, var_name)

    for d in devices
        cost_component = getfield(PSY.get_op_cost(d), cost_symbol)
        cost_expression =
            ps_cost(psi_container, variable[PSY.get_name(d), :], cost_component, dt, sign)
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
