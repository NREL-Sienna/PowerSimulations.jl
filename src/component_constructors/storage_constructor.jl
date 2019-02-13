function constructdevice!(ps_m::CanonicalModel, category::Type{St}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {St <: PSY.Storage, D <: PSI.AbstractStorageForm, S <: PM.AbstractPowerFormulation}

    #Variables
    activepower_variables(ps_m, sys.storage, time_range);

    reactivepower_variables(ps_m, sys.storage, time_range);

    energystoragevariables(ps_m, sys.storage, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.storage, category_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.storage, category_formulation, system_formulation, time_range)

end

function constructdevice!(ps_m::CanonicalModel, category::Type{St}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {St <: PSY.Storage, D <: PSI.AbstractStorageForm, S <: PM.AbstractActivePowerFormulation}

    #Variables
    activepower_variables(ps_m, sys.storage, time_range);

    energystoragevariables(ps_m, sys.storage, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.storage, category_formulation, system_formulation, time_range)

end