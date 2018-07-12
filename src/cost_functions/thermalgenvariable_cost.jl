function variablecostgen(m::JuMP.Model, pth::JuMP.JuMPArray{JuMP.Variable}, devices::Array{T}) where T <: PowerSystems.ThermalGen

    cost = JuMP.AffExpr()

    for  (ix, name) in enumerate(pth.indexsets[1])
        if name == devices[ix].name
            c = gencost(m, pth[name,:], devices[ix].variablecost)
        else
            error("Bus name in Array and variable do not match")
        end
            (isa(cost,JuMP.AffExpr) && isa(c,JuMP.AffExpr)) ? append!(cost,c) : (isa(cost,JuMP.GenericQuadExpr) && isa(c,JuMP.GenericQuadExpr) ? append!(cost,c) : cost += c)
    end

    return

end

#=
function gencost(m::JuMP.Model, X::JuMP.JuMPArray{JuMP.Variable}, cost_component::Float64)

    cost = sum(X*cost_component)

    return cost
end
=#

function gencost(m::JuMP.Model, X::JuMP.JuMPArray{JuMP.Variable}, cost_component::Function)

    # TODO: Make type stable later, now it can return AffExpr or GenericQuadExpr
    total = [cost_component(e) for e in X]

    cost = @expression(m, sum(total))

    return cost

end

function pwl_gencost(m::JuMP.Model, variable::JuMP.Variable, cost_component::Array{Tuple})

    pwlvars = @variable(m, [i = 1:(length(cost_component)-1)], lowerbound = 0.0, upperbound = (cost_component[i+1][1] - cost_component[i][1]))
    @constraint(m, sum(pwlvars) == var)

    cost = JuMP.GenericAffExpr(pwlvars, [c[2]/c[1] for c in cost_component[2:end]], 0.0)

end

function gencost(m::JuMP.Model, X::JuMP.JuMPArray{JuMP.Variable}, cost_component::Function)

    for var in X
        pwl_gencost(m, var, cost_component::Function)
    end

end

function cost_filter(pth::JuMP.JuMPArray{JuMP.Variable},generators::Array{T}) where T <: PowerSystems.ThermalGen
    linear = []
    pwl = []
    func= []
    for (ix, name) in enumerate(pth.indexsets[1])
        if name == generators[ix].name
            var_c = generators[ix].econ.variablecost
            isa(var_c, Real) ? push!(linear,name) : isa(var_c, Function) ? push!(func,name) : isa(var_c, Array) ? push!(pwl,name) : warn("Cost type unknown")
        end
    end
    return linear, pwl, func
end

function gencost(m::JuMP.Model, pth::JuMP.Variable, cost_component::Array)
    cost_p =  [i for (ix,i) in enumerate(cost_component) if iseven(ix)]
    power_p = [i for (ix,i) in enumerate(cost_component) if isodd(ix)]
    time = 1:Int(length(pth))
    n = 1:Int((length(cost_component)/2)-1)

    @constraintref pwl_gen[1:length(time)]
    @constraintref pwl_limit[1:length(time),n]
    for t in time
        for i in n
            pwl_limit[t,n] = @constraint(m, pwl[t,i] <= power_p[i+1]-power_p[i] )
        end
    end
    for t in time
        pwl_gen[t] = @constraint(m, sum([pwl[t, i] for i in n ])== pth[t])
    end
    var = [pwl[i,j] for j in n for i in time]
    cost = JuMP.AffExpr(var,repeat(cost_p[2:end]./power_p[2:end],inner=length(time)),0.0)
    return cost
end