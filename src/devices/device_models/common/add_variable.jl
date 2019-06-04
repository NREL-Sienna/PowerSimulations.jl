function _container_spec(m::M, ax...) where M <: JuMP.AbstractModel
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, ax...)
end

function add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool) where {D <: Union{Vector{<:PSY.Device},
                                                      PSY.FlattenedVectorsIterator{<:PSY.Device}}}

   time_steps = model_time_steps(ps_m)  
   ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (d.name for d in devices), time_steps)

   for t in time_steps, d in devices
      ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                                           base_name="$(var_name)_{$(d.name),$(t)}",
                                                           binary=binary)
   end

   return

end

function add_variable(ps_m::CanonicalModel,
                      devices::D,                     
                      var_name::Symbol,
                      binary::Bool,
                      expression::Symbol) where {D <: Union{Vector{<:PSY.Device},
                                                            PSY.FlattenedVectorsIterator{<:PSY.Device}}}

   time_steps = model_time_steps(ps_m)  
   ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (d.name for d in devices), time_steps)

   for t in time_steps, d in devices
      ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel,
                                             base_name="{$(var_name)}_{$(d.name),$(t)}",
                                             binary=binary)

      _add_to_expression!(ps_m.expressions[expression],
                          d.bus.number,
                          t,
                          ps_m.variables[var_name][d.name,t])
   end

   return

end

function add_variable(ps_m::CanonicalModel,
                      devices::D,
                      var_name::Symbol,
                      binary::Bool,
                      expression::Symbol,
                      sign::Int64) where {D <: Union{Vector{<:PSY.Device},
                                          PSY.FlattenedVectorsIterator{<:PSY.Device}}}

    time_steps = model_time_steps(ps_m)                                              
    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, (d.name for d in devices), time_steps)

   for t in time_steps, d in devices
       ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel, 
                                                           base_name="{$(var_name)}_{$(d.name),$(t)}", 
                                                           binary=binary)
                                                           
       _add_to_expression!(ps_m.expressions[expression], d.bus.number, t, ps_m.variables[var_name][d.name,t], sign)
   end

   return

end
