function _container_spec(m::JuMP.Model, ax1, ax2)
    return JuMP.Containers.DenseAxisArray{JuMP.VariableRef}(undef, ax1, ax2)
end

function add_variable(ps_m::CanonicalModel,
                      devices::Array{T,1},
                      time_range::UnitRange{Int64},
                      var_name::String,
                      binary::Bool) where {T <: PSY.PowerSystemDevice}

    ps_m.variables["$(var_name)"] = _container_spec(ps_m.JuMPmodel, [d.name for d in devices], time_range)

   for t in time_range, d in devices

       ps_m.variables["$(var_name)"][d.name,t] = JuMP.@variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary)

   end

end

function add_variable(ps_m::CanonicalModel,
                      devices::Array{T,1},
                      time_range::UnitRange{Int64},
                      var_name::String,
                      binary::Bool,
                      expression::String) where {T <: PSY.PowerSystemDevice}

    ps_m.variables["$(var_name)"] = _container_spec(ps_m.JuMPmodel, [d.name for d in devices], time_range)

   for t in time_range, d in devices

       ps_m.variables["$(var_name)"][d.name,t] = JuMP.@variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary)

       _add_to_expression!(ps_m.expressions["$(expression)"], d.bus.number, t, ps_m.variables["$(var_name)"][d.name,t])

   end

end

function add_variable(ps_m::CanonicalModel,
                      devices::Array{T,1},
                      time_range::UnitRange{Int64},
                      var_name::String,
                      binary::Bool,
                      expression::String,
                      sign::Int64) where {T <: PSY.PowerSystemDevice}

    ps_m.variables["$(var_name)"] = _container_spec(ps_m.JuMPmodel, [d.name for d in devices], time_range)

   for t in time_range, d in devices

       ps_m.variables["$(var_name)"][d.name,t] = JuMP.@variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary)

       _add_to_expression!(ps_m.expressions["$(expression)"], d.bus.number, t, ps_m.variables["$(var_name)"][d.name,t], sign)

   end

end
