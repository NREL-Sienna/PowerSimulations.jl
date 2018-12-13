function add_variable(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}, var_name::String, binary::Bool) where {T <: PowerSystems.PowerSystemDevice}

    ps_m.variables["$(var_name)"] = JuMP.Containers.DenseAxisArray{VariableRef}(undef, [d.name for d in devices], time_range)

   for t in time_range, d in devices

       ps_m.variables["$(var_name)"][d.name,t] = @variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary) # Power output of generators

   end

end

function add_variable(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}, var_name::String, binary::Bool, expression::String) where {T <: PowerSystems.PowerSystemDevice}

    ps_m.variables["$(var_name)"] = JuMP.Containers.DenseAxisArray{VariableRef}(undef, [d.name for d in devices], time_range)

   for t in time_range, d in devices

       ps_m.variables["$(var_name)"][d.name,t] = @variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary) # Power output of generators

       _add_to_expression!(ps_m.expressions["$(expression)"], d.bus.number, t, ps_m.variables["$(var_name)"][d.name,t])

   end

end

function add_variable(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}, var_name::String, binary::Bool, expression::String, sign::Int64) where {T <: PowerSystems.PowerSystemDevice}

    ps_m.variables["$(var_name)"] = JuMP.Containers.DenseAxisArray{VariableRef}(undef, [d.name for d in devices], time_range)

   for t in time_range, d in devices

       ps_m.variables["$(var_name)"][d.name,t] = @variable(ps_m.JuMPmodel, base_name="$(var_name)_{$(d.name),$(t)}", start = 0.0, binary=binary) # Power output of generators

       _add_to_expression!(ps_m.expressions["$(expression)"], d.bus.number, t, ps_m.variables["$(var_name)"][d.name,t], sign)

   end

end

