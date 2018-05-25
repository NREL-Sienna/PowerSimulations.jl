



function GenerationVariables(m::JuMP.Model, PowerSystem::PowerSystem) 
    th_on_set = [g.name for g in PowerSystem.generators if (g.status == true && !isa(g,ReFix))]
    t = 1:PowerSystem.timesteps
    @variable(m::JuMP.Model, P_th[g_on_set,t]) # Power output of generators
    return true    
end



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