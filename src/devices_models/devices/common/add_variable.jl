"""
Add variables to the OptimizationContainer for any component.
"""
function add_variables!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
) where {T <: VariableType, U <: PSY.Component}
    add_variable!(optimization_container, T(), devices)
end

"""
Add variables to the OptimizationContainer for a service.
"""
function add_variables!(
    optimization_container::OptimizationContainer,
    ::Type{T},
    service::U,
    devices::Vector{V},
) where {T <: VariableType, U <: PSY.Reserve, V <: PSY.Device}
    add_variable!(optimization_container, T(), devices, service)
end

@doc raw"""
Adds a variable to the optimization model and to the affine expressions contained
in the optimization_container model according to the specified sign. Based on the inputs, the variable can
be specified as binary.

# Bounds

``` lb_value_function <= varstart[name, t] <= ub_value_function ```

If binary = true:

``` varstart[name, t] in {0,1} ```

# LaTeX

``  lb \ge x^{device}_t \le ub \forall t ``

``  x^{device}_t \in {0,1} \forall t iff \text{binary = true}``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* devices : Vector or Iterator with the devices
* var_name::Symbol : Base Name for the variable
* binary::Bool : Select if the variable is binary
* expression_name::Symbol : Expression_name name stored in optimization_container.expressions to add the variable
* sign::Float64 : sign of the addition of the variable to the expression_name. Default Value is 1.0

# Accepted Keyword Arguments
* ub_value : Provides the function over device to obtain the value for a upper_bound
* lb_value : Provides the function over device to obtain the value for a lower_bound. If the variable is meant to be positive define lb = x -> 0.0
* initial_value : Provides the function over device to obtain the warm start value

"""
function add_variable!(
    optimization_container::OptimizationContainer,
    variable_type::VariableType,
    devices::U,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = model_time_steps(optimization_container)

    var_name = make_variable_name(typeof(variable_type), D)
    binary = get_variable_binary(variable_type, D)
    expression_name =
        get_variable_expression_name(variable_type, D, optimization_container.pm)
    sign = get_variable_sign(variable_type, D)

    variable = add_var_container!(
        optimization_container,
        var_name,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(variable_type, d, optimization_container.settings)
        !(ub === nothing) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(variable_type, d, optimization_container.settings)
        !(lb === nothing) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        init = get_variable_initial_value(variable_type, d, optimization_container.settings)
        !(init === nothing) && JuMP.set_start_value(variable[name, t], init)

        if !((expression_name === nothing))
            bus_number = PSY.get_number(PSY.get_bus(d))
            ix = isa(optimization_container.pm, CopperPlatePowerModel) ? t : (bus_number, t)
            add_to_expression!(
                get_expression(optimization_container, expression_name),
                variable[name, t],
                get_variable_sign(variable_type, D),
                ix...,
            )
        end
    end

    return
end

# TODO: refactor this function when ServiceModel is updated to include service name
function add_variable!(
    optimization_container::OptimizationContainer,
    variable_type::VariableType,
    devices::U,
    service::PSY.Reserve,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = model_time_steps(optimization_container)

    var_name = make_variable_name(PSY.get_name(service), D)
    binary = get_variable_binary(variable_type, D)
    sign = get_variable_sign(variable_type, D)

    variable = add_var_container!(
        optimization_container,
        var_name,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            optimization_container.JuMPmodel,
            base_name = "$(var_name)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(
            variable_type,
            service,
            d,
            optimization_container.settings,
        )
        !(ub === nothing) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(
            variable_type,
            service,
            d,
            optimization_container.settings,
        )
        !(lb === nothing) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        init = get_variable_initial_value(variable_type, d, optimization_container.settings)
        !(init === nothing) && JuMP.set_start_value(variable[name, t], init)
    end

    return
end

@doc raw"""
Adds a bounds to a variable in the optimization model.

# Bounds

``` bounds.min <= varstart[name, t] <= bounds.max  ```


# LaTeX

``  x^{device}_t >= bound^{min;} \forall t ``

``  x^{device}_t <= bound^{max} \forall t ``

# Arguments
* optimization_container::OptimizationContainer : the optimization_container model built in PowerSimulations
* bounds::DeviceRangeConstraintInfo : contains names and vector of min / max
* var_type::AbstractString : type of the variable
* T: type of the device

"""
function set_variable_bounds!(
    optimization_container::OptimizationContainer,
    bounds::Vector{DeviceRangeConstraintInfo},
    var_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    var = get_variable(optimization_container, var_type, T)
    for t in model_time_steps(optimization_container), bound in bounds
        _var = var[get_component_name(bound), t]
        JuMP.set_upper_bound(_var, bound.limits.max)
        JuMP.set_lower_bound(_var, bound.limits.min)
    end
end

function commitment_variables!(
    optimization_container::OptimizationContainer,
    devices::IS.FlattenIteratorWrapper{T},
) where {T <: PSY.ThermalGen}
    time_steps = model_time_steps(optimization_container)
    if get_warm_start(optimization_container.settings)
        initial_value = d -> (PSY.get_active_power(d) > 0 ? 1.0 : 0.0)
    else
        initial_value = nothing
    end

    add_variable!(optimization_container, OnVariable(), devices)
    var_status = get_variable(optimization_container, OnVariable, T)
    if typeof(optimization_container.pm) == CopperPlatePowerModel
        expression_name = :system_balance_active
    else
        expression_name = :nodal_balance_active
    end
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        if typeof(optimization_container.pm) == CopperPlatePowerModel
            expression_name = :system_balance_active
            ix = t
        else
            expression_name = :nodal_balance_active
            bus_number = PSY.get_number(PSY.get_bus(d))
            ix = (bus_number, t)
        end
        add_to_expression!(
            get_expression(optimization_container, expression_name),
            var_status[name, t],
            PSY.get_active_power_limits(d).min,
            ix...
        )
    end

    variable_types = [StartVariable(), StopVariable()]
    for variable_type in variable_types
        add_variable!(optimization_container, variable_type, devices)
    end

    return
end
