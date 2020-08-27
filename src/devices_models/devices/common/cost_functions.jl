function _add_to_cost_expression!(psi_container::PSIContainer, cost_expression)
    T_ce = typeof(cost_expression)
    T_cf = typeof(psi_container.cost_function)
    if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
        psi_container.cost_function += cost_expression
    else
        JuMP.add_to_expression!(psi_container.cost_function, cost_expression)
    end
    return
end


function _has_on_variable(psi_container::PSIContainer, ::Type{T}) T <: PSY.Component
    #get_variable can't be used because the default behavior is to error if variables is not present
    return !isnothing(get(psi_container.variables, make_variable_name(OnVariable, T), nothing))
end

function _linear_cost(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    linear_term::Float64,
    sign::Float64,
)
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    variable = get_variable(psi_container, var_name)[index, :]
    gen_cost = sum(variable) * linear_term
    return sign * gen_cost * dt
end

"""
Adds to the models costs represented by PowerSystems TwoPart costs
"""
function add_to_cost!(psi_container::PSIContainer,
                      cost_data::PSY.TwoPartCost,
                      component_name::String,
                      ::Type{T};
                      multiplier::Float64 = 1.0) where T <: PSY.Component
    variable_cost = PSY.get_variable(cost_data)
    var_name = make_variable_name(ActivePowerVariable, T)
    variable_cost!(psi_container, var_name, component_name, variable_cost, multiplier)

    if _has_on_variable(psi_container, T)
        on_var = get_variable(psi_container, OnVariable, T)
        fixed_cost = _linear_cost(psi_container, var_name, component_name, PSY.get_fixed(cost_data), multiplier)
        _add_to_cost_expression!(psi_container, fixed_cost)
    end
    return
end

"""
Adds to the models costs represented by PowerSystems ThreePart costs
"""
function add_to_cost!(psi_container::PSIContainer,
                      cost_data::PSY.ThreePartCost,
                      component_name::String,
                      ::Type{T};
                      multiplier::Float64 = 1.0) where T <: PSY.Component
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    variable_cost = PSY.get_variable(cost_data)
    var_name = make_variable_name(ActivePowerVariable, T)
    variable_cost!(psi_container, var_name, component_name, variable_cost, multiplier)

    start_cost = _linear_cost(psi_container, make_variable_name(StartVariable, T), component_name, PSY.get_start_up(cost_data), multiplier)
    _add_to_cost_expression!(psi_container, start_cost)

    stop_cost = _linear_cost(psi_container, make_variable_name(StopVariable, T), component_name, PSY.get_shut_down(cost_data), multiplier)
    _add_to_cost_expression!(psi_container, stop_cost)

    fixed_cost = _linear_cost(psi_container, make_variable_name(OnVariable, T), component_name, PSY.get_fixed(cost_data), multiplier)
    _add_to_cost_expression!(psi_container, fixed_cost)
    return
end

"""
Adds to the models costs represented by PowerSystems Multi-Start costs
"""
function add_to_cost!(psi_container::PSIContainer,
                      cost_data::PSY.MultiStartCost,
                      component_name::String,
                      ::Type{T}) where T <: PSY.Component
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    total_fixed_cost = PSY.get_fixed(cost_data) + PSY.get_no_load(cost_data)
    fixed_cost = _linear_cost(psi_container, make_variable_name(OnVariable, T), component_name, total_fixed_cost, multiplier)
    _add_to_cost_expression!(psi_container, fixed_cost)

    #TODO: Clean up code here
    function _ps_cost!(
        d::PSY.ThermalMultiStart,
        cost_component::PSY.VariableCost,
        var_name::Symbol,
        bin_var::Symbol,
        dt::Float64,
        sign::Float64 = 1.0,
    )
        gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
        index = PSY.get_name(d)
        cost_array = cost_component.cost
        all(iszero.(last.(cost_array))) && return JuMP.AffExpr(0.0)
        variable = get_variable(psi_container, var_name)[index, :]
        bin = get_variable(psi_container, bin_var)[index, :]
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
        for (t, var) in enumerate(variable)
            c, pwl_vars = _pwlgencost_sos!(psi_container, var, cost_array, bin[t])
            for (ix, v) in enumerate(pwl_vars)
                container[(index, t, ix)] = v
            end
            JuMP.add_to_expression!(gen_cost, c)
        end

        return sign * gen_cost * dt
    end

    for d in devices
        cost_component = PSY.get_variable(PSY.get_operation_cost(d))
        cost_expression = _ps_cost!(
            d,
            cost_component,
            make_variable_name(ActivePowerVariable, PSY.ThermalMultiStart),
            make_variable_name(OnVariable, PSY.ThermalMultiStart),
            dt,
        )
        T_ce = typeof(cost_expression)
        T_cf = typeof(psi_container.cost_function)
        if T_cf <: JuMP.GenericAffExpr && T_ce <: JuMP.GenericQuadExpr
            psi_container.cost_function += cost_expression
        else
            JuMP.add_to_expression!(psi_container.cost_function, cost_expression)
        end
    end

    ## Start up cost
    function _ps_cost!(d::PSY.ThermalMultiStart, cost_component::StartUpStages)
        gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(psi_container)}()
        startup_var = (HotStartVariable, WarmStartVariable, ColdStartVariable)
        for st in 1:PSY.get_start_types(d)
            JuMP.add_to_expression!(
                gen_cost,
                ps_cost!(
                    psi_container,
                    make_variable_name(startup_var[st], PSY.ThermalMultiStart),
                    PSY.get_name(d),
                    cost_component[st],
                    dt,
                    1.0,
                ),
            )
        end
        return gen_cost

    end

    for d in devices
        cost_component = PSY.get_startup(PSY.get_operation_cost(d))
        cost_expression = _ps_cost!(d, cost_component)
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

