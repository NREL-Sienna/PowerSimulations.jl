function validate_available_devices(devices, device::Type{D}) where {D <: PSY.Device}
    if isempty(devices)
        @warn("The data doesn't include devices of type $(device), consider changing the device models")
        return true
    end
    return false
end

function validate_available_services(services, service::Type{S}) where {S <: PSY.Service}
    if isempty(services)
        @warn("The data doesn't include services of type $(service), consider changing the service models")
        return true
    end
    return false
end
