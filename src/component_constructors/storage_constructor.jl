function constructdevice!(ps_m::CanonicalModel, category::Type{St}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {St <: PSY.Storage, D <: PSI.AbstractStorageForm, S <: PM.AbstractPowerFormulation}

    #wrangle initial_conditions
    if :initial_conditions in keys(kwargs)

        initial_conditions = kwargs[:initial_conditions]

        "energy_initial_conditions" in keys(initial_conditions) ? status_initial_conditions = initial_conditions["energy_initial_conditions"] : @warn("No energy initial conditions provided")

    else

        initial_conditions = Dict{"String",Any}()

        @warn("Initial Conditions not provided, this can lead to infeasible problems")

        energy_initial_conditions =

    end

    #Variables
    activepower_variables(ps_m, sys.storage, time_range);

    reactivepower_variables(ps_m, sys.storage, time_range);

    energystoragevariables(ps_m, sys.storage, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.storage, category_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.storage, category_formulation, system_formulation, time_range)

    # Energy Balanace limits

    #TODO: Energy Balance Constraints

end

function constructdevice!(ps_m::CanonicalModel, category::Type{St}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {St <: PSY.Storage, D <: PSI.AbstractStorageForm, S <: PM.AbstractActivePowerFormulation}

    #wrangle initial_conditions
    if :initial_conditions in keys(kwargs)

        initial_conditions = kwargs[:initial_conditions]

    else

        initial_conditions = Dict{"String",Any}()

        @warn("Initial Conditions not provided, this can lead to infeasible problems")

    end

    #Variables
    activepower_variables(ps_m, sys.storage, time_range);

    energystoragevariables(ps_m, sys.storage, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.storage, category_formulation, system_formulation, time_range)

    # Energy Balanace limits

    #TODO: Energy Balance Constraints

end