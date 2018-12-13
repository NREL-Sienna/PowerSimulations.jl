function activepower_range(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}, cons_name::String, var_name::String) where {T <: PowerSystems.PowerSystemDevice}

    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{ConstraintRef}(undef, [d.name for d in devices], time_range)

    for t in time_range, d in devices

            ps_m.constraints["$(cons_name)"][d.name, t] = @constraint(ps_m.JuMPmodel, d.tech.activepowerlimits.min <= ps_m.variables["$(var_name)"][d.name, t] <= d.tech.activepowerlimits.max)

    end

end


function reactivepower_range(ps_m::canonical_model, devices::Array{T,1}, time_range::UnitRange{Int64}, cons_name::String, var_name::String, nomin::Bool) where {T <: PowerSystems.PowerSystemDevice}

    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{ConstraintRef}(undef, [d.name for d in devices], time_range)

    for t in time_range, d in devices

            ps_m.constraints["$(cons_name)"][d.name, t] = @constraint(ps_m.JuMPmodel, d.tech.reactivepowerlimits.min <= ps_m.variables["$(var_name)"][d.name, t] <= d.tech.reactivepowerlimits.max)

    end

end