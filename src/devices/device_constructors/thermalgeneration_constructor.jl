"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.System,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             D <: AbstractThermalFormulation,
                                             S <: PM.AbstractPowerFormulation}

    parameters = get(kwargs, :parameters, true)

    if isempty(keys(ps_m.initial_conditions))
        @warn("Initial Conditions not provided, this can lead to infeasible problem formulations")
    end

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    reactivepower_variables(ps_m, sys.generators.thermal, time_range);

    commitment_variables(ps_m, sys.generators.thermal, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    commitment_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    time_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.System,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             D <: AbstractThermalFormulation,
                                             S <: PM.AbstractActivePowerFormulation}

    parameters = get(kwargs, :parameters, true)

    if isempty(keys(ps_m.initial_conditions))
        @warn("Initial Conditions not provided, this can lead to infeasible problem formulations")
    end

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    commitment_variables(ps_m, sys.generators.thermal, time_range)

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    commitment_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    time_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{PSI.ThermalRampLimited},
                           system_formulation::Type{S},
                           sys::PSY.System,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             S <: PM.AbstractPowerFormulation}

    if isempty(keys(ps_m.initial_conditions))
        @warn("Initial Conditions not provided, this can lead to infeasible problem formulations")
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    reactivepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{ThermalRampLimited},
                           system_formulation::Type{S},
                           sys::PSY.System,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             S <: PM.AbstractActivePowerFormulation}

    if isempty(keys(ps_m.initial_conditions))
        @warn("Initial Conditions not provided, this can lead to infeasible problem formulations")
    end

    parameters = get(kwargs, :parameters, true)

    #Variables
    activepower_variables(ps_m, sys.generators.thermal, time_range);

    #Constraints
    activepower_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range)

    ramp_constraints(ps_m, sys.generators.thermal, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return

end



function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.System,
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

    #Cost Function
    cost_function(ps_m, sys.generators.thermal, device_formulation, system_formulation)

    return

end

function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.System,
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

    return

end
