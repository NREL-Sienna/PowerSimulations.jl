function validate_available_devices(
    model::DeviceModel{T, <:AbstractDeviceFormulation},
    system::PSY.System,
) where {T <: Union{PSY.Device, PSY.HydroReservoir}}
    devices =
        get_available_components(model,
            system,
        )
    if isempty(devices)
        return false
    end
    PSY.check_components(system, devices)
    return true
end
