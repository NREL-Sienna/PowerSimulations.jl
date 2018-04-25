using PowerSystems
cd(string(homedir(),"/.julia/v0.6/PowerSystems/data_files"))
include("data_5bus.jl")

sys5 = PowerSystem(nodes5, generators5, loads5_DA, branches5, 230.0, 1000.0);

using JuMP
m = Model()


function GenerationVariables(m::JuMP.Model, PowerSystem::PowerSystem) 
    g_on_set = [g.name for g in PowerSystem.generators if g.status == true]
    t = 1:PowerSystem.timesteps
    @variable(m::JuMP.Model, P_g[g_on_set,t]) # Power output of generators
end

