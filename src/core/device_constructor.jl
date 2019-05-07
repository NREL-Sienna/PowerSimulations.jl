function construct_device!(ps_m::CanonicalModel,
                            device_model::DeviceModel,
                            system_formulation::Type{S},
                            system::PSY.ConcreteSystem,
                            time_range::UnitRange{Int64};
                            kwargs...) where {S <: PM.AbstractPowerFormulation}

    _internal_device_constructor!(ps_m,
                                  device_model.device,
                                  device_model.formulation,
                                  system_formulation,
                                  system,
                                  time_range;
                                  kwargs...)

    return

end

function InitialCondition(ps_m::CanonicalModel,
                           device::PSY.Device,
                           value::Float64)

    return InitialCondition(device,
                             PJ.add_parameter(ps_m.JuMPmodel, value))

end