function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{CopperPlatePowerModel},
                            sys::PSY.System,
                            lookahead::UnitRange{Int64}; kwargs...)

    buses = PSY.get_components(PSY.Bus, sys)                             
    bus_count = length(buses)
    
    copper_plate(ps_m, :nodal_balance_active, bus_count, lookahead)

    return
end

function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{StandardPTDFForm},
                            sys::PSY.System,
                            lookahead::UnitRange{Int64}; kwargs...)

    if :PTDF in keys(kwargs)
        buses = PSY.get_components(PSY.Bus, sys)
        ac_branches = PSY.get_components(PSY.ACBranch, sys)
        flow_variables(ps_m, system_formulation, ac_branches, lookahead)
        ptdf_networkflow(ps_m, ac_branches, buses, :nodal_balance_active, kwargs[:PTDF], lookahead)
    else
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    return

end

function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{S},
                            sys::PSY.System,
                            lookahead::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractPowerFormulation}

    incompat_list = [PM.SDPWRMForm,
                     PM.SparseSDPWRMForm,
                     PM.SOCWRConicForm,
                     PM.SOCBFForm,
                     PM.SOCBFConicForm]

    if system_formulation in incompat_list
       throw(ArgumentError("$(sys) formulation is not currently supported in PowerSimulations"))
    end                         

    powermodels_network!(ps_m, system_formulation, sys, lookahead)

    return

end