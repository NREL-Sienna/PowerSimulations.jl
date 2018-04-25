function powerconstraints(P_g::JuMP.JuMPArray{JuMP.Variable})

for (ix, name) in enumerate(P_g.indexsets[1])
    if name == generators5[ix].name
        powerconstraints(EconomicDispatch, P_g[name,:], generators5[ix])
    
    else
        error("Bus name in Array and variable do not match")
    end
end

end