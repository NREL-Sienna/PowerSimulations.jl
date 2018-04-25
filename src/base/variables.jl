# To Do
# 1. Eliminate P_g Variables that are not needed in a smart way. 
# 2. Create Variables for ac_pf network model.
# 3. Add limits to the constraints when creating the variable

function GenerationVariables(m::JuMP.Model, PowerSystem::PowerSystem) 
    g_on_set = [g.name for g in PowerSystem.generators if g.status == true]
    t = 1:PowerSystem.timesteps
    @variable(m, P_g[g_on_set,t]) # Power output of generators
end

function CommitmentVariables(m::JuMP.Model, PowerSystem::PowerSystem)
    g_on_set = [g.name for g in PowerSystem.generators if g.status == true]
    t = 1:PowerSystem.timesteps
    @variable(uc, start[g_on_set,t], Bin)
    @variable(uc, stop[g_on_set,t], Bin)
    @variable(uc, status[g_on_set,t], Bin) 
end

function BranchFlowVariables(m::JuMP.Model, PowerSystem::PowerSystem)
    b_on_set = [b.name for b in PowerSystem.network.branches if b.status == true]
    t = 1:PowerSystem.timesteps
    @variable(m, f_b[b_on_set,t])
end


function InterruptibleLoadVariables(m::JuMP.Model, PowerSystem::PowerSystem)
    il_on_set = [il.name for il in PowerSystem.loads if (il.status == true && typeof(il) != StaticLoad)]
    t = 1:PowerSystem.timesteps
    @variable(m, P_l[il_on_set,t]) 
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