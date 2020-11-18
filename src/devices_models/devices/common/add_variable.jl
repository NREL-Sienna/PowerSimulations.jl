struct AddVariableSpec
    variable_name::Symbol
    binary::Bool
    expression_name::Union{Nothing, Symbol}
    sign::Float64
    devices_filter_func::Union{Nothing, Function}
    initial_value_func::Union{Nothing, Function}
    lb_value_func::Union{Nothing, Function}
    ub_value_func::Union{Nothing, Function}
end

"""
Construct AddVariableSpec.

Accepts a single variable_name or a vector variable_names. One must be passed but not both.
"""
function AddVariableSpec(;
    variable_name,
    binary,
    expression_name = nothing,
    sign = 1.0,
    devices_filter_func = nothing,
    initial_value_func = nothing,
    lb_value_func = nothing,
    ub_value_func = nothing,
)
    return AddVariableSpec(
        variable_name,
        binary,
        expression_name,
        sign,
        devices_filter_func,
        initial_value_func,
        lb_value_func,
        ub_value_func,
    )
end

function AddVariableSpec(
    ::PSIContainer,
    ::Type{<:T},
    ::Type{<:U},
) where {T <: VariableType, U <: PSY.Component}
    # TODO: this error method will never be hit, right?
    error("AddVariableSpec is not implemented for $T / $U")
end

"""
Add variables to the PSIContainer for any component.
"""
function add_variables!(
    psi_container::PSIContainer,
    ::Type{T},
    devices::Union{Vector{U}, IS.FlattenIteratorWrapper{U}},
) where {T <: VariableType, U <: PSY.Component}
    add_variable!(
        psi_container,
        T(),
        devices,
    )
end

"""
Add variables to the PSIContainer for a service.
"""
function add_variables!(
    psi_container::PSIContainer,
    ::Type{T},
    service::U,
    devices::Vector{V},
) where {T <: VariableType, U <: PSY.Reserve, V <: PSY.Device}
    add_variable!(
        psi_container,
        T(),
        devices,
        service,
    )
end

