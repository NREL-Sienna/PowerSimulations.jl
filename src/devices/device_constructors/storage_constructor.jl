function construct_device!(ps_m::CanonicalModel,
                           device::Type{St},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {St <: PSY.Storage,
                                             D <: PSI.AbstractStorageForm,
                                             S <: PM.AbstractPowerFormulation}

    #wrangle initial_conditions
    if  !isempty(keys(ps_m.initial_conditions))

        if "energy_initial_conditions" in keys(ps_m.initial_conditions)
             energy_initial_conditions = ps_m.initial_conditions["energy_initial_conditions"]
        else
             @warn("No energy initial conditions provided")
        end

    else

        @warn("Initial Conditions not provided, this can lead to infeasible problems")

        energy_initial_conditions = zeros(length(sys.storage))

    end

    #Variables
    activepower_variables(ps_m, sys.storage, time_range);

    reactivepower_variables(ps_m, sys.storage, time_range);

    energystorage_variables(ps_m, sys.storage, time_range);

    storagereservation_variables(ps_m, sys.storage, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.storage, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.storage, device_formulation, system_formulation, time_range)

    # Energy Balanace limits
    energy_balance_constraint(ps_m,sys.storage, device_formulation, system_formulation, time_range, energy_initial_conditions)

    #TODO: rate constraints

    return

end

function construct_device!(ps_m::CanonicalModel,
                           device::Type{St},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {St <: PSY.Storage,
                                             D <: PSI.AbstractStorageForm,
                                             S <: PM.AbstractActivePowerFormulation}

    #wrangle initial_conditions
    if !isempty(keys(ps_m.initial_conditions))

       if "energy_initial_conditions" in keys(ps_m.initial_conditions)
         energy_initial_conditions = ps_m.initial_conditions["energy_initial_conditions"]
       else
        @warn("No energy initial conditions provided")
       end

    else
        @warn("Initial Conditions not provided, this can lead to infeasible problems")

        energy_initial_conditions = zeros(length(sys.storage))

    end

    #Variables
    activepower_variables(ps_m, sys.storage, time_range);

    energystorage_variables(ps_m, sys.storage, time_range);

    storagereservation_variables(ps_m, sys.storage, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.storage, device_formulation, system_formulation, time_range)

    # Energy Balanace limits
    energy_balance_constraint(ps_m,sys.storage, device_formulation, system_formulation, time_range, energy_initial_conditions)

    return

end
