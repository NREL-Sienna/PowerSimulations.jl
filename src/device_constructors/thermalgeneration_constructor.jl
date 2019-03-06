"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             D <: AbstractThermalFormulation,
                                             S <: PM.AbstractPowerFormulation}

    #wrangle initial_conditions
    if !isempty(keys(ps_m.initial_conditions))

        "status_initial_conditions" in keys(ps_m.initial_conditions) ? status_initial_conditions = ps_m.initial_conditions["status_initial_conditions"] : @warn("No status initial conditions provided")

        "ramp_initial_conditions" in keys(ps_m.initial_conditions) ? ramp_initial_conditions = ps_m.initial_conditions["ramp_initial_conditions"] : @warn("No ramp initial conditions provided")

        "time_initial_conditions" in keys(ps_m.initial_conditions) ? time_initial_conditions = ps_m.initial_conditions["time_initial_conditions"] : @warn("No duration initial conditions provided")

    else

        @warn("Initial Conditions not provided, this can lead to infeasible problem formulations")

        status_initial_conditions = zeros(length(sys.generators.thermal))

        ramp_initial_conditions = zeros(length(sys.generators.thermal))

        time_initial_conditions = hcat(9999*ones(length(sys.generators.thermal)), zeros(length(sys.generators.thermal)))

    end

    #Variables

    #TODO: Enable Initial Conditions for variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    reactivepower_variables(ps_m, sys.generators.thermal, time_range);

    commitment_variables(ps_m, sys.generators.thermal, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    commitment_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, status_initial_conditions)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, ramp_initial_conditions)

    time_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, time_initial_conditions)

    #TODO: rate constraints

    #Cost Function

    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return nothing

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             D <: AbstractThermalFormulation,
                                             S <: PM.AbstractActivePowerFormulation}

    #wrangle initial_conditions
    if !isempty(keys(ps_m.initial_conditions))

        "status_initial_conditions" in keys(ps_m.initial_conditions) ? status_initial_conditions = ps_m.initial_conditions["status_initial_conditions"] : @warn("No status initial conditions provided")

        "ramp_initial_conditions" in keys(ps_m.initial_conditions) ? ramp_initial_conditions = ps_m.initial_conditions["ramp_initial_conditions"] : @warn("No ramp initial conditions provided")

        "time_initial_conditions" in keys(ps_m.initial_conditions) ? time_initial_conditions = ps_m.initial_conditions["time_initial_conditions"] : @warn("No duration initial conditions provided")

    else

        @warn("Initial Conditions not provided, this can lead to infeasible problems")

        status_initial_conditions = zeros(length(sys.generators.thermal))

        ramp_initial_conditions = zeros(length(sys.generators.thermal))

        time_initial_conditions = hcat(9999*ones(length(sys.generators.thermal)), zeros(length(sys.generators.thermal)))

    end

    #Variables

    #TODO: Enable Initial Conditions for variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    commitment_variables(ps_m, sys.generators.thermal, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    commitment_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, status_initial_conditions)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, ramp_initial_conditions)

    time_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, time_initial_conditions)

    #TODO: rate constraints

    #Cost Function

    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return nothing

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{PSI.ThermalRampLimited},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             S <: PM.AbstractPowerFormulation}

    #wrangle initial_conditions
    if !isempty(keys(ps_m.initial_conditions))

        "ramp_initial_conditions" in keys(ps_m.initial_conditions) ? ramp_initial_conditions = ps_m.initial_conditions["ramp_initial_conditions"] : @warn("No ramp initial conditions provided")

    else

        @warn("Initial Conditions not provided, this can lead to infeasible problem formulations")

        status_initial_conditions = zeros(length(sys.generators.thermal))

        ramp_initial_conditions = zeros(length(sys.generators.thermal))

        time_initial_conditions = hcat(9999*ones(length(sys.generators.thermal)), zeros(length(sys.generators.thermal)))

    end

    #Variables

    #TODO: Enable Initial Conditions for variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    reactivepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, ramp_initial_conditions)

    #TODO: rate constraints

    #Cost Function

    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return nothing

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{ThermalRampLimited},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             S <: PM.AbstractActivePowerFormulation}

    #wrangle initial_conditions
    if !isempty(keys(ps_m.initial_conditions))

        "ramp_initial_conditions" in keys(ps_m.initial_conditions) ? ramp_initial_conditions = ps_m.initial_conditions["ramp_initial_conditions"] : @warn("No ramp initial conditions provided")

    else

        @warn("Initial Conditions not provided, this can lead to infeasible problems")

        ramp_initial_conditions = zeros(length(sys.generators.thermal))

    end

   #Variables

    #TODO: Enable Initial Conditions for variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, ramp_initial_conditions)

    #TODO: rate constraints

    #Cost Function

    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return nothing

end



function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T<: PSY.ThermalGen,
                                             D <: AbstractThermalDispatchForm,
                                             S <: PM.AbstractPowerFormulation}

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    reactivepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    #TODO: rate constraints

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return nothing

end

function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T<: PSY.ThermalGen,
                                             D <: AbstractThermalDispatchForm,
                                             S <: PM.AbstractActivePowerFormulation}

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return nothing

end
