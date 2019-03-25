function construct_device!(ps_m::CanonicalModel,
                            device_model::DeviceModel,
                            system_formulation::Type{S},
                            system::PSY.PowerSystem,
                            time_range::UnitRange{Int64};
                            kwargs...) where {S <: PM.AbstractPowerFormulation}

    construct_device!(ps_m,
                      device_model.device,
                      device_model.formulation,
                      system_formulation,
                      system,
                      time_range;
                      kwargs...)

    return

end

function initial_condition(ps_m::CanonicalModel, 
                           device::PSY.PowerSystemDevice, 
                           value::Float64)
    
    return initial_contidion(device, 
                             ParameterJuMP.Parameter(ps_m.JuMPmodel, value))

end                         