function _container_spec(m::M, ax...) where M <: JuMP.AbstractModel
    return JuMP.Containers.DenseAxisArray{JuMP.variable_type(m)}(undef, ax...)
end

function add_variable(ps_m::CanonicalModel,
                      devices::Array{T,1},
                      time_range::UnitRange{Int64},
                      var_name::Symbol,
                      binary::Bool) where {T <: PSY.PowerSystemDevice}

    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, [d.name for d in devices], time_range)

   for t in time_range, d in devices

       ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary)

   end

   return

end

function add_variable(ps_m::CanonicalModel,
                      devices::Array{T,1},
                      time_range::UnitRange{Int64},
                      var_name::Symbol,
                      binary::Bool,
                      expression::Symbol) where {T <: PSY.PowerSystemDevice}

    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, [d.name for d in devices], time_range)

   for t in time_range, (ix, d) in enumerate(devices)

       ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary)

       _add_to_expression!(ps_m.expressions[expression].data, ix, t, ps_m.variables[var_name][d.name,t])

   end

   return

end

function add_variable(ps_m::CanonicalModel,
                      devices::Array{T,1},
                      time_range::UnitRange{Int64},
                      var_name::Symbol,
                      binary::Bool,
                      expression::Symbol,
                      sign::Int64) where {T <: PSY.PowerSystemDevice}

    ps_m.variables[var_name] = _container_spec(ps_m.JuMPmodel, [d.name for d in devices], time_range)

   for t in time_range, (ix, d) in enumerate(devices)

       ps_m.variables[var_name][d.name,t] = JuMP.@variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary)

       _add_to_expression!(ps_m.expressions[expression].data, ix, t, ps_m.variables[var_name][d.name,t], sign)

   end

   return

end