"""
Adds to the models costs represented by PowerSystems Market-Bid costs
"""
function add_to_cost!(psi_container::PSIContainer,
                      cost_data::PSY.MarketBidCost,
                      component_name::String,
                      ::Type{T}) where T <: PSY.Component
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    variable_cost = PSY.get_variable(cost_data)
    var_name = make_variable_name(ActivePowerVariable, T)
    variable_cost!(psi_container, var_name, component_name, variable_cost, sign)


    return
end


@doc raw"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for psi_container model.

    # Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* var_name::Symbol: The variable name
* index::String: The index of the variable container
* cost_component::PSY.VariableCost{Float64} : container for cost to be associated with variable
* sign::Float64 : positive or negative sign to be associated cost term
"""
function variable_cost!(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    cost_component::PSY.VariableCost{Float64},
    sign::Float64,
)
    cost = _linear_cost(psi_container, var_name, index, PSY.get_cost(cost_component), sign)
     _add_to_cost_expression!(psi_container, cost)
    return
end

@doc raw"""
Adds to the cost function cost terms for sum of variables with common factor to be used for cost expression for psi_container model.

# Equation

``` gen_cost = dt*sign*(sum(variable.^2)*cost_component[1] + sum(variable)*cost_component[2]) ```

# LaTeX

`` cost = dt\times sign (sum_{i\in I} c_1 v_i^2 + sum_{i\in I} c_2 v_i ) ``

for quadratic factor large enough. If the first term of the quadratic objective is 0.0, adds a
linear cost term `sum(variable)*cost_component[2]`

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* var_name::Symbol: The variable name
* index::String: The index of the variable container
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
* sign::Float64 : positive or negative sign to be associated cost term
"""
function variable_cost!(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    cost_component::PSY.VariableCost{NTuple{2, Float64}},
    sign::Float64,
)
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    if cost_component[1] >= eps()
        variable = get_variable(psi_container, var_name)[index, :]
        gen_cost =
            sum(variable .^ 2) * cost_component[1] + sum(variable) * cost_component[2]
        _add_to_cost_expression!(psi_container, sign * gen_cost * dt)
    else
        gen_cost = _linear_cost(psi_container, var_name, index, cost_component[2], 1.0)
        _add_to_cost_expression!(psi_container, gen_cost)
    end
    return
end

@doc raw"""
Returns True/False depending on compatibility of the cost data with the linear implementation method

Returns ```flag```

# Arguments

* cost_ : container for quadratic and linear factors
"""
function _pwlparamcheck(cost_)
    slopes = PSY.get_slopes(cost_)
    return _pwlparamcheck(slopes)
end

@doc raw"""
Returns True/False depending on compatibility of the cost data with the linear implementation method

Returns ```flag```

# Arguments

* slopes::Array{Float64, 1} : slopes of pwl cost function calculated by `PSY.get_slopes()`
"""
function _pwlparamcheck(slopes::Array{Float64, 1})
    flag = true
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
function _pwlgencost_sos!(
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
function _pwlgencost_linear!(
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
Returns JuMP expression for a piecewise linear cost function depending on the data compatibility.

Returns ```gen_cost```

# Arguments

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* variable::JuMP.Containers.DenseAxisArray{JV} : variable array
* cost_component::PSY.VariableCost{NTuple{2, Float64}} : container for quadratic and linear factors
"""
function _pwl_cost!(
    psi_container::PSIContainer,
    variable::JV,
    cost_component::Vector{NTuple{2, Float64}},
    on_status::Union{Nothing, JuMP.AbstractVariableRef} = nothing,
) where {JV <: JuMP.AbstractVariableRef}
    if !_pwlparamcheck(cost_component)
        @warn("The cost function provided for $(variable) device is not compatible with a linear PWL cost function.
        An SOS-2 formulation will be added to the model.
        This will result in additional binary variables added to the model.")
        gen_cost, vars =
            _pwlgencost_sos!(psi_container, variable, cost_component, on_status)
    else
        gen_cost, vars = _pwlgencost_linear!(psi_container, variable, cost_component)
    end
    return gen_cost, vars
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

* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* var_name::Symbol: The variable name
* index::String: The index of the variable container
* cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}}
* dt::Float64 : fraction of hour
* sign::Float64 : positive or negative sign to be associated cost term
"""
function variable_cost!(
    psi_container::PSIContainer,
    var_name::Symbol,
    index::String,
    cost_component::PSY.VariableCost{Vector{NTuple{2, Float64}}},
    sign::Float64,
)
    resolution = model_resolution(psi_container)
    dt = Dates.value(Dates.Second(resolution)) / SECONDS_IN_HOUR
    cost_array = cost_component.cost
    # If array is full of tuples with zeros return 0.0
    all(iszero.(last.(cost_array))) && return JuMP.AffExpr(0.0)

    variable = get_variable(psi_container, var_name)[index, :]
    settings_ext = get_ext(get_settings(psi_container))

    #TODO: Put this somewhere
    # if !isnothing(feedforward)
    #    #Setting kwarg for PWL
    #    add_to_setting_ext!(
    #        psi_container,
    #        "parameter_on",
    #        make_variable_name(OnVariable, T),
    #    )
    # end

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
                c, pwl_vars = _pwl_cost!(psi_container, var, cost_array, bin)
            else
                c, pwl_vars = _pwl_cost!(psi_container, var, cost_array, bin[t])
            end
        else
            c, pwl_vars = _pwl_cost!(psi_container, var, cost_array)
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
