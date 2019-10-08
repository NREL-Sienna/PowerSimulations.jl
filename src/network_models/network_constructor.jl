function _internal_network_constructor(canonical::CanonicalModel,
                                        system_formulation::Type{CopperPlatePowerModel},
                                        sys::PSY.System;
                                        kwargs...)

    buses = PSY.get_components(PSY.Bus, sys)
    bus_count = length(buses)

    copper_plate(canonical, :nodal_balance_active, bus_count)

    return
end

function _internal_network_constructor(canonical::CanonicalModel,
                                        system_formulation::Type{StandardPTDF},
                                        sys::PSY.System;
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
            flow_variables(canonical,
                           StandardPTDF,
                           typed_dc_branches)
        end

    else
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    return

end

function _internal_network_constructor(canonical::CanonicalModel,
                                        system_formulation::Type{T},
                                        sys::PSY.System;
                                        kwargs...) where {T<:PM.AbstracPowerModel}

    incompat_list = [PM.SDPWRMForm,
                     PM.SparseSDPWRMForm,
                     PM.SOCWRConicForm,
                     PM.SOCBFForm,
                     PM.SOCBFConicForm]

    if system_formulation in incompat_list
       throw(ArgumentError("$(sys) formulation is not currently supported in PowerSimulations"))
    end

    powermodels_network!(canonical, system_formulation, sys)
    add_pm_var_refs!(canonical, system_formulation, sys)

    return

end

function construct_network!(op_model::OperationModel,
                            system_formulation::Type{S}; kwargs...) where {S<:PM.AbstracPowerModel}

    sys = get_system(op_model)
    _internal_network_constructor(op_model.canonical, system_formulation, sys; kwargs... )

    return

end
