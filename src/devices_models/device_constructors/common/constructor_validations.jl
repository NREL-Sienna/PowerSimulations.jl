function validate_available_devices(device::Type{D}, devices) where {D <: PSY.Device}
    if isempty(devices)
        @warn("The data doesn't include devices of type $(device), consider changing the device models")
        return false
    end
    return true
end

function validate_available_services(service::Type{S}, services::Vector{S}, sys::PSY.System) where {S <: PSY.Service}
    services_ = PSY.get_components(S, sys)
    if isempty(services_)
        @warn("The data doesn't include services of type $(service), consider changing the service models")
        return false
    end

    services_mapping = PSY.get_contributing_device_mapping(sys)
    for s in services_
        if !isempty(services_mapping[(type = S, name = PSY.get_name(s))].contributing_devices)
            push!(services, s)
        end
    end
    return true
end
