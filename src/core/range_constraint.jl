function device_range(ps_m::canonical_model, range_data::Array{Tuple{String,NamedTuple{(:min, :max),Tuple{Float64,Float64}}},1}, time_range::UnitRange{Int64}, cons_name::String, var_name::String)

    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{ConstraintRef}(undef, [r[1] for r in range_data], time_range)

    for t in time_range, r in range_data

            ps_m.constraints["$(cons_name)"][r[1], t] = @constraint(ps_m.JuMPmodel, r[2].min <= ps_m.variables["$(var_name)"][r[1], t] <= r[2].max)

    end

end

function device_semicontinuousrange(ps_m::canonical_model, range_data::Array{Tuple{String,NamedTuple{(:min, :max),Tuple{Float64,Float64}}},1}, time_range::UnitRange{Int64}, cons_name::String, var_name::String)

    #MOI has a semicontinous set, but after some tests is not clear most MILP solvers support it. In the future this can be updated
    ps_m.constraints["$(cons_name)"] = JuMP.Containers.DenseAxisArray{ConstraintRef}(undef, [r[1] for r in range_data], time_range)

    for t in time_range, r in range_data

            ps_m.constraints["$(cons_name)"][r[1], t] = @constraint(ps_m.JuMPmodel, r[2].min*r[3] <= ps_m.variables["$(var_name)"][r[1], t] <= r[2].max*r[3])

    end

end