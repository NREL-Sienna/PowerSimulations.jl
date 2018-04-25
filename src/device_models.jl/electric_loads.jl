function PowerConstraints(m::JuMP.Model, P_g::JuMP.JuMPArray{JuMP.Variable}, source::ThermalGen)
    for var in P_g
        @constraint(m, var >= source.tech.realpowerlimits.min)
        @constraint(m, var <= source.tech.realpowerlimits.max)
    end
end