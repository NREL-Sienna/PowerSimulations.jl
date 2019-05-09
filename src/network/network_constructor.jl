function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{CopperPlatePowerModel},
                            sys::PSY.ConcreteSystem,
                            time_range::UnitRange{Int64}; kwargs...)

    buses = PSY.get_components(PSY.Bus, sys)                             
    bus_count = length(sum(length, buses.it))
    
    copper_plate(ps_m, :nodal_balance_active, bus_count, time_range)

    return
end

function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{StandardPTDFForm},
                            sys::PSY.ConcreteSystem,
                            time_range::UnitRange{Int64}; kwargs...)

    if :PTDF in keys(kwargs)

        ac_branches = collect(PSY.get_components(PSY.ACBranch, sys))

        flow_variables(ps_m, system_formulation, ac_branches, time_range)

        ptdf_networkflow(ps_m, ac_branches, sys.buses, :nodal_balance_active, kwargs[:PTDF], time_range)

    else
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    return

end

function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{S},
                            sys::PSY.ConcreteSystem,
                            time_range::UnitRange{Int64}; kwargs...) where {S <: PM.AbstractPowerFormulation}

    powermodels_network!(ps_m, system_formulation, sys, time_range)

    return

end