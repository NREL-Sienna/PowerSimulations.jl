function ps_cost(ps_m::CanonicalModel,
                 variable::JuMP.Containers.DenseAxisArray{JV},
                 cost_component::Function,
                 sign::Int64) where {JV <: JuMP.AbstractVariableRef}

    store = Vector{Any}(undef,length(variable))

    for (ix, element) in enumerate(variable)
        store[ix] = cost_component(element)
    end

    gen_cost = sum(store)

    return sign*gen_cost

end


function ps_cost(ps_m::CanonicalModel,
                 variable::JuMP.Containers.DenseAxisArray{JV},
                 cost_component::Float64,
                 sign::Int64) where {JV <: JuMP.AbstractVariableRef}

    gen_cost = sum(variable)*cost_component

    return sign*gen_cost

end

function pwl_param_check(cost_::Array{Tuple{Float64, Float64}})
    flag = true;
    for i in 1:(length(cost_)-1)
        if i == 1 
            (cost_[i][1]/cost_[i][2]) <= ((cost_[i+1][1] - cost_[i][1])/(cost_[i+1][2] - cost_[i][2])) ? nothing : flag = false;
        else
            ((cost_[i][1] - cost_[i-1][1])/(cost_[i][2] - cost_[i-1][2])) <= ((cost_[i+1][1] - cost_[i][1])/(cost_[i+1][2] - cost_[i][2])) ? nothing : flag = false;
        end
    end
    return flag
end

function pwl_gen_cost(ps_m::CanonicalModel,
                    variable::JV,
                    cost_component::Array{Tuple{Float64, Float64}}) where {JV <: JuMP.AbstractVariableRef}

    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}()
    pwl_param_check(cost_component) ? @warn("Data provide is not suitable for linear implementation of PWL cost, this will result in a INVALID SOLUTION") : nothing ;
    # TODO: implement a fallback to either Linear Cost function or SOS2 based PWL Cost function
    upperbound(i) = (i == 1 ? cost_component[i+1][2] : (cost_component[i+1][2] - cost_component[i][2]));
    pwlvars = JuMP.@variable(ps_m.JuMPmodel, [i = 1:(length(cost_component)-1)], base_name = "{$(variable)}_{pwl}", start = 0.0, lower_bound = 0.0, upper_bound = upperbound(i))
 
    for (ix, pwlvar) in enumerate(pwlvars)
        if ix == 1 
            temp_gen_cost = cost_component[ix][1] * (pwlvar / cost_component[ix][2] ) ;
        else
            temp_gen_cost = (cost_component[ix][1] - cost_component[ix-1][1]) * (pwlvar/(cost_component[ix][2] - cost_component[ix-1][2]) );
        end
        gen_cost = gen_cost + temp_gen_cost
    end

    c = JuMP.@constraint(ps_m.JuMPmodel, variable == sum([pwlvar for (ix, pwlvar) in enumerate(pwlvars) if ix > 1]) )

    return gen_cost

end

function ps_cost(ps_m::CanonicalModel,
                 variable::JuMP.Containers.DenseAxisArray{JV},
                 cost_component::Array{Tuple{Float64, Float64}},
                 sign::Int64) where {JV <: JuMP.AbstractVariableRef}

    gen_cost = JuMP.GenericAffExpr{Float64, _variable_type(ps_m)}()

    for var in variable
        c = pwl_gen_cost(ps_m, var, cost_component)
        gen_cost += c
    end

    return sign*gen_cost

end

function add_to_cost(ps_m::CanonicalModel,
                     devices::Array{C,1},
                     var_name::Symbol,
                     cost_symbol::Symbol, sign::Int64 = 1) where {C <: PSY.Device}

   for d in devices
        cost_expression = ps_cost(ps_m, ps_m.variables[var_name][d.name,:], getfield(d.econ,cost_symbol), sign)
        ps_m.cost_function += cost_expression
    end

    return

end
