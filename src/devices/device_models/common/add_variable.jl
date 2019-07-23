function _container_spec(m::M, ax...) where M <: JuMP.AbstractModel
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, ax...)
end

function add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool) where {D <: Union{Vector{<:PSY.Device},
                                                      PSY.FlattenIteratorWrapper{<:PSY.Device}}}

    time_steps = model_time_steps(ps_m)
    _add_var_container!(ps_m, var_name, (PSY.get_name(d) for d in devices), time_steps)
    variable = var(ps_m, var_name)
    jvar_name = _remove_underscore(var_name)

    for t in time_steps, d in devices
      name = PSY.get_name(d)

      variable[name, t] = JuMP.@variable(ps_m.JuMPmodel,
                                       base_name="$(jvar_name)_{$(name),$(t)}",
                                       binary=binary)
    end

    return

end

function add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool,
                      expression::Symbol) where {D <: Union{Vector{<:PSY.Device},
                                                            PSY.FlattenIteratorWrapper{<:PSY.Device}}}

    time_steps = model_time_steps(ps_m)
    _add_var_container!(ps_m, var_name, (PSY.get_name(d) for d in devices), time_steps)
    variable = var(ps_m, var_name)
    jvar_name = _remove_underscore(var_name)
    expr = exp(ps_m, expression)

    for t in time_steps, d in devices
      name = PSY.get_name(d)

      variable[name, t] = JuMP.@variable(ps_m.JuMPmodel,
                                             base_name="{$(jvar_name)}_{$(name), $(t)}",
                                             binary=binary)

      _add_to_expression!(expr,
                          PSY.get_number(PSY.get_bus(d)),
                          t,
                          variable[name, t])
    end

    return

end

function add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool,
                      expression::Symbol,
                      sign::Float64) where {D <: Union{Vector{<:PSY.Device},
                                          PSY.FlattenIteratorWrapper{<:PSY.Device}}}

    time_steps = model_time_steps(ps_m)
    _add_var_container!(ps_m, var_name, (PSY.get_name(d) for d in devices), time_steps)
    variable = var(ps_m, var_name)
    expr = exp(ps_m, expression)
    jvar_name = _remove_underscore(var_name)

    for t in time_steps, d in devices
       name = PSY.get_name(d)

       variable[name, t] = JuMP.@variable(ps_m.JuMPmodel,
                                        base_name="{$(jvar_name)}_{$(name), $(t)}",
                                        binary=binary)

       _add_to_expression!(expr,
                           PSY.get_number(PSY.get_bus(d)),
                           t,
                           variable[name, t], sign)
    end

    return

end
