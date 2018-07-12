function variablecostgen(m::JuMP.Model, pth::JuMP.JuMPArray{JuMP.Variable}, generators::Array{T}) where T <: PowerSystems.ThermalGen

    cost = 0.0;
    linear, pwl, func = PowerSimulations.cost_filter(pth, generators)
    for (ix, name) in enumerate(pth.indexsets[1])
        if name == generators[ix].name
            if (name in linear) | (name in func)
                for time in pth.indexsets[2]
                    cost = cost + PowerSimulations.gencost(pth[string(name),time], generators[ix].econ.variablecost)
                end
            elseif name in pwl
                cost = cost + gencost(m, pth[string(name),pth.indexsets[2]], generators[ix].econ.variablecost)
            else
                warn("Cost type unknown")
            end
        else
            error("Bus name in Array and variable do not match")
        end
    end
    
    return cost

end

function gencost(X::JuMP.Variable, cost_component::Real)

    return cost = X*cost_component
end

function gencost(X::JuMP.Variable, cost_component::Function)

    return cost_component(X)
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

function gencost(m::JuMP.Model, pth::Array{JuMP.Variable,1},  cost_component::Array)
    cost_p =  [i for (ix,i) in enumerate(cost_component) if iseven(ix)]
    power_p = [i for (ix,i) in enumerate(cost_component) if isodd(ix)]
    time = 1:Int(length(pth))
    n = 1:Int((length(cost_component)/2)-1)
    @variable(m, pwl[time,n])
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