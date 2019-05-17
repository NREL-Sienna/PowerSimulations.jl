function construct_device!(ps_m::CanonicalModel,
                            device_model::DeviceModel,
                            system_formulation::Type{S},
                            sys::PSY.System,
                            lookahead::UnitRange{Int64},
                            resolution::Dates.Period;
                            kwargs...) where {S <: PM.AbstractPowerFormulation}

    _internal_device_constructor!(ps_m,
                                  device_model.device,
                                  device_model.formulation,
                                  system_formulation,
                                  sys,
                                  lookahead,
                                  resolution;
                                  kwargs...)

    return

end

function InitialCondition(ps_m::CanonicalModel,
                           device::PSY.Device,
                           value::Float64)

    return InitialCondition(device,
                             PJ.add_parameter(ps_m.JuMPmodel, value))

end