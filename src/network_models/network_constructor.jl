function construct_network!(canonical::Canonical, sys::PSY.System,
                            system_formulation::Type{CopperPlatePowerModel};
                            kwargs...)


    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    copper_plate(canonical, :nodal_balance_active, bus_count)

    return
end

function construct_network!(canonical::Canonical, sys::PSY.System,
                            system_formulation::Type{StandardPTDFModel};
                            kwargs...)

    if :PTDF in keys(kwargs)
        buses = PSY.get_components(PSY.Bus, sys)
        ac_branches = PSY.get_components(PSY.ACBranch, sys)
        ptdf_networkflow(canonical,
                         ac_branches,
                         buses,
                         :nodal_balance_active,
                         kwargs[:PTDF])

        dc_branches = PSY.get_components(PSY.DCBranch, sys)
        dc_branch_types = typeof.(dc_branches)
        for btype in Set(dc_branch_types)
            typed_dc_branches = IS.FlattenIteratorWrapper(btype, Vector([[b for b in dc_branches if typeof(b) == btype]]))
            flow_variables!(canonical,
                           StandardPTDFModel,
                           typed_dc_branches)
        end

    else
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    return

end

function construct_network!(canonical::Canonical,
                            sys::PSY.System,
                            ::Type{T};
                            kwargs...) where {T<:PM.AbstractPowerModel}


    incompat_list = [PM.SDPWRMPowerModel,
                     PM.SparseSDPWRMPowerModel,
                     PM.SOCBFPowerModel,
                     PM.SOCBFConicPowerModel]

    if T in incompat_list
       throw(ArgumentError("$(T) formulation is not currently supported in PowerSimulations"))
    end

    powermodels_network!(canonical, T, sys)
    add_pm_var_refs!(canonical, T, sys)

    return

end
