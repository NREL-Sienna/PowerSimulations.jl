function validate_available_devices(
    device_model::DeviceModel{T, <:AbstractDeviceFormulation},
    system::PSY.System,
) where {T <: PSY.Device}
    devices =
        get_available_components(T, system, get_attribute(device_model, "filter_function"))
    if isempty(devices)
        return false
    end
    PSY.check_components(system, devices)
    return true
end
