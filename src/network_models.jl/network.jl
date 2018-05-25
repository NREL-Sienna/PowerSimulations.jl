export NetworkBuild

function NetworkBuild(branches::Array{T}, nodes::Array{Bus}) where {T<:Branch}
    ybus = PowerSystems.build_ybus(buscount,branches);
    ptdf, A = PowerSystems.build_ptdf(buscount, branches, nodes)

    return Network(branches, ybus, ptdf, A) 
    
end