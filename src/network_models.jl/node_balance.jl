function KCL(m::JuMP.Model, bus, network, p_g, f_b, loads)
    
    sum(P_g[generators[i].name, t] for i = 1:n_g
       if generators[i].bus.Number == )  == 
sum(loads[i].maxrealpower*loads[i].scalingfactor.values[t] for i = 1:n_l
       if loads[i].bus.Number == n))


end   