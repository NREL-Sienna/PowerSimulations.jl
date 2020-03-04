function validate_available_devices(devices, device::Type{D}) where {D <: PSY.Device}

    if isempty(devices)
        @warn("The data doesn't include devices of type $(device), consider changing the device models")
        return true
    end

    return false

end
