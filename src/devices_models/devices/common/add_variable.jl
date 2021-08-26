"""
Add variables to the OptimizationContainer for any component.
"""
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
    formulation::Union{AbstractServiceFormulation, AbstractDeviceFormulation},
) where {T <: VariableType, U <: PSY.Component}
    add_variable!(container, T(), devices, formulation)
end

"""
Add variables to the OptimizationContainer for a service.
"""
function add_variables!(
    container::OptimizationContainer,
    ::Type{T},
    service::U,
    contributing_devices::Vector{V},
    formulation::AbstractReservesFormulation,
) where {T <: VariableType, U <: PSY.Reserve, V <: PSY.Device}
    add_service_variable!(container, T(), service, contributing_devices, formulation)
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
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* devices : Vector or Iterator with the devices
* var_key::VariableKey : Base Name for the variable
* binary::Bool : Select if the variable is binary
* expression_name::Symbol : Expression_name name stored in container.expressions to add the variable
* sign::Float64 : sign of the addition of the variable to the expression_name. Default Value is 1.0

# Accepted Keyword Arguments
* ub_value : Provides the function over device to obtain the value for a upper_bound
* lb_value : Provides the function over device to obtain the value for a lower_bound. If the variable is meant to be positive define lb = x -> 0.0
* initial_value : Provides the function over device to obtain the warm start value

"""
function add_variable!(
    container::OptimizationContainer,
    variable_type::T,
    devices::U,
    formulation,
) where {
    T <: VariableType,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    @assert !isempty(devices)
    time_steps = get_time_steps(container)
    settings = get_settings(container)
    binary = get_variable_binary(variable_type, D, formulation)

    variable = add_var_container!(
        container,
        variable_type,
        D,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            container.JuMPmodel,
            base_name = "$(variable_type)_$(D)_$(T)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(variable_type, d, formulation)
        !(ub === nothing) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(variable_type, d, formulation)
        !(lb === nothing) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        if get_warm_start(settings)
            init = get_variable_initial_value(variable_type, d, formulation)
            !(init === nothing) && JuMP.set_start_value(variable[name, t], init)
        end
    end

    return
end

function add_service_variable!(
    container::OptimizationContainer,
    variable_type::VariableType,
    service::T,
    contributing_devices::U,
    formulation::AbstractReservesFormulation,
) where {
    T <: PSY.Service,
    U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}},
} where {D <: PSY.Component}
    @assert !isempty(contributing_devices)
    time_steps = get_time_steps(container)

    binary = get_variable_binary(variable_type, T, formulation)
    expression_name = get_variable_expression_name(variable_type, T)

    variable = add_var_container!(
        container,
        variable_type,
        T,
        PSY.get_name(service),
        [PSY.get_name(d) for d in contributing_devices],
        time_steps,
    )

    for t in time_steps, d in contributing_devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            container.JuMPmodel,
            base_name = "$(variable_type)_$(D)_$(T)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(variable_type, service, d, container.settings)
        !(ub === nothing) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(variable_type, service, d, container.settings)
        !(lb === nothing) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        init = get_variable_initial_value(variable_type, d, container.settings)
        !(init === nothing) && JuMP.set_start_value(variable[name, t], init)

        if !((expression_name === nothing))
            bus_number = PSY.get_number(PSY.get_bus(d))
            add_to_expression!(
                get_expression(container, expression_name),
                bus_number,
                t,
                variable[name, t],
                get_variable_sign(variable_type, eltype(devices), formulation),
            )
        end
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
* container::OptimizationContainer : the optimization_container model built in PowerSimulations
* bounds::DeviceRangeConstraintInfo : contains names and vector of min / max
* var_type::AbstractString : type of the variable
* T: type of the device

"""
function set_variable_bounds!(
    container::OptimizationContainer,
    bounds::Vector{DeviceRangeConstraintInfo},
    var_type::VariableType,
    ::Type{T},
) where {T <: PSY.Component}
    var = get_variable(container, var_type, T)
    for t in get_time_steps(container), bound in bounds
        _var = var[get_component_name(bound), t]
        JuMP.set_upper_bound(_var, bound.limits.max)
        JuMP.set_lower_bound(_var, bound.limits.min)
    end
end
