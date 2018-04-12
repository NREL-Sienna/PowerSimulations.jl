function generationvariables(m::JuMP.Model, data)

    @variable(m::JuMP.Model, P_g[g_set = [generators[i].name for i in 1:n_g], t = 1:sys.timesteps]) # Power output of generators

end

function branchflowvariables(m::JuMP.Model,data)

    @variable(m::JuMP.Model, f_b[1:length(Net5.branches)])

end

function commitmentvariables(uc, data)

    @variable(uc, start[g_set = [generators[i].name for i in 1:n_g], t = 1:sys.timesteps], Bin)
    @variable(uc, stop[g_set = [generators[i].name for i in 1:n_g], t = 1:sys.timesteps], Bin)
    @variable(uc, status[g_set = [generators[i].name for i in 1:n_g], t = 1:sys.timesteps], Bin) 

end

function voltagevariables(m::JuMP.Model, data)

    @variable(m::JuMP.Model, voltage_n[1:sys.busquantity]) # if one were to define voltages for full ac - opf 

end

function anglevariables(m::JuMP.Model, data)

    @variable(m::JuMP.Model, theta_n[1:sys.busquantity]) # if one were to define angles for dc - opf 

end

function residualvariables(m::JuMP.Model, data)

    @variable(m::JuMP.Model, epsilon_n[1:sys.busquantity])

end