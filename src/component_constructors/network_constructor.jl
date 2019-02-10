function constructnetwork!(ps_m::CanonicalModel, system_formulation::Type{CopperPlatePowerModel}, sys::PSY.PowerSystem; kwargs...)

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods
    bus_count = length(sys.buses)

    copper_plate(ps_m, "var_active", bus_count, time_range)


end

function constructnetwork!(ps_m::CanonicalModel, system_formulation::Type{StandardPTDFModel}, sys::PSY.PowerSystem; kwargs...)

    if :PTDF in keys(kwargs)

        #Defining this outside in order to enable time slicing later
        time_range = 1:sys.time_periods

        ac_branches = [br for br in sys.branches if !isa(br, PSY.DCLine)]

        flowvariables(ps_m, system_formulation, ac_branches, time_range)

        ptdf_networkflow(ps_m, ac_branches, sys.buses, "var_active", kwargs[:PTDF], time_range)

    else
        throw(ArgumentError("no PTDF matrix supplied"))
    end

    #=
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; args..., PTDF=PTDF)
    end
    =#

end

function constructnetwork!(ps_m::CanonicalModel, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {S <: PM.AbstractPowerFormulation}

    time_range = 1:sys.time_periods

    powermodels_network!(ps_m, system_formulation, sys, time_range)

    #=
    for category in branch_models
        constructdevice!(m, netinjection, category.device, category.formulation, system_formulation, sys; kwargs...)
    end
    =#


end