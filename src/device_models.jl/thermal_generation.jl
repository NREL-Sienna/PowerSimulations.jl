function PowerConstraints(m::JuMP.Model, P_g::JuMP.JuMPArray{JuMP.Variable}, source::ThermalGen)
    for var in P_g
        @constraint(m::JuMP.Model, var >= source.tech.realpowerlimits.min)
        @constraint(m::JuMP.Model, var <= source.tech.realpowerlimits.max)
    end
end

function RampConstraints(m::JuMP.Model, P_g::JuMP.JuMPArray{JuMP.Variable}, source::ThermalGen)


end

function TimeConstraints(m::JuMP.Model, UC_g::JuMP.JuMPArray{JuMP.Variable}, source::Thermalgen) 


end