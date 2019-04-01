function value(p::InitialCondition{Float64})
    return p.value
end

function value(p::InitialCondition{Parameter})
    return PJ.value(p.value)
end