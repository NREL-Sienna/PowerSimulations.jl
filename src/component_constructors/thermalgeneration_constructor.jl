"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function constructdevice!(ps_m::CanonicalModel, category::Type{T}, category_formulation::Type{D}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {T <: PSY.ThermalGen, D <: AbstractThermalFormulation, S <: PM.AbstractPowerFormulation}

    #wrangle initial_conditions
    if :initial_conditions in keys(kwargs)

        initial_conditions = kwargs[:initial_conditions]

        "status_initial_conditions" in keys(initial_conditions) ? status_initial_conditions = initial_conditions["status_initial_conditions"] : @warn("No status initial conditions provided")

        "ramp_initial_conditions" in keys(initial_conditions) ? ramp_initial_conditions = initial_conditions["ramp_initial_conditions"] : @warn("No ramp initial conditions provided")

        "time_initial_conditions" in keys(initial_conditions) ? time_initial_conditions = initial_conditions["time_initial_conditions"] : @warn("No duration initial conditions provided")

    else

        @warn("Initial Conditions not provided, this can lead to infeasible problems")

        status_initial_conditions = zeros(length(sys.generators.thermal))

        ramp_initial_conditions = zeros(length(sys.generators.thermal))

        time_initial_conditions = hcat(zeros(length(sys.generators.thermal)), 9999*ones(length(sys.generators.thermal)))

    end

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    #Variables

    #TODO: Enable Initial Conditions for variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    reactivepower_variables(ps_m, sys.generators.thermal, time_range);

    commitment_variables(ps_m, sys.generators.thermal, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    commitment_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range, status_initial_conditions)

    ramp_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range, ramp_initial_conditions)

    time_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range, time_initial_conditions)

    #TODO: rate constraints

    #Cost Function

    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end


function constructdevice!(ps_m::CanonicalModel, category::Type{T}, category_formulation::Type{PSI.ThermalDispatch}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {T<: PSY.ThermalGen, S <: PM.AbstractPowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    reactivepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    #TODO: rate constraints

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end

function constructdevice!(ps_m::CanonicalModel, category::Type{T}, category_formulation::Type{PSI.ThermalDispatch}, system_formulation::Type{S}, sys::PSY.PowerSystem; kwargs...) where {T<: PSY.ThermalGen, S <: PM.AbstractActivePowerFormulation}

    #Defining this outside in order to enable time slicing later
    time_range = 1:sys.time_periods

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, category_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, category_formulation, system_formulation)

end