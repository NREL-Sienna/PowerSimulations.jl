function validate_available_devices(device::Type{D}, devices) where {D <: PSY.Device}
    if isempty(devices)
        @warn("The data doesn't include devices of type $(device), consider changing the device models")
        return false
    end
    return true
end

function validate_available_services(service::Type{S}, services) where {S <: PSY.Service}
    if isempty(services)
        @warn("The data doesn't include services of type $(service), consider changing the service models")
        return false
    end
    return true
end
