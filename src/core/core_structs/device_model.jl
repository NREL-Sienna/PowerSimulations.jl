abstract type AbstractDeviceFormulation end

mutable struct DeviceModel{D <: PSY.PowerSystemDevice,
                           B <: PSI.AbstractDeviceFormulation}
    device::Type{D}
    formulation::Type{B}
end

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
    
    return nothing

end
