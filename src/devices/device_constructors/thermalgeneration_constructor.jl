"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.ConcreteSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             D <: AbstractThermalFormulation,
                                             S <: PM.AbstractPowerFormulation}

    isconcretetype(device) ? true : true    

    parameters = get(kwargs, :parameters, true)

    devices = collect(PSY.get_components(device, sys))

    #Variables
    activepower_variables(ps_m, devices, time_range);

    reactivepower_variables(ps_m, devices, time_range);

    commitment_variables(ps_m, devices, time_range)

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    commitment_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    ramp_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    time_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.ConcreteSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             D <: AbstractThermalFormulation,
                                             S <: PM.AbstractActivePowerFormulation}

    parameters = get(kwargs, :parameters, true)
 
    devices = collect(PSY.get_components(device, sys))

    #Variables
    activepower_variables(ps_m, devices, time_range);

    commitment_variables(ps_m, devices, time_range)

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    commitment_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    ramp_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    time_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{PSI.ThermalRampLimited},
                           system_formulation::Type{S},
                           sys::PSY.ConcreteSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             S <: PM.AbstractPowerFormulation}


    parameters = get(kwargs, :parameters, true)

    devices = collect(PSY.get_components(device, sys))

    #Variables
    activepower_variables(ps_m, devices, time_range);

    reactivepower_variables(ps_m, devices, time_range);

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    ramp_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end


"""
This function creates the model for a full themal dispatch formulation depending on combination of devices, device_formulation and system_formulation
"""
function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{ThermalRampLimited},
                           system_formulation::Type{S},
                           sys::PSY.ConcreteSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T <: PSY.ThermalGen,
                                             S <: PM.AbstractActivePowerFormulation}

    parameters = get(kwargs, :parameters, true)

    devices = collect(PSY.get_components(device, sys))

    #Variables
    activepower_variables(ps_m, devices, time_range);

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    ramp_constraints(ps_m, devices, device_formulation, system_formulation, time_range, parameters)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end



function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.ConcreteSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T<: PSY.ThermalGen,
                                             D <: AbstractThermalDispatchForm,
                                             S <: PM.AbstractPowerFormulation}

                                            
    devices = collect(PSY.get_components(device, sys))
  
    #Variables
    activepower_variables(ps_m, devices, time_range);

    reactivepower_variables(ps_m, devices, time_range);

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    reactivepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end

function construct_device!(ps_m::CanonicalModel,
                           device::Type{T},
                           device_formulation::Type{D},
                           system_formulation::Type{S},
                           sys::PSY.ConcreteSystem,
                           time_range::UnitRange{Int64};
                           kwargs...) where {T<: PSY.ThermalGen,
                                             D <: AbstractThermalDispatchForm,
                                             S <: PM.AbstractActivePowerFormulation}
                                           
    devices = collect(PSY.get_components(device, sys))

    #Variables
    activepower_variables(ps_m, devices, time_range);

    #Constraints
    activepower_constraints(ps_m, devices, device_formulation, system_formulation, time_range)

    #Cost Function
    cost_function(ps_m, devices, device_formulation, system_formulation)

    return

end
