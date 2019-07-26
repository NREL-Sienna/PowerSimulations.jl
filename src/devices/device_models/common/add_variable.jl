""" Returns the correct container spec for the selected type of JuMP Model"""
function _container_spec(m::M, ax...) where M <: JuMP.AbstractModel
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, ax...)
end

@doc raw"""
    add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool,
                      expression::Symbol,
                      sign::Float64)

Adds a positive variable to the optimization model and to the affine expressions contained
in the canonical model according to the specified sign. Based on the inputs, the variable can
be specified as binary.

# Bounds

``` 0 <= varstart[name, t]  ```

If binary = true:

``` varstart[name, t] in {0,1} ```

# LaTeX

``  x^{device}_t >= 0.0 \forall t ``

``  x^{device}_t \in {0,1} \forall t iff \text{binary = true}``

# Arguments
* ps_m::CanonicalModel : the canonical model built in PowerSimulations
* devices : Vector or Iterator with the devices
* var_name::Symbol : Base Name for the variable
* binary::Bool : Select if the variable is binary
* expression::Symbol : Expression name stored in canonical_model.expressions to add the variable
* sign::Float64 : sign of the addition of the variable to the expression. Default Value is 1.0

# Accepted Keyword Arguments
* ub_value_function : Provides the function over device to obtain the value for a upper_bound
* lb_value_function : Provides the function over device to obtain the value for a lower_bound other than 0
* initial_value_function : Provides the function over device to obtain the warm start value

"""
function add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool,
                      expression::Union{Nothing,Symbol}=nothing,
                      sign::Float64=1.0; kwargs...) where {D <: Union{Vector{<:PSY.Device},
                                          PSY.FlattenIteratorWrapper{<:PSY.Device}}}

    time_steps = model_time_steps(ps_m)
    _add_var_container!(ps_m, var_name, (PSY.get_name(d) for d in devices), time_steps)
    variable = var(ps_m, var_name)
    jvar_name = _remove_underscore(var_name)

    lb_f = get(kwargs, :lb_value, nothing)
    init_f= get(kwargs, :initial_value, nothing)
    ub_f = get(kwargs, :ub_value, nothing)

    for t in time_steps, d in devices
        name = PSY.get_name(d)
        variable[name, t] = JuMP.@variable(ps_m.JuMPmodel,
                                        base_name="$(jvar_name)_{$(name), $(t)}",
                                        binary=binary,
                                        #lower_bound = 0.0
                                        )

        !isnothing(ub_f) && JuMP.set_upper_bound(variable[name, t], ub_f(d))
        !isnothing(lb_f) && !binary && JuMP.set_lower_bound(variable[name, t], lb_f(d))
        isnothing(lb_f) && !binary && JuMP.set_lower_bound(variable[name, t], 0.0)
        !isnothing(init_f) && JuMP.set_start_value(variable[name, t], init_f(d))

        if !(isnothing(expression))
        bus_number = PSY.get_number(PSY.get_bus(d))
        _add_to_expression!(exp(ps_m, expression),
                            bus_number,
                            t,
                            variable[name, t],
                            sign)
        end
    end

    return

end
