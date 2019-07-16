function _container_spec(m::M, ax...) where M <: JuMP.AbstractModel
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, ax...)
end

function add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool) where {D <: Union{Vector{<:PSY.Device},
                                                      PSY.FlattenIteratorWrapper{<:PSY.Device}}}

   time_steps = model_time_steps(ps_m)
   ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (PSY.get_name(d) for d in devices), time_steps)

   for t in time_steps, d in devices
      ps_m.variables[var_name][PSY.get_name(d), t] = JuMP.@variable(ps_m.JuMPmodel,
                                                           base_name="$(var_name)_{$(PSY.get_name(d)), $(t)}",
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
   ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (PSY.get_name(d) for d in devices), time_steps)

   for t in time_steps, d in devices
      ps_m.variables[var_name][PSY.get_name(d), t] = JuMP.@variable(ps_m.JuMPmodel,
                                             base_name="{$(var_name)}_{$(PSY.get_name(d)), $(t)}",
                                             binary=binary)

      _add_to_expression!(ps_m.expressions[expression],
                          PSY.get_number(PSY.get_bus(d)),
                          t,
                          ps_m.variables[var_name][PSY.get_name(d), t])
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
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (PSY.get_name(d) for d in devices), time_steps)

   for t in time_steps, d in devices
       ps_m.variables[var_name][PSY.get_name(d), t] = JuMP.@variable(ps_m.JuMPmodel,
                                                           base_name="{$(var_name)}_{$(PSY.get_name(d)), $(t)}",
                                                           binary=binary)

       _add_to_expression!(ps_m.expressions[expression],
                           PSY.get_number(PSY.get_bus(d)),
                           t,
                           ps_m.variables[var_name][PSY.get_name(d), t], sign)
   end

   return

end