@doc raw"""
Adds a variable to the optimization model and to the affine expressions contained
in the psi_container model according to the specified sign. Based on the inputs, the variable can
be specified as binary.

# Bounds

``` lb_value_function <= varstart[name, t] <= ub_value_function ```

If binary = true:

``` varstart[name, t] in {0,1} ```

# LaTeX

``  lb \ge x^{device}_t \le ub \forall t ``

``  x^{device}_t \in {0,1} \forall t iff \text{binary = true}``

# Arguments
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* devices : Vector or Iterator with the devices
* var_name::Symbol : Base Name for the variable
* binary::Bool : Select if the variable is binary
* expression_name::Symbol : Expression_name name stored in psi_container.expressions to add the variable
* sign::Float64 : sign of the addition of the variable to the expression_name. Default Value is 1.0

# Accepted Keyword Arguments
* ub_value : Provides the function over device to obtain the value for a upper_bound
* lb_value : Provides the function over device to obtain the value for a lower_bound. If the variable is meant to be positive define lb = x -> 0.0
* initial_value : Provides the function over device to obtain the warm start value

"""
function add_variable!(
    psi_container::PSIContainer,
    variable_type::VariableType,
    devices::U,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where D<:PSY.Component

    @assert !isempty(devices)
    time_steps = model_time_steps(psi_container)

    var_name = make_variable_name(typeof(variable_type), eltype(devices))
    binary = get_variable_binary(variable_type, eltype(devices))
    expression_name = get_variable_expression_name(variable_type, eltype(devices))
    sign = get_variable_sign(variable_type, eltype(devices))

    variable = add_var_container!(
        psi_container,
        var_name,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            psi_container.JuMPmodel,
            base_name = "$(var_name)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(variable_type, d, psi_container.settings)
        !isnothing(ub) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(variable_type, d, psi_container.settings)
        !isnothing(lb) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        init = get_variable_initial_value(variable_type, d, psi_container.settings)
        !isnothing(init) && JuMP.set_start_value(variable[name, t], init)

        if !(isnothing(expression_name))
            bus_number = PSY.get_number(PSY.get_bus(d))
            add_to_expression!(
                get_expression(psi_container, expression_name),
                bus_number,
                t,
                variable[name, t],
                get_variable_sign(variable_type, eltype(devices)),
            )
        end
    end

    return
end

# TODO: refactor this function when ServiceModel is updated to include service name
function add_variable!(
    psi_container::PSIContainer,
    variable_type::VariableType,
    devices::U,
    service::PSY.Reserve,
) where {U <: Union{Vector{D}, IS.FlattenIteratorWrapper{D}}} where D<:PSY.Component

    @assert !isempty(devices)
    time_steps = model_time_steps(psi_container)

    var_name = make_variable_name(PSY.get_name(service), typeof(service))
    binary = get_variable_binary(variable_type, typeof(service))
    expression_name = get_variable_expression_name(variable_type, typeof(service))
    sign = get_variable_sign(variable_type, typeof(service))

    variable = add_var_container!(
        psi_container,
        var_name,
        [PSY.get_name(d) for d in devices],
        time_steps,
    )

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(
            psi_container.JuMPmodel,
            base_name = "$(var_name)_{$(name), $(t)}",
            binary = binary
        )

        ub = get_variable_upper_bound(variable_type, d, psi_container.settings)
        !isnothing(ub) && JuMP.set_upper_bound(variable[name, t], ub)

        lb = get_variable_lower_bound(variable_type, d, psi_container.settings)
        !isnothing(lb) && !binary && JuMP.set_lower_bound(variable[name, t], lb)

        init = get_variable_initial_value(variable_type, d, psi_container.settings)
        !isnothing(init) && JuMP.set_start_value(variable[name, t], init)

        if !(isnothing(expression_name))
            bus_number = PSY.get_number(PSY.get_bus(d))
            add_to_expression!(
                get_expression(psi_container, expression_name),
                bus_number,
                t,
                variable[name, t],
                get_variable_sign(variable_type, eltype(devices)),
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
* psi_container::PSIContainer : the psi_container model built in PowerSimulations
* bounds::DeviceRangeConstraintInfo : contains names and vector of min / max
* var_type::AbstractString : type of the variable
* T: type of the device

"""
function set_variable_bounds!(
    psi_container::PSIContainer,
    bounds::Vector{DeviceRangeConstraintInfo},
    var_type::AbstractString,
    ::Type{T},
) where {T <: PSY.Component}
    var = get_variable(psi_container, var_type, T)
    for t in model_time_steps(psi_container), bound in bounds
        _var = var[get_component_name(bound), t]
        JuMP.set_upper_bound(_var, bound.limits.max)
        JuMP.set_lower_bound(_var, bound.limits.min)
    end
end


function commitment_variables!(
    psi_container::PSIContainer,
    devices::IS.FlattenIteratorWrapper{PSY.ThermalMultiStart},
)
    time_steps = model_time_steps(psi_container)
    if get_warm_start(psi_container.settings)
        initial_value = d -> (PSY.get_active_power(d) > 0 ? 1.0 : 0.0)
    else
        initial_value = nothing
    end

    add_variable!(
        psi_container,
        OnVariable(),
        devices,
    )
    varstatus = get_variable(psi_container, OnVariable, PSY.ThermalMultiStart)
    for t in time_steps, d in devices
        name = PSY.get_name(d)
        bus_number = PSY.get_number(PSY.get_bus(d))
        add_to_expression!(
            get_expression(psi_container, :nodal_balance_active),
            bus_number,
            t,
            varstatus[name, t],
            PSY.get_active_power_limits(d).min,
        )
    end

    variable_types = [
        StartVariable(),
        StopVariable(),
    ]
    for variable_type in variable_types
        add_variable!(psi_container, variable_type, devices)
    end

    return
end
