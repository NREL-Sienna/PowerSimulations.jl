function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{CopperPlatePowerModel},
                            sys::PSY.System; kwargs...)

    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    copper_plate(ps_m, :nodal_balance_active, bus_count)

    return
end

function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{StandardPTDFForm},
                            sys::PSY.System; kwargs...)

    if :PTDF in keys(kwargs)
        buses = PSY.get_components(PSY.Bus, sys)
        ac_branches = PSY.get_components(PSY.ACBranch, sys)
        ptdf_networkflow(ps_m, ac_branches, buses, :nodal_balance_active, kwargs[:PTDF])

        dc_branches = PSY.get_components(PSY.DCBranch, sys)
        dc_branch_types = typeof.(dc_branches)
        for btype in Set(dc_branch_types)
            typed_dc_branches = PSY.FlattenIteratorWrapper(btype, Vector([[b for b in dc_branches if typeof(b) == btype]]))
            flow_variables(ps_m, StandardPTDFForm, typed_dc_branches)
        end

    else
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    return

end

function construct_network!(ps_m::CanonicalModel,
                            system_formulation::Type{S},
                            sys::PSY.System; kwargs...) where {S <: PM.AbstractPowerFormulation}

    incompat_list = [PM.SDPWRMForm,
                     PM.SparseSDPWRMForm,
                     PM.SOCWRConicForm,
                     PM.SOCBFForm,
                     PM.SOCBFConicForm]

    if system_formulation in incompat_list
       throw(ArgumentError("$(sys) formulation is not currently supported in PowerSimulations"))
    end

    powermodels_network!(ps_m, system_formulation, sys)
    add_pm_var_refs!(ps_m, system_formulation, sys)

    return

end