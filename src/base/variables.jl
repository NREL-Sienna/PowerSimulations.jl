# To Do
# 1. Eliminate P_g Variables that are not needed in a smart way. 
# 2. Create Variables for ac_pf network model.
# 3. Add limits to the constraints when creating the variable

function GenerationVariables(m::JuMP.Model, PowerSystem::PowerSystem) 
    g_on_set = [g.name for g in PowerSystem.generators if g.status]
    t = 1:PowerSystem.timesteps
    @variable(m, P_g[g_on_set,t]) # Power output of generators
end

function CommitmentVariables(m::JuMP.Model, PowerSystem::PowerSystem)
    g_on_set = [g.name for g in PowerSystem.generators if g.status]
    t = 1:PowerSystem.timesteps
    @variable(uc, start[g_on_set,t], Bin)
    @variable(uc, stop[g_on_set,t], Bin)
    @variable(uc, status[g_on_set,t], Bin) 
end

function BranchFlowVariables(m::JuMP.Model, PowerSystem::PowerSystem)
    br_on_set = [br.name for br in PowerSystem.network.branches if br.status]
    t = 1:PowerSystem.timesteps
    @variable(m, f_br[br_on_set,t])
end


function ControlableLoadVariables(m::JuMP.Model, PowerSystem::PowerSystem)
    cl_on_set = [cl.name for cl in PowerSystem.loads if (cl.status && typeof(cl) != StaticLoad)]
    t = 1:PowerSystem.timesteps
    @variable(m, P_cl[cl_on_set,t]) 
end

#=
function voltagevariables(m::JuMP.Model, data)

    @variable(m::JuMP.Model, voltage_n[1:sys.busquantity]) # if one were to define voltages for full ac - opf 

end

function anglevariables(m::JuMP.Model, data)

    @variable(m::JuMP.Model, theta_n[1:sys.busquantity]) # if one were to define angles for dc - opf 

end

function residualvariables(m::JuMP.Model, data)

    @variable(m::JuMP.Model, epsilon_n[1:sys.busquantity])

end
=#