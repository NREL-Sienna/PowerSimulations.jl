mutable struct DeviceModel{D <: PSY.PowerSystemDevice,
                           B <: PSI.AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
end



function construct_device!(ps_m::CanonicalModel,
                           device_model::DeviceModel,
                           system_formulation::Type{S},
                           sys::PSY.PowerSystem;
                           kwargs...) where {S <: PM.AbstractPowerFormulation}

    construct_device!(ps_m,
                      device_model.device,
                      device_model.formulation,
                      system_formulation,
                      sys; kwargs...)

end
